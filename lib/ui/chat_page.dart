import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../data/human/human_models.dart';
import '../data/human/sticker_lib.dart';
import 'human_pages.dart' show hAsk;

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/text_utils.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../data/workspace/workspace_metadata.dart';
import '../data/workspace/workspace_paths.dart' show PathResolutionException;
import '../l10n/x.dart';
import 'attach_sheet.dart';
import 'bubble.dart';
import 'calendar_sheet.dart';
import 'emoji_panel.dart';
import 'input_bar.dart';
import 'media_bubbles.dart';
import 'workspace/file_preview_page.dart' show showFilePreview;
import 'persona_card.dart';
import 'profile_page.dart';
import 'trace_view.dart';
import 'user_persona.dart';
import 'wallpaper.dart';
import 'wallpaper_page.dart';
import 'workspace/workspace_pages.dart';
import 'workspace/workspace_prompts.dart' show askTypeDelete;

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.chat, this.focusId, this.query, this.startSearch = false});
  final Chat chat;
  final String? focusId;
  final String? query;
  final bool startSearch;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final GlobalKey _inputKey = GlobalKey();
  late final AnimationController _wall = AnimationController(vsync: this, duration: const Duration(milliseconds: 500), value: 1);
  late final AnimationController _panel = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
  late final Store _store;
  final Set<String> _known = {};
  final Map<String, GlobalKey> _keys = {};
  Msg? _reply;
  bool _down = false;
  int _newUp = 0;
  int _phase = 1;
  double _inputH = 60;
  String? _lastId;
  bool _emoji = false;
  double _panelH = 290;
  DateTime _ignoreKb = DateTime.fromMillisecondsSinceEpoch(0);
  bool _searching = false;
  bool _asList = false;
  final TextEditingController _sq = TextEditingController();
  List<Msg> _hits = [];
  int _hitIdx = 0;
  String? _flashId;
  int _flashSeq = 0;

  Chat get chat => widget.chat;

  @override
  void initState() {
    super.initState();
    _store = Store.read(context);
    _store.openId = chat.id;
    chat.unread = 0;
    chat.markedUnread = false;
    _ctl.text = chat.draft;
    _known.addAll(chat.msgs.map((e) => e.id));
    _lastId = chat.msgs.isEmpty ? null : chat.msgs.last.id;
    chat.addListener(_onChat);
    _scroll.addListener(_onScroll);
    _panel.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measure();
      final q = widget.query;
      if (q != null && q.isNotEmpty) {
        _openSearch(q);
      } else if (widget.startSearch) {
        _openSearch('');
      }
      if (widget.focusId != null) _reveal(widget.focusId!);
    });
  }

  @override
  void dispose() {
    chat.removeListener(_onChat);
    if (_store.openId == chat.id) _store.openId = null;
    chat.draft = _ctl.text;
    _scroll.dispose();
    _ctl.dispose();
    _sq.dispose();
    _focus.dispose();
    _wall.dispose();
    _panel.dispose();
    super.dispose();
  }

  void _measure() {
    final ro = _inputKey.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.hasSize && (ro.size.height - _inputH).abs() > .5 && mounted) setState(() => _inputH = ro.size.height);
  }

  void _onScroll() {
    final far = _scroll.hasClients && _scroll.position.pixels > 260;
    if (far != _down) setState(() => _down = far);
    if (!far && _newUp != 0) setState(() => _newUp = 0);
  }

  bool get _atBottom => !_scroll.hasClients || _scroll.position.pixels < 140;

  void _toBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: TgCurves.easeOutQuint);
  }

  void _onChat() {
    final ms = chat.msgs;
    if (ms.isNotEmpty && ms.last.id != _lastId) {
      final m = ms.last;
      _lastId = m.id;
      if (m.out || _atBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
      } else if (!m.service) {
        _newUp++;
      }
    } else if (ms.isEmpty) {
      _lastId = null;
    }
    chat.unread = 0;
    if (mounted) setState(() {});
  }

  // emoji panel and keyboard swap
  void _toggleEmoji() {
    if (_emoji) {
      setState(() => _emoji = false);
      _panel.reverse();
      _focus.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _ignoreKb = DateTime.now().add(const Duration(milliseconds: 600));
      setState(() => _emoji = true);
      _panel.forward();
      _focus.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
  }

  void _closePanel() {
    if (!_emoji) return;
    setState(() => _emoji = false);
    _panel.reverse();
  }

  void _send() {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    _store.send(chat, t, reply: _reply?.id);
    _ctl.clear();
    setState(() {
      _reply = null;
      _phase++;
    });
    _wall.forward(from: 0);
  }

  void _sendSticker(String e) {
    _store.send(chat, '', kind: MsgKind.sticker, data: {'emoji': e}, reply: _reply?.id);
    setState(() {
      _reply = null;
      _phase++;
    });
    _wall.forward(from: 0);
  }

  Future<void> _attach() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _closePanel();
    final rid = _reply?.id;
    await showAttachSheet(context, chat: chat, replyId: rid);
    if (mounted) setState(() => _reply = null);
  }

  bool _grouped(Msg? a, Msg? b) => a != null && b != null && !a.service && !b.service && a.out == b.out && (a.time - b.time).abs() < 5 * 60 * 1000;

  Rect _rectOf(BuildContext c) {
    final box = c.findRenderObject() as RenderBox;
    final o = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(o.dx, o.dy, box.size.width, box.size.height);
  }

  String _nameOf(Msg m) => m.out ? _store.userName : chat.persona.name;

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  // bring a message into view then flash its row like the jump highlight in ChatActivity
  Future<void> _reveal(String id) async {
    final idx = chat.msgs.indexWhere((m) => m.id == id);
    if (idx < 0 || !_scroll.hasClients) return;
    final fromBottom = chat.msgs.length - 1 - idx;
    const factors = [1.0, 1.25, .8, 1.5, .65, 1.8];
    for (var i = 0; i < factors.length; i++) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx, alignment: .5, duration: const Duration(milliseconds: 380), curve: TgCurves.easeOutQuint);
        break;
      }
      _scroll.jumpTo((fromBottom * 92.0 * factors[i]).clamp(0.0, _scroll.position.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    setState(() {
      _flashId = id;
      _flashSeq++;
    });
  }

  void _menu(Msg m, Rect rect, Widget ghost) {
    final lastReal = chat.last;
    final l = context.l;
    showTgMenu(context, anchor: rect, blur: true, ghost: ghost, items: [
      MenuItem(l.chatMenuReply, Ic.reply, () {
        setState(() => _reply = m);
        _focus.requestFocus();
      }),
      MenuItem(l.chatMenuCopy, Ic.copy, () {
        Clipboard.setData(ClipboardData(text: m.text.isEmpty ? m.preview : m.text));
        showBulletin(context, l.toastMessageCopied);
      }),
      if (!m.out && identical(m, lastReal) && !_store.busy(chat)) MenuItem(l.chatMenuRegenerate, Ic.regen, () => _store.regenerate(chat)),
      if (!m.recalled) MenuItem(m.pinned ? l.menuUnpin : l.menuPin, Ic.pin, () => _store.humanPin(chat, m)),
      if (m.kind == MsgKind.text && !m.recalled) MenuItem(l.actionEdit, Ic.pencil, () => _editMsg(m)),
      if (m.edits.isNotEmpty) MenuItem(l.chatEditHistoryTitle, Ic.list, () => _editHistory(m)),
      const MenuItem.gap(),
      MenuItem(l.chatMenuDelete, Ic.trash, () {
        if (_reply == m) _reply = null;
        _store.deleteMsg(chat, m);
      }, danger: true),
    ]);
  }

  String _statusText(BuildContext c) {
    final l = c.l;
    if (!_store.humanOn) return l.chatStatusBot;
    final now = DateTime.now().millisecondsSinceEpoch;
    final life = chat.human.activeLife(now);
    return switch (chat.human.effective(now, dnd: _store.human!.settings.dnd)) {
      StatusKind.online || StatusKind.typing => l.statusOnline,
      StatusKind.away => life == null ? l.statusAway : '${l.statusAway} · ${life.title}',
      StatusKind.dnd => l.statusDnd,
      StatusKind.readNoReply => l.statusRead,
    };
  }

  Future<void> _editMsg(Msg m) async {
    final l = context.l;
    final t = await hAsk(context, l.chatEditMessageTitle, l.inputMessageHint, initial: m.text, lines: 4, ok: l.actionSave);
    if (t != null && mounted) _store.humanEdit(chat, m, t);
  }

  Future<void> _editHistory(Msg m) async {
    final l = context.l;
    final all = [...m.edits, m.text];
    await showTgDialog<void>(context, title: l.chatEditHistoryTitle, message: [for (var i = 0; i < all.length; i++) '${i + 1}. ${all[i]}${i == all.length - 1 ? '  ← ${l.chatEditCurrentMark}' : ''}'].join('\n'), actions: [DialogAction(l.actionOk, null)]);
  }

  void _sendLibSticker(UserSticker s) {
    _store.human!.stickers.markUsed(s.id);
    _store.send(chat, '', kind: MsgKind.sticker, data: {'emoji': s.kind == StickerKind.emoji ? s.value : '', 'sid': s.id, 'path': s.kind == StickerKind.emoji ? '' : s.value, 'gif': s.kind == StickerKind.gif}, reply: _reply?.id);
    setState(() {
      _reply = null;
      _phase++;
    });
    _wall.forward(from: 0);
  }

  Widget _pinnedBar(Pal p) {
    final l = L10n.current;
    final pins = chat.msgs.where((m) => m.pinned && !m.recalled).toList();
    if (pins.isEmpty) return const SizedBox.shrink();
    final m = pins.last;
    return Tap(
      scale: .98,
      onTap: () => _reveal(m.id),
      child: Container(
        height: 44,
        padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
        decoration: BoxDecoration(color: p.bar, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 1))]),
        child: Row(children: [
          Container(width: 2.5, margin: const EdgeInsets.symmetric(vertical: 1), decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pins.length > 1 ? '${l.msgPinned} #${pins.length}' : l.msgPinned, style: TextStyle(color: p.accent, fontSize: 13.5, fontWeight: FontWeight.w500, height: 1.1, decoration: TextDecoration.none)),
              Text(m.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 14, height: 1.15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
            ]),
          ),
          Tap(scale: .85, onTap: () => _store.humanPin(chat, m, false), child: Padding(padding: const EdgeInsets.all(8), child: TgIcon(Ic.close, color: p.subtitle, size: 18))),
        ]),
      ),
    );
  }

  // typed confirm, a tap through a menu is too easy for what this takes away
  Future<void> _confirmDelete(String title, String msg, VoidCallback run) async {
    final ok = await askTypeDelete(context, title: title, message: msg);
    if (ok) run();
  }

  /// Tapping a transfer or a red packet takes the money straight away. The card
  /// is the affordance on its own and a confirmation step only got in the way.
  void _openWallet(Msg m) {
    if (m.out || '${m.data['status'] ?? 'pending'}' != 'pending') return;
    final l = L10n.current;
    final red = m.data['kind'] == 'redpacket';
    final amount = L10n.number('#,##0.00').format(((m.data['amount'] as num?) ?? 0).toDouble());
    _store.humanAcceptTransfer(chat, m);
    showBulletin(context, red ? l.chatWalletOpened(amount) : l.chatWalletReceived(amount));
  }

  /// Opens a `paradise://…` file link a bubble cites, the same road the trace
  /// rows take their file chips down: parse, resolve for real, preview.
  Future<void> _openFileLink(String link) async {
    final parsed = FileLink.tryParse(link);
    if (parsed == null) return;
    final ctx = await _store.wsContext(chat);
    if (ctx == null || !mounted) {
      if (mounted) showBulletin(context, L10n.current.wsPreviewMissing);
      return;
    }
    try {
      final resolved = await ctx.paths.resolveReal(parsed.modelPath);
      if (!mounted) return;
      await showFilePreview(context, File(resolved.hostPath), title: parsed.modelPath.split('/').last);
    } on PathResolutionException {
      if (mounted) showBulletin(context, L10n.current.wsPreviewMissing);
    }
  }

  void _headerMenu(BuildContext ctx) {
    final locked = _store.personaFor(chat);
    final l = context.l;
    showTgMenu(ctx, anchor: _rectOf(ctx), items: [
      MenuItem(l.headerMenuSearch, Ic.search, () => _openSearch('')),
      MenuItem(l.headerMenuViewProfile, Ic.user, _openProfile),
      MenuItem(l.headerMenuEditPersona, Ic.pencil, () => openPersonaCard(context, chat: chat)),
      MenuItem(chat.muted ? l.menuUnmute : l.menuMute, chat.muted ? Ic.unmute : Ic.mute, () => _store.toggleMute(chat), sub: chat.muted ? l.headerMenuMutedSub : null),
      const MenuItem.gap(),
      // the chat lock, the per chat half of a SillyTavern persona connection
      MenuItem(l.headerMenuLockPersona, Ic.user, _openPersonaLock, sub: locked.name.trim().isEmpty ? locked.initial : locked.name.trim()),
      MenuItem(l.wallpaperChatTitle, Ic.image, () => openWallpaperSheet(context, chat: chat), sub: chat.wallpaperPath == null ? null : l.wallpaperRow),
      MenuItem(l.wsTitle, Ic.folder, () => bindWorkspace(context, _store, chat), sub: _store.wsFor(chat)?.name),
       if (_store.wsFor(chat) != null)
         MenuItem(l.termTitle, Ic.terminal, () => openWorkspaceTerminal(context, _store.wsFor(chat)!)),
      MenuItem(l.headerMenuClearHistory, Ic.trash, () => _confirmDelete(l.dialogClearHistoryHereTitle, l.dialogClearHistoryHereMessage, () => _store.clearHistory(chat))),
      MenuItem(l.headerMenuDeleteChat, Ic.close, () => _confirmDelete(l.dialogDeleteChatHereTitle, l.dialogDeleteChatMessage(chat.persona.name), () {
            Navigator.of(context).pop();
            _store.deleteChat(chat);
          }), danger: true),
    ]);
  }

  void _openPersonaLock() {
    showTgSheet<void>(context, (_) => _ChatLockSheet(chat: chat, store: _store));
  }

  Future<void> _openProfile() async {
    final r = await Navigator.of(context).push<String>(TgRoute<String>(builder: (_) => ProfilePage(chat: chat, fromChat: true)));
    if (r == 'search' && mounted) _openSearch('');
  }

  // in chat search
  void _openSearch(String q) {
    if (!mounted) return;
    setState(() {
      _searching = true;
      _asList = false;
      _sq.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
    });
    _closePanel();
    _runSearch(keep: widget.focusId);
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _asList = false;
      _hits = [];
      _sq.clear();
    });
  }

  void _runSearch({String? keep}) {
    final q = _sq.text.trim();
    final hits = q.isEmpty ? <Msg>[] : chat.find(q);
    var idx = 0;
    if (keep != null) {
      final k = hits.indexWhere((m) => m.id == keep);
      if (k >= 0) idx = k;
    }
    setState(() {
      _hits = hits;
      _hitIdx = idx;
    });
    if (hits.isNotEmpty && !_asList && keep == null) _reveal(hits[idx].id);
  }

  void _step(int by) {
    if (_hits.isEmpty) return;
    final n = (_hitIdx + by).clamp(0, _hits.length - 1);
    if (n == _hitIdx) return;
    setState(() => _hitIdx = n);
    _reveal(_hits[n].id);
  }

  Future<void> _pickDate() async {
    final d = await showCalendarSheet(context, chat);
    if (d == null || !mounted) return;
    final m = chat.msgs.where((e) => !e.service && sameDay(e.time, d.millisecondsSinceEpoch)).toList();
    if (m.isEmpty) return;
    setState(() => _asList = false);
    _reveal(m.first.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final st = context.store;
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    if (kb > 200) _panelH = kb;
    if (_emoji && kb > 100 && DateTime.now().isAfter(_ignoreKb)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _closePanel());
    }
    final panelInset = TgCurves.easeOutQuint.transform(_panel.value) * _panelH;
    final inset = math.max(math.max(kb, panelInset), mq.padding.bottom);
    final headTop = mq.padding.top + 8;
    final maxW = mq.size.width - 60;
    final ms = chat.msgs;
    final q = _searching ? _sq.text.trim() : '';
    final photos = ms.where((m) => m.kind == MsgKind.photo).toList();
    return PopScope(
      canPop: !_emoji && !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_emoji) {
          _closePanel();
        } else if (_searching) {
          _closeSearch();
        }
      },
      child: SwipeBack(
        child: ColoredBox(
          color: p.gray,
          child: Stack(children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _wall,
                builder: (_, __) => ChatWallpaper(
                  // a chat that picked its own picture wins over the global one.
                  // Null has to mean follow the global setting, which is why the
                  // model keeps the three states apart.
                  path: chat.wallpaperPath ?? _store.wallpaperPath,
                  blur: _store.wallpaperBlur,
                  colors: p.wall,
                  accent: p.accent,
                  phase: _phase - 1 + Curves.easeOut.transform(_wall.value),
                ),
              ),
            ),
            Positioned.fill(
              child: ListView.builder(
                controller: _scroll,
                reverse: true,
                physics: const ClampingScrollPhysics(),
                findChildIndexCallback: (k) {
                  final id = k is ValueKey<String> ? k.value : null;
                  final j = ms.indexWhere((m) => m.id == id);
                  return j < 0 ? null : ms.length - 1 - j;
                },
                padding: EdgeInsets.only(top: headTop + 44 + 10, bottom: inset + _inputH + 6),
                itemCount: ms.length,
                itemBuilder: (context, i) {
                  final j = ms.length - 1 - i;
                  final m = ms[j];
                  final older = j > 0 ? ms[j - 1] : null;
                  final newer = j < ms.length - 1 ? ms[j + 1] : null;
                  final isNew = !_known.contains(m.id);
                  _known.add(m.id);
                  return Enter(
                    key: ValueKey(m.id),
                    enabled: isNew,
                    fly: isNew && m.out,
                    child: _item(context, p, st, m, older, newer, maxW, q, photos),
                  );
                },
              ),
            ),
            if (ms.isEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: p.service, borderRadius: BorderRadius.circular(16)),
                  child: Text(context.l.chatEmptyPill, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                ),
              ),
            Positioned.fill(
              top: headTop + 44 + 10,
              bottom: inset + _inputH,
              child: IgnorePointer(
                ignoring: !_asList,
                child: AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: _asList ? 1 : 0, child: _resultList(p)),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: headTop,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, -.25), end: Offset.zero).animate(a), child: c)),
                child: _searching ? _searchHeader(context, p) : _header(context, p, st),
              ),
            ),
            if (!_searching) Positioned(left: 8, right: 8, top: headTop + 52, child: _pinnedBar(p)),
            Positioned(
              right: 12,
              bottom: inset + _inputH + 10,
              child: IgnorePointer(
                ignoring: !_down,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _down ? 1 : 0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    curve: TgCurves.easeOut,
                    scale: _down ? 1 : .6,
                    child: Tap(
                      scale: .9,
                      onTap: () {
                        setState(() => _newUp = 0);
                        _scroll.animateTo(0, duration: const Duration(milliseconds: 380), curve: TgCurves.easeOutQuint);
                      },
                      child: Stack(clipBehavior: Clip.none, children: [
                        Glass(radius: 22, width: 44, height: 44, child: Center(child: TgIcon(Ic.down, color: p.glassIcon, size: 26))),
                        if (_newUp > 0) Positioned(top: -8, left: 0, right: 0, child: Center(child: _Badge(count: _newUp, color: p.unread))),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            if (_emoji || _panel.value > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _panelH,
                child: Transform.translate(
                  offset: Offset(0, (1 - TgCurves.easeOutQuint.transform(_panel.value)) * _panelH),
                  child: EmojiPanel(ctl: _ctl, onSticker: _sendSticker, onLibrary: _sendLibSticker),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: inset,
              child: NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
                  return false;
                },
                child: SizeChangedLayoutNotifier(
                  child: KeyedSubtree(
                    key: _inputKey,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: TgCurves.easeOutQuint,
                      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .4), end: Offset.zero).animate(a), child: c)),
                      child: _searching
                          ? _searchBar(context, p)
                          : InputBar(
                              key: const ValueKey('input'),
                              ctl: _ctl,
                              focus: _focus,
                              busy: _store.busy(chat),
                              canStop: !(_store.humanOn && !_store.agentFor(chat)),
                              reply: _reply,
                              replyName: _reply == null ? '' : _nameOf(_reply!),
                              onCancelReply: () => setState(() => _reply = null),
                              onSend: _send,
                              onStop: () => _store.stop(chat),
                              onAttach: _attach,
                              onEmoji: _toggleEmoji,
                              emojiOpen: _emoji,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, Pal p, Store st, Msg m, Msg? older, Msg? newer, double maxW, String q, List<Msg> photos) {
    final date = older == null || !sameDay(older.time, m.time);
    final grouped = _grouped(older, m);
    final pill = date ? Padding(padding: const EdgeInsets.only(top: 6, bottom: 4), child: Center(child: _Pill(text: dayLabel(m.time)))) : const SizedBox.shrink();
    Widget row;
    if (m.kind == MsgKind.trace) {
      // one step of the model's work. Consecutive steps link their rails, so a
      // think followed by three tool calls reads as one timeline.
      bool step(Msg? x) => x != null && x.kind == MsgKind.trace;
      row = TraceView(msg: m, linkedAbove: step(older), linkedBelow: step(newer));
    } else if (m.service) {
      row = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: p.service, borderRadius: BorderRadius.circular(14)),
            child: Text(m.text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13, fontWeight: FontWeight.w500, height: 1.25, decoration: TextDecoration.none)),
          ),
        ),
      );
    } else {
      final tail = !_grouped(m, newer);
      final replyTo = chat.byId(m.reply);
      Widget bubble({bool ghost = false}) => BubbleView(
            msg: m,
            tail: tail,
            topNear: grouped,
            maxWidth: maxW,
            replyTo: replyTo,
            replyName: replyTo == null ? '' : _nameOf(replyTo),
            senderName: chat.persona.name,
            scroll: ghost ? null : _scroll,
            query: q,
            onRetry: () => _store.retry(chat, m),
            onVote: (i) => _store.votePoll(chat, m, i),
            onPhoto: () => openPhotoViewer(context, photos, m),
            onAction: () => _openWallet(m),
            onFileLink: ghost ? null : (link) => _openFileLink(link),
            onLongPress: ghost ? null : (rect) => _menu(m, rect, bubble(ghost: true)),
          );
      row = Padding(
        padding: EdgeInsets.only(top: grouped ? 1 : 5, left: 4, right: 4),
        // a recalled placeholder is a system line, not a bubble: it belongs in
        // the middle of the column rather than on the sender's side
        child: m.recalled ? Center(child: bubble()) : Align(alignment: m.out ? Alignment.centerRight : Alignment.centerLeft, child: bubble()),
      );
    }
    Widget col = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [pill, row]);
    if (_flashId == m.id) {
      col = TweenAnimationBuilder<double>(
        key: ValueKey('f$_flashSeq'),
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: 1800),
        curve: const Interval(.25, 1, curve: Curves.easeOut),
        builder: (_, v, child) => DecoratedBox(decoration: BoxDecoration(color: p.accent.withAlpha((70 * v).round())), child: child),
        child: col,
      );
    }
    return KeyedSubtree(key: _keyFor(m.id), child: col);
  }

  // search header close pill and the field pill
  Widget _searchHeader(BuildContext context, Pal p) {
    return Row(key: const ValueKey('sh'), children: [
      Tap(scale: .9, onTap: _closeSearch, child: Glass(radius: 22, width: 44, height: 44, child: Center(child: TgIcon(Ic.back, color: p.glassIcon.withAlpha(230), size: 24)))),
      const SizedBox(width: 8),
      Expanded(
        child: Glass(
          radius: 22,
          height: 44,
          child: Row(children: [
            const SizedBox(width: 14),
            TgIcon(Ic.search, color: p.glassIcon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: TgEdit(controller: _sq, hint: context.l.chatSearchHint, autofocus: true, onChanged: (_) => _runSearch(), style: TextStyle(color: p.title, fontSize: 17, decoration: TextDecoration.none, fontWeight: FontWeight.w400))),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _sq.text.isEmpty ? 0 : 1,
              child: Tap(
                scale: .85,
                onTap: () {
                  _sq.clear();
                  _runSearch();
                },
                child: SizedBox(width: 40, height: 44, child: Center(child: TgIcon(Ic.close, color: p.glassIcon, size: 20))),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  // bottom bar calendar counter arrows and the list toggle like the chat search container
  Widget _searchBar(BuildContext context, Pal p) {
    final l = context.l;
    final q = _sq.text.trim();
    final has = _hits.isNotEmpty;
    final label = q.isEmpty ? '' : (has ? l.chatSearchCount(_hitIdx + 1, _hits.length) : l.chatSearchNoResults);
    Widget arrow(Ic ic, bool on, VoidCallback f) => Tap(scale: .85, onTap: on ? f : null, child: SizedBox(width: 40, height: 44, child: Center(child: Opacity(opacity: on ? 1 : .35, child: TgIcon(ic, color: p.glassIcon, size: 24)))));
    return Padding(
      key: const ValueKey('sb'),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Glass(
        radius: 22,
        height: 44,
        child: Row(children: [
          Tap(scale: .88, onTap: _pickDate, child: SizedBox(width: 44, height: 44, child: Center(child: TgIcon(Ic.calendar, color: p.glassIcon, size: 22, stroke: 1.8)))),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .35), end: Offset.zero).animate(a), child: c)),
              layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, if (cur != null) cur]),
              child: Text(label, key: ValueKey(label), style: TextStyle(color: p.title, fontSize: 15, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
            ),
          ),
          arrow(Ic.up, has && _hitIdx < _hits.length - 1, () => _step(1)),
          arrow(Ic.down, has && _hitIdx > 0, () => _step(-1)),
          Tap(
            scale: .95,
            onTap: has ? () => setState(() => _asList = !_asList) : null,
            child: SizedBox(width: 62, height: 44, child: Center(child: Opacity(opacity: has ? 1 : .4, child: Text(_asList ? l.chatSearchModeChat : l.chatSearchModeList, style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w600, decoration: TextDecoration.none))))),
          ),
        ]),
      ),
    );
  }

  Widget _resultList(Pal p) {
    final q = _sq.text.trim();
    final base = TextStyle(color: p.msg, fontSize: 16, height: 1.2, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
    return ColoredBox(
      color: p.bg,
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        itemCount: _hits.length,
        itemBuilder: (_, i) {
          final m = _hits[i];
          return Tap(
            highlight: true,
            onTap: () {
              setState(() {
                _asList = false;
                _hitIdx = i;
              });
              _reveal(m.id);
            },
            child: SizedBox(
              height: 64,
              child: Row(children: [
                const SizedBox(width: 12),
                Avatar(name: m.out ? _store.userName : chat.persona.name, color: m.out ? 5 : chat.persona.color, size: 44, path: m.out ? _store.userAvatar : chat.persona.avatarPath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text(_nameOf(m), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.name, fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.none))),
                      Text(dialogDate(m.time), style: TextStyle(color: p.date, fontSize: 12, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                    ]),
                    const SizedBox(height: 2),
                    Text.rich(TextSpan(children: hlSpans(snippet(m.text.isEmpty ? m.preview : m.text, q), q, base, p.accent)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const SizedBox(width: 16),
              ]),
            ),
          );
        },
      ),
    );
  }

  // glass header back pill title pill and menu pill
  Widget _header(BuildContext context, Pal p, Store st) {
    final other = st.chats.where((c) => c != chat && !c.muted).fold<int>(0, (a, c) => a + st.unreadOf(c));
    return Row(key: const ValueKey('hd'), children: [
      Tap(
        scale: .9,
        onTap: () => Navigator.of(context).maybePop(),
        child: Stack(clipBehavior: Clip.none, children: [
          Glass(radius: 22, width: 44, height: 44, child: Center(child: TgIcon(Ic.back, color: p.glassIcon.withAlpha(230), size: 24))),
          Positioned(
            top: -6,
            right: -8,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: other > 0 ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 250),
              curve: TgCurves.easeOutBack,
              builder: (_, t, __) => t <= 0.01 ? const SizedBox.shrink() : Transform.scale(scale: t, child: _Badge(count: other, color: p.unread)),
            ),
          ),
        ]),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Tap(
          scale: .98,
          onTap: _openProfile,
          child: Glass(
            radius: 22,
            height: 44,
            child: Row(children: [
              const SizedBox(width: 4),
              Avatar(name: chat.persona.emoji.isEmpty ? chat.persona.name : chat.persona.emoji, color: chat.persona.color, size: 36, path: chat.persona.avatarPath),
              const SizedBox(width: 9),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(chat.persona.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 17.5, fontWeight: FontWeight.w500, height: 1.1, decoration: TextDecoration.none)),
                  SizedBox(
                    height: 16,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(a), child: c)),
                      layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, if (cur != null) cur]),
                      child: chat.typing
                          ? Row(key: const ValueKey('t'), mainAxisSize: MainAxisSize.min, children: [
                              Text(context.l.chatStatusTyping, style: TextStyle(color: p.accent, fontSize: 13.5, height: 1.1, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                              const SizedBox(width: 2),
                              TypingDots(color: p.accent),
                            ])
                          : Text(_statusText(context), key: ValueKey('b${chat.human.status.name}${_store.humanOn}'), style: TextStyle(color: p.subtitle, fontSize: 13.5, height: 1.1, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Builder(
        builder: (ctx) => Tap(
          scale: .9,
          onTap: () => _headerMenu(ctx),
          child: Glass(radius: 22, width: 44, height: 44, child: Center(child: TgIcon(Ic.more, color: p.glassIcon.withAlpha(230), size: 24))),
        ),
      ),
    ]);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: context.p.service, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13, fontWeight: FontWeight.w500, height: 1.25, decoration: TextDecoration.none)),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(count > 99 ? '99+' : L10n.number('#,##0').format(count), style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12, fontWeight: FontWeight.w500, height: 1.1, decoration: TextDecoration.none)),
      );
}

// pick which of my persona cards speaks in this chat, the chat lock from the
// SillyTavern persona panel. The first row clears the lock so the card in hand
// takes over again.
class _ChatLockSheet extends StatelessWidget {
  const _ChatLockSheet({required this.chat, required this.store});
  final Chat chat;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final mq = MediaQuery.of(context);
    return TgSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
            child: Text(l.lockSheetTitle, style: TextStyle(color: p.title, fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(l.lockSheetSub, style: TextStyle(color: p.subtitle, fontSize: 13.5, decoration: TextDecoration.none)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                for (final c in store.personas)
                  _row(p, c.id == chat.personaId, c.avatarPath, c.color, c.name.trim().isEmpty ? l.lockSheetUnnamed : c.name.trim(), c.summary, () => store.toggleChatLock(chat, c.id)),
                if (store.personas.isNotEmpty)
                  _row(p, chat.personaId == null, '', -1, l.lockSheetNone, l.lockSheetNoneSub, () {
                    if (chat.personaId == null) return;
                    store.toggleChatLock(chat, chat.personaId!);
                  }),
                if (store.personas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 26, 16, 26),
                    child: Text(l.lockSheetEmpty, textAlign: TextAlign.center, style: TextStyle(color: p.subtitle, fontSize: 14.5, height: 1.35, decoration: TextDecoration.none)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TgButton(label: l.actionDone, onTap: () => Navigator.of(context).pop()),
          ),
        ]),
      ),
    );
  }

  Widget _row(Pal p, bool on, String path, int color, String title, String sub, VoidCallback onTap) => Tap(
        scale: .99,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: TgCurves.easeOut,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(14, 11, 16, 11),
          decoration: BoxDecoration(color: on ? p.accent.withAlpha(28) : p.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? p.accent : const Color(0x00000000), width: .6)),
          child: Row(children: [
            AnimatedAvatar(path: path, name: title, color: color < 0 ? 4 : color, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none)),
                const SizedBox(height: 1),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none)),
              ]),
            ),
            if (on) TgIcon(Ic.check, color: p.accent, size: 20, stroke: 2.2),
          ]),
        ),
      );
}
