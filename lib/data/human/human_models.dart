import 'dart:math';

// Settings, randomness and the per chat state of the humanized assistant.

enum ToolPerm { allow, ask, deny }

ToolPerm permOf(String? raw) => ToolPerm.values.firstWhere((e) => e.name == raw, orElse: () => ToolPerm.allow);

T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) => values.firstWhere((e) => e.name == raw, orElse: () => fallback);

double _d(Object? v, double f) => (v as num?)?.toDouble() ?? f;
int _i(Object? v, int f) => (v as num?)?.toInt() ?? f;
bool _b(Object? v, bool f) => v as bool? ?? f;
String _s(Object? v, String f) => v as String? ?? f;

/// Every knob the user can reach from Settings > Humanize.
class HumanSettings {
  HumanSettings();

  // master switches
  bool enabled = true;
  bool wallet = true;

  // <i-br> and randomness
  bool br = true;
  int brDefaultMs = 600;
  double randomRange = 0.2;

  /// null draws a fresh sequence each turn, a number replays the same dice for
  /// the same chat and turn counter so a run can be reproduced.
  int? seed;
  double typoProb = 0.05;
  double particleProb = 0.2;
  double splitProb = 0.6;

  /// 0 normal, 1 loose (fewer full stops, more ellipses), 2 minimal
  int punct = 0;

  // proactive messages
  bool proactive = true;
  int maxConsecutive = 3;
  bool quiet = true;
  int quietStart = 23 * 60;
  int quietEnd = 8 * 60;
  bool dnd = false;
  bool allowUrgent = false;
  bool greetMorning = true;
  bool greetEvening = true;
  int morningAt = 8 * 60 + 30;
  int eveningAt = 22 * 60;
  int icebreakDays = 3;

  // stickers
  double stickerFreq = 0.35;
  bool aiSaveSticker = true;
  bool stickerOnly = true;

  // recall
  bool recall = true;
  int recallPerHour = 4;
  int recallWindowSec = 180;

  // tool permissions by tool name, absent means the default for its origin
  final Map<String, String> perms = {};

  // voice
  String ttsUrl = '';
  String ttsKey = '';
  String ttsModel = 'tts-1';
  String ttsVoice = 'alloy';
  double ttsSpeed = 1.0;
  bool ttsSystem = true;

  // server side fallback for scheduled messages
  String serverUrl = '';
  String deviceId = '';

  // 1 to 5 scores, the tuning inputs
  double humanScore = 3;
  double annoyScore = 2;
  double satisfaction = 3;
  bool autoRate = true;

  /// MCP servers as plain maps, see McpServerConfig.
  List<Map<String, dynamic>> mcp = [];

  bool inQuietHours(int nowMs) {
    if (!quiet) return false;
    final d = DateTime.fromMillisecondsSinceEpoch(nowMs);
    final m = d.hour * 60 + d.minute;
    if (quietStart == quietEnd) return false;
    return quietStart < quietEnd ? (m >= quietStart && m < quietEnd) : (m >= quietStart || m < quietEnd);
  }

  /// Annoyance pulls proactive frequency down, a high human score lets the
  /// assistant lean into the behaviour. Result is a multiplier around 1.
  double get tuning {
    final annoy = (annoyScore - 1) / 4; // 0..1
    final human = (humanScore - 1) / 4;
    return (1.15 - annoy * 0.9 + (human - 0.5) * 0.2).clamp(0.1, 1.3);
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'wallet': wallet,
        'br': br,
        'brDefaultMs': brDefaultMs,
        'randomRange': randomRange,
        'seed': seed,
        'typoProb': typoProb,
        'particleProb': particleProb,
        'splitProb': splitProb,
        'punct': punct,
        'proactive': proactive,
        'maxConsecutive': maxConsecutive,
        'quiet': quiet,
        'quietStart': quietStart,
        'quietEnd': quietEnd,
        'dnd': dnd,
        'allowUrgent': allowUrgent,
        'greetMorning': greetMorning,
        'greetEvening': greetEvening,
        'morningAt': morningAt,
        'eveningAt': eveningAt,
        'icebreakDays': icebreakDays,
        'stickerFreq': stickerFreq,
        'aiSaveSticker': aiSaveSticker,
        'stickerOnly': stickerOnly,
        'recall': recall,
        'recallPerHour': recallPerHour,
        'recallWindowSec': recallWindowSec,
        'perms': perms,
        'ttsUrl': ttsUrl,
        'ttsKey': ttsKey,
        'ttsModel': ttsModel,
        'ttsVoice': ttsVoice,
        'ttsSpeed': ttsSpeed,
        'ttsSystem': ttsSystem,
        'serverUrl': serverUrl,
        'deviceId': deviceId,
        'humanScore': humanScore,
        'annoyScore': annoyScore,
        'satisfaction': satisfaction,
        'autoRate': autoRate,
        'mcp': mcp,
      };

  factory HumanSettings.fromJson(Map<String, dynamic> j) {
    final s = HumanSettings();
    s.enabled = _b(j['enabled'], s.enabled);
    s.wallet = _b(j['wallet'], s.wallet);
    s.br = _b(j['br'], s.br);
    s.brDefaultMs = _i(j['brDefaultMs'], s.brDefaultMs);
    s.randomRange = _d(j['randomRange'], s.randomRange);
    s.seed = (j['seed'] as num?)?.toInt();
    s.typoProb = _d(j['typoProb'], s.typoProb);
    s.particleProb = _d(j['particleProb'], s.particleProb);
    s.splitProb = _d(j['splitProb'], s.splitProb);
    s.punct = _i(j['punct'], s.punct);
    s.proactive = _b(j['proactive'], s.proactive);
    s.maxConsecutive = _i(j['maxConsecutive'], s.maxConsecutive);
    s.quiet = _b(j['quiet'], s.quiet);
    s.quietStart = _i(j['quietStart'], s.quietStart);
    s.quietEnd = _i(j['quietEnd'], s.quietEnd);
    s.dnd = _b(j['dnd'], s.dnd);
    s.allowUrgent = _b(j['allowUrgent'], s.allowUrgent);
    s.greetMorning = _b(j['greetMorning'], s.greetMorning);
    s.greetEvening = _b(j['greetEvening'], s.greetEvening);
    s.morningAt = _i(j['morningAt'], s.morningAt);
    s.eveningAt = _i(j['eveningAt'], s.eveningAt);
    s.icebreakDays = _i(j['icebreakDays'], s.icebreakDays);
    s.stickerFreq = _d(j['stickerFreq'], s.stickerFreq);
    s.aiSaveSticker = _b(j['aiSaveSticker'], s.aiSaveSticker);
    s.stickerOnly = _b(j['stickerOnly'], s.stickerOnly);
    s.recall = _b(j['recall'], s.recall);
    s.recallPerHour = _i(j['recallPerHour'], s.recallPerHour);
    s.recallWindowSec = _i(j['recallWindowSec'], s.recallWindowSec);
    if (j['perms'] is Map) s.perms.addAll(Map<String, String>.from((j['perms'] as Map).map((k, v) => MapEntry('$k', '$v'))));
    s.ttsUrl = _s(j['ttsUrl'], '');
    s.ttsKey = _s(j['ttsKey'], '');
    s.ttsModel = _s(j['ttsModel'], s.ttsModel);
    s.ttsVoice = _s(j['ttsVoice'], s.ttsVoice);
    s.ttsSpeed = _d(j['ttsSpeed'], 1);
    s.ttsSystem = _b(j['ttsSystem'], true);
    s.serverUrl = _s(j['serverUrl'], '');
    s.deviceId = _s(j['deviceId'], '');
    s.humanScore = _d(j['humanScore'], 3);
    s.annoyScore = _d(j['annoyScore'], 2);
    s.satisfaction = _d(j['satisfaction'], 3);
    s.autoRate = _b(j['autoRate'], true);
    if (j['mcp'] is List) s.mcp = [for (final e in j['mcp'] as List) Map<String, dynamic>.from(e as Map)];
    return s;
  }
}

/// All dice go through here. With a fixed seed the sequence depends on the chat
/// and on how many turns it has seen, so the same conversation replays alike.
class HumanRandom {
  HumanRandom(this._r);

  factory HumanRandom.forTurn(HumanSettings s, String chatId, int turn) {
    final seed = s.seed;
    return HumanRandom(seed == null ? Random() : Random(seed ^ chatId.hashCode ^ (turn * 7919)));
  }

  final Random _r;

  double next() => _r.nextDouble();
  bool chance(double p) => _r.nextDouble() < p;

  /// base +- range, e.g. 600ms with 0.2 lands in 480..720
  int jitter(int base, double range) {
    if (base <= 0) return 0;
    final f = 1 + (_r.nextDouble() * 2 - 1) * range;
    return max(0, (base * f).round());
  }
}

// ------------------------------------------------------------------ status

enum StatusKind { online, away, dnd, typing, readNoReply }

String statusWire(StatusKind k) => switch (k) { StatusKind.readNoReply => 'read_no_reply', _ => k.name };

StatusKind statusFrom(String? raw) => switch (raw) {
      'away' => StatusKind.away,
      'dnd' => StatusKind.dnd,
      'typing' => StatusKind.typing,
      'read_no_reply' => StatusKind.readNoReply,
      _ => StatusKind.online,
    };

enum Stage { stranger, acquaintance, close }

// -------------------------------------------------------------- life flow

enum LifeKind { busy, rest, meeting }

class LifeEntry {
  LifeEntry({required this.id, required this.title, required this.start, required this.end, this.kind = LifeKind.busy, this.by = 'ai', this.announced = false});
  final String id;
  String title;
  int start;
  int end;
  LifeKind kind;

  /// who set it, 'ai' or 'user'
  String by;

  /// true once the "done" message has been scheduled
  bool announced;

  bool activeAt(int now) => now >= start && now < end;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'start': start, 'end': end, 'kind': kind.name, 'by': by, 'announced': announced};
  factory LifeEntry.fromJson(Map<String, dynamic> j) => LifeEntry(
        id: _s(j['id'], ''),
        title: _s(j['title'], ''),
        start: _i(j['start'], 0),
        end: _i(j['end'], 0),
        kind: _enum(LifeKind.values, j['kind'], LifeKind.busy),
        by: _s(j['by'], 'ai'),
        announced: _b(j['announced'], false),
      );
}

// ---------------------------------------------------------- character card

/// Personality sheet that is injected before every generation so the voice does
/// not drift. The import/export format is a SillyTavern chara_card_v2 with the
/// extra fields kept under `extensions.lib3`.
class CharacterCard {
  CharacterCard({
    this.catchphrases = const [],
    this.values = '',
    this.taboos = '',
    this.speechStyle = '',
    this.addressStranger = '',
    this.addressAcquaintance = '',
    this.addressClose = '',
  });

  List<String> catchphrases;
  String values;
  String taboos;
  String speechStyle;
  String addressStranger;
  String addressAcquaintance;
  String addressClose;

  bool get isEmpty => catchphrases.isEmpty && values.isEmpty && taboos.isEmpty && speechStyle.isEmpty && addressStranger.isEmpty && addressAcquaintance.isEmpty && addressClose.isEmpty;

  String addressFor(Stage s) => switch (s) {
        Stage.stranger => addressStranger,
        Stage.acquaintance => addressAcquaintance.isEmpty ? addressStranger : addressAcquaintance,
        Stage.close => addressClose.isEmpty ? (addressAcquaintance.isEmpty ? addressStranger : addressAcquaintance) : addressClose,
      };

  Map<String, dynamic> toJson() => {
        'catchphrases': catchphrases,
        'values': values,
        'taboos': taboos,
        'speechStyle': speechStyle,
        'addressStranger': addressStranger,
        'addressAcquaintance': addressAcquaintance,
        'addressClose': addressClose,
      };

  factory CharacterCard.fromJson(Map<String, dynamic> j) => CharacterCard(
        catchphrases: [for (final e in (j['catchphrases'] as List? ?? const [])) '$e'],
        values: _s(j['values'], ''),
        taboos: _s(j['taboos'], ''),
        speechStyle: _s(j['speechStyle'], ''),
        addressStranger: _s(j['addressStranger'], ''),
        addressAcquaintance: _s(j['addressAcquaintance'], ''),
        addressClose: _s(j['addressClose'], ''),
      );

  /// SillyTavern chara_card_v2
  Map<String, dynamic> toTavern({required String name, required String description, required String firstMes}) => {
        'spec': 'chara_card_v2',
        'spec_version': '2.0',
        'data': {
          'name': name,
          'description': description,
          'personality': speechStyle,
          'scenario': '',
          'first_mes': firstMes,
          'mes_example': catchphrases.map((e) => '{{char}}: $e').join('\n'),
          'creator_notes': '',
          'system_prompt': '',
          'post_history_instructions': taboos.isEmpty ? '' : 'Never: $taboos',
          'alternate_greetings': <String>[],
          'tags': <String>[],
          'creator': '',
          'character_version': '1',
          'extensions': {'lib3': toJson()},
        },
      };

  static CharacterCard fromTavern(Map<String, dynamic> j) {
    final data = (j['data'] is Map ? j['data'] : j) as Map;
    final ext = data['extensions'];
    if (ext is Map && ext['lib3'] is Map) return CharacterCard.fromJson(Map<String, dynamic>.from(ext['lib3'] as Map));
    return CharacterCard(
      speechStyle: _s(data['personality'], ''),
      taboos: _s(data['post_history_instructions'], '').replaceFirst(RegExp(r'^Never:\s*'), ''),
    );
  }
}

// ------------------------------------------------------------------- state

/// Everything that makes the assistant feel like it lives between messages.
/// One per chat, saved with the chat.
class HumanState {
  HumanState();

  StatusKind status = StatusKind.online;
  double mood = 60;
  double affection = 30;
  double energy = 80;
  Stage stage = Stage.stranger;

  int userMsgs = 0;
  int aiMsgs = 0;

  /// total minutes of back and forth, a gap over ten minutes does not count
  int interactionMin = 0;
  int firstAt = 0;
  int lastUserAt = 0;
  int lastAiAt = 0;
  int lastTickAt = 0;
  int lastReadAt = 0;
  int consecutiveProactive = 0;
  int turn = 0;
  final List<int> recallStamps = [];
  final List<LifeEntry> life = [];
  CharacterCard card = CharacterCard();

  /// day keys ('yyyy-mm-dd:morning') of the greetings that were already queued
  final Set<String> autoKeys = {};

  /// short log of what changed the numbers, shown in the per chat page
  final List<String> feelingLog = [];

  LifeEntry? activeLife(int now) {
    for (final e in life) {
      if (e.activeAt(now)) return e;
    }
    return null;
  }

  /// What the header shows. A running life entry or a do not disturb switch
  /// outranks what the assistant last set itself.
  StatusKind effective(int now, {bool dnd = false}) {
    if (status == StatusKind.typing) return StatusKind.typing;
    if (dnd) return StatusKind.dnd;
    final l = activeLife(now);
    if (l != null) return l.kind == LifeKind.rest ? StatusKind.dnd : StatusKind.away;
    return status;
  }

  void _log(String s) {
    feelingLog.add('${DateTime.now().toIso8601String().substring(11, 16)} $s');
    if (feelingLog.length > 40) feelingLog.removeAt(0);
  }

  void adjust({double mood = 0, double affection = 0, double energy = 0, String reason = ''}) {
    this.mood = (this.mood + mood).clamp(0, 100);
    this.affection = (this.affection + affection).clamp(0, 100);
    this.energy = (this.energy + energy).clamp(0, 100);
    if (mood != 0 || affection != 0 || energy != 0) {
      _log('mood ${mood.toStringAsFixed(0)} affection ${affection.toStringAsFixed(0)} energy ${energy.toStringAsFixed(0)} $reason');
    }
  }

  static final _praise = RegExp(r'(谢谢|感谢|太棒|真棒|厉害|喜欢你|爱你|可爱|聪明|好样的|辛苦了|thank|awesome|great job|love you|you.re (the best|great|cute))', caseSensitive: false);
  static final _insult = RegExp(r'(傻[逼比x]|撒比|沙比|蠢|滚|闭嘴|废物|垃圾|烦死|讨厌你|智障|stupid|idiot|shut up|hate you|useless)', caseSensitive: false);

  /// Heuristic first pass on the numbers, the assistant can still correct them
  /// through the adjust_feeling tool because it reads the text with more care.
  void noteUser(String text, int now) {
    if (firstAt == 0) firstAt = now;
    if (lastUserAt != 0 && now - lastUserAt < 10 * 60 * 1000) interactionMin += max(1, (now - lastUserAt) ~/ 60000);
    userMsgs++;
    lastUserAt = now;
    consecutiveProactive = 0;
    if (status == StatusKind.readNoReply || status == StatusKind.typing) status = StatusKind.online;
    if (_insult.hasMatch(text)) {
      adjust(mood: -12, affection: -6, reason: 'insulted');
    } else if (_praise.hasMatch(text)) {
      adjust(mood: 6, affection: 3, reason: 'praised');
    } else {
      adjust(affection: 0.15);
    }
    // a long session wears the assistant out
    adjust(energy: -0.4);
  }

  void noteAi(int now, {bool proactive = false}) {
    aiMsgs++;
    lastAiAt = now;
    if (proactive) consecutiveProactive++;
  }

  /// Time based drift: energy comes back, mood walks to neutral, the stage is
  /// reconsidered. Called before every generation and by the scheduler tick.
  void tick(int now) {
    if (lastTickAt == 0) lastTickAt = now;
    final hours = (now - lastTickAt) / 3600000;
    lastTickAt = now;
    if (hours > 0) {
      final e = activeLife(now) != null ? 0.0 : 6.0;
      energy = (energy + hours * e).clamp(0, 100);
      mood += (55 - mood) * min(1.0, hours * 0.08);
      // long silence cools affection slowly
      if (lastUserAt != 0 && now - lastUserAt > 3 * 24 * 3600000) affection = max(0, affection - hours * 0.05);
    }
    evaluateStage(now);
  }

  /// stranger <-> acquaintance <-> close. Upgrading needs interactions, time
  /// together and affection, downgrading needs affection to fall or silence.
  /// The gap between the two thresholds stops it flapping.
  bool evaluateStage(int now) {
    final silentDays = lastUserAt == 0 ? 0 : (now - lastUserAt) / 86400000;
    final before = stage;
    switch (stage) {
      case Stage.stranger:
        if (userMsgs >= 20 && affection >= 35) stage = Stage.acquaintance;
      case Stage.acquaintance:
        if (userMsgs >= 100 && interactionMin >= 240 && affection >= 70) {
          stage = Stage.close;
        } else if (affection < 20 || silentDays >= 30) {
          stage = Stage.stranger;
        }
      case Stage.close:
        if (affection < 50 || silentDays >= 14) stage = Stage.acquaintance;
    }
    if (before != stage) _log('stage ${before.name} -> ${stage.name}');
    return before != stage;
  }

  /// How willing the assistant is to start a conversation, 0..1.
  double proactiveWill(HumanSettings s, int now) {
    var f = switch (stage) { Stage.stranger => 0.25, Stage.acquaintance => 0.6, Stage.close => 1.0 };
    f *= 0.4 + energy / 100 * 0.6;
    f *= 0.6 + affection / 100 * 0.4;
    final eff = effective(now, dnd: s.dnd);
    if (eff == StatusKind.away) f *= 0.15;
    if (eff == StatusKind.dnd) f = 0;
    return (f * s.tuning).clamp(0, 1);
  }

  int recallsInLastHour(int now) => recallStamps.where((t) => now - t < 3600000).length;

  Map<String, dynamic> toJson() => {
        'status': statusWire(status == StatusKind.typing ? StatusKind.online : status),
        'mood': mood,
        'affection': affection,
        'energy': energy,
        'stage': stage.name,
        'userMsgs': userMsgs,
        'aiMsgs': aiMsgs,
        'interactionMin': interactionMin,
        'firstAt': firstAt,
        'lastUserAt': lastUserAt,
        'lastAiAt': lastAiAt,
        'lastTickAt': lastTickAt,
        'lastReadAt': lastReadAt,
        'consecutiveProactive': consecutiveProactive,
        'turn': turn,
        'recallStamps': recallStamps,
        'life': life.map((e) => e.toJson()).toList(),
        'card': card.toJson(),
        'autoKeys': autoKeys.toList(),
        'feelingLog': feelingLog,
      };

  factory HumanState.fromJson(Map<String, dynamic> j) {
    final s = HumanState();
    s.status = statusFrom(j['status'] as String?);
    s.mood = _d(j['mood'], 60);
    s.affection = _d(j['affection'], 30);
    s.energy = _d(j['energy'], 80);
    s.stage = _enum(Stage.values, j['stage'], Stage.stranger);
    s.userMsgs = _i(j['userMsgs'], 0);
    s.aiMsgs = _i(j['aiMsgs'], 0);
    s.interactionMin = _i(j['interactionMin'], 0);
    s.firstAt = _i(j['firstAt'], 0);
    s.lastUserAt = _i(j['lastUserAt'], 0);
    s.lastAiAt = _i(j['lastAiAt'], 0);
    s.lastTickAt = _i(j['lastTickAt'], 0);
    s.lastReadAt = _i(j['lastReadAt'], 0);
    s.consecutiveProactive = _i(j['consecutiveProactive'], 0);
    s.turn = _i(j['turn'], 0);
    s.recallStamps.addAll([for (final e in (j['recallStamps'] as List? ?? const [])) (e as num).toInt()]);
    s.life.addAll([for (final e in (j['life'] as List? ?? const [])) LifeEntry.fromJson(Map<String, dynamic>.from(e as Map))]);
    if (j['card'] is Map) s.card = CharacterCard.fromJson(Map<String, dynamic>.from(j['card'] as Map));
    s.autoKeys.addAll([for (final e in (j['autoKeys'] as List? ?? const [])) '$e']);
    s.feelingLog.addAll([for (final e in (j['feelingLog'] as List? ?? const [])) '$e']);
    return s;
  }
}
