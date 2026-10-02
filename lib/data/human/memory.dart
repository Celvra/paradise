import 'dart:math';

// Long term memory. The assistant writes entries with write_memory and reads
// them with read_memory, and before every generation the most relevant ones
// are injected into the context.
//
// Forgetting: every entry loses weight over time since it was last used. Under
// the threshold it is marked forgotten and stops being injected. Promises and
// todos are exempt, they stay until complete_todo or the user dismisses them.

enum MemType { preference, event, promise, todo, conflict }

MemType memTypeOf(String? raw) => MemType.values.firstWhere((e) => e.name == raw, orElse: () => MemType.event);

const _halfLifeDays = 30.0;
const _forgetBelow = 0.15;

class MemoryItem {
  MemoryItem({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    required this.lastAccess,
    this.weight = 1.0,
    this.forgotten = false,
    this.dueAt = 0,
    this.done = false,
    this.reminded = false,
    this.decayedAt = 0,
  });

  final String id;
  MemType type;
  String content;
  final int createdAt;
  int lastAccess;
  double weight;
  bool forgotten;

  /// optional due time for todos and promises, 0 means none
  int dueAt;
  bool done;
  bool reminded;
  int decayedAt;

  /// promises and todos are never forgotten while they are open
  bool get sticky => (type == MemType.promise || type == MemType.todo) && !done;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'content': content,
        'createdAt': createdAt,
        'lastAccess': lastAccess,
        'weight': weight,
        'forgotten': forgotten,
        'dueAt': dueAt,
        'done': done,
        'reminded': reminded,
        'decayedAt': decayedAt,
      };

  factory MemoryItem.fromJson(Map<String, dynamic> j) => MemoryItem(
        id: j['id'] as String,
        type: memTypeOf(j['type'] as String?),
        content: j['content'] as String? ?? '',
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        lastAccess: (j['lastAccess'] as num?)?.toInt() ?? 0,
        weight: (j['weight'] as num?)?.toDouble() ?? 1,
        forgotten: j['forgotten'] as bool? ?? false,
        dueAt: (j['dueAt'] as num?)?.toInt() ?? 0,
        done: j['done'] as bool? ?? false,
        reminded: j['reminded'] as bool? ?? false,
        decayedAt: (j['decayedAt'] as num?)?.toInt() ?? 0,
      );
}

class MemoryBank {
  final List<MemoryItem> items = [];
  var _seq = 0;

  String _id() => 'mem_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  MemoryItem write(MemType type, String content, {double weight = 1.0, int dueAt = 0, int? now}) {
    final t = now ?? DateTime.now().millisecondsSinceEpoch;
    final text = content.trim();
    // the same fact written twice strengthens the old entry instead of piling up
    for (final m in items) {
      if (m.type == type && m.content == text && !m.done) {
        m.weight = min(5, m.weight + 0.5);
        m.forgotten = false;
        m.lastAccess = t;
        if (dueAt > 0) m.dueAt = dueAt;
        return m;
      }
    }
    final m = MemoryItem(id: _id(), type: type, content: text, createdAt: t, lastAccess: t, weight: weight.clamp(0.1, 5), dueAt: dueAt, decayedAt: t);
    items.add(m);
    return m;
  }

  MemoryItem? byId(String id) => items.where((m) => m.id == id).firstOrNull;

  static Set<String> _tokens(String s) {
    final out = <String>{};
    final lower = s.toLowerCase();
    for (final w in RegExp(r'[a-z0-9]+').allMatches(lower)) {
      if (w.group(0)!.length > 1) out.add(w.group(0)!);
    }
    // CJK has no spaces so character bigrams stand in for words
    final cjk = lower.replaceAll(RegExp(r'[^\u4e00-\u9fff\u3040-\u30ff]'), '');
    for (var i = 0; i + 1 < cjk.length; i++) {
      out.add(cjk.substring(i, i + 2));
    }
    return out;
  }

  double _score(MemoryItem m, Set<String> q, int now) {
    final days = max(0, now - m.lastAccess) / 86400000;
    final recency = pow(0.5, days / 14).toDouble();
    var rel = 0.0;
    if (q.isNotEmpty) {
      final t = _tokens(m.content);
      final hit = t.intersection(q).length;
      rel = hit / max(3, q.length) * 3;
    }
    final stickyBoost = m.sticky ? 1.2 : 0;
    return m.weight * (0.5 + recency * 0.5) + rel + stickyBoost;
  }

  /// read_memory: by type and query, strongest first. Reading counts as use.
  List<MemoryItem> read({String query = '', MemType? type, int limit = 10, bool includeForgotten = false, int? now}) {
    final t = now ?? DateTime.now().millisecondsSinceEpoch;
    final q = _tokens(query);
    final list = items.where((m) => (includeForgotten || !m.forgotten) && (type == null || m.type == type)).toList();
    if (q.isNotEmpty) list.removeWhere((m) => _tokens(m.content).intersection(q).isEmpty && !m.content.toLowerCase().contains(query.toLowerCase()));
    list.sort((a, b) => _score(b, q, t).compareTo(_score(a, q, t)));
    final out = list.take(limit).toList();
    for (final m in out) {
      m.lastAccess = t;
      m.weight = min(5, m.weight + 0.1);
    }
    return out;
  }

  /// The batch injected before a generation. Open promises and todos always go
  /// in, the rest is picked by weight, recency and overlap with the user text.
  List<MemoryItem> forContext(String userText, {int limit = 12, int? now}) {
    final t = now ?? DateTime.now().millisecondsSinceEpoch;
    final q = _tokens(userText);
    final sticky = items.where((m) => m.sticky && !m.forgotten).toList();
    final rest = items.where((m) => !m.sticky && !m.forgotten && !m.done).toList()..sort((a, b) => _score(b, q, t).compareTo(_score(a, q, t)));
    final picked = [...sticky, ...rest.take(max(0, limit - sticky.length))];
    // injecting is not a use: only read_memory refreshes lastAccess, otherwise
    // nothing could ever fade
    return picked;
  }

  /// Applies the decay. Safe to call often, each entry only decays for the time
  /// since it was last decayed.
  int decay({int? now}) {
    final t = now ?? DateTime.now().millisecondsSinceEpoch;
    var forgot = 0;
    for (final m in items) {
      final from = max(m.decayedAt, m.lastAccess);
      m.decayedAt = t;
      if (m.sticky || m.forgotten) continue;
      final days = max(0, t - from) / 86400000;
      if (days <= 0) continue;
      m.weight *= pow(0.5, days / _halfLifeDays).toDouble();
      if (m.weight < _forgetBelow) {
        m.forgotten = true;
        forgot++;
      }
    }
    return forgot;
  }

  /// complete_todo, also used when the user says it is not needed any more.
  bool complete(String id) {
    final m = byId(id);
    if (m == null) return false;
    m.done = true;
    m.dueAt = 0;
    return true;
  }

  void remove(String id) => items.removeWhere((m) => m.id == id);

  List<MemoryItem> dueReminders(int now) => [for (final m in items) if (m.sticky && m.dueAt > 0 && m.dueAt <= now && !m.reminded) m];

  // ----------------------------------------------------------------- backup

  List<Map<String, dynamic>> toJson() => [for (final m in items) m.toJson()];

  /// merge keeps what is already here and adds the unknown ids, overwrite
  /// replaces the whole bank.
  void importJson(List<dynamic> raw, {required bool overwrite}) {
    if (overwrite) items.clear();
    final have = items.map((e) => e.id).toSet();
    for (final e in raw) {
      final m = MemoryItem.fromJson(Map<String, dynamic>.from(e as Map));
      if (!have.contains(m.id)) items.add(m);
    }
  }
}
