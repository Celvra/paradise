import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random, max, min;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_info.dart' show appVersion;
import '../core/perf.dart';
import '../core/speech.dart';
import '../core/theme.dart';
import '../l10n/errors.dart';
import '../l10n/x.dart';
import 'ai/chain.dart';
import 'ai/compaction.dart';
import 'ai/content.dart';
import 'ai/errors.dart';
import 'ai/image_gen.dart';
import 'ai/prompt.dart';
import 'ai/speech.dart';
import 'ai/provider_model.dart';
import 'ai/segmenter.dart' show Segmenter, humanDelay, jitterMs, typingMs;
import 'ai/adapter.dart';
import 'ai_client.dart';
import 'ai/tool_wire.dart';
import 'ai_config.dart';
import 'auto_backup.dart';
import 'backup.dart';
import 'backup_archive.dart';
import 'backup_remote.dart';
import 'db.dart';
import 'file_text.dart';
import 'gen_prefs.dart';
import 'speech_config.dart';
import 'human/br_parser.dart';
import 'human/hub.dart';
import 'human/human_models.dart';
import 'human/mcp_client.dart';
import 'human/memory.dart';
import 'human/notifications.dart';
import 'human/scheduler.dart';
import 'human/sticker_lib.dart';
import 'models.dart';
import 'oii/backup_archive.dart' show buildBackupArchive, hasOiiBackupManifest, parseBackupArchive, safeChatFileName, shaHex;
import 'skills/skill.dart';
import 'skills/skill_prompt.dart';
import 'skills/skill_store.dart';
import 'workspace/host_file_tools.dart';
import 'workspace/workspace.dart';
import 'workspace/workspace_metadata.dart';
import 'workspace/workspace_runtime.dart';
import 'workspace/workspace_bootstrap.dart';
import 'workspace/workspace_store.dart';
import 'workspace/workspace_tools.dart';

part 'store_human.dart';
part 'store_agent.dart';
part 'store_gen.dart';
part 'store_workspace.dart';
part 'backup_store.dart';
part 'backup_store_oii.dart';

class _Run {
  final AiCancel token = AiCancel();

  /// the streaming break-tag parser of this run, so an interrupt can reach it
  BrParser? parser;

  /// bubbles that were cut but are still waiting for their pause
  final List<String> queued = [];

  /// The trace row the tool call currently running is writing into. A tool
  /// handler cannot reach the row any other way: HTool.run only sees the
  /// arguments, not the call. The workspace tools use this to attach a diff that
  /// belongs on screen and must not go into the transcript.
  Msg? row;

  bool get cancelled => token.cancelled;
}

// Inline file injection ceilings, in characters. A single file never exceeds
// _inlineFileMaxChars (over-budget files still go in as a head+tail excerpt,
// see sampleTextFile), and the whole request never carries more than
// _inlineFilesTotalChars of file content on top of the transcript. The request
// builder also truncates against the context window afterwards, so even a
// worst-case CJK file lands in a window that was sized for it.
const _inlineFileMaxChars = 40000;
const _inlineFilesTotalChars = 120000;

// Mutable allowance handed across the per-message describe calls inside one
// history build, so the newest files win when everything does not fit.
class _InlineBudget {
  _InlineBudget(this.left);
  int left;
}

// single source of truth for chats and settings
class Store extends ChangeNotifier {
  Store._(this._sp);
  final SharedPreferences _sp;
  final AiClient ai = AiClient();
  final List<Chat> chats = [];
  final Map<String, _Run> _runs = {};

  /// Pending ask polls by message id. An `ask` tool call registers its
  /// completer here and blocks; voting on the poll completes it, and a
  /// stop / interrupt / regenerate cancels it. Keyed by message id so a
  /// reloaded chat cannot complete the wrong wait.
  final Map<String, Completer<String>> _askPending = {};

  /// Message history storage. Null when SQLite is unavailable, which is the
  /// test harness and any platform the plugin does not reach; the blob in
  /// SharedPreferences carries the chats instead, exactly as before.
  ChatDb? _db;

  /// Ids of chats changed since the last flush. The listener marks; the flush
  /// writes one chat per id, so a keystroke in one draft no longer rewrites
  /// every conversation in the app. Ids rather than chat objects because a
  /// backup restore can swap the object under a live id.
  final Set<String> _dirtyIds = {};

  /// Message indexes changed inside a chat since the last flush, keyed by chat
  /// id. This is the incremental half of [_dirtyIds]: the id says *which* chat
  /// to write, this says *which rows* of it. Without it every flush rewrites
  /// the chat's whole history, so a streamed chunk in a 2000 message chat costs
  /// 2000 encodes and 2000 row writes. Empty for a chat means "the head changed
  /// but the messages did not" (a draft keystroke, a mute toggle), which still
  /// needs the head row written.
  final Map<String, Set<int>> _dirtyMsgs = {};

  /// A message id that changed without a usable index. Falling back to a full
  /// rewrite for that chat is always correct, just slower, so a message that
  /// cannot be located never silently fails to persist.
  final Set<String> _dirtyIdsFallback = {};

  /// Per-message streaming fan-out. A streamed chunk bumps one message's
  /// revision instead of notifying the whole store, so only the bubble that
  /// listens to that message repaints.
  final StreamBus streams = StreamBus();

  /// Per chat listener closures. Tearoffs cannot carry the chat, and a fresh
  /// `() => _onChat(c)` at remove time would not match the one at add time,
  /// so the closure is kept where removal can find it.
  final Map<Chat, VoidCallback> _chatListeners = {};

  /// How many of a chat's messages currently carry a change hook.
  ///
  /// Messages are appended from a dozen places — the send path, the trace rows,
  /// the greeting seeder, the humanize layer, the agent loop — and hooking each
  /// site by hand means the one that gets missed silently stops persisting.
  /// Comparing this count against `c.msgs.length` on the chat-level change
  /// signal catches every one of them for the price of an int compare, and only
  /// a real change pays for the re-walk.
  final Map<Chat, int> _hooked = {};

  /// Sidebar position per chat id, database ordinals when SQLite is on and
  /// list indexes when it is not. New chats take [maxOrd] + 1, so adding one
  /// cannot shuffle the existing ones.
  final Map<String, int> _chatOrd = {};

  int get maxOrd => _chatOrd.values.fold(-1, (a, b) => a > b ? a : b);

  /// humanize layer: settings, memory, stickers, scheduler, wallet, MCP
  HumanHub? human;

  /// workspace list and the feature switch. Its own notifier so the file
  /// browser does not rebuild the chat list on every rename.
  late final WorkspaceStore workspace;

  /// Installed skills and the per role selection. Its own notifier so the
  /// skills page does not rebuild the chat list on every toggle.
  late final SkillStore skills;

  /// The environment stack. Set at startup by main so the tool layer and the
  /// environment page share one channel and one installer.
  WorkspaceStack? workspaceStack;

  /// Asked before a workspace write lands, with the diff already computed. Set
  /// by main.dart next to askHandler. Null means a headless reply, which writes
  /// without asking because there is nobody there to ask.
  ///
  /// The chat is passed in because "allow this for the rest of the conversation"
  /// writes to its binding, and the tool handler has no argument for it.
  Future<bool?> Function(WsPendingWrite write, Chat chat)? wsReviewHandler;

  Timer? _humanTimer;
  Timer? _saveTimer;

  /// Automatic backup policy and where it writes. Loaded at boot; the tick
  /// rides the scheduler heartbeat in [startHuman].
  AutoBackup autoBackup = AutoBackup();

  /// The remote target every automatic backup is also pushed to, when one is
  /// configured. Holds credentials, so it is deliberately kept out of the
  /// backup document: a restore must never be able to carry a secret.
  RemoteConfig remoteBackup = RemoteConfig();

  BackupSink? _backupSink;
  bool _backupDirty = false;
  bool _backupRunning = false;
  Directory? _debugBackupDocsDir;
  int _seq = 0;

  /// Provider list, fallback chain and API keys. Set once at startup.
  AiConfig? _ai;

  /// The voice module. Held separately from the AI config because it is a
  /// module of its own, not a provider in the chat list.
  SpeechConfig? _speech;

  /// The last node that actually answered, shown as a footer on the reply.
  String? lastServedBy;  AiConfig get aiConfig => _ai!;

  /// The voice module. Attached during [load] rather than from main, so a
  /// widget test that only builds a [Store] still has one: the drawing and
  /// speech tools read this, and a missing module silently drops both.
  SpeechConfig get speechConfig => _speech!;

  /// The nodes a chat actually runs on. A persona model override goes in front
  /// of the global chain, or stands alone when the persona opted out of the
  /// fallback, so one bad model cannot quietly reroute an override.
  List<ChainNode> chainFor(Chat c) {
    final cfg = _ai;
    if (cfg == null) return const [];
    final global = activeChain(cfg.settings);
    final persona = c.persona;
    if (!persona.hasModelOverride) return global;
    final node = ChainNode(
      id: 'persona_${c.id}',
      providerId: persona.modelProvider.trim(),
      modelId: persona.modelId.trim(),
      retries: 1,
      enabled: true,
    );
    if (!persona.modelFallback) return [node];
    // the very same pair already sits on the chain, trying it twice only
    // burns a retry before reaching the node that works
    final rest = global.where((n) => n.providerId != node.providerId || n.modelId != node.modelId);
    return [node, ...rest];
  }

  /// The endpoint the ai editor probes and the profile card shows: the first
  /// chain node that actually has a key behind it. Keys are per provider, so
  /// reading `providers.first` used to report an empty key even when the user
  /// had configured one on any other provider.
  ({Provider provider, String baseUrl, String key, String model})? get _endpoint {
    final cfg = _ai;
    if (cfg == null) return null;
    for (final node in activeChain(cfg.settings)) {
      final provider = findProvider(cfg.settings, node.providerId);
      if (provider == null) continue;
      final key = cfg.keyOf(provider.id);
      if (key.isEmpty) continue;
      return (provider: provider, baseUrl: provider.baseUrl, key: key, model: node.modelId);
    }
    // no chain entry can run yet, so settle for any provider holding a key
    for (final provider in cfg.settings.providers) {
      final key = cfg.keyOf(provider.id);
      if (key.isEmpty) continue;
      return (provider: provider, baseUrl: provider.baseUrl, key: key, model: provider.models.firstOrNull?.id ?? '');
    }
    return null;
  }

  /// The provider behind [baseUrl], for callers that must ride the same wire.
  Provider? get endpointProvider => _endpoint?.provider;

  String get baseUrl => _endpoint?.baseUrl ?? 'https://api.openai.com/v1';

  String get model {
    final model = _endpoint?.model ?? '';
    return model.isEmpty ? 'gpt-4o-mini' : model;
  }

  /// Legacy single key view, kept for the ai editor which does one off calls.
  String get apiKey => _endpoint?.key ?? '';

  /// My own persona cards, the SillyTavern persona side of the app
  final List<UserPersona> personas = [];
  String _activePersonaId = '';
  String? _defaultPersonaId;
  /// ai persona name -> ids of my cards locked to it
  final Map<String, List<String>> charLocks = {};

  /// stands in while the store has no cards at all, so the ui never has to
  /// null check the card it is editing
  final UserPersona _placeholder = UserPersona(id: '', name: 'You');

  /// The bio stays a short blurb shown on the profile, it is never injected.
  /// The long form of "who I am" lives in the persona cards.
  String userBio = '';
  bool haptics = true;
  bool countMuted = false;
  bool dark = false;
  double textSize = 16;
  double bubbleRadius = 17;

  /// Global chat wallpaper. Empty draws the plain procedural gradient, the
  /// default. A conversation can override this in either direction.
  String wallpaperPath = '';

  /// Whether that wallpaper is blurred. Photos behind text are hard to read,
  /// so this defaults on.
  bool wallpaperBlur = true;

  /// Accent lifted out of the wallpaper, ARGB, or null to keep the stock one.
  int? wallpaperColor;

  /// Which outgoing bubble gradient to draw when [wallpaperColor] is set, as an
  /// index into [BubbleGrad.values]. Stored as an int rather than a name so an
  /// older build reading a newer value cannot fall over on an unknown string.
  int wallpaperBubbleGrad = BubbleGrad.medium.index;

  String? openId;
  List<String> recentEmoji = [];
  List<String> recentStickers = [];
  List<String> recentSearch = [];

  // ---- the two reply switches, global half of a setting the persona can take

  /// Show what the model thinks before it answers. Off by default so a plain
  /// assistant still reads like a chat and not like a console.
  bool showThinking = false;

  /// Let the model call tools (MCP and the local ones) and show every step of
  /// it. Independent of the humanize layer: on a plain chat this hands the
  /// model the MCP catalogue, under humanize it adds the step display to the
  /// tools that layer already offers.
  bool agentMode = false;

  /// How many tool passes one reply may run before the store pulls the brake.
  /// 0 runs without a cap: the loop only spins while the model keeps asking
  /// for tools, so a well behaved model never lands on the brake anyway.
  /// Eight covers every sane agent task, which is why it is the default.
  int agentMaxPass = 8;

  /// False until the first-run wizard finishes. Every install starts false, so
  /// an upgrade lands in the wizard exactly once too; the last step is the
  /// only thing that flips it.
  bool onboarded = false;

  /// Persona override wins, the global switch is the fallback. A persona that
  /// never touched the row has null on both halves and simply follows.
  bool thinkingFor(Chat c) => c.persona.thinking ?? showThinking;
  bool agentFor(Chat c) => c.persona.agent ?? agentMode;

  /// null follows the device language, anything else is one of the tags the
  /// arb files are named after
  String? localeTag;

  /// Release tag the user asked not to be reminded of again. Empty means no
  /// version is skipped: a new tag always shows, a skipped one only on a
  /// manual check from settings.
  String skippedRelease = '';

  static Future<Store> load({String? dbPath}) async {
    final s = Store._(await SharedPreferences.getInstance());
    // base/key/model now live in AiConfig and are migrated there
    s._loadPersonas();
    s.human = await HumanHub.load(s._sp);
    s.workspace = await WorkspaceStore.load(s._sp);
    s.skills = await SkillStore.load(s._sp);
    s.userBio = s._sp.getString('userBio') ?? '';
    s.haptics = s._sp.getBool('haptics') ?? true;
    s.countMuted = s._sp.getBool('countMuted') ?? false;
    s.showThinking = s._sp.getBool('showThinking') ?? false;
    s.agentMode = s._sp.getBool('agentMode') ?? false;
    s.agentMaxPass = s._sp.getInt('agentMaxPass') ?? 8;
    s.onboarded = s._sp.getBool('onboarded') ?? false;
    s.dark = s._sp.getBool('dark') ?? false;
    s.textSize = s._sp.getDouble('textSize') ?? 16;
    s.bubbleRadius = s._sp.getDouble('radius') ?? 17;
    s.wallpaperPath = s._sp.getString('wallpaper') ?? '';
    s.wallpaperBlur = s._sp.getBool('wallpaperBlur') ?? true;
    final wc = s._sp.getInt('wallpaperColor');
    s.wallpaperColor = wc == null || wc == 0 ? null : wc;
    // clamped rather than trusted: a value written by a build with more levels
    // than this one would otherwise index off the end of BubbleGrad.values
    s.wallpaperBubbleGrad = (s._sp.getInt('wallpaperBubbleGrad') ?? BubbleGrad.medium.index).clamp(0, BubbleGrad.values.length - 1);
    s.recentEmoji = s._sp.getStringList('recentEmoji') ?? [];
    s.recentStickers = s._sp.getStringList('recentStickers') ?? [];
    s.recentSearch = s._sp.getStringList('recentSearch') ?? s._sp.getStringList('recentSearches') ?? [];
    final lang = s._sp.getString('locale');
    s.localeTag = lang == null || lang.isEmpty ? null : lang;
    s.skippedRelease = s._sp.getString('skippedRelease') ?? '';
    await s._loadChats(dbPath: dbPath);
    s._loadAutoBackup();
    s._loadRemoteBackup();
    s._backupSink = MediaStoreBackupSink();
    // the voice module rides along here rather than being handed in from main:
    // it reads the same SharedPreferences this store already holds, and every
    // path that builds a Store gets a working module without a second load.
    s.attachSpeech(SpeechConfig.fromPrefs(s._sp));
    themeCtl.setDark(s.dark, animate: false);
    return s;
  }

  /// The chat list, from SQLite when there is a database and from the
  /// SharedPreferences blob when there is not.
  ///
  /// Upgrading is automatic and safe to interrupt: a legacy blob is moved into
  /// the database in one transaction, and the blob key is removed only after
  /// the chats read back out of the database match what went in. If anything
  /// disagrees, the blob stays and remains the source of truth for every
  /// later run.
  Future<void> _loadChats({String? dbPath}) async {
    final raw = _sp.getString('chats');
    try {
      _db = await ChatDb.open(path: dbPath);
    } catch (_) {
      _db = null;
    }

    if (_db != null) {
      await _migrateBlob(raw);
      try {
        chats.addAll(await _db!.loadChats());
        final ords = await _db!.chatOrds();
        // keep the positions the sidebar had, so new chats append after them
        _chatOrd.addAll(ords);
        for (var i = 0; i < chats.length; i++) {
          _chatOrd.putIfAbsent(chats[i].id, () => i);
        }
        // every chat's history back into memory: the ui reads c.msgs directly
        // and a chat without its rows would render empty
        for (final c in chats) {
          c.msgs.addAll(await _db!.loadMsgs(c.id));
        }
      } catch (_) {
        // a database that opened but cannot be read falls back to the blob,
        // which the migration above has not touched in that case
        _db = null;
        chats.clear();
        _chatOrd.clear();
      }
    }

    // no database, or one that could not be read: the blob path, exactly as
    // every build before this one
    if (_db == null) {
      if (raw != null) {
        try {
          for (final j in jsonDecode(raw) as List) {
            chats.add(Chat.fromJson(j as Map<String, dynamic>));
          }
        } catch (_) {
          chats.clear();
        }
      }
    }

    for (var i = 0; i < chats.length; i++) {
      _chatOrd.putIfAbsent(chats[i].id, () => i);
    }
    // The starter chats moved into the onboarding: a fresh install now begins
    // empty and the template picker on the last step creates the first ones.
    // An explicit empty list or an empty database stays a user who deleted
    // everything, not a missed first run. The marker is still written on every
    // load so the migration bookkeeping keeps a single meaning.
    _sp.setBool('chatsSeen', true);
    for (final c in chats) {
      _listen(c);
    }
  }

  /// Moves the legacy chat blob into SQLite. Only runs while the blob key is
  /// still present, so this is once per install. Migration runs in
  /// [ChatDb.migrateFrom]'s transaction, and the key is dropped only when
  /// what went in and what came back agree, so an interrupted upgrade finds
  /// the blob still there rather than an empty database.
  Future<void> _migrateBlob(String? raw) async {
    if (raw is! String) return;
    var migrated = 0;
    var inBlob = 0;
    try {
      inBlob = (jsonDecode(raw) as List).length;
    } catch (_) {
      return; // an unreadable blob cannot be verified, leave it alone
    }
    try {
      migrated = await _db!.migrateFrom(raw);
    } catch (_) {
      return; // the blob stays, next run tries again
    }
    if (migrated != inBlob) return; // unverifiable, keep the blob
    await _sp.remove('chats');
  }

  static Store of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static Store read(BuildContext c) => (c.getElementForInheritedWidgetOfExactType<StoreScope>()!.widget as StoreScope).notifier!;

  /// Called once from [load], right after the module has read its keys.
  void attachSpeech(SpeechConfig config) {
    _speech = config;
    _speech!.addListener(notifyListeners);
  }

  void attachAi(AiConfig config) {
    _ai = config;
    _ai!.addListener(_onAiChanged);
  }

  void _onAiChanged() => notifyListeners();

  /// Foreground heartbeat of the scheduler, wired to notifications once. The
  /// background isolate does not call this, it runs [runDueHeadless] instead.
  void startHuman() {
    final hh = human;
    if (hh == null || _humanTimer != null) return;
    hh.onNotify = (chatId, msgId, title, body) => unawaited(Notifier.instance.show(msgId, title, body));
    hh.onCancelNotify = (msgId) => unawaited(Notifier.instance.cancel(msgId));
    unawaited(hh.mcp.refresh(hh.mcpServers).then((_) => hh.changed()));
    _humanTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      humanTick();
      // the auto backup shares the scheduler heartbeat: no second timer, and
      // the tick itself decides per mode whether anything is due
      unawaited(_autoBackupTick());
    });
    unawaited(humanTick());
  }

  String _id() => '${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  // dialogs order pinned first then newest
  List<Chat> get sorted {
    final l = [...chats];
    l.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.lastTime.compareTo(a.lastTime);
    });
    return l;
  }

  int unreadOf(Chat c) => c.unread > 0 ? c.unread : (c.markedUnread ? 1 : 0);

  int get totalUnread => chats.where((c) => countMuted || !c.muted).fold(0, (a, c) => a + c.unread);

  // bytes held by attachments in every chat
  int get attachBytes {
    var n = 0;
    for (final c in chats) {
      for (final m in c.msgs) {
        n += (m.data['size'] as num?)?.toInt() ?? 0;
      }
    }
    return n;
  }

  // drop the local media refs but keep the messages
  void clearMedia() {
    for (final c in chats) {
      c.msgs.removeWhere((m) => m.kind == MsgKind.photo || m.kind == MsgKind.video || m.kind == MsgKind.file || m.kind == MsgKind.music);
      c.touch();
    }
  }

  // every hit of a query across chats newest first
  List<(Chat, Msg)> searchAll(String q, {Chat? only, bool Function(Msg)? where}) {
    final t = q.trim().toLowerCase();
    final out = <(Chat, Msg)>[];
    for (final c in only == null ? chats : [only]) {
      for (final m in c.msgs) {
        if (m.service) continue;
        if (where != null && !where(m)) continue;
        if (t.isEmpty || m.haystack.contains(t)) out.add((c, m));
      }
    }
    out.sort((a, b) => b.$2.time.compareTo(a.$2.time));
    return out;
  }

  void _onChat(Chat c) {
    _dirtyIds.add(c.id);
    // A chat that grew a message since the last walk has an unhooked one, so
    // re-walk before the flush reads the hooks. This is what makes the
    // incremental path safe to rely on rather than something every one of the
    // dozen append sites has to remember to feed.
    if ((_hooked[c] ?? -1) != c.msgs.length) {
      // The transcript shape moved: rows were appended or removed, which the
      // per-message dirty set cannot express (a new row is not a change to an
      // old one, and a removed row leaves no index behind). A full rewrite is
      // the only correct statement of that, and it is rare enough - one per
      // message, not one per chunk - to stay cheap.
      _dirtyIdsFallback.add(c.id);
      _reindex(c);
    }
    notifyListeners();
    _scheduleSave();
  }

  /// Marks one message of [c] as changed.
  ///
  /// Wired to [Msg.onChange], which every message owns but nothing had ever
  /// pointed at a listener: the store learned a chat was dirty through
  /// `Chat.touch()` alone, which says nothing about *which* message moved and
  /// so forced every flush to rewrite the whole history. [i] is the index the
  /// hook was built with; it is validated here rather than trusted, so a message
  /// that has moved, been deleted or been detached from the transcript falls
  /// back to the whole-chat path instead of writing the wrong row.
  void _onMsg(Chat c, Msg m, int i) {
    _dirtyIds.add(c.id);
    if (i < 0 || i >= c.msgs.length || !identical(c.msgs[i], m)) {
      // The index the hook was built with no longer names this message: the
      // list was reordered, spliced or restored under it. Falling back to the
      // whole-chat rewrite is always correct, just slower.
      _dirtyIdsFallback.add(c.id);
    } else {
      (_dirtyMsgs[c.id] ??= <int>{}).add(i);
      // The bubble's own pixels moved. Bumping its revision repaints that
      // bubble alone; the page is not notified, which is the whole point.
      streams.bump(m.id);
    }
    _scheduleSave();
  }

  /// Wires [c] so edits to it reach storage, the way every chat loaded at
  /// startup is wired.
  void _listen(Chat c) {
    if (_chatListeners.containsKey(c)) return;
    final fn = () => _onChat(c);
    _chatListeners[c] = fn;
    c.addListener(fn);
    // Each message reports its own changes. This is the hook that makes the
    // incremental flush possible; without it the only signal is the chat-level
    // one, which cannot name a row.
    _reindex(c);
  }

  void _unlisten(Chat c) {
    final fn = _chatListeners.remove(c);
    if (fn != null) c.removeListener(fn);
    for (final m in c.msgs) {
      m.onChange = null;
    }
    _dirtyMsgs.remove(c.id);
    _dirtyIdsFallback.remove(c.id);
    _hooked.remove(c);
  }

  /// Attaches the per-message change hook to a message that was just added.
  ///
  /// A message constructed after [_listen] ran has no `onChange` yet, and the
  /// streaming path constructs the live bubble mid-run, so every append goes
  /// through here. The owning chat and the index are passed rather than looked
  /// up: the caller knows both, and a scan of the history per chunk would cost
  /// more than the incremental save it exists to make cheap. The index is
  /// validated against the list at call time, so a stale one degrades to the
  /// full rewrite rather than writing the wrong row.
  void _watch(Msg m, Chat c, [int? at]) {
    final i = at ?? c.msgs.indexOf(m);
    m.onChange = (_) => _onMsg(c, m, i);
  }

  /// Re-points every message's hook at its current index.
  ///
  /// Called whenever the list is restructured (a load, a restore, a delete that
  /// shifts the tail) because the captured index would otherwise name a
  /// different message.
  void _reindex(Chat c) {
    for (var i = 0; i < c.msgs.length; i++) {
      _watch(c.msgs[i], c, i);
    }
    _hooked[c] = c.msgs.length;
  }

  /// Floor between two flushes while changes keep arriving.
  ///
  /// This is kelivo's `LatestWinsCheckpointWriter.minimumInterval`, 250 ms, and
  /// it exists because the previous implementation was a plain reset debounce:
  /// every change cancelled the timer and started a fresh 400 ms one, so a
  /// stream that produced a delta more often than that never flushed at all
  /// until the reply ended. A ten minute answer, or a phone that kills the app
  /// mid-reply, lost the whole thing. Here a pending flush is never pushed back,
  /// so the transcript is written at least four times a second while it grows.
  static const _flushMinInterval = Duration(milliseconds: 250);

  /// How long to wait after the last change before writing, when nothing is
  /// arriving. Keeps a typing user from writing on every keystroke.
  static const _flushIdle = Duration(milliseconds: 400);

  DateTime? _lastSaveAt;

  /// Schedules the next flush.
  ///
  /// An already pending flush is left alone rather than postponed. That single
  /// difference is what turns the old starving reset-debounce into a
  /// bounded-staleness writer: the write happens no later than
  /// [_flushMinInterval] after the previous one, whatever the delta rate.
  void _scheduleSave() {
    if (_saveTimer?.isActive ?? false) return;
    final last = _lastSaveAt;
    var wait = _flushIdle;
    if (last != null) {
      final since = DateTime.now().difference(last);
      if (since < _flushMinInterval) wait = _flushMinInterval - since;
    }
    _saveTimer = Timer(wait, _save);
  }

  /// Says the chat list itself changed, rather than the contents of one chat.
  ///
  /// Public because the backup restore is an extension and an extension cannot
  /// reach notifyListeners. The whole list is marked: a restore swaps or adds
  /// chats wholesale, and each of them must be written back.
  void chatsChanged() {
    _dirtyIds.addAll(chats.map((e) => e.id));
    _backupDirty = true;
    // A restore replaces chat objects wholesale, so every message row of every
    // chat is new. Marking them head-only here would write the metadata and
    // silently keep the old bodies.
    _dirtyIdsFallback.addAll(chats.map((e) => e.id));
    notifyListeners();
    _scheduleSave();
  }

  /// Rebuilds listeners without marking anything dirty. Public for the same
  /// reason as chatsChanged: extensions in this library are not instance
  /// members, so the protected notifyListeners is off limits to them.
  void bump() => notifyListeners();

  /// Stops the periodic timers. The app never calls this (the process owns
  /// them); it exists so tests can shut a store down cleanly.
  @visibleForTesting
  void shutdown() {
    _humanTimer?.cancel();
    _humanTimer = null;
  }

  /// Persists what changed since the last flush: on SQLite the touched chats,
  /// one transaction each, otherwise the whole list as the single blob.
  ///
  /// A dirty id without a live chat is the deletion path: its database row
  /// has to go. The blob path cannot lose a deletion because it rewrites the
  /// surviving list in full.
  void _save() {
    _backupDirty = true;
    _lastSaveAt = DateTime.now();
    final db = _db;
    if (db == null) {
      _sp.setString('chats', jsonEncode(chats.map((e) => e.toJson()).toList()));
      _dirtyIds.clear();
      _dirtyMsgs.clear();
      _dirtyIdsFallback.clear();
      return;
    }
    if (_dirtyIds.isEmpty) return;
    final ids = [..._dirtyIds];
    final dirty = Map<String, Set<int>>.from(_dirtyMsgs);
    final fallback = Set<String>.of(_dirtyIdsFallback);
    _dirtyIds.clear();
    _dirtyMsgs.clear();
    _dirtyIdsFallback.clear();
    unawaited(_saveChats(db, ids, dirty, fallback));
  }

  /// Serializes the actual writes.
  ///
  /// [_save] can fire again while a previous flush is still on the SQLite
  /// thread — a stream produces a chunk every few tens of milliseconds and the
  /// debounce only spaces the *starts* — so two flushes could otherwise
  /// interleave transactions against the same chat and one could read the other
  /// half applied. Chaining on this future keeps them in order without blocking
  /// the caller.
  Future<void> _writes = Future<void>.value();

  Future<void> _saveChats(ChatDb db, List<String> ids, Map<String, Set<int>> dirty, Set<String> fallback) async {
    _writes = _writes.then((_) => _saveChatsNow(db, ids, dirty, fallback));
    return _writes;
  }

  Future<void> _saveChatsNow(ChatDb db, List<String> ids, Map<String, Set<int>> dirty, Set<String> fallback) async {
    for (final id in ids) {
      final at = chats.indexWhere((e) => e.id == id);
      try {
        if (at < 0) {
          _chatOrd.remove(id);
          await db.deleteChat(id);
        } else {
          final c = chats[at];
          _chatOrd[id] ??= maxOrd + 1;
          // Three states, and they have to stay distinct:
          //   null        -> the messages changed wholesale (or moved under
          //                  their hooks), so rewrite the lot
          //   {}          -> only the head changed, so write no message rows
          //   {i, j, ...} -> rewrite just those, which is the streaming case
          final rows = fallback.contains(id) ? null : (dirty[id] ?? const <int>{});
          await db.saveChat(c, _chatOrd[id]!, msgs: c.msgs, dirty: rows);
        }
      } catch (_) {
        // a failed write must not take the run that touched the chat down
        // with it; the in memory copy is intact, the row keeps its old shape
      }
    }
  }

  /// Writes into the first provider and the first chain node, so the old
  /// single endpoint editor keeps working against the new chain model.
  void setSetting({String? base, String? key, String? mdl}) {
    final cfg = _ai;
    if (cfg == null) return;
    final provider = cfg.settings.providers.firstOrNull;
    if (provider == null) return;

    if (base != null) {
      cfg.patchProvider(provider.id, (p) => p.baseUrl = base.trim().isEmpty ? 'https://api.openai.com/v1' : base.trim());
    }
    if (key != null) {
      cfg.saveApiKey(provider.id, key);
    }
    if (mdl != null) {
      final id = mdl.trim().isEmpty ? 'gpt-4o-mini' : mdl.trim();
      ChainNode? node;
      for (final n in activeChain(cfg.settings)) {
        if (n.providerId == provider.id) {
          node = n;
          break;
        }
      }
      if (node != null) {
        cfg.removeChainNode(node.id);
      }
      cfg.addChainNode(provider.id, id);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- personas

  void _loadPersonas() {
    final raw = _sp.getString('userPersonas');
    if (raw != null) {
      try {
        for (final j in jsonDecode(raw) as List) {
          final p = UserPersona.fromJson(j as Map<String, dynamic>);
          if (p.id.isNotEmpty) personas.add(p);
        }
      } catch (_) {
        personas.clear();
      }
    }

    // older builds only had a name, a bio and a photo, so fold those into the
    // very first card rather than losing what the user already wrote
    if (personas.isEmpty) {
      final name = _sp.getString('userName') ?? _sp.getString('user');
      final avatar = _sp.getString('userAvatar') ?? '';
      if (name == null && avatar.isEmpty) return;
      final card = UserPersona(
        id: _pid(),
        name: (name == null || name.trim().isEmpty) ? 'You' : name.trim(),
        description: _sp.getString('userBio') ?? '',
        avatarPath: avatar,
        color: 4,
      );
      personas.add(card);
      _activePersonaId = card.id;
      _defaultPersonaId = card.id;
      _savePersonas();
      // the bio moved into the card, keep the display copy in step with it
      userBio = card.description;
    }

    _defaultPersonaId = _sp.getString('defaultPersona');
    final wanted = _sp.getString('activePersona');
    // a lock or a default left behind by a deleted card must not strand the app
    if (wanted != null && personas.any((p) => p.id == wanted)) {
      _activePersonaId = wanted;
    } else if (!personas.any((p) => p.id == _defaultPersonaId)) {
      _defaultPersonaId = null;
      _activePersonaId = personas.isEmpty ? '' : personas.first.id;
    } else {
      _activePersonaId = _defaultPersonaId!;
    }
    final locks = _sp.getString('personaCharLocks');
    if (locks != null) {
      try {
        for (final e in (jsonDecode(locks) as Map).entries) {
          final ids = (e.value as List).map((v) => v as String).where((id) => personas.any((p) => p.id == id)).toList();
          if (ids.isNotEmpty) charLocks[e.key as String] = ids;
        }
      } catch (_) {
        charLocks.clear();
      }
    }
  }

  void _savePersonas() {
    _sp.setString('userPersonas', jsonEncode(personas.map((e) => e.toJson()).toList()));
    _sp.setString('activePersona', _activePersonaId);
    if (_defaultPersonaId != null) {
      _sp.setString('defaultPersona', _defaultPersonaId!);
    } else {
      _sp.remove('defaultPersona');
    }
    _sp.setString('personaCharLocks', jsonEncode(charLocks));
  }

  String _pid() => 'p${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  /// The card currently being edited. Never null, an empty store borrows a
  /// throwaway so the ui always has something to bind to.
  UserPersona get activePersona => _byId(_activePersonaId) ?? (personas.isEmpty ? _placeholder : personas.first);

  UserPersona? _byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in personas) {
      if (p.id == id) return p;
    }
    return null;
  }

  UserPersona? get defaultPersona => _byId(_defaultPersonaId);

  bool isDefault(String id) => _defaultPersonaId == id;

  /// Chat lock wins over character lock wins over the card in hand, the same
  /// order SillyTavern resolves loadPersonaForCurrentChat walks.
  UserPersona personaFor(Chat c) {
    final locked = _byId(c.personaId);
    if (locked != null) return locked;
    final byChar = _byId(_firstLockFor(c.persona.name));
    if (byChar != null) return byChar;
    final active = _byId(_activePersonaId);
    if (active != null) return active;
    return defaultPersona ?? (personas.isEmpty ? _placeholder : personas.first);
  }

  String? _firstLockFor(String charName) => charLocks[charName]?.firstWhere((id) => _byId(id) != null, orElse: () => '');

  UserPersona createPersonaCard({String name = '', String description = ''}) {
    final card = UserPersona(id: _pid(), name: name.trim(), description: description.trim(), color: personas.length % avatarColorCount);
    // a fresh card becomes the one in hand, that is what the user just touched
    personas.add(card);
    _activePersonaId = card.id;
    _savePersonas();
    notifyListeners();
    return card;
  }

  void updatePersonaCard(String id, void Function(UserPersona p) patch) {
    final card = _byId(id);
    if (card == null) return;
    patch(card);
    _savePersonas();
    notifyListeners();
  }

  /// Duplicates a card the way SillyTavern clones an avatar, description and
  /// position come along so it can be tweaked independently.
  UserPersona duplicatePersonaCard(String id) {
    final src = _byId(id);
    if (src == null) return activePersona;
    final copy = src.copyWith(name: '${src.name} copy');
    final card = UserPersona(id: _pid(), name: copy.name, title: copy.title, description: copy.description, avatarPath: copy.avatarPath, color: copy.color, position: copy.position, depth: copy.depth, role: copy.role);
    personas.add(card);
    _activePersonaId = card.id;
    _savePersonas();
    notifyListeners();
    return card;
  }

  void deletePersonaCard(String id) {
    personas.removeWhere((p) => p.id == id);
    for (final ids in charLocks.values) {
      ids.remove(id);
    }
    charLocks.removeWhere((_, ids) => ids.isEmpty);
    // a chat locked to the card that just went has to fall back too
    for (final c in chats) {
      if (c.personaId == id) {
        c.personaId = null;
        c.touch();
      }
    }
    if (_defaultPersonaId == id) _defaultPersonaId = null;
    if (_activePersonaId == id) _activePersonaId = personas.isEmpty ? '' : personas.first.id;
    _savePersonas();
    notifyListeners();
  }

  void selectPersona(String id) {
    if (_byId(id) == null) return;
    _activePersonaId = id;
    _savePersonas();
    notifyListeners();
  }

  void toggleDefaultPersona(String id) {
    if (_byId(id) == null) return;
    _defaultPersonaId = _defaultPersonaId == id ? null : id;
    _savePersonas();
    notifyListeners();
  }

  void toggleChatLock(Chat c, String id) {
    // a chat lock and a character lock are independent entries, SillyTavern
    // keeps both in one connections array, so unsetting one must leave the
    // other standing
    c.personaId = c.personaId == id ? null : id;
    c.touch();
    _savePersonas();
    notifyListeners();
  }

  void toggleCharLock(String charName, String id) {
    final ids = charLocks.putIfAbsent(charName, () => []);
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    if (ids.isEmpty) charLocks.remove(charName);
    _savePersonas();
    notifyListeners();
  }

  /// Cards locked to a given ai persona, used by the connections row
  List<UserPersona> lockedTo(String charName) {
    final out = <UserPersona>[];
    for (final id in charLocks[charName] ?? const <String>[]) {
      final p = _byId(id);
      if (p != null) out.add(p);
    }
    return out;
  }

  // --------------------------------------------------------------- identity

  /// Name and avatar follow the card in hand, so every screen that shows them
  /// picks up a switch without a single call site changing.
  String get userName => activePersona.name.trim().isEmpty ? 'You' : activePersona.name.trim();
  String get userAvatar => activePersona.avatarPath;

  void setProfile({String? name, String? bio}) {
    if (name != null) {
      final card = activePersona;
      card.name = name.trim().isEmpty ? 'You' : name.trim();
      _savePersonas();
    }
    if (bio != null) userBio = bio.trim();
    _sp.setString('userBio', userBio);
    notifyListeners();
  }

  // the photo lands on its own the moment it is picked, so it must not drag the
  // half edited name and bio along with it. Makes the card first: on a fresh
  // install there is none yet and writing onto the placeholder would look
  // saved until the next restart, then be gone.
  void setAvatar(String path) {
    final card = personas.isEmpty ? createPersonaCard() : activePersona;
    card.avatarPath = path;
    _savePersonas();
    notifyListeners();
  }

  void setHaptics(bool v) {
    haptics = v;
    _sp.setBool('haptics', v);
    notifyListeners();
  }

  void setCountMuted(bool v) {
    countMuted = v;
    _sp.setBool('countMuted', v);
    notifyListeners();
  }

  void setShowThinking(bool v) {
    showThinking = v;
    _sp.setBool('showThinking', v);
    notifyListeners();
  }

  void setAgentMode(bool v) {
    agentMode = v;
    _sp.setBool('agentMode', v);
    notifyListeners();
  }

  void setAgentMaxPass(int v) {
    agentMaxPass = v;
    _sp.setInt('agentMaxPass', v);
    notifyListeners();
  }

  /// Called by the last step of the onboarding. Flipping it rebuilds [TgApp]'s
  /// home, which is how the wizard hands over to the dialog list without any
  /// navigator surgery.
  void setOnboarded(bool v) {
    if (onboarded == v) return;
    onboarded = v;
    _sp.setBool('onboarded', v);
    notifyListeners();
  }

  void setDark(bool v) {
    dark = v;
    _sp.setBool('dark', v);
    themeCtl.setDark(v);
    notifyListeners();
  }

  void setTextSize(double v) {
    textSize = v;
    _sp.setDouble('textSize', v);
    notifyListeners();
  }

  void setRadius(double v) {
    bubbleRadius = v;
    _sp.setDouble('radius', v);
    notifyListeners();
  }

  void setWallpaper(String path) {
    final changed = wallpaperPath != path;
    wallpaperPath = path;
    if (path.isEmpty) {
      _sp.remove('wallpaper');
    } else {
      _sp.setString('wallpaper', path);
    }
    // The accent was read off whichever picture was set before, so it describes
    // an image that is no longer on screen. Left behind it would tint the whole
    // app from a wallpaper the user has just put away, and on a fresh pick it
    // would be a colour lifted from the old photo sitting under the new one.
    if (changed && wallpaperColor != null) {
      setWallpaperColor(null);
      return; // that already notified
    }
    notifyListeners();
  }

  void setWallpaperBlur(bool v) {
    wallpaperBlur = v;
    _sp.setBool('wallpaperBlur', v);
    notifyListeners();
  }

  /// Picks one of the three outgoing bubble gradients, as an index into
  /// [BubbleGrad.values].
  ///
  /// Only has a visible effect while [wallpaperColor] is set: that is the only
  /// case where the bubble is repainted at all, and with no seed the stock
  /// bubbles keep the treatment the palettes shipped with.
  void setWallpaperBubbleGrad(int index) {
    final v = index.clamp(0, BubbleGrad.values.length - 1);
    if (wallpaperBubbleGrad == v) return;
    wallpaperBubbleGrad = v;
    _sp.setInt('wallpaperBubbleGrad', v);
    themeCtl.setAccent(wallpaperColor, BubbleGrad.values[v]);
    notifyListeners();
  }

  void setWallpaperColor(int? argb) {
    wallpaperColor = argb;
    if (argb == null) {
      _sp.remove('wallpaperColor');
    } else {
      _sp.setInt('wallpaperColor', argb);
    }
    themeCtl.setAccent(argb, BubbleGrad.values[wallpaperBubbleGrad]);
    notifyListeners();
  }

  /// Sets or clears the wallpaper of one conversation. Null hands the chat back
  /// Persists a chat that something outside the store changed, such as a
  /// workspace binding picked in a menu.
  void saveChat(Chat c) {
    c.touch();
    _scheduleSave();
  }

  /// to the global choice, an empty string opts it out to the plain gradient.
  void setChatWallpaper(Chat c, String? path) {
    c.wallpaperPath = path;
    c.touch();
    _save();
    notifyListeners();
  }

  /// The language the user picked, or null to follow the device. MaterialApp
  /// takes this straight through, and the arb lookup handles the zh_Hant
  /// script on its own.
  Locale? get locale => switch (localeTag) {
        'en' => const Locale('en'),
        'zh' => const Locale('zh'),
        'zh_Hant' => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        _ => null,
      };

  void setLocale(String? tag) {
    localeTag = tag;
    if (tag == null) {
      _sp.remove('locale');
    } else {
      _sp.setString('locale', tag);
    }
    notifyListeners();
  }

  /// Whether [tag] was skipped from the update sheet. An empty tag is never
  /// skipped, so a broken release payload cannot mute a later real one.
  bool isUpdateSkipped(String tag) => tag.isNotEmpty && skippedRelease == tag;

  /// Remembers [tag] so the automatic check stops nagging about it. A manual
  /// check from settings still shows it.
  void setSkippedRelease(String tag) {
    skippedRelease = tag.trim();
    if (skippedRelease.isEmpty) {
      _sp.remove('skippedRelease');
    } else {
      _sp.setString('skippedRelease', skippedRelease);
    }
  }

  // most recent first capped list
  List<String> _bump(List<String> l, String v, int cap) {
    final n = [v, ...l.where((e) => e != v)];
    return n.length > cap ? n.sublist(0, cap) : n;
  }

  void pushEmoji(String e) {
    recentEmoji = _bump(recentEmoji, e, 32);
    _sp.setStringList('recentEmoji', recentEmoji);
  }

  void pushSticker(String e) {
    recentStickers = _bump(recentStickers, e, 24);
    _sp.setStringList('recentStickers', recentStickers);
  }

  void addRecentSearch(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    recentSearch = _bump(recentSearch, t, 12);
    _sp.setStringList('recentSearch', recentSearch);
    notifyListeners();
  }

  void removeRecentSearch(String q) {
    recentSearch = recentSearch.where((e) => e != q).toList();
    _sp.setStringList('recentSearch', recentSearch);
    notifyListeners();
  }

  void clearRecentSearch() {
    recentSearch = [];
    _sp.setStringList('recentSearch', recentSearch);
    notifyListeners();
  }

Chat createChat(String name, String prompt, {String bio = '', String greeting = '', String emoji = '', String examples = '', String avatarPath = '', int? color, String modelProvider = '', String modelId = '', bool modelFallback = true, bool? thinking, bool? agent, bool clingy = false, int clingySilentMin = 90, bool clingyCap = false, int clingyMax = 3, List<String>? skillIds, bool imageEnabled = false, String imageProvider = '', String imageModel = '', String imageSize = '', bool ttsEnabled = false, TtsEngine? ttsEngine, String ttsBaseUrl = '', String ttsModel = '', String ttsVoice = '', bool ttsAutoSpeak = false}) {
    final c = Chat(id: _id(), persona: Persona(name: name, prompt: prompt, color: color ?? name.hashCode.abs() % avatarColorCount, bio: bio, greeting: greeting, emoji: emoji, examples: examples, avatarPath: avatarPath, modelProvider: modelProvider, modelId: modelId, modelFallback: modelFallback, thinking: thinking, agent: agent, clingy: clingy, clingySilentMin: clingySilentMin, clingyCap: clingyCap, clingyMax: clingyMax, skillIds: skillIds, imageEnabled: imageEnabled, imageProvider: imageProvider, imageModel: imageModel, imageSize: imageSize, ttsEnabled: ttsEnabled, ttsEngine: ttsEngine, ttsBaseUrl: ttsBaseUrl, ttsModel: ttsModel, ttsVoice: ttsVoice, ttsAutoSpeak: ttsAutoSpeak));
    if (greeting.trim().isNotEmpty) c.msgs.add(Msg(id: _id(), out: false, text: greeting.trim(), time: DateTime.now().millisecondsSinceEpoch));
    _listen(c);
    chats.add(c);
    _dirtyIds.add(c.id);
    notifyListeners();
    _scheduleSave();
    return c;
  }

  void editPersona(Chat c, String name, String prompt, {String? bio, String? greeting, String? emoji, String? examples, String? avatarPath, int? color, String? modelProvider, String? modelId, bool? modelFallback, bool? thinking, bool? agent, bool? clingy, int? clingySilentMin, bool? clingyCap, int? clingyMax, List<String>? skillIds, bool clearSkillIds = false}) {
    c.persona
      ..name = name
      ..prompt = prompt;
    if (bio != null) c.persona.bio = bio;
    if (greeting != null) c.persona.greeting = greeting;
    if (examples != null) c.persona.examples = examples;
    if (emoji != null) c.persona.emoji = emoji;
    if (avatarPath != null) c.persona.avatarPath = avatarPath;
    if (color != null) c.persona.color = color;
    if (modelProvider != null) c.persona.modelProvider = modelProvider;
    if (modelId != null) c.persona.modelId = modelId;
    if (modelFallback != null) c.persona.modelFallback = modelFallback;
    if (thinking != null) c.persona.thinking = thinking;
    if (agent != null) c.persona.agent = agent;
    if (clingy != null) c.persona.clingy = clingy;
    if (clingySilentMin != null) c.persona.clingySilentMin = clingySilentMin;
    if (clingyCap != null) c.persona.clingyCap = clingyCap;
    if (clingyMax != null) c.persona.clingyMax = clingyMax;
    if (clearSkillIds) {
      c.persona.skillIds = null;
    } else if (skillIds != null) {
      c.persona.skillIds = skillIds;
    }
    c.touch();
  }

  /// Replaces the skill selection of one role. Null follows the global set.
  void setPersonaSkills(Chat c, List<String>? ids) {
    c.persona.skillIds = ids == null ? null : List<String>.from(ids);
    c.touch();
  }

  /// Replaces the drawing and speaking settings of one role.
  ///
  /// One call rather than ten setters because the card saves the whole
  /// section at once, and a half applied group would leave the persona
  /// claiming a channel it has no endpoint for.
  void setPersonaGen(
    Chat c, {
    required bool imageEnabled,
    required String imageProvider,
    required String imageModel,
    required String imageSize,
    required bool ttsEnabled,
    required TtsEngine? ttsEngine,
    required String ttsBaseUrl,
    required String ttsModel,
    required String ttsVoice,
    required bool ttsAutoSpeak,
  }) {
    c.persona
      ..imageEnabled = imageEnabled
      ..imageProvider = imageProvider
      ..imageModel = imageModel
      ..imageSize = imageSize
      ..ttsEnabled = ttsEnabled
      ..ttsEngine = ttsEngine
      ..ttsBaseUrl = ttsBaseUrl
      ..ttsModel = ttsModel
      ..ttsVoice = ttsVoice
      ..ttsAutoSpeak = ttsAutoSpeak;
    c.touch();
  }

  void deleteChat(Chat c) {
    stop(c);
    _unlisten(c);
    chats.remove(c);
    // the id itself is the work order: at flush time the chat is gone from
    // [chats], which is what turns the write into a row deletion
    _dirtyIds.add(c.id);
    notifyListeners();
    _scheduleSave();
  }

  void clearHistory(Chat c) {
    stop(c);
    c.msgs.clear();
    c.unread = 0;
    c.markedUnread = false;
    // Every captured index is now stale and the rows are gone, so the chat has
    // to take the full-rewrite path: there is no narrower statement of "all of
    // it changed".
    _dirtyIdsFallback.add(c.id);
    c.touch();
  }

  void deleteMsg(Chat c, Msg m) {
    c.msgs.remove(m);
    // Removing from the middle shifts every index after it, so the hooks are
    // re-pointed before the next flush reads them.
    //
    // The chat is also marked for a full rewrite *before* the touch, and that
    // order is load bearing: _reindex sets _hooked to the new length, so the
    // length check in _onChat would see no change and skip the fallback, and a
    // delete expressed only as a per-message dirty index cannot remove a row.
    // The row would survive the flush and the message would come back on the
    // next launch.
    _dirtyIdsFallback.add(c.id);
    _reindex(c);
    c.touch();
  }

  /// The native engine could not render a canvas card. Recording it on the
  /// message is what turns the failure into feedback: the transcript tells the
  /// model, which can resend a corrected card on its next turn.
  void canvasRenderFailed(Chat c, Msg m, String error) {
    final trimmed = error.length > 160 ? error.substring(0, 160) : error;
    if ('${m.data['renderError'] ?? ''}' == trimmed) return;
    m.data['renderError'] = trimmed;
    c.touch();
    if (kDebugMode) debugPrint('ParaStore: canvasRenderFailed [${m.kind.name}] $trimmed');
  }

  void togglePin(Chat c) {
    c.pinned = !c.pinned;
    c.touch();
  }

  void toggleMute(Chat c) {
    c.muted = !c.muted;
    c.touch();
  }

  void markRead(Chat c) {
    c.unread = 0;
    c.markedUnread = false;
    c.touch();
  }

  void markUnread(Chat c) {
    c.markedUnread = true;
    c.touch();
  }

  void clearAll() {
    for (final c in [...chats]) {
      stop(c);
      c.msgs.clear();
      c.unread = 0;
      c.markedUnread = false;
      _dirtyIdsFallback.add(c.id);
      c.touch();
    }
  }

  // one outgoing message the reply is started by the caller
  Msg addOut(Chat c, {String text = '', MsgKind kind = MsgKind.text, Map<String, dynamic>? data, String? reply}) {
    final m = Msg(id: _id(), out: true, text: text.trim(), time: DateTime.now().millisecondsSinceEpoch, reply: reply, state: St.sending, kind: kind, data: data);
    c.msgs.add(m);
    _watch(m, c, c.msgs.length - 1);
    c.draft = '';
    c.touch();
    return m;
  }

  void send(Chat c, String text, {String? reply, MsgKind kind = MsgKind.text, Map<String, dynamic>? data}) {
    final t = text.trim();
    if (t.isEmpty && kind == MsgKind.text) return;
    if (humanOn) {
      humanInterrupt(c);
      humanOnUser(c, t);
    }
    addOut(c, text: t, kind: kind, data: data, reply: reply);
    _reply(c);
  }

  // a shop purchase: the effect lands on the persona state first so it is
  // genuinely in effect, then a gift card goes out as the user's message and
  // the model is told through the gift describe what happened and to react
  void sendGift(Chat c, {required String itemId, required String title, required String effect}) {
    switch (itemId) {
      case 'affection':
        c.human.adjust(affection: 10, reason: 'shop');
      case 'energy':
        c.human.adjust(energy: 30, reason: 'shop');
      case 'mood':
        c.human.adjust(mood: 20, reason: 'shop');
      case 'apology':
        // annoyance is one global dial, the card cools it to the minimum
        if (human != null) human!.settings.annoyScore = 1;
    }
    c.touch();
    human?.changed();
    if (humanOn) humanInterrupt(c);
    addOut(c, kind: MsgKind.gift, data: {'item': itemId, 'title': title, 'effect': effect});
    _reply(c);
  }

  // several attachments go out together and get a single answer
  void sendBatch(Chat c, List<({MsgKind kind, Map<String, dynamic> data, String text})> items, {String? reply}) {
    if (items.isEmpty) return;
    if (humanOn) {
      humanInterrupt(c);
      humanOnUser(c, items.map((e) => e.text).join(' '));
    }
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      addOut(c, text: it.text, kind: it.kind, data: it.data, reply: i == 0 ? reply : null);
    }
    _reply(c);
  }

  void retry(Chat c, Msg m) {
    if (m.state != St.failed) return;
    m.state = St.sending;
    c.touch();
    _reply(c);
  }

  void votePoll(Chat c, Msg m, int idx) {
    final d = m.data;
    if (d['closed'] == true) return;
    final votes = List<int>.from((d['votes'] as List?) ?? const []);
    var mine = List<int>.from((d['mine'] as List?) ?? const []);
    if (idx < 0 || idx >= votes.length) return;
    final multi = d['multi'] == true;
    final quiz = d['quiz'] == true;
    if (quiz && mine.isNotEmpty) return;
    if (multi) {
      if (mine.contains(idx)) {
        mine.remove(idx);
        votes[idx]--;
      } else {
        mine.add(idx);
        votes[idx]++;
      }
    } else {
      for (final i in mine) {
        votes[i]--;
      }
      if (mine.contains(idx)) {
        mine = [];
      } else {
        mine = [idx];
        votes[idx]++;
      }
    }
    d['votes'] = votes;
    d['mine'] = mine;
    c.touch();
    // an ask poll blocks its tool call until the answer lands. Single choice
    // closes on the first tap so one tap is one answer; multi choice only
    // stages the selection and waits for submitAskPoll, so several options
    // can be picked first. Non-ask polls keep the old toggle behaviour and
    // never touch the pending table.
    if (d['ask'] == true) {
      final multiAsk = d['multi'] == true;
      if (!multiAsk && mine.isNotEmpty) {
        d['closed'] = true;
        c.touch();
        _completeAsk(m);
      }
      return;
    }
  }

  /// Stages a custom text answer on an ask poll without closing it. The text
  /// rides in `data['custom']` so it persists with the chat like votes do.
  void setAskCustom(Chat c, Msg m, String text) {
    final d = m.data;
    if (d['ask'] != true || d['closed'] == true) return;
    final t = text.trim();
    if (t.length > 500) {
      d['custom'] = t.substring(0, 500);
    } else {
      d['custom'] = t;
    }
    c.touch();
  }

  /// Submits an ask poll: closes the card and returns the answer to the
  /// blocked tool call. Needs at least one selected option or a custom text,
  /// unless the poll allows skipping (then use skipAskPoll instead).
  /// Returns false when there is nothing to submit yet.
  bool submitAskPoll(Chat c, Msg m) {
    final d = m.data;
    if (d['ask'] != true || d['closed'] == true) return false;
    final mine = List<int>.from((d['mine'] as List?) ?? const []);
    final custom = '${d['custom'] ?? ''}'.trim();
    if (mine.isEmpty && custom.isEmpty) return false;
    d['closed'] = true;
    c.touch();
    _completeAsk(m);
    return true;
  }

  /// Skips an ask poll: closes the card and tells the blocked tool call the
  /// user passed. Always succeeds on an open ask card.
  void skipAskPoll(Chat c, Msg m) {
    final d = m.data;
    if (d['ask'] != true || d['closed'] == true) return;
    d['skipped'] = true;
    d['closed'] = true;
    c.touch();
    _completeAsk(m);
  }

  /// Formats one ask answer for the model. Plain words rather than JSON: the
  /// chat models already read tool results as text, and a short sentence
  /// survives compaction better than a payload.
  String _askAnswerText(Msg m) {
    final d = m.data;
    if ('${d['skipped'] ?? ''}' == 'true' || d['skipped'] == true) {
      return 'The user skipped the question.';
    }
    final opts = List<String>.from((d['opts'] as List?) ?? const []);
    final mine = List<int>.from((d['mine'] as List?) ?? const []);
    final picked = [for (final i in mine) if (i >= 0 && i < opts.length) opts[i]];
    final custom = '${d['custom'] ?? ''}'.trim();
    if (picked.isEmpty && custom.isEmpty) return 'The user gave no answer.';
    final parts = <String>[];
    if (picked.isNotEmpty) parts.add('chose: ${picked.join(', ')}');
    if (custom.isNotEmpty) parts.add('wrote: $custom');
    return 'The user answered "${d['q'] ?? ''}" — ${parts.join('; ')}.';
  }

  /// Completes the pending ask wait for [m], if any. No-op for ordinary
  /// polls and for an ask that nobody is waiting on (a restart, a restored
  /// chat, or a vote that arrived after the wait already ended).
  void _completeAsk(Msg m) {
    final waiter = _askPending.remove(m.id);
    if (waiter == null || waiter.isCompleted) return;
    waiter.complete(_askAnswerText(m));
  }

  /// Cancels every pending ask of one chat. Called on interrupt / stop /
  /// regenerate / clear so a blocked tool call never hangs a dead run.
  void cancelAskForChat(String chatId) {
    final ids = <String>[];
    for (final e in _askPending.entries) {
      // the message id is the key; find its chat by scanning once. Pending
      // tables are tiny (at most a few per chat), so no index is kept.
      ids.add(e.key);
    }
    if (ids.isEmpty) return;
    // only complete waits whose message belongs to this chat
    final c = chats.where((e) => e.id == chatId).firstOrNull;
    if (c == null) return;
    final mine = {for (final m in c.msgs) m.id};
    for (final id in ids) {
      if (!mine.contains(id)) continue;
      final waiter = _askPending.remove(id);
      if (waiter == null || waiter.isCompleted) continue;
      final m = c.byId(id);
      if (m != null) {
        m.data['closed'] = true;
      }
      waiter.complete('The user did not answer (cancelled).');
    }
    c.touch();
  }

  void regenerate(Chat c) {
    cancelAskForChat(c.id);
    if (humanOn) {
      // one answer is often several bubbles, all of them go
      humanInterrupt(c);
      while (c.msgs.isNotEmpty && !c.msgs.last.out && !c.msgs.last.service && !c.msgs.last.pinned) {
        c.msgs.removeLast();
      }
    }
    if (!humanOn && c.msgs.isNotEmpty && !c.msgs.last.out && !c.msgs.last.service) c.msgs.removeLast();
    while (c.msgs.isNotEmpty && c.msgs.last.service) {
      c.msgs.removeLast();
    }
    // The tail was truncated, so the surviving hooks still name the right rows
    // (only trailing indexes went away) but the deleted rows have to be dropped
    // from storage, which the full rewrite is the safe way to state.
    _dirtyIdsFallback.add(c.id);
    c.touch();
    _reply(c);
  }

  bool busy(Chat c) => _runs.containsKey(c.id);

  void stop(Chat c) {
    cancelAskForChat(c.id);
    if (humanOn) {
      humanInterrupt(c);
      return;
    }
    _runs[c.id]?.token.cancel();
  }

  void _service(Chat c, String text) {
    c.msgs.add(Msg(id: _id(), out: false, text: text, time: DateTime.now().millisecondsSinceEpoch, service: true));
    c.touch();
  }

  // ------------------------------------------------------------ trace rows

  /// One step of the model's work, stored as a service message so it never
  /// reaches the model, never turns up in search and never shows up in a
  /// dialog preview, while still being part of the chat json the user can
  /// scroll back and open. The row is written when the step starts so the
  /// reading order is the real one: think, answer, call, answer again.
  Msg _trace(Chat c, Map<String, dynamic> data) {
    final m = Msg(id: _id(), out: false, text: '', time: DateTime.now().millisecondsSinceEpoch, service: true, kind: MsgKind.trace, data: data);
    c.msgs.add(m);
    return m;
  }

  /// The reasoning row currently being written into, if the last row of this
  /// run is still one. Reasoning that resumes after visible text opens a new
  /// row, the same way the chain already splits its reasoning blocks.
  Msg? _openThink;

  /// Reasoning of one pass. While the model is still writing, the row is open
  /// and the next delta lands in the same one, so a two minute think does not
  /// turn into two hundred rows.
  void traceThinking(Chat c, String delta) {
    if (delta.isEmpty) return;
    final open = _openThink;
    if (open == null || c.msgs.isEmpty || !identical(c.msgs.last, open)) {
      _openThink = _trace(c, {'type': 'think', 'body': '', 't0': _nowMs, 'state': 'run'});
    }
    final row = _openThink!;
    row.data['body'] = '${row.data['body'] ?? ''}$delta';
    // the thinking text arrives in small pieces, repainting on every one of
    // them would cost more than it shows
    final last = row.data['painted'] as int? ?? 0;
    if (_nowMs - last < 120) return;
    row.data['painted'] = _nowMs;
    c.touch();
  }

  /// Closes the open reasoning row and stamps how long it took. Called between
  /// passes and once at the end, so a run that dies mid think still leaves a
  /// finished row behind instead of a spinner that never stops.
  void endThinking(Chat c) {
    final row = _openThink;
    _openThink = null;
    if (row == null) return;
    row.data['state'] = 'ok';
    row.data['ms'] = _nowMs - (row.data['t0'] as int? ?? _nowMs);
    c.touch();
  }

  /// Opens a tool row. [mcp] is the server name when the call came from MCP,
  /// empty for the local tools, which is what separates the two in the ui.
  Msg traceTool(Chat c, ToolCallPart call, {String mcp = ''}) {
    endThinking(c);
    return _trace(c, {
      'type': 'tool',
      'tool': call.name,
      'mcp': mcp,
      'args': call.args,
      'result': '',
      // the chat a workspace tool needs in order to turn a model path back into
      // a file. Trace rows live inside the chat json, so this is redundant while
      // the chat is loaded and load bearing once one is rendered from history.
      'chatId': c.id,
      't0': _nowMs,
      'state': 'run',
    });
  }

  /// Writes the outcome of a tool row. The result is trimmed because a tool
  /// can hand back a megabyte of json and the row only ever shows a preview.
  void endTool(Chat c, Msg row, {required String result, required bool isError}) {
    row.data['state'] = isError ? 'err' : 'ok';
    row.data['result'] = result.length > 4000 ? '${result.substring(0, 4000)}…' : result;
    row.data['ms'] = _nowMs - (row.data['t0'] as int? ?? _nowMs);
    c.touch();
  }

  // move every pending outgoing message forward one state
  void _advance(Chat c, int from, int to) {
    var any = false;
    for (final m in c.msgs) {
      if (m.out && m.state == from) {
        m.state = to;
        any = true;
      }
    }
    if (any) c.touch();
  }

  String _describe(Msg m, [_InlineBudget? budget]) {
    final cap = m.text.isEmpty ? '' : '\n${m.text}';
    switch (m.kind) {
      case MsgKind.text:
        return m.text;
      case MsgKind.photo:
        return '[Photo attached]$cap';
      case MsgKind.video:
        return '[Video: ${m.data['name'] ?? 'video'} (${fileSize((m.data['size'] as num?) ?? 0)})]$cap';
      case MsgKind.file:
        final name = '${m.data['name'] ?? 'file'}';
        final size = (m.data['size'] as num?) ?? 0;
        var body = '';
        final path = m.data['path'] as String?;
        // anything that decodes as mostly-printable text goes in, not just a
        // fixed extension whitelist: unknown log formats and subtitles reach
        // the model, while archives and documents are skipped by the sampler
        if (path != null && size <= sampleMaxBytes && (budget == null || budget.left > 0)) {
          final room = budget == null ? _inlineFileMaxChars : (budget.left < _inlineFileMaxChars ? budget.left : _inlineFileMaxChars);
          final s = sampleTextFile(path, room);
          if (s != null) {
            budget?.left -= s.usedChars;
            body = '\n```\n${s.text}\n```';
          }
        }
        return '[File: $name (${fileSize(size)})]$body$cap';
      case MsgKind.music:
        return '[Audio file: ${m.data['name'] ?? 'audio'} (${fileSize((m.data['size'] as num?) ?? 0)})]$cap';
      case MsgKind.location:
        return '[Location: ${m.data['lat']}, ${m.data['lng']}]$cap';
      case MsgKind.contact:
        return '[Contact: ${m.data['name']}, ${m.data['phone']}]$cap';
      case MsgKind.poll:
        final opts = ((m.data['opts'] as List?) ?? const []).join(' / ');
        final mine = List<int>.from((m.data['mine'] as List?) ?? const []);
        final all = List<String>.from((m.data['opts'] as List?) ?? const []);
        final picked = [for (final i in mine) if (i >= 0 && i < all.length) all[i]].join(', ');
        final custom = '${m.data['custom'] ?? ''}'.trim();
        final skipped = m.data['skipped'] == true || '${m.data['skipped'] ?? ''}' == 'true';
        final extra = skipped
            ? ' (skipped by the user)'
            : (picked.isEmpty && custom.isEmpty ? '' : ' (answered: ${[if (picked.isNotEmpty) picked, if (custom.isNotEmpty) 'custom: $custom'].join('; ')})');
        return '[Poll: ${m.data['q']} options: $opts]$extra';
      case MsgKind.sticker:
        final emoji = '${m.data['emoji'] ?? ''}';
        final sid = m.data['sid'] == null ? '' : ' ${m.data['sid']}';
        // an image or gif sticker carries no glyph, so without its library
        // metadata the model only sees an opaque id and cannot learn what it
        // means or pick a fitting one later; the emotion word and tags are
        // the meaning it was saved under
        var meaning = '';
        final s = human?.stickers.byId('${m.data['sid'] ?? ''}');
        if (s != null && s.kind != StickerKind.emoji) {
          final emo = s.emotion.isEmpty ? '?' : s.emotion;
          meaning = ' means $emo${s.tags.isEmpty ? '' : ' (${s.tags.take(4).join('/')})'}';
        }
        return '[Sticker$sid: ${emoji.isEmpty ? 'image sticker' : emoji}$meaning]';
      case MsgKind.transfer:
        return '[${m.data['kind'] == 'redpacket' ? 'Red packet' : 'Transfer'} ${m.data['amount']} (${m.data['status']}): ${m.data['note'] ?? ''}]';
      case MsgKind.gift:
        // the shop purchase is real: the effect already landed on the persona
        // state, so the message tells the model plainly what arrived and asks
        // it to respond in character instead of guessing what happened
        return "[Gift: ${m.data['title'] ?? 'a gift'} — ${m.data['effect'] ?? 'a gift effect'} (already in effect, this is not hypothetical). The user spent their balance on this for you. Respond in character: acknowledge the gift and let it genuinely move you.]";
      case MsgKind.trace:
        // a trace row is a service message and never reaches this, the case
        // exists so the switch stays total
        return '';
      case MsgKind.html:
      case MsgKind.latex:
        // the source already sits in the tool call that sent it, repeating it
        // here would only burn context. A card the engine refused is marked on
        // the message, so the model learns the syntax was wrong and can send a
        // fixed one; the user only sees the small notice.
        final what = m.kind == MsgKind.html
            ? 'HTML'
            : (m.data['cetz'] == true ? 'CeTZ drawing' : 'LaTeX');
        final err = '${m.data['renderError'] ?? ''}';
        if (err.isNotEmpty) return '[$what card render FAILED: $err. The user sees a small notice, not the source. Send a corrected version or move on.]$cap';
        return '[$what card rendered]$cap';
    }
  }

  Future<String?> _dataUrl(String? path) async {
    if (path == null) return null;
    try {
      final f = File(path);
      if (await f.length() > 5 * 1024 * 1024) return null;
      final ext = path.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : (ext == 'gif' ? 'image/gif' : 'image/jpeg'));
      return 'data:$mime;base64,${base64Encode(await f.readAsBytes())}';
    } catch (_) {
      return null;
    }
  }

  /// Gemini takes inline video but caps the whole request near 20 MB, and
  /// base64 inflates by 4/3, so phone clips above 15 MB stay text-only rather
  /// than failing the request
  Future<String?> _videoDataUrl(String? path) async {
    if (path == null) return null;
    const mimes = {
      'mp4': 'video/mp4',
      'webm': 'video/webm',
      'mov': 'video/quicktime',
      'mkv': 'video/x-matroska',
      'avi': 'video/x-msvideo',
      '3gp': 'video/3gpp',
      'm4v': 'video/mp4',
      'mpeg': 'video/mpeg',
      'mpg': 'video/mpeg',
    };
    try {
      final f = File(path);
      if (await f.length() > 15 * 1024 * 1024) return null;
      final ext = path.split('.').last.toLowerCase();
      final mime = mimes[ext];
      if (mime == null) return null;
      return 'data:$mime;base64,${base64Encode(await f.readAsBytes())}';
    } catch (_) {
      return null;
    }
  }

  /// Flat transcript used for token estimation and compaction.
  List<HistoryItem> _historyItems(Chat c) {
    final real = c.msgs.where((m) => !m.service && (m.text.isNotEmpty || m.kind != MsgKind.text || m.recalled)).toList();
    final budget = _InlineBudget(_inlineFilesTotalChars);
    // spend the allowance newest first: a file in the current turn matters
    // more than one fifty messages back, and the oldest ones drop to their
    // placeholder line without it
    final items = <HistoryItem>[
      for (final m in real.reversed) HistoryItem(id: m.id, role: m.out ? 'user' : 'assistant', content: humanOn ? humanDescribe(m) : _describe(m, budget)),
    ];
    return items.reversed.toList();
  }

  String _systemPrompt(Chat c) {
    final cfg = _ai;
    final card = personaFor(c);
    final base = buildSystemPrompt(
      PromptInput(
        personaName: c.persona.name,
        personaPrompt: c.persona.prompt,
        personaBio: c.persona.bio,
        personaExamples: c.persona.examples,
        userName: card.name,
        userBio: userBio,
        userDescription: expandMacros(card.description, c.persona.name, card.name),
        userPosition: card.position,
        replyMode: cfg?.settings.replyMode ?? ReplyMode.full,
      ),
    );
    final skillsBlock = skillFragmentFor(c);
    // the generative channels are announced the same way skills are: only when
    // the role actually has one, so a persona that never asked for them is not
    // told about a tool it cannot call
    final voice = _speech;
    final genBlock = cfg == null || voice == null ? '' : genCapabilityBlock(genPrefsFor(c, cfg.settings, voice));
    final extra = [if (skillsBlock.isNotEmpty) skillsBlock, if (genBlock.isNotEmpty) genBlock];
    if (extra.isEmpty) return base;
    return '$base\n\n${extra.join('\n\n')}';
  }

  /// Skills this chat's role sees, after the global enable switches and the
  /// role's own selection. Empty when the store has none enabled for it.
  List<Skill> skillsFor(Chat c) {
    try {
      return skills.resolveFor(c.persona.skillIds);
    } catch (_) {
      return const [];
    }
  }

  /// Whether the next reply will offer the skill reader tool. The listing
  /// is only injected when the tool is there to fetch with: a list the
  /// model cannot open is noise, not help.
  bool _skillsOffered(Chat c) {
    if (skillsFor(c).isEmpty) return false;
    if (humanOn) return true;
    return agentFor(c);
  }

  /// The `<available_skills>` block for one chat, or empty when there is
  /// nothing to offer. Synchronous on purpose: the records live in memory
  /// after load, so every reply path (plain, agent, humanized) shares it
  /// through [_systemPrompt] without turning async.
  String skillFragmentFor(Chat c) {
    if (!_skillsOffered(c)) return '';
    final list = skillsFor(c);
    if (list.isEmpty) return '';
    try {
      return buildAvailableSkillsFragment(list);
    } catch (_) {
      return '';
    }
  }

  /// The dedicated skill reader. Unlike the workspace file tools it needs
  /// no binding: skills live under the app directory and are readable in
  /// every chat that lists them. A successful read counts as a use so the
  /// listing can put frequently used skills first.
  HTool? skillToolFor(Chat c) {
    if (skillsFor(c).isEmpty) return null;
    return HTool(
      'read_skill',
      'Read an installed skill by its id and follow the returned instructions. Call it before doing a task that matches a skill description.',
      {
        'skill': _p('string', 'Skill id as listed in <available_skills>, for example "pdf-tools".'),
      },
      (a) async {
        final raw = a['skill'] ?? a['id'] ?? a['name'] ?? '';
        final id = '$raw'.trim();
        if (id.isEmpty) {
          final ids = skillsFor(c).map((s) => s.id).join(', ');
          return 'Error: skill is required. Available: $ids.';
        }
        final body = await skills.readSkill(id);
        if (body == null) {
          final ids = skillsFor(c).map((s) => s.id).join(', ');
          return 'Error: no enabled skill named "$id". Available: $ids.';
        }
        return body;
      },
      required: const ['skill'],
    );
  }

  /// SillyTavern in-chat depth injection, the equivalent of setExtensionPrompt
  /// with IN_CHAT. The turn lands `depth` messages back from the newest one and
  /// carries no sourceId, so the attachment rebuild below passes it through.
  void _injectDepth(Chat c, List<ChatTurn> turns) {
    final card = personaFor(c);
    if (card.position != PersonaPosition.atDepth) return;
    injectPersonaDepth(
      turns,
      expandMacros(card.description, c.persona.name, card.name),
      depth: card.depth,
      role: card.role,
    );
  }

  /// Rebuilds the request turns, loading base64 for recent photos.
  Future<List<ChatTurn>> _history(Chat c) async {
    final items = _historyItems(c);
    final cfg = _ai;
    var turns = assembleTurns(items, cfg?.compactionOf(c.id));

    // rebuild the tail with real attachments, the summary head stays text only
    final rebuilt = <ChatTurn>[];
    // sticker images ride the same path as photos but only into a chain that
    // can see: handing an image part to a text model fails the whole request,
    // and the same gate covers photos and videos or a fallback that answers
    // blind brings the whole run down with a 400
    final caps = cfg == null ? const ModelCaps() : chainCaps(cfg.settings, chainFor(c));
    final vision = caps.vision;
    final videoOk = caps.video;
    for (final turn in turns) {
      final source = turn.sourceId == null ? null : items.where((h) => h.id == turn.sourceId).firstOrNull;
      if (source == null) {
        rebuilt.add(turn);
        continue;
      }
      final msg = c.msgs.where((m) => m.id == source.id).firstOrNull;
      if (msg == null || !msg.out) {
        rebuilt.add(turn);
        continue;
      }
      if (msg.kind == MsgKind.sticker) {
        // emoji stickers are already glyphs in the text; image and gif ones
        // only add bytes when a local file exists and the model has vision
        final isGlyph = '${msg.data['emoji'] ?? ''}'.isNotEmpty;
        if (isGlyph || !vision) {
          rebuilt.add(turn);
          continue;
        }
        final loaded = await _dataUrl(msg.data['path'] as String?);
        if (loaded == null) {
          rebuilt.add(turn);
          continue;
        }
        final comma = loaded.indexOf(',');
        final mime = comma > 0 ? loaded.substring(5, comma) : 'image/jpeg';
        rebuilt.add(ChatTurn(turn.role, [TextPart(source.content), ImagePart(loaded.substring(comma + 1), mime)], sourceId: turn.sourceId));
        continue;
      }
      if (msg.kind != MsgKind.photo && msg.kind != MsgKind.video) {
        rebuilt.add(turn);
        continue;
      }
      if (msg.kind == MsgKind.video) {
        if (!videoOk) {
          // the chain cannot watch: keep the text placeholder, drop the bytes
          rebuilt.add(turn);
          continue;
        }
        final loaded = await _videoDataUrl(msg.data['path'] as String?);
        if (loaded == null) {
          rebuilt.add(turn);
          continue;
        }
        final comma = loaded.indexOf(',');
        final mime = comma > 0 ? loaded.substring(5, comma) : 'video/mp4';
        rebuilt.add(ChatTurn(turn.role, [TextPart(source.content), VideoPart(loaded.substring(comma + 1), mime)], sourceId: turn.sourceId));
        continue;
      }
      if (!vision) {
        // same blind-chain guard for photos: the placeholder line already
        // tells the model a picture was here, the bytes would only 400
        rebuilt.add(turn);
        continue;
      }
      final loaded = await _dataUrl(msg.data['path'] as String?);
      if (loaded == null) {
        rebuilt.add(turn);
        continue;
      }
      final comma = loaded.indexOf(',');
      final mime = comma > 0 ? loaded.substring(5, comma) : 'image/jpeg';
      rebuilt.add(ChatTurn(turn.role, [TextPart(source.content), ImagePart(loaded.substring(comma + 1), mime)], sourceId: turn.sourceId));
    }
    turns = rebuilt;

    // the card goes in after the rebuild so an attachment never eats the slot
    _injectDepth(c, turns);

    // a last resort when compaction is off or has not run yet
    final active = cfg?.settings;
    if (active != null) {
      // the persona override may be the node in front, and it is the one whose
      // context window the transcript has to fit
      final node = chainFor(c).firstOrNull;
      if (node != null) turns = truncateHistory(turns, contextWindowOf(active, node));
    }
    return turns;
  }

  Future<void> _reply(Chat c) async {
    if (humanOn) {
      if (_runs.containsKey(c.id)) return;
      await humanReply(c);
      return;
    }
    if (_runs.containsKey(c.id)) return;
    final cfg = _ai;
    // a persona override can carry a chat on its own, the global chain does not
    // have to hold anything
    final nodes = chainFor(c);
    if (cfg == null || nodes.isEmpty) {
      _advance(c, St.sending, St.failed);
      _service(c, 'No model is on the chain yet. Open Settings > AI and add one.');
      return;
    }
    // a key on any provider is not enough, every node that will run needs its own
    if (!nodes.every((n) => cfg.keyOf(n.providerId).trim().isNotEmpty)) {
      _advance(c, St.sending, St.failed);
      _service(c, 'No API key. Open Settings > AI and add one to chat.');
      return;
    }

    final run = _Run();
    _runs[c.id] = run;
    c.touch();
    // the message reached the server the moment the run exists, the clock is
    // for undelivered mail not for a pending reply, so it goes straight to
    // the sent check and only turns into the double check when the answer
    // actually lands
    _advance(c, St.sending, St.sent);

    final charMode = cfg.settings.replyMode == ReplyMode.character;
    final segmenter = charMode ? Segmenter(strip: cfg.settings.stripMarkdownInCharacterMode) : null;

    // the two switches of this chat, persona override already folded in. The
    // humanize branch above already left, so agent mode here is the plain
    // assistant getting a tool table of its own.
    final showThink = thinkingFor(c);
    final agent = agentFor(c);
    final table = agent ? <String, HTool>{for (final t in await agentTools(c, _runs[c.id])) t.name: t} : <String, HTool>{};
    final specs = [for (final t in table.values) t.spec];

    // Deltas accumulate here and the string is only built when a frame asks for
    // it. \`live.text += delta\` reallocated the whole reply per chunk, which is
    // quadratic over an answer and was the largest single allocation source on
    // the streaming path.
    final buf = StreamTextBuffer();
    var accepted = false;
    var reported = false;
    Msg? live;
    // Painted at most this often, matching kelivo's 50 ms stream publish
    // interval. A provider that bursts a screenful in one read now lands as a
    // steady crawl rather than one jump.
    var lastPaint = 0;
    const paintIntervalMs = 50;

    /// Pushes the accumulated buffer into the live bubble and repaints just it.
    ///
    /// The buffer holds the whole reply, not a tail, so this writes the full
    /// text each time. That is one string build per *paint* rather than per
    /// chunk: the throttle below is what keeps it from being quadratic in the
    /// number of deltas.
    void paint({bool force = false}) {
      final current = live;
      if (current == null) return;
      final text = buf.value;
      if (text == current.text) return;
      if (!force) {
        // Leading-edge throttle: the first delta after each window paints, so a
        // delta rate above 20/s cannot starve the display — the next one past
        // the boundary always gets through. This is kelivo's
        // \`_streamThrottleInterval\`, 50 ms, the same 20 Hz ceiling.
        final now = _nowMs;
        if (now - lastPaint < paintIntervalMs) return;
        lastPaint = now;
      }
      // The assignment runs [Msg.onChange], which is what marks the row dirty
      // and bumps this bubble's revision. Nothing here calls \`c.touch()\`: that
      // would rebuild the whole page — every message in the history — once per
      // chunk, which is exactly what the per-message revision replaces.
      current.text = text;
    }

    // each call appends finished text to the live bubble, opening it if needed.
    // Only the plain path streams into one bubble; character mode hands every
    // finished segment to placeSeg below instead.
    void emit(List<String> texts) {
      var opened = false;
      for (final text in texts) {
        if (text.isEmpty) continue;
        final current = live;
        if (current == null) {
          final fresh = Msg(id: _id(), out: false, text: text, time: DateTime.now().millisecondsSinceEpoch, streaming: true);
          live = fresh;
          buf.value = text;
          c.typing = false;
          if (haptics) HapticFeedback.lightImpact();
          _advance(c, St.sent, St.read);
          c.msgs.add(fresh);
          _watch(fresh, c, c.msgs.length - 1);
          if (openId != c.id) c.unread++;
          opened = true;
        } else {
          buf.add(text);
        }
      }
      // Opening the bubble appends a row, which is a structural change the page
      // and the list both have to see. A chunk that merely grew the bubble that
      // already exists is not: that repaints the one bubble through its own
      // revision and leaves the page alone.
      if (opened) {
        c.touch();
      } else {
        paint();
      }
    }

    // Character mode owes the reader one bubble per segment with a human pause
    // in between, and the segmenter only decides *where* to cut, never when to
    // show. The chunk callback is synchronous so segments queue up here and a
    // timer drains them in order. Without this the segments were concatenated
    // into the single live bubble and splitting did nothing the reader could
    // see, which is what "character mode does not split" looked like.
    final segQueue = <String>[];
    Timer? segTimer;
    String? segHolding;
    final segRandom = Random();
    final jitter = cfg.settings.pacingJitter;
    // the first bubble waits a read delay the same way the humanize layer does
    // otherwise the opening line lands while the user is still watching their
    // own message go out
    var segNextAt = _nowMs + jitterMs(cfg.settings.firstBubbleDelayMs, segRandom, jitter);
    var segAny = false;

    void placeSeg(String text) {
      if (run.cancelled) return;
      final fresh = Msg(id: _id(), out: false, text: text, time: DateTime.now().millisecondsSinceEpoch);
      if (haptics) HapticFeedback.lightImpact();
      c.msgs.add(fresh);
      _watch(fresh, c, c.msgs.length - 1);
      if (openId != c.id) c.unread++;
      c.typing = false;
      segNextAt = _nowMs + humanDelay(text, random: segRandom, scale: cfg.settings.bubbleGapScale, spread: jitter);
      c.touch();
    }

    // the bubble is typed out at keyboard pace, this is also where the double
    // check lands: a reply being composed is proof the message was read
    // three phases per bubble, hesitation dark, typing with the indicator up,
    // then the bubble lands, one loop drives all of them
    var segTypingUntil = 0;
    void pumpSeg([Completer<void>? done]) {
      segTimer?.cancel();
      segTimer = null;
      if (run.cancelled) {
        if (done != null && !done.isCompleted) done.complete();
        return;
      }
      // mid typing phase, the bubble lands when the keyboard work is done
      if (segTypingUntil > _nowMs) {
        segTimer = Timer(Duration(milliseconds: segTypingUntil - _nowMs), () {
          segTypingUntil = 0;
          final text = segHolding!;
          segHolding = null;
          placeSeg(text);
          pumpSeg(done);
        });
        return;
      }
      if (segHolding == null) {
        if (segQueue.isEmpty) {
          if (done != null && !done.isCompleted) done.complete();
          return;
        }
        final next = segQueue.removeAt(0);
        if (next.trim().isEmpty) {
          pumpSeg(done);
          return;
        }
        segHolding = next;
      }
      // hesitation first, a persona thinking between bubbles shows nothing
      final wait = segNextAt - _nowMs;
      if (wait > 0) {
        segTimer = Timer(Duration(milliseconds: wait), () => pumpSeg(done));
        return;
      }
      final text = segHolding!;
      // composing is proof the message was read, the flip happens once the
      // first bubble reaches the keyboard
      _advance(c, St.sent, St.read);
      c.typing = true;
      c.touch();
      segTypingUntil = _nowMs + typingMs(text, random: segRandom, spread: jitter);
      pumpSeg(done);
    }

    void queueSegs(List<String> texts) {
      if (texts.isEmpty) return;
      segAny = true;
      segQueue.addAll(texts);
      pumpSeg();
    }

    void onText(String delta) {
      if (run.cancelled) return;
      if (!accepted) {
        accepted = true;
        c.touch();
      }
      if (segmenter != null) {
        // character mode cuts on newlines, on sentence ends, and on the
        // segmenter's own length fallback when the model wrote no separator
        queueSegs(segmenter.push(delta));
        return;
      }
      buf.add(delta);
      if (live == null) {
        // Nothing on screen yet: open the bubble with everything buffered so
        // the first paint is the whole opening line, not one character.
        emit([buf.value]);
      } else {
        paint();
      }
    }

    try {
      var turns = await _history(c);
      final system = agent ? await agentSystem(c) : _systemPrompt(c);
      // a plain reply is one pass, an agent reply keeps going while the model
      // asks for tools. The cap is the agentMaxPass setting: a confused model
      // cannot spin forever unless the user opened the cap to none.
      final maxPass = agent ? agentMaxPass : 1;
      for (var pass = 0; maxPass <= 0 || pass < maxPass; pass++) {
        final outcome = await runChain(
          settings: cfg.settings,
          apiKeys: cfg.apiKeys,
          system: system,
          messages: turns,
          nodes: nodes,
          tools: specs,
          options: ChainOptions(
            cancel: run.token,
            sessionId: c.id,
            onChunk: (chunk) {
              if (chunk.isText) {
                onText(chunk.delta);
              } else if (chunk.isReasoning) {
                // the scratchpad is hidden unless the user asked for it, and
                // when it is on it lands in a row of its own above the answer
                if (showThink) traceThinking(c, chunk.delta);
              }
            },
            onCompact: () async {
              // summaries go through whatever this chat would answer with, so an
              // override is summarised by the same model that carries the chat
              final node = nodes.firstOrNull;
              if (node == null) return;
              final result = await compactHistory(
                settings: cfg.settings,
                apiKeys: cfg.apiKeys,
                system: _systemPrompt(c),
                history: _historyItems(c),
                previous: cfg.compactionOf(c.id),
                node: node,
              );
              cfg.setCompaction(c.id, result);
              turns = await _history(c);
            },
            onEvent: (e) {
              // a node gave up, note which one answered instead
              if (e.kind == ChainEventKind.node && e.node != null) lastServedBy = e.node!.modelId;
            },
          ),
        );

        if (run.cancelled) return;
        endThinking(c);
        // drain whatever the segmenter still holds, plus the plain mode tail.
        // Character mode has to wait for the queued bubbles to actually land,
        // otherwise the pass would be scored on an empty transcript.
        if (segmenter != null) {
          queueSegs(segmenter.flush());
          final drained = Completer<void>();
          pumpSeg(drained);
          await drained.future;
        } else if (buf.isNotEmpty) {
          // Forced: the reply is over, so the last chunk must land regardless
          // of where the paint window happened to be.
          if (live == null) {
            emit([buf.value]);
          } else {
            paint(force: true);
          }
        }

        // a pass that produced nothing at all is an empty answer, a pass that
        // only asked for tools is a normal step of an agent reply
        if (outcome.error != null && outcome.text.isEmpty && outcome.toolCalls.isEmpty) {
          _advance(c, St.sending, St.failed);
          // the reason is already in the active language, the provider's own
          // wording rides along untranslated because it is not ours to rewrite
          reported = true;
          _service(c, '${describeErrorL10n(outcome.error!)} (${outcome.error!.message})');
          break;
        } else if (live == null && !segAny && outcome.toolCalls.isEmpty) {
          // text came back but character mode stripped all of it, same as an
          // answer that was never written
          _advance(c, St.sent, St.read);
          reported = true;
          _service(c, L10n.current.errorEmpty);
          break;
        } else if (outcome.error != null) {
          // partial text already on screen, keep it and explain the tail
          reported = true;
          _service(c, L10n.current.errorStoppedEarly(describeErrorL10n(outcome.error!)));
          break;
        }

        // no tools asked for, this pass was the answer
        if (outcome.toolCalls.isEmpty) break;
        // a model with no tools in front of it should never reach this line
        if (table.isEmpty) break;

        turns.add(ChatTurn('assistant', [if (outcome.text.trim().isNotEmpty) TextPart(outcome.text), ...outcome.toolCalls]));
        final results = <ContentPart>[];
        for (final call in outcome.toolCalls) {
          if (run.cancelled) break;
          results.add(await _execTool(call, table, c));
        }
        if (run.cancelled) break;
        turns.add(ChatTurn('tool', results));
      }

      // the loop can also simply run out: a model that spent every pass on
      // tools and never wrote a word. The user already saw the steps, but
      // steps alone are not an answer.
      if (live == null && !segAny && !reported && !run.cancelled) {
        _advance(c, St.sent, St.read);
        _service(c, L10n.current.errorEmpty);
      }
    } on AiError catch (e) {
      _advance(c, St.sending, St.failed);
      _service(c, describeErrorL10n(e));
    } catch (e) {
      _advance(c, St.sending, St.failed);
      _service(c, '${L10n.current.errorUnknown}: $e');
    } finally {
      // even an abort or a crash must not leave a reasoning row spinning
      endThinking(c);
      // a queued character mode bubble belongs to a run that is over now. It
      // would land after the transcript was saved, out of order and orphaned.
      segTimer?.cancel();
      segTimer = null;
      segQueue.clear();
      segHolding = null;
      for (final m in c.msgs.where((m) => m.streaming)) {
        m.streaming = false;
        // The reply is over, so this bubble will never be repainted by a
        // revision again. Releasing the notifier here keeps the bus from
        // growing one entry per message of every conversation ever streamed,
        // which is the same retention kelivo avoids by handing inactive rows an
        // immutable listenable.
        streams.drop(m.id);
      }
      _advance(c, St.sending, St.sent);
      c.typing = false;
      _runs.remove(c.id);
      c.touch();
      // The terminal flush writes the finished reply, so it is the one place a
      // whole-chat rewrite is cheap and certain.
      _dirtyIdsFallback.add(c.id);
      _save();
    }
  }
}

class StoreScope extends InheritedNotifier<Store> {
  const StoreScope({super.key, required Store store, required super.child}) : super(notifier: store);
}

extension StoreX on BuildContext {
  Store get store => Store.of(this);
}

