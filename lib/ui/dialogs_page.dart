import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/status.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'chat_page.dart';
import 'persona_card.dart';
import 'profile_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'shop_page.dart';
import 'workspace/workspace_prompts.dart' show askTypeDelete;

// main tabs shell like MainTabsActivity with the glass tab row floating at the bottom
class DialogsPage extends StatefulWidget {
  const DialogsPage({super.key});

  @override
  State<DialogsPage> createState() => _DialogsPageState();
}

class _DialogsPageState extends State<DialogsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    final st = context.store;
    return ColoredBox(
      color: p.gray,
      child: Stack(children: [
        for (var i = 0; i < 3; i++)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _tab != i,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: TgCurves.easeOut,
                opacity: _tab == i ? 1 : 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 320),
                  curve: TgCurves.easeOutQuint,
                  offset: Offset(_tab == i ? 0 : (i < _tab ? -.04 : .04), 0),
                  child: i == 0 ? ChatsTab(active: _tab == 0) : (i == 1 ? const SettingsTab() : ProfilePage(mine: true, onBack: () => setState(() => _tab = 1))),
                ),
              ),
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: mq.padding.bottom + 8,
          child: _TabBar(index: _tab, unread: st.totalUnread, onPick: (i) => setState(() => _tab = i)),
        ),
      ]),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.unread, required this.onPick});
  final int index;
  final int unread;
  final void Function(int) onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final st = context.store;
    final labels = [context.l.tabChats, context.l.tabSettings, context.l.tabProfile];
    return Glass(
      radius: 28,
      height: 56,
      child: LayoutBuilder(builder: (_, box) {
        final w = box.maxWidth / 3;
        return Stack(children: [
          // selector pill with the quint slide
          AnimatedPositioned(
            duration: const Duration(milliseconds: 380),
            curve: TgCurves.easeOutQuint,
            left: w * index,
            width: w,
            top: 0,
            bottom: 0,
            child: Container(margin: const EdgeInsets.all(4), decoration: BoxDecoration(color: p.tabSel.withAlpha(24), borderRadius: BorderRadius.circular(24))),
          ),
          Row(children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Tap(
                  onTap: () => onPick(i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      AnimatedScale(
                        scale: index == i ? 1.1 : 1,
                        duration: const Duration(milliseconds: 300),
                        curve: TgCurves.easeOutBack,
                        child: i == 2
                            ? Avatar(name: st.userName, color: 4, size: 24, path: st.userAvatar)
                            : TgIcon(i == 0 ? Ic.chats : Ic.gear, color: index == i ? p.tabSel : p.tabUnsel.withAlpha(170), size: 24, stroke: 1.8),
                      ),
                      if (i == 0)
                        Positioned(
                          top: -6,
                          left: 14,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: unread > 0 ? 1.0 : 0.0),
                            duration: const Duration(milliseconds: 250),
                            curve: TgCurves.easeOutBack,
                            builder: (_, t, __) => t <= .01 ? const SizedBox.shrink() : Transform.scale(scale: t, child: _CountBadge(count: unread, color: p.unread, muted: false, small: true)),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(color: index == i ? p.tabSel : p.tabUnsel.withAlpha(170), fontSize: 11, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
                      child: Text(labels[i]),
                    ),
                  ]),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

// unread badge used by rows and tabs
class _CountBadge extends StatelessWidget {
  const _CountBadge({super.key, required this.count, required this.color, required this.muted, this.small = false});
  final int count;
  final Color color;
  final bool muted;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      constraints: BoxConstraints(minWidth: small ? 18 : 20.67),
      height: small ? 18 : 20.67,
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 6.33),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: muted ? p.unreadMuted : color, borderRadius: BorderRadius.circular(11)),
      child: Text(count > 999 ? L10n.number('#,##0').format(count ~/ 1000) + 'K' : L10n.number('#,##0').format(count), style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: small ? 11 : 13, fontWeight: FontWeight.w500, height: 1.1, decoration: TextDecoration.none)),
    );
  }
}

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key, required this.active});
  final bool active;

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final ScrollController _scroll = ScrollController();
  bool _fab = true;
  double _last = 0;
  final Set<String> _known = {};
  bool _first = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final y = _scroll.offset;
      // fab leaves on scroll down and returns on scroll up
      if ((y - _last).abs() > 8) {
        final show = y < _last || y < 40;
        if (show != _fab) setState(() => _fab = show);
        _last = y;
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _newPersona() async {
    final c = await openPersonaCard(context);
    if (c != null && mounted) openChat(context, c);
  }

  void _rowMenu(Chat c, Rect rect) {
    final st = Store.read(context);
    final l = context.l;
    showTgMenu(context, anchor: rect, items: [
      MenuItem(c.pinned ? l.menuUnpin : l.menuPin, Ic.pin, () => st.togglePin(c)),
      MenuItem(c.muted ? l.menuUnmute : l.menuMute, c.muted ? Ic.unmute : Ic.mute, () => st.toggleMute(c)),
      if (c.unread > 0) MenuItem(l.menuMarkAsRead, Ic.check2, () {
            c.unread = 0;
            c.markedUnread = false;
            c.touch();
          }),
      const MenuItem.gap(),
      MenuItem(l.menuClearHistory, Ic.trash, () => _confirmDelete(l.dialogClearHistoryTitle, l.dialogClearHistoryMessage(c.persona.name), () => st.clearHistory(c)), danger: true),
      MenuItem(l.menuDeleteChat, Ic.close, () => _confirmDelete(l.dialogDeleteChatTitle, l.dialogDeleteChatMessage(c.persona.name), () => st.deleteChat(c)), danger: true),
    ]);
  }

  // typed confirm, a tap through a menu is too easy for what this takes away
  Future<void> _confirmDelete(String title, String msg, VoidCallback run) async {
    final ok = await askTypeDelete(context, title: title, message: msg);
    if (ok) run();
  }

  void _topMenu(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox;
    final o = box.localToGlobal(Offset.zero);
    final st = Store.read(context);
    final l = context.l;
    showTgMenu(context, anchor: Rect.fromLTWH(o.dx, o.dy, box.size.width, box.size.height), items: [
      MenuItem(l.chatsNewPersona, Ic.user, _newPersona),
      MenuItem(l.shopEntry, Ic.crown, () => Navigator.of(context).push(TgRoute(builder: (_) => const ShopPage()))),
      MenuItem(l.chatsMenuReadAll, Ic.check2, () {
        for (final c in st.chats) {
          c.unread = 0;
          c.markedUnread = false;
          c.touch();
        }
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final st = context.store;
    final mq = MediaQuery.of(context);
    final list = st.sorted;
    final top = mq.padding.top;
    return ColoredBox(
      color: p.bg,
      child: Stack(children: [
        Positioned.fill(
          child: list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TgIcon(Ic.chats, color: p.subtitle, size: 64),
                      const SizedBox(height: 14),
                      Text(context.l.chatsEmptyTitle, style: TextStyle(color: p.title, fontSize: 20, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                      const SizedBox(height: 6),
                      Text(context.l.chatsEmptySub, textAlign: TextAlign.center, style: TextStyle(color: p.subtitle, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                      const SizedBox(height: 20),
                      SizedBox(width: 200, child: TgButton(label: context.l.chatsNewPersona, onTap: _newPersona)),
                    ]),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  physics: const ClampingScrollPhysics(),
                  cacheExtent: 700,
                  padding: EdgeInsets.only(top: top + 56 + 52, bottom: mq.padding.bottom + 100),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final isNew = !_first && !_known.contains(c.id);
                    _known.add(c.id);
                    return _Reorder(
                      key: ValueKey(c.id),
                      index: i,
                      child: Enter(enabled: isNew, child: DialogRow(chat: c, onTap: () => openChat(context, c), onLongPress: (r) => _rowMenu(c, r))),
                    );
                  },
                ),
        ),
        // header with title and search pill
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            color: p.bar,
            padding: EdgeInsets.only(top: top),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 56,
                child: Row(children: [
                  const SizedBox(width: 20),
                  Expanded(child: Text(context.l.chatsTitle, style: TextStyle(color: p.title, fontSize: 22, fontWeight: FontWeight.w600, decoration: TextDecoration.none))),
                  Builder(builder: (ctx) => Tap(scale: .88, onTap: () => _topMenu(ctx), child: SizedBox(width: 48, height: 48, child: Center(child: TgIcon(Ic.more, color: p.icon, size: 24))))),
                  const SizedBox(width: 4),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Tap(
                  scale: .985,
                  onTap: () => Navigator.of(context).push(TgRoute(builder: (_) => const SearchPage())),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(color: p.title.withAlpha(p.dark ? 18 : 13), borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      const SizedBox(width: 14),
                      TgIcon(Ic.search, color: p.hint, size: 20, stroke: 1.8),
                      const SizedBox(width: 10),
                      Text(context.l.chatsSearchHint, style: TextStyle(color: p.hint, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Positioned(
          right: 16,
          bottom: mq.padding.bottom + 8 + 56 + 16,
          child: IgnorePointer(
            ignoring: !_fab,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _fab ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 380),
              curve: TgCurves.easeOutQuint,
              builder: (_, t, child) => Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, 40 * (1 - t)), child: Transform.scale(scale: .4 + .6 * t, child: child))),
              child: Tap(
                scale: .92,
                onTap: _newPersona,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: p.send, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 3))]),
                  child: Center(child: TgIcon(Ic.pencil, color: const Color(0xFFFFFFFF), size: 26)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

void openChat(BuildContext context, Chat c, {String? jumpTo, String query = '', bool search = false}) {
  Navigator.of(context).push(TgRoute(builder: (_) => ChatPage(chat: c, focusId: jumpTo, query: query, startSearch: search)));
}

// rows glide to their new slot when pin or a new message reorders the list
class _Reorder extends StatefulWidget {
  const _Reorder({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_Reorder> createState() => _ReorderState();
}

class _ReorderState extends State<_Reorder> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  double _from = 0;

  @override
  void didUpdateWidget(_Reorder old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      final cur = _from * (1 - TgCurves.easeOutQuint.transform(_c.value));
      _from = cur + (old.index - widget.index) * 72.0;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) => Transform.translate(offset: Offset(0, _from * (1 - TgCurves.easeOutQuint.transform(_c.value))), child: child),
      );
}

// DialogCell layout avatar name mute time ticks message badge pin
class DialogRow extends StatelessWidget {
  const DialogRow({super.key, required this.chat, required this.onTap, required this.onLongPress});
  final Chat chat;
  final VoidCallback onTap;
  final void Function(Rect) onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final st = context.store;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        final l = context.l;
        final last = chat.last;
        final draft = chat.draft.trim();
        final hasDraft = draft.isNotEmpty && st.openId != chat.id;
        final time = last == null ? '' : dialogDate(last.time);
        final state = last == null || !last.out ? null : last.state;
        final msgStyle = TextStyle(color: p.msg, fontSize: 16, height: 1.2, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
        Widget sub;
        if (chat.typing) {
          sub = Row(children: [
            Text(l.chatsRowTyping, style: msgStyle.copyWith(color: p.accent)),
            const SizedBox(width: 3),
            TypingDots(color: p.accent),
          ]);
        } else if (hasDraft) {
          sub = Text.rich(TextSpan(children: [TextSpan(text: l.chatsRowDraft, style: msgStyle.copyWith(color: p.draft)), TextSpan(text: draft.replaceAll('\n', ' '), style: msgStyle)]), maxLines: 1, overflow: TextOverflow.ellipsis);
        } else if (last == null) {
          sub = Text(l.chatsRowEmpty, style: msgStyle);
        } else {
          sub = Text.rich(
            TextSpan(children: [
              if (last.out) TextSpan(text: l.chatsRowYou, style: msgStyle.copyWith(color: p.name)),
              TextSpan(text: last.preview, style: msgStyle.copyWith(color: last.kind == MsgKind.text ? p.msg : p.accent.withAlpha(230))),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        final rowKey = GlobalKey();
        return Tap(
          highlight: true,
          onTap: onTap,
          onLongPress: () {
            final box = rowKey.currentContext!.findRenderObject() as RenderBox;
            final o = box.localToGlobal(Offset.zero);
            onLongPress(Rect.fromLTWH(o.dx + 40, o.dy, box.size.width - 80, box.size.height));
          },
          child: SizedBox(
            key: rowKey,
            height: 72,
            child: Row(children: [
              const SizedBox(width: 10),
              Avatar(name: chat.persona.emoji.isEmpty ? chat.persona.name : chat.persona.emoji, color: chat.persona.color, size: 56, path: chat.persona.avatarPath),
              const SizedBox(width: 12),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Flexible(child: Text(chat.persona.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.name, fontSize: 17, fontWeight: FontWeight.w500, height: 1.2, decoration: TextDecoration.none))),
                    if (chat.muted) ...[const SizedBox(width: 5), TgIcon(Ic.mute, color: p.muteIcon, size: 16, stroke: 1.6)],
                    const SizedBox(width: 6),
                    if (state != null) ...[MsgStatus(state: state, color: p.sentCheck, list: true, danger: p.danger), const SizedBox(width: 2)],
                    Text(time, style: TextStyle(color: p.date, fontSize: 13, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                    const SizedBox(width: 14),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Expanded(child: sub),
                    const SizedBox(width: 8),
                    // badge pops on every count change like the counter animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: TgCurves.easeOutBack,
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                      child: chat.unread > 0
                          ? _CountBadge(key: ValueKey(chat.unread), count: chat.unread, color: p.unread, muted: chat.muted)
                          : (chat.pinned ? TgIcon(Ic.pinTilt, key: const ValueKey('pin'), color: p.pinIcon, size: 17) : const SizedBox(key: ValueKey('none'), width: 0, height: 0)),
                    ),
                    const SizedBox(width: 14),
                  ]),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// keep math linked for callers that clamp badges
double clampBadge(double v) => math.min(v, 999);
