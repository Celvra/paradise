import 'package:flutter/foundation.dart';

import '../l10n/x.dart';
import 'ai/provider_model.dart';
import 'human/human_models.dart';
import 'observable.dart';
import 'workspace/workspace.dart';

class Persona {
  Persona({
    required this.name,
    required this.prompt,
    required this.color,
    this.bio = '',
    this.greeting = '',
    this.emoji = '',
    this.examples = '',
    this.avatarPath = '',
    this.modelProvider = '',
    this.modelId = '',
    this.modelFallback = true,
    this.thinking,
    this.agent,
    this.clingy = false,
    this.clingySilentMin = 90,
    this.clingyCap = false,
    this.clingyMax = 3,
    this.skillIds,
    this.imageEnabled = false,
    this.imageProvider = '',
    this.imageModel = '',
    this.imageSize = '',
    this.ttsEnabled = false,
    this.ttsEngine,
    this.ttsBaseUrl = '',
    this.ttsModel = '',
    this.ttsVoice = '',
    this.ttsAutoSpeak = false,
  });
  String name;
  String prompt;
  int color;
  // descriptive fields shown on the profile and dialog rows, never sent to the model
  String bio;
  // first message seeded into a new chat
  String greeting;
  // single glyph used in place of the name for the avatar
  String emoji;

  /// A few lines of `{{user}}:` / `{{char}}:` transcript the model reads as a
  /// style reference, the SillyTavern example messages slot. Empty on personas
  /// that predate the field; normalized by formatExamples before the send.
  String examples;

  /// Local image path for this persona's avatar. Empty falls back to the
  /// gradient plus emoji or initial, so an older persona without one still
  /// renders the way it always did.
  String avatarPath;

  /// True once a photo has been picked, the avatar then shows it on every
  /// screen instead of the glyph.
  bool get hasAvatar => avatarPath.isNotEmpty;

  /// Model of this persona alone, empty means it follows the global chain.
  /// Both halves have to be set, a provider pointing at no model is ignored so
  /// a half finished pick can never strand the chat.
  String modelProvider;
  String modelId;

  /// Whether a failing override hands over to the global chain instead of
  /// giving up. Only meaningful while an override is set.
  bool modelFallback;

  bool get hasModelOverride => modelProvider.trim().isNotEmpty && modelId.trim().isNotEmpty;

  /// What the profile shows for the model row: the word Global while the
  /// persona follows the chain, the overridden model id once one is picked.
  String get modelLabel => hasModelOverride ? modelId.trim() : 'Global';

  /// Per persona answer to the two global reply switches. Null means this
  /// persona follows the global setting, which is why these are nullable all
  /// the way down to the json: a stored `false` is a decision, a missing key
  /// is not.
  bool? thinking;
  bool? agent;

  /// "Clingy" proactive chatter. When on and the user has been silent for
  /// [clingySilentMin] minutes the scheduler queues a check-in so the persona
  /// speaks up on its own. The silence is measured from the last message of
  /// either side, so one check-in never chains straight into the next one.
  bool clingy;

  /// Minutes of user silence that triggers a proactive check-in.
  int clingySilentMin;

  /// Cap on consecutive proactive messages. Off means the feature imposes no
  /// limit of its own and the global proactive chain setting keeps applying.
  bool clingyCap;

  /// The cap value, in consecutive proactive messages. The counter refreshes
  /// every time the user sends a message.
  int clingyMax;
  /// Skills this role may use. Null follows the global set (every enabled
  /// skill), an explicit list names exactly the skills in the prompt. Empty
  /// means this role uses none.
  List<String>? skillIds;

  /// Whether this role may draw. Off unless the role turns it on: there is no
  /// app wide switch to inherit from, and a character that quietly starts
  /// spending the user's image credits the moment it is imported is a
  /// surprise worth avoiding.
  bool imageEnabled;

  /// Image endpoint override. Empty follows the global default, which is
  /// what every persona written before this field wants.
  String imageProvider;
  String imageModel;

  /// Pixel size for this role, e.g. `1024x1024`. Empty follows the global
  /// default so a gateway that only accepts one size stays working.
  String imageSize;

  /// Whether this role speaks. Off unless turned on, same rule as drawing.
  bool ttsEnabled;

  /// Which engine speaks for this role. Null follows the voice module's own
  /// setting, so one character can use the phone's voice while another uses a
  /// cloned voice on the server.
  TtsEngine? ttsEngine;

  /// Per role override of the voice module's endpoint and model. Empty follows
  /// the module, which is the common case: a user with one voice service sets
  /// it once and every character shares it.
  String ttsBaseUrl;
  String ttsModel;

  /// The voice id this role speaks in. This is the field worth setting per
  /// character: one voice service can carry several characters, and the whole
  /// point of a cloned voice is that it differs per role.
  String ttsVoice;

  /// Read every finished reply out loud without being asked. Off by default:
  /// a chat that starts talking on its own the first time a role is imported
  /// is worse than one that waits to be told.
  bool ttsAutoSpeak;

  Map<String, dynamic> toJson() => {
        'name': name,
        'prompt': prompt,
        'color': color,
        'bio': bio,
        'greeting': greeting,
        'emoji': emoji,
        if (examples.isNotEmpty) 'examples': examples,
        'avatarPath': avatarPath,
        'modelProvider': modelProvider,
        'modelId': modelId,
        'modelFallback': modelFallback,
        if (thinking != null) 'thinking': thinking,
        if (agent != null) 'agent': agent,
        'clingy': clingy,
        'clingySilentMin': clingySilentMin,
        'clingyCap': clingyCap,
        'clingyMax': clingyMax,
        if (skillIds != null) 'skillIds': skillIds,
        if (imageEnabled) 'imageEnabled': true,
        if (imageProvider.isNotEmpty) 'imageProvider': imageProvider,
        if (imageModel.isNotEmpty) 'imageModel': imageModel,
        if (imageSize.isNotEmpty) 'imageSize': imageSize,
        if (ttsEnabled) 'ttsEnabled': true,
        if (ttsEngine != null) 'ttsEngine': ttsEngineWire(ttsEngine!),
        if (ttsBaseUrl.isNotEmpty) 'ttsBaseUrl': ttsBaseUrl,
        if (ttsModel.isNotEmpty) 'ttsModel': ttsModel,
        if (ttsVoice.isNotEmpty) 'ttsVoice': ttsVoice,
        if (ttsAutoSpeak) 'ttsAutoSpeak': true,
      };
  factory Persona.fromJson(Map<String, dynamic> j) => Persona(
        name: j['name'] as String,
        prompt: j['prompt'] as String,
        color: j['color'] as int,
        bio: j['bio'] as String? ?? '',
        greeting: j['greeting'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '',
        examples: j['examples'] as String? ?? '',
        // personas saved before the photo existed simply have no key
        avatarPath: j['avatarPath'] as String? ?? '',
        modelProvider: j['modelProvider'] as String? ?? '',
        modelId: j['modelId'] as String? ?? '',
        // an older build had no switch at all, the forgiving default keeps
        // those personas answering instead of failing on the first error
        modelFallback: j['modelFallback'] as bool? ?? true,
        thinking: j['thinking'] as bool?,
        agent: j['agent'] as bool?,
        // personas saved before clingy existed stay quiet until switched on
        clingy: j['clingy'] as bool? ?? false,
        clingySilentMin: (j['clingySilentMin'] as num?)?.toInt() ?? 90,
        clingyCap: j['clingyCap'] as bool? ?? false,
        clingyMax: (j['clingyMax'] as num?)?.toInt() ?? 3,
        skillIds: j['skillIds'] is List ? [for (final e in j['skillIds'] as List) '$e'] : null,
        // every one of these is optional: a persona saved before the
        // field existed has no key and follows the global setting, the
        // same rule the two reply switches already follow
        imageEnabled: j['imageEnabled'] as bool? ?? false,
        imageProvider: j['imageProvider'] as String? ?? '',
        imageModel: j['imageModel'] as String? ?? '',
        imageSize: j['imageSize'] as String? ?? '',
        ttsEnabled: j['ttsEnabled'] as bool? ?? false,
        ttsEngine: j['ttsEngine'] is String ? ttsEngineOf(j['ttsEngine'] as String) : null,
        ttsBaseUrl: j['ttsBaseUrl'] as String? ?? '',
        ttsModel: j['ttsModel'] as String? ?? '',
        ttsVoice: j['ttsVoice'] as String? ?? '',
        ttsAutoSpeak: j['ttsAutoSpeak'] as bool? ?? false,
      );
}

/// Where a user persona description lands in a request, matching SillyTavern
/// persona_description_positions. The enum reads better than the bare ints the
/// original uses and the order here is the order the picker shows.
enum PersonaPosition { none, inPrompt, topNote, bottomNote, atDepth }

/// Role carried by the turn injected at PersonaPosition.atDepth. Providers
/// without a system role inside the history (gemini, anthropic) demote it to a
/// plain user turn, the same way the original lets the role through untouched.
enum PersonaRole { system, user, assistant }

/// One of my own persona cards, the "who am I" half of a SillyTavern persona.
/// The AI side already has Persona; this is the user side.
class UserPersona {
  UserPersona({
    required this.id,
    required this.name,
    this.title = '',
    this.description = '',
    this.avatarPath = '',
    this.color = 4,
    this.position = PersonaPosition.inPrompt,
    this.depth = 2,
    this.role = PersonaRole.system,
  });

  final String id;

  /// Goes into the prompt as the name the character is talking to
  String name;

  /// Display only, never sent to the model. SillyTavern calls this the title.
  String title;

  /// The card body, this is what actually tells the model who the user is
  String description;

  /// Local image path, empty falls back to the initial on a gradient
  String avatarPath;

  int color;
  PersonaPosition position;

  /// Messages back from the newest one when injecting at depth
  int depth;
  PersonaRole role;

  /// One line used by the card list and the profile cell
  String get summary {
    final d = description.replaceAll(RegExp(r'\s+'), ' ').trim();
    return d.isEmpty ? 'No description' : d;
  }

  /// The initial drawn in the avatar when no photo is picked
  String get initial {
    final t = name.trim();
    return t.isEmpty ? '?' : String.fromCharCodes(t.runes.take(1)).toUpperCase();
  }

  UserPersona copyWith({String? name, String? title, String? description, String? avatarPath, int? color, PersonaPosition? position, int? depth, PersonaRole? role}) => UserPersona(
        id: id,
        name: name ?? this.name,
        title: title ?? this.title,
        description: description ?? this.description,
        avatarPath: avatarPath ?? this.avatarPath,
        color: color ?? this.color,
        position: position ?? this.position,
        depth: depth ?? this.depth,
        role: role ?? this.role,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'title': title,
        'description': description,
        'avatarPath': avatarPath,
        'color': color,
        'position': position.name,
        'depth': depth,
        'role': role.name,
      };

  factory UserPersona.fromJson(Map<String, dynamic> j) => UserPersona(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        avatarPath: j['avatarPath'] as String? ?? '',
        color: (j['color'] as num?)?.toInt() ?? 4,
        // an unknown name from a newer build falls back to the safe default
        position: PersonaPosition.values.firstWhere((e) => e.name == j['position'], orElse: () => PersonaPosition.inPrompt),
        depth: (j['depth'] as num?)?.toInt() ?? 2,
        role: PersonaRole.values.firstWhere((e) => e.name == j['role'], orElse: () => PersonaRole.system),
      );
}

// delivery states match the dialog cell sent state constants
class St {
  static const sending = 0;
  static const sent = 1;
  static const read = 2;
  static const failed = 3;
}

/// [trace] is one step of the model's work rather than something it said: a
/// stretch of reasoning, or a tool call with its result. Trace rows are always
/// service rows, so they stay out of the model history and out of search while
/// still living in the chat json where the user can scroll back and open them.
enum MsgKind { text, photo, video, file, music, location, contact, poll, sticker, transfer, gift, html, latex, trace }

class Msg {
  Msg({
    required this.id,
    required this.out,
    required String text,
    required this.time,
    this.reply,
    bool read = false,
    int? state,
    this.service = false,
    this.streaming = false,
    this.kind = MsgKind.text,
    Map<String, dynamic>? data,
    bool recalled = false,
    bool recalledAfterRead = false,
    String recalledText = '',
    bool edited = false,
    List<String>? edits,
    bool pinned = false,
    bool proactive = false,
  })  : _text = text,
        _state = state ?? (read ? St.read : St.sent),
        _data = data == null ? ObservableMap<String, dynamic>.of() : ObservableMap<String, dynamic>(data),
        _recalled = recalled,
        _recalledAfterRead = recalledAfterRead,
        _recalledText = recalledText,
        _edited = edited,
        _edits = edits == null ? ObservableList<String>.of() : ObservableList<String>(edits),
        _pinned = pinned,
        _proactive = proactive {
    _data.onChange = _changed;
    _edits.onChange = _changed;
  }

  /// Reports that a persisted field changed, so storage can write the row back.
  ///
  /// Assigned by the storage layer. The alternative was a save call at each of
  /// the call sites that touch a message, and there were enough of them, spread
  /// across four files, that a missed one is a message which changes on screen
  /// and reverts on the next launch.
  ///
  /// Streaming text arrives through here one chunk at a time, so the listener is
  /// expected to coalesce rather than write on every call.
  void Function(Msg msg)? onChange;

  final String id;
  final bool out;
  final int time;
  final String? reply;
  final bool service;
  bool streaming;
  final MsgKind kind;

  String _text;
  int _state;
  late final ObservableMap<String, dynamic> _data;

  String get text => _text;
  set text(String v) {
    if (_text == v) return;
    _text = v;
    onChange?.call(this);
  }

  int get state => _state;
  set state(int v) {
    if (_state == v) return;
    _state = v;
    onChange?.call(this);
  }

  Map<String, dynamic> get data => _data;

  /// recalled messages stay as a placeholder, the text is kept for the context
  bool _recalled;
  bool _recalledAfterRead;
  String _recalledText;

  bool get recalled => _recalled;
  set recalled(bool v) {
    if (_recalled == v) return;
    _recalled = v;
    onChange?.call(this);
  }

  bool get recalledAfterRead => _recalledAfterRead;
  set recalledAfterRead(bool v) {
    if (_recalledAfterRead == v) return;
    _recalledAfterRead = v;
    onChange?.call(this);
  }

  String get recalledText => _recalledText;
  set recalledText(String v) {
    if (_recalledText == v) return;
    _recalledText = v;
    onChange?.call(this);
  }

  /// edit history, oldest first, the current text is not in it
  bool _edited;
  late final ObservableList<String> _edits;

  bool get edited => _edited;
  set edited(bool v) {
    if (_edited == v) return;
    _edited = v;
    onChange?.call(this);
  }

  List<String> get edits => _edits;

  bool _pinned;
  bool get pinned => _pinned;
  set pinned(bool v) {
    if (_pinned == v) return;
    _pinned = v;
    onChange?.call(this);
  }

  /// the assistant started this one on its own
  bool _proactive;
  bool get proactive => _proactive;
  set proactive(bool v) {
    if (_proactive == v) return;
    _proactive = v;
    onChange?.call(this);
  }

  /// Hooks [data] and [edits] to this message's own change report.
  ///
  /// Called once after construction, since the collections are built before
  /// there is an [onChange] to point them at.
  void _changed() => onChange?.call(this);

  bool get read => state == St.read;
  set read(bool v) => state = v ? St.read : St.sent;

  bool get isMedia => kind == MsgKind.photo || kind == MsgKind.video;
  bool get isSticker => kind == MsgKind.sticker;

  // one line summary used by dialog rows reply quotes and search. The lead is
  // a noun we made up, so it follows the active language.
  String get preview {
    // the preview is a one line summary for a list row, there is no sender name
    // in front of it, so it takes the nameless variant
    if (recalled) return L10n.current.msgRecalledAnonymous;
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final l = L10n.current;
    String lead;
    switch (kind) {
      case MsgKind.text:
        return t;
      case MsgKind.photo:
        lead = l.msgLeadPhoto;
      case MsgKind.video:
        lead = l.msgLeadVideo;
      case MsgKind.file:
        lead = '${data['name'] ?? l.attachFileFallback}';
      case MsgKind.music:
        lead = '${data['name'] ?? l.msgLeadMusic}';
      case MsgKind.location:
        lead = l.attachLocationTitle;
      case MsgKind.contact:
        lead = '${data['name'] ?? l.msgLeadContact}';
      case MsgKind.poll:
        lead = '${data['q'] ?? l.msgLeadPoll}';
      case MsgKind.sticker:
        return '${data['emoji'] ?? ''} ${l.msgLeadSticker}';
      case MsgKind.transfer:
        // plain text, this one feeds search and list previews where a painted
        // glyph would not fit, so it leads with a word instead of an emoji
        return '${data['kind'] == 'redpacket' ? l.walletRedPacket : l.walletTransfer} ¥${data['amount'] ?? ''} ${data['note'] ?? ''}'.trim();
      case MsgKind.gift:
        // a shop purchase lands as a card from the user; the list row only
        // needs the item name, which sits in data so the model-facing describe
        // can build its instruction around it
        return '${data['title'] ?? ''}';
      case MsgKind.trace:
        // never shown, it is a service row, but the switch has to be total
        return '${data['tool'] ?? l.traceThinking}';
      case MsgKind.html:
        lead = l.msgLeadHtml;
      case MsgKind.latex:
        lead = l.msgLeadLatex;
    }
    return t.isEmpty ? lead : '$lead, $t';
  }

  // text that the search indexes
  String get haystack => '$text ${kind == MsgKind.text || kind == MsgKind.sticker ? '' : preview}'.toLowerCase();

  bool get hasLink => RegExp(r'https?://\S+').hasMatch(text);

  Map<String, dynamic> toJson() => {
        'id': id,
        'out': out,
        'text': text,
        'time': time,
        'reply': reply,
        'state': state,
        'service': service,
        'kind': kind.name,
        'data': data,
        if (recalled) 'recalled': true,
        if (recalledAfterRead) 'recalledAfterRead': true,
        if (recalledText.isNotEmpty) 'recalledText': recalledText,
        if (edited) 'edited': true,
        if (edits.isNotEmpty) 'edits': edits,
        if (pinned) 'pinned': true,
        if (proactive) 'proactive': true,
      };

  // older builds kept media in flat columns, named audio/video differently and
  // stored a single poll vote, so reads accept both shapes
  factory Msg.fromJson(Map<String, dynamic> j) {
    final kind = switch (j['kind'] as String?) {
      'photo' => MsgKind.photo,
      'video' => MsgKind.video,
      'file' => MsgKind.file,
      'music' || 'audio' => MsgKind.music,
      'location' => MsgKind.location,
      'contact' => MsgKind.contact,
      'poll' => MsgKind.poll,
      'sticker' => MsgKind.sticker,
      'transfer' => MsgKind.transfer,
      'trace' => MsgKind.trace,
      'html' => MsgKind.html,
      'latex' => MsgKind.latex,
      _ => MsgKind.text,
    };
    var st = j['state'] as int? ?? ((j['read'] as bool? ?? false) ? St.read : St.sent);
    if (st == St.sending) st = St.sent;
    final data = <String, dynamic>{...Map<String, dynamic>.from((j['data'] as Map?) ?? {})};
    for (final k in const ['path', 'name', 'size']) {
      if (data[k] == null && j[k] != null) data[k] = j[k];
    }
    if (kind == MsgKind.sticker && data['emoji'] == null && data['e'] != null) {
      data['emoji'] = data['e'];
    }
    if (kind == MsgKind.poll && data['mine'] is int) {
      final mine = data['mine'] as int;
      data['mine'] = mine < 0 ? <int>[] : [mine];
    }
    return Msg(
      id: j['id'] as String,
      out: j['out'] as bool,
      text: j['text'] as String,
      time: j['time'] as int,
      reply: j['reply'] as String?,
      state: st,
      service: j['service'] as bool? ?? false,
      kind: kind,
      data: data,
      recalled: j['recalled'] as bool? ?? false,
      recalledAfterRead: j['recalledAfterRead'] as bool? ?? false,
      recalledText: j['recalledText'] as String? ?? '',
      edited: j['edited'] as bool? ?? false,
      edits: [for (final e in (j['edits'] as List? ?? const [])) '$e'],
      pinned: j['pinned'] as bool? ?? false,
      proactive: j['proactive'] as bool? ?? false,
    );
  }
}

// one dialog with an ai persona
class Chat extends ChangeNotifier {
  Chat({required this.id, required this.persona, List<Msg>? msgs, this.unread = 0, this.pinned = false, this.muted = false, this.draft = '', this.markedUnread = false, this.personaId, this.wallpaperPath}) : msgs = msgs ?? [];
  final String id;
  Persona persona;
  final List<Msg> msgs;
  int unread;
  bool pinned;
  bool muted;
  bool markedUnread;
  String draft;
  bool typing = false;

  /// Wallpaper of this conversation. Null follows the global setting, an empty
  /// string means this chat deliberately wants the plain gradient and a path is
  /// a picture of its own. The three states are distinct on purpose: without
  /// the empty string there would be no way to opt one chat out of a global
  /// picture while the rest keep it.
  String? wallpaperPath;

  /// status, mood, stage, schedule and character card of this conversation
  HumanState human = HumanState();

  /// My persona card locked to this chat, the equivalent of chat_metadata.persona
  /// in SillyTavern. Null means the globally selected card is used.
  String? personaId;

  /// The workspace this chat's files live in. Unbound is the default and
  /// serialises to nothing at all, so a chat that never picked one is byte
  /// identical to one written before the feature existed.
  WorkspaceBinding ws = WorkspaceBinding();

  Msg? get last {
    for (var i = msgs.length - 1; i >= 0; i--) {
      if (!msgs[i].service) return msgs[i];
    }
    return null;
  }

  int get lastTime => last?.time ?? 0;

  Msg? byId(String? id) {
    if (id == null) return null;
    for (final m in msgs) {
      if (m.id == id) return m;
    }
    return null;
  }

  // messages matching a query newest first
  List<Msg> find(String q, {MsgKind? kind, bool links = false}) {
    final s = q.trim().toLowerCase();
    final out = <Msg>[];
    for (var i = msgs.length - 1; i >= 0; i--) {
      final m = msgs[i];
      if (m.service) continue;
      if (kind != null && m.kind != kind) continue;
      if (links && !m.hasLink) continue;
      if (s.isNotEmpty && !m.haystack.contains(s)) continue;
      out.add(m);
    }
    return out;
  }

  void touch() => notifyListeners();

  Map<String, dynamic> toJson() => {'id': id, 'persona': persona.toJson(), 'msgs': msgs.map((e) => e.toJson()).toList(), 'unread': unread, 'pinned': pinned, 'muted': muted, 'draft': draft, 'markedUnread': markedUnread, 'personaId': personaId, if (wallpaperPath != null) 'wallpaperPath': wallpaperPath, if (ws.isBound) 'ws': ws.toJson(), 'human': human.toJson()};
  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
        id: j['id'] as String,
        persona: Persona.fromJson(j['persona'] as Map<String, dynamic>),
        msgs: (j['msgs'] as List).map((e) => Msg.fromJson(e as Map<String, dynamic>)).toList(),
        unread: j['unread'] as int? ?? 0,
        pinned: j['pinned'] as bool? ?? false,
        muted: j['muted'] as bool? ?? false,
        draft: j['draft'] as String? ?? '',
        markedUnread: j['markedUnread'] as bool? ?? false,
        personaId: j['personaId'] as String?,
        wallpaperPath: j['wallpaperPath'] as String?,
      )..human = j['human'] is Map ? HumanState.fromJson(Map<String, dynamic>.from(j['human'] as Map)) : HumanState()
      ..ws = WorkspaceBinding.fromJson(j['ws'] is Map ? Map<String, dynamic>.from(j['ws'] as Map) : null);
}

// time helpers matching the dialog cell date rules
String hm(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

bool sameDay(int a, int b) {
  final x = DateTime.fromMillisecondsSinceEpoch(a);
  final y = DateTime.fromMillisecondsSinceEpoch(b);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

// today shows the clock, the rest of the week a short weekday, anything older
// a month and a day. intl owns the shapes: 'Jan 5' in english, '1月5日' in
// chinese, '1月5日' in japanese, all from the same pattern.
String dialogDate(int ms) {
  final now = DateTime.now();
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff <= 0) return hm(ms);
  if (diff < 7) return L10n.date('E').format(d);
  return L10n.date('MMMd').format(d);
}

// the pill between message groups, so it carries the year whenever the message
// is not from this one
String dayLabel(int ms) {
  final now = DateTime.now();
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff <= 0) return L10n.current.dayToday;
  if (diff == 1) return L10n.current.dayYesterday;
  if (diff < 7) return L10n.date('EEEE').format(d);
  return L10n.date(d.year == now.year ? 'yMMMd' : 'yMMMMd').format(d);
}

/// Month name plus year for the calendar sheet header, 'January 2026',
/// '2026年1月'.
String monthYear(DateTime d) => L10n.date('yMMMM').format(d);

// file size like AndroidUtilities.formatFileSize. The unit suffixes are the
// same in every language we ship, only the digits and the separator move.
String fileSize(num b) {
  String one(num v) => L10n.number('#,##0.0').format(v);
  if (b < 1024) return '${L10n.number('#,##0').format(b.toInt())} B';
  if (b < 1024 * 1024) return '${one(b / 1024)} KB';
  if (b < 1024 * 1024 * 1024) return '${one(b / 1024 / 1024)} MB';
  return '${one(b / 1024 / 1024 / 1024)} GB';
}


/// Duration in the agent trace rows. The unit rides on the arb string because
/// Chinese writes a space and a word where english glues a suffix on, so it is
/// a translated fragment rather than a formatter.
String traceSeconds(int ms) => L10n.current.traceSeconds(L10n.number('0.#').format(ms / 1000));

