import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'account_page.dart';
import 'dialogs_page.dart';
import 'persona_card.dart';

// ProfileActivity2 lerp3 over collapsed default and expanded
double _l3(double a, double b, double c, double t) => t < 0 ? a + (b - a) * (t + 1) : b + (c - b) * t;

// Telegram ProfileActivity2 lays two spacers in the list, 152 for the expanded
// block and 122 for the default one, so the header runs 56 collapsed into the
// action bar, 178 at rest and 330 fully expanded
const double kBar = 56;
const double kDefault = 122;
const double kExpanded = 152;
const double kSpacer = kExpanded + kDefault;

// the three places a scroll is allowed to settle on, matching the snap helper
const _anchors = [0.0, kExpanded, kSpacer];

// persona profile from the chat header or my own profile as a tab
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.chat, this.mine = false, this.fromChat = false, this.onBack});
  final Chat? chat;
  final bool mine;
  final bool fromChat;
  final VoidCallback? onBack;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // open on the default block, the spacer above it is the room the header grows into
  final ScrollController _scroll = ScrollController(initialScrollOffset: kExpanded);
  Timer? _idle;
  bool _dragging = false;
  int _snapping = 0;
  int _tab = 0;

  Chat? get chat => widget.chat;

  // the collapsed header parks the avatar at x 85, so the left side only reads
  // as deliberate when something is sitting there
  VoidCallback? get _back => widget.mine ? widget.onBack : () => Navigator.of(context).maybePop();

  // -1 action bar, 0 default, 1 expanded, read straight off the scroll offset
  // so the header and the list content below it can never drift apart
  double get _progress {
    if (!_scroll.hasClients) return 0;
    final s = _scroll.offset;
    return s <= kExpanded ? 1 - s / kExpanded : -(s - kExpanded) / kDefault;
  }

  // LinearSnapHelper: only the three anchor offsets may come to rest, anything
  // else springs back to the nearer one over 420ms ease out quint, the same
  // curve and duration the expanded AnimatedFloat uses
  bool _settle(ScrollNotification n) {
    if (n is ScrollStartNotification) _dragging = n.dragDetails != null;
    if (n is ScrollEndNotification) _dragging = false;
    _idle?.cancel();
    _idle = Timer(const Duration(milliseconds: 90), _snap);
    return false;
  }

  void _snap() {
    if (!mounted || !_scroll.hasClients || _snapping > 0 || _dragging) return;
    final pos = _scroll.position;
    // past the header travel the list is just an ordinary scroller, so it must
    // not be yanked back to the collapsed anchor
    final s = pos.pixels;
    if (s < 0 || s > kSpacer) return;
    var target = _anchors.first;
    var best = double.infinity;
    for (final a in _anchors) {
      final d = (a - s).abs();
      if (d < best) {
        best = d;
        target = a;
      }
    }
    if (best < .5) return;
    _snapping++;
    _scroll.animateTo(math.min(target, pos.maxScrollExtent), duration: const Duration(milliseconds: 420), curve: TgCurves.easeOutQuint).whenComplete(() {
      if (mounted && _snapping > 0) _snapping--;
    });
  }

  @override
  void dispose() {
    _idle?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  String get _name => widget.mine ? Store.read(context).userName : chat!.persona.name;
  int get _color => widget.mine ? 4 : chat!.persona.color;
  String get _emoji => widget.mine ? '' : chat!.persona.emoji;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final st = context.store;
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    final w = mq.size.width;
    final bottom = widget.mine ? mq.padding.bottom + 96 : mq.padding.bottom + 24;
    return ListenableBuilder(
      listenable: Listenable.merge([_scroll, if (chat != null) chat!]),
      builder: (context, _) {
        final t = _progress.clamp(-1.0, 1.0);
        final h = _l3(kBar, kBar + kDefault, kBar + kSpacer, t);
        final page = ColoredBox(
          color: p.gray,
          child: Stack(children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: _settle,
                child: ListView(
                  controller: _scroll,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(top: top + kBar, bottom: bottom),
                  // the list is padded by the action bar only, the 274 spacer
                  // below is what the header slides over
                  children: [
                    ConstrainedBox(
                      // always leave room for the whole 274 travel so the
                      // collapsed state stays reachable even on a short page
                      constraints: BoxConstraints(minHeight: mq.size.height - top - kBar + kSpacer),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _body(context, p, st)),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(left: 0, right: 0, top: 0, height: top + h, child: _header(p, t, w, top, h)),
            if (_back != null) Positioned(left: 8, top: top + 6, child: Tap(scale: .9, onTap: _back, child: SizedBox(width: 44, height: 44, child: Center(child: TgIcon(Ic.back, color: t > .5 ? const Color(0xFFFFFFFF) : p.icon, size: 24))))),
            Positioned(right: 8, top: top + 6, child: Builder(builder: (ctx) => Tap(scale: .9, onTap: () => _menu(ctx), child: SizedBox(width: 44, height: 44, child: Center(child: TgIcon(Ic.more, color: t > .5 ? const Color(0xFFFFFFFF) : p.icon, size: 24)))))),
          ]),
        );
        return widget.mine ? page : SwipeBack(child: page);
      },
    );
  }

  Widget _header(Pal p, double t, double w, double top, double h) {
    final g = avatarColors[_color % avatarColors.length];
    // avatar geometry from AvatarImage.dispatchDraw
    final cx = _l3(85, w / 2, w / 2, t);
    final cy = _l3(28, 59, h / 2, t);
    final aw = _l3(42, 90, w, t);
    final ah = _l3(42, 90, h, t);
    final rad = t > 0 ? (1 - t) * aw / 2 : aw / 2;
    final name = _name;
    final ini = _emoji.isNotEmpty ? _emoji : (name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase());
    // the photo takes over the gradient block, rounded while collapsed and
    // square once the header is open, the same corner the initial gets
    final _pic = widget.mine ? Store.read(context).userAvatar : chat!.persona.avatarPath;
    final tSize = _l3(18, 22, 25, t);
    final sub = widget.mine ? context.l.accountOnlineFallback : (chat!.typing ? context.l.profileHeaderTyping : context.l.chatStatusBot);
    final tp = TextPainter(text: TextSpan(text: name, style: TextStyle(fontSize: tSize, fontWeight: FontWeight.w600)), maxLines: 1, textDirection: TextDirection.ltr)..layout();
    final sp = TextPainter(text: TextSpan(text: sub, style: const TextStyle(fontSize: 14)), maxLines: 1, textDirection: TextDirection.ltr)..layout();
    // the title measures against the plain 18.66 side margins, never against the
    // room the action bar buttons leave, otherwise a long name sits off centre
    final fit = math.min(w - 37.32, 2000.0);
    final avail = (w - _l3(150, 64, 37.32, t)).clamp(60.0, 2000.0);
    final tx = _l3(118, (w - math.min(tp.width, fit)) / 2, 18.66, t);
    final ty = _l3(8.33, 114, h - 32 - tp.height, t);
    final sx = _l3(118, (w - math.min(sp.width, fit)) / 2, 18.66, t);
    final sy = _l3(31, 143.66, h - 12 - sp.height, t);
    final tc = Color.lerp(p.title, const Color(0xFFFFFFFF), t.clamp(0.0, 1.0))!;
    final sc = Color.lerp(p.subtitle, const Color(0xD9FFFFFF), t.clamp(0.0, 1.0))!;
    return ClipRect(
      child: Container(
        color: p.bar,
        child: Stack(clipBehavior: Clip.hardEdge, children: [
          Positioned(
            left: cx - aw / 2,
            top: top + cy - ah / 2,
            width: aw,
            height: ah,
            child: _pic.isEmpty
                ? Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(rad), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: g)),
                    child: Text(ini, style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: math.min(aw, ah) * (t > .5 ? .34 : .42), fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(rad),
                    child: Image.file(File(_pic), width: aw, height: ah, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
          ),
          // scrim so the white title reads on the big avatar
          if (t > 0)
            Positioned(left: 0, right: 0, bottom: 0, height: 110, child: Opacity(opacity: t.clamp(0.0, 1.0), child: const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x66000000)]))))),
          Positioned(left: tx, top: top + ty, width: avail, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tc, fontSize: tSize, fontWeight: FontWeight.w600, decoration: TextDecoration.none))),
          Positioned(left: sx, top: top + sy, child: Text(sub, style: TextStyle(color: chat?.typing == true && t <= 0 ? p.accent : sc, fontSize: 14, decoration: TextDecoration.none, fontWeight: FontWeight.w400))),
          Positioned(left: 0, right: 0, bottom: 0, child: Opacity(opacity: t < 0 ? -t : 0, child: Container(height: .5, color: p.divider))),
        ]),
      ),
    );
  }

  List<Widget> _body(BuildContext context, Pal p, Store st) {
    final items = <Widget>[const SizedBox(height: kSpacer)];
    final l = context.l;
    // button tiles like the ID_BUTTONS row
    final buttons = widget.mine
        ? [
            (Ic.pencil, l.profileButtonEdit, () => openAccount(context)),
            (Ic.share, l.profileButtonShare, () {
              final card = st.activePersona;
              final lines = [
                st.userName,
                if (st.userBio.isNotEmpty) st.userBio,
                if (card.title.trim().isNotEmpty) card.title.trim(),
                if (card.description.trim().isNotEmpty) card.description.trim(),
              ];
              Clipboard.setData(ClipboardData(text: lines.join('\n')));
              showBulletin(context, l.profileCopied);
            }),
          ]
        : [
            (Ic.chats, l.profileButtonMessage, () => widget.fromChat ? Navigator.of(context).maybePop() : openChat(context, chat!)),
            (chat!.muted ? Ic.unmute : Ic.mute, chat!.muted ? l.menuUnmute : l.menuMute, () => st.toggleMute(chat!)),
            (Ic.search, l.profileButtonSearch, () {
              if (widget.fromChat) Navigator.of(context).pop('search');
              else openChat(context, chat!, search: true);
            }),
            (Ic.pencil, l.profileButtonEdit, () => openPersonaCard(context, chat: chat)),
          ];
    items.add(Container(
      color: p.bg,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
      child: Row(children: [
        for (final b in buttons)
          Expanded(
            child: Tap(
              scale: .94,
              onTap: b.$3,
              child: Container(
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: p.accent.withAlpha(p.dark ? 30 : 20), borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TgIcon(b.$1, color: p.accent, size: 22, stroke: 1.8),
                  const SizedBox(height: 3),
                  Text(b.$2, style: TextStyle(color: p.accent, fontSize: 12, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                ]),
              ),
            ),
          ),
      ]),
    ));
    items.add(const SizedBox(height: 8));
    // info cells value on top label below
    final cells = <Widget>[];
    void cell(String value, String label, {bool copy = true, Widget? trailing}) {
      if (value.trim().isEmpty) return;
      cells.add(Tap(
        highlight: true,
        onTap: copy
            ? () {
                Clipboard.setData(ClipboardData(text: value));
                showBulletin(context, context.l.toastCopiedLabel(label));
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, maxLines: 6, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 16, height: 1.25, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
              ]),
            ),
            if (trailing != null) trailing,
          ]),
        ),
      ));
    }

    if (widget.mine) {
      cell(st.userName, l.profileLabelName);
      cell(st.userBio.isEmpty ? l.profileBioEmpty : st.userBio, l.profileLabelBio, copy: st.userBio.isNotEmpty);
      // the card in hand, so it is obvious which identity the ai is talking to
      final card = st.activePersona;
      cell(card.description.isEmpty ? l.profileCardEmpty : card.description, l.profileLabelPersonaCard, copy: card.description.isNotEmpty, trailing: st.personas.length > 1 ? _cardCount(p, st.personas.length) : null);
      cell(l.profileActivity(st.chats.length, st.chats.fold<int>(0, (a, c) => a + c.msgs.where((m) => m.out).length)), l.profileLabelActivity, copy: false);
    } else {
      cell(chat!.persona.bio, l.profileLabelAbout);
      cell(chat!.persona.prompt, l.profileLabelInstructions);
      // Global while the persona follows the chain, its own model once it has
      // one. Read only here, the override is set in the persona editor.
      cell(chat!.persona.modelLabel, l.profileLabelModel, copy: false);
      cells.add(Tap(
        highlight: true,
        onTap: () => st.toggleMute(chat!),
        child: SizedBox(
          height: 52,
          child: Row(children: [
            const SizedBox(width: 20),
            Expanded(child: Text(l.profileLabelNotifications, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400))),
            Text(chat!.muted ? l.profileOff : l.profileOn, style: TextStyle(color: p.subtitle, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
            const SizedBox(width: 12),
            TgSwitch(value: !chat!.muted, onChanged: (_) => st.toggleMute(chat!)),
            const SizedBox(width: 16),
          ]),
        ),
      ));
    }
    items.add(Container(color: p.bg, child: Column(children: cells)));
    items.add(const SizedBox(height: 10));
    items.add(_shared(context, p, st));
    return items;
  }

  // small pill showing how many cards exist, so the count is visible on the
  // profile without opening the editor
  Widget _cardCount(Pal p, int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: p.accent.withAlpha(p.dark ? 30 : 20), borderRadius: BorderRadius.circular(9)),
        child: Text(L10n.number('#,##0').format(n), style: TextStyle(color: p.accent, fontSize: 13, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
      );

  void _menu(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox;
    final o = box.localToGlobal(Offset.zero);
    final st = Store.read(context);
    final l = context.l;
    final r = Rect.fromLTWH(o.dx, o.dy, box.size.width, box.size.height);
    if (widget.mine) {
      showTgMenu(context, anchor: r, items: [MenuItem(l.accountTitle, Ic.pencil, () => openAccount(context))]);
      return;
    }
    showTgMenu(context, anchor: r, items: [
      MenuItem(l.headerMenuEditPersona, Ic.pencil, () => openPersonaCard(context, chat: chat)),
      MenuItem(chat!.muted ? l.menuUnmute : l.menuMute, chat!.muted ? Ic.unmute : Ic.mute, () => st.toggleMute(chat!)),
      MenuItem(chat!.pinned ? l.menuUnpin : l.menuPin, Ic.pin, () => st.togglePin(chat!)),
      const MenuItem.gap(),
      MenuItem(l.menuClearHistory, Ic.trash, () async {
        final ok = await showTgDialog<bool>(context, title: l.dialogClearHistoryTitle, message: l.dialogClearHistoryMessage(chat!.persona.name), actions: [DialogAction(l.actionCancel, false), DialogAction(l.actionClear, true, danger: true)]);
        if (ok == true) st.clearHistory(chat!);
      }, danger: true),
    ]);
  }

  // shared media tabs media files music links
  Widget _shared(BuildContext context, Pal p, Store st) {
    final l = context.l;
    final names = [l.profileTabMedia, l.profileTabFiles, l.profileTabMusic, l.profileTabLinks];
    final empties = [l.profileSharedEmptyMedia, l.profileSharedEmptyFiles, l.profileSharedEmptyMusic, l.profileSharedEmptyLinks];
    final src = widget.mine ? st.chats : [chat!];
    final rows = <(Chat, Msg)>[];
    for (final c in src) {
      for (final m in c.msgs) {
        final ok = switch (_tab) {
          0 => m.kind == MsgKind.photo,
          1 => m.kind == MsgKind.file,
          2 => m.kind == MsgKind.music,
          _ => m.kind == MsgKind.text && m.hasLink,
        };
        if (ok) rows.add((c, m));
      }
    }
    rows.sort((a, b) => b.$2.time.compareTo(a.$2.time));
    Widget body;
    if (rows.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          TgIcon(_tab == 0 ? Ic.image : (_tab == 1 ? Ic.file : (_tab == 2 ? Ic.music : Ic.link)), color: p.subtitle.withAlpha(140), size: 44),
          const SizedBox(height: 10),
          Text(empties[_tab], style: TextStyle(color: p.subtitle, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
        ]),
      );
    } else if (_tab == 0) {
      body = GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        padding: const EdgeInsets.all(2),
        children: [
          for (final r in rows)
            Tap(
              onTap: () => openChat(context, r.$1, jumpTo: r.$2.id),
              child: r.$2.kind == MsgKind.photo && r.$2.data['path'] != null
                  ? ClipRect(child: Image.file(File(r.$2.data['path'] as String), fit: BoxFit.cover, width: 300, errorBuilder: (_, __, ___) => const SizedBox.shrink()))
                  : Container(color: const Color(0xFF26303B), child: Center(child: TgIcon(Ic.video, color: const Color(0xFFFFFFFF), size: 30))),
            ),
        ],
      );
    } else {
      body = Column(children: [
        for (final r in rows)
          Tap(
            highlight: true,
            onTap: () => openChat(context, r.$1, jumpTo: r.$2.id),
            child: SizedBox(
              height: 64,
              child: Row(children: [
                const SizedBox(width: 16),
                Container(width: 44, height: 44, decoration: BoxDecoration(color: p.accent.withAlpha(_tab == 3 ? 30 : 255), shape: BoxShape.circle), child: Center(child: TgIcon(_tab == 1 ? Ic.file : (_tab == 2 ? Ic.music : Ic.link), color: _tab == 3 ? p.accent : const Color(0xFFFFFFFF), size: 22))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_tab == 3 ? (RegExp(r'https?://\S+').firstMatch(r.$2.text)?.group(0) ?? '') : ('${r.$2.data['name'] ?? l.profileFileFallback}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _tab == 3 ? p.accent : p.title, fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                    const SizedBox(height: 2),
                    Text('${_tab == 3 ? '' : '${fileSize((r.$2.data['size'] as num?) ?? 0)} · '}${dialogDate(r.$2.time)}', style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                  ]),
                ),
              ]),
            ),
          ),
      ]);
    }
    return Container(
      color: p.bg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 48,
          child: LayoutBuilder(builder: (_, box) {
            final tw = box.maxWidth / names.length;
            return Stack(children: [
              Row(children: [
                for (var i = 0; i < names.length; i++)
                  Expanded(
                    child: Tap(
                      onTap: () => setState(() => _tab = i),
                      child: Center(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 200), style: TextStyle(color: _tab == i ? p.tabSel : p.subtitle, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none), child: Text(names[i]))),
                    ),
                  ),
              ]),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: TgCurves.easeOutQuint,
                left: tw * _tab + 14,
                width: tw - 28,
                bottom: 0,
                child: Container(height: 3, decoration: BoxDecoration(color: p.tabSel, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))),
              ),
              Positioned(left: 0, right: 0, bottom: 0, child: Container(height: .5, color: p.divider)),
            ]);
          }),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(key: ValueKey('$_tab${rows.length}'), child: body),
        ),
      ]),
    );
  }
}
