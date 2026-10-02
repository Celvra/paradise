import 'dart:math';

import 'human_models.dart';

// The user owned sticker library. Entries come from three places: the built in
// seed, the user (settings page, GIF tab) and the assistant (save_sticker). The
// assistant picks from it by emotion and context, never at random.

enum StickerKind { emoji, image, gif }

class UserSticker {
  UserSticker({
    required this.id,
    required this.kind,
    required this.value,
    this.name = '',
    List<String>? tags,
    this.emotion = '',
    this.category = 'General',
    this.favorite = false,
    this.uses = 0,
    this.lastUsed = 0,
    int? createdAt,
    this.source = 'user',
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  StickerKind kind;

  /// the glyph for emoji, a file path or an https url for image and gif
  String value;
  String name;
  List<String> tags;

  /// one word mood such as "笑死", "无语", "敷衍"
  String emotion;
  String category;
  bool favorite;
  int uses;
  int lastUsed;
  final int createdAt;

  /// 'seed', 'user' or 'ai'
  String source;

  bool get isRemote => value.startsWith('http');

  String get label => name.isNotEmpty ? name : (tags.isNotEmpty ? tags.first : id);

  bool matches(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;
    return name.toLowerCase().contains(s) || emotion.toLowerCase().contains(s) || category.toLowerCase().contains(s) || tags.any((t) => t.toLowerCase().contains(s));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'value': value,
        'name': name,
        'tags': tags,
        'emotion': emotion,
        'category': category,
        'favorite': favorite,
        'uses': uses,
        'lastUsed': lastUsed,
        'createdAt': createdAt,
        'source': source,
      };

  factory UserSticker.fromJson(Map<String, dynamic> j) => UserSticker(
        id: j['id'] as String,
        kind: StickerKind.values.firstWhere((e) => e.name == j['kind'], orElse: () => StickerKind.emoji),
        value: j['value'] as String? ?? '',
        name: j['name'] as String? ?? '',
        tags: [for (final e in (j['tags'] as List? ?? const [])) '$e'],
        emotion: j['emotion'] as String? ?? '',
        category: j['category'] as String? ?? 'General',
        favorite: j['favorite'] as bool? ?? false,
        uses: (j['uses'] as num?)?.toInt() ?? 0,
        lastUsed: (j['lastUsed'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] as num?)?.toInt(),
        source: j['source'] as String? ?? 'user',
      );
}

/// Nothing is seeded any more. The library starts empty, the emoji tab covers
/// the plain glyphs and the assistant only sends what the user or the
/// save_sticker tool put here. Entries a previous build seeded stay in the
/// library, the user can clear them from the settings page in one go.
const String kStickerLibEmptyNote = 'The library is empty, the user has not added a sticker yet.';

class StickerLib {
  final List<UserSticker> items = [];
  final List<String> extraCategories = [];
  var _seq = 0;

  String newId() => 'stk_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_seq++}';

  void removeAll(Iterable<String> ids) {
    final set = ids.toSet();
    items.removeWhere((s) => set.contains(s.id));
  }

  void setFavorite(Iterable<String> ids, bool on) {
    for (final id in ids) {
      byId(id)?.favorite = on;
    }
  }

  /// Moves stickers into one category, an empty name puts them back to General.
  void moveTo(Iterable<String> ids, String category) {
    final name = category.trim().isEmpty ? 'General' : category.trim();
    for (final id in ids) {
      byId(id)?.category = name;
    }
    if (!extraCategories.contains(name)) extraCategories.add(name);
  }

  List<String> get categories {
    final s = <String>{...extraCategories, for (final i in items) i.category};
    return s.toList()..sort();
  }

  UserSticker? byId(String id) => items.where((s) => s.id == id).firstOrNull;

  UserSticker add({required StickerKind kind, required String value, String name = '', List<String>? tags, String emotion = '', String category = 'General', String source = 'user'}) {
    // the same image saved twice only merges the tags
    final dup = items.where((s) => s.value == value).firstOrNull;
    if (dup != null) {
      for (final t in tags ?? const <String>[]) {
        if (!dup.tags.contains(t)) dup.tags.add(t);
      }
      if (emotion.isNotEmpty) dup.emotion = emotion;
      return dup;
    }
    final s = UserSticker(id: newId(), kind: kind, value: value, name: name, tags: tags, emotion: emotion, category: category, source: source);
    items.add(s);
    return s;
  }

  void remove(String id) => items.removeWhere((s) => s.id == id);

  void markUsed(String id, {int? now}) {
    final s = byId(id);
    if (s == null) return;
    s.uses++;
    s.lastUsed = now ?? DateTime.now().millisecondsSinceEpoch;
  }

  List<UserSticker> search(String q, {String? category, bool favorites = false, StickerKind? kind}) => [
        for (final s in items)
          if (s.matches(q) && (category == null || s.category == category) && (!favorites || s.favorite) && (kind == null || s.kind == kind)) s,
      ];

  List<UserSticker> recent({int limit = 24}) {
    final l = items.where((s) => s.lastUsed > 0).toList()..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return l.take(limit).toList();
  }

  /// The catalogue shown to the model, id plus emotion plus tags, favourites
  /// and often used first so the list stays short.
  String catalogue({int limit = 40}) {
    final l = [...items]..sort((a, b) => ((b.favorite ? 5 : 0) + b.uses).compareTo((a.favorite ? 5 : 0) + a.uses));
    return l.take(limit).map((s) => '${s.id} [${s.emotion.isEmpty ? '-' : s.emotion}] ${s.tags.take(4).join('/')}${s.kind == StickerKind.emoji ? ' ${s.value}' : ' (${s.kind.name})'}').join('\n');
  }

  /// Chooses a sticker for a mood word or free text. The score is tag and
  /// emotion overlap, a little favour for favourites, a penalty for what was
  /// just used so the same one is not sent twice in a row. The pick among the
  /// top three is random (seeded) so it is not mechanical either.
  UserSticker? pick(String hint, {required double mood, required HumanRandom rng, int? now}) {
    if (items.isEmpty) return null;
    final t = now ?? DateTime.now().millisecondsSinceEpoch;
    final words = hint.toLowerCase().split(RegExp(r'[\s,，、/]+')).where((w) => w.isNotEmpty).toList();
    final scored = <(UserSticker, double)>[];
    for (final s in items) {
      var score = 0.0;
      for (final w in words) {
        if (s.emotion.toLowerCase() == w) score += 3;
        if (s.emotion.toLowerCase().contains(w) || w.contains(s.emotion.toLowerCase()) && s.emotion.isNotEmpty) score += 1.5;
        if (s.tags.any((tag) => tag.toLowerCase() == w)) score += 2;
        if (s.tags.any((tag) => tag.toLowerCase().contains(w) || (w.length > 1 && w.contains(tag.toLowerCase())))) score += 1;
        if (s.name.toLowerCase().contains(w)) score += 1;
      }
      if (words.isEmpty) score += 0.5;
      if (s.favorite) score += 0.4;
      // good mood leans to the cheerful ones, a low mood to the quiet ones
      final cheerful = const {'笑死', '开心', '喜欢', '比心', '坏笑'}.contains(s.emotion);
      final quiet = const {'无语', '敷衍', '委屈', '困'}.contains(s.emotion);
      if (mood >= 65 && cheerful) score += 0.4;
      if (mood <= 40 && quiet) score += 0.4;
      if (t - s.lastUsed < 60000 && s.lastUsed > 0) score -= 2;
      scored.add((s, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final top = scored.take(3).where((e) => e.$2 > 0 || words.isEmpty).toList();
    if (top.isEmpty) return null;
    return top[min(top.length - 1, (rng.next() * top.length).floor())].$1;
  }

  List<Map<String, dynamic>> toJson() => [for (final s in items) s.toJson()];

  void importJson(List<dynamic> raw, {required bool overwrite}) {
    if (overwrite) items.clear();
    final have = items.map((e) => e.id).toSet();
    for (final e in raw) {
      final s = UserSticker.fromJson(Map<String, dynamic>.from(e as Map));
      if (!have.contains(s.id)) items.add(s);
    }
  }
}
