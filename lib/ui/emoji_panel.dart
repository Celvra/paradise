import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../data/human/sticker_lib.dart';
import 'human_data_pages.dart' show stickerView, addStickerFlow;

import '../core/anim.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/store.dart';
import '../l10n/x.dart';

// text field helpers that respect the caret and multi codepoint emoji
void insertAtCursor(TextEditingController c, String s) {
  final v = c.value;
  final sel = v.selection;
  final start = sel.isValid ? sel.start : v.text.length;
  final end = sel.isValid ? sel.end : v.text.length;
  c.value = TextEditingValue(text: v.text.replaceRange(start, end, s), selection: TextSelection.collapsed(offset: start + s.length));
}

void backspaceAtCursor(TextEditingController c) {
  final v = c.value;
  if (!v.selection.isValid) {
    if (v.text.isEmpty) return;
    final t = v.text.characters.skipLast(1).toString();
    c.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
    return;
  }
  if (!v.selection.isCollapsed) {
    c.value = TextEditingValue(text: v.text.replaceRange(v.selection.start, v.selection.end, ''), selection: TextSelection.collapsed(offset: v.selection.start));
    return;
  }
  if (v.selection.start == 0) return;
  final before = v.text.substring(0, v.selection.start).characters.skipLast(1).toString();
  c.value = TextEditingValue(text: before + v.text.substring(v.selection.start), selection: TextSelection.collapsed(offset: before.length));
}

// One category of the emoji tab. The strip names it with [icon]; [title] is
// only there so search can still find a family by its name.
class _Cat {
  const _Cat(this.icon, this.title, this.items);
  final Ic icon;
  final String title;
  final List<String> items;
}

List<String> _sp(String s) => s.split(' ');

// the panel strip, in the order telegram lays the categories out: recent first,
// then the families. The title is only used for search, the strip shows [icon].
final _emojiCats = <_Cat>[
  _Cat(Ic.emoji, 'Smileys & People', _sp('😀 😃 😄 😁 😆 😅 😂 🤣 🥲 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🥸 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🫡 🤭 🫢 🤫 🫠 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪 😵 🤐 🥴 🤢 🤮 🤧 😷 🤒 🤕 🤑 🤠 😈 👿 👹 👺 🤡 💩 👻 💀 👽 👾 🤖 🎃')),
  _Cat(Ic.cat, 'Animals & Nature', _sp('🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🙈 🙉 🙊 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🦇 🐺 🐗 🐴 🦄 🐝 🐛 🦋 🐌 🐞 🐜 🐢 🐍 🦎 🐙 🦑 🦀 🐠 🐟 🐬 🐳 🦈 🐊 🐘 🦒 🦓 🐪 🌵 🌲 🌳 🌴 🌱 🍀 🍁 🍂 🌺 🌸 🌼 🌻 🌞 🌝 🌙 ⭐ 🌈 ☁️ ❄️ 🔥 💧 🌊')),
  _Cat(Ic.pizza, 'Food & Drink', _sp('🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🥑 🥦 🥕 🌽 🥔 🍞 🥐 🥨 🧀 🥚 🍳 🥞 🥓 🍗 🍔 🍟 🍕 🌭 🌮 🌯 🥗 🍝 🍜 🍲 🍣 🍤 🍙 🍚 🍦 🍩 🍪 🎂 🍰 🍫 🍬 🍿 ☕ 🍵 🥤 🍺 🍻 🥂 🍷 🍸')),
  _Cat(Ic.ball, 'Activities', _sp('⚽ 🏀 🏈 ⚾ 🎾 🏐 🏉 🎱 🏓 🏸 🥊 🥋 ⛳ 🏹 🎣 🛹 ⛸️ 🎿 🏂 🏆 🥇 🥈 🥉 🎮 🎲 🧩 🎯 🎳 🎨 🎭 🎬 🎤 🎧 🎸 🎹 🥁 🎷 🎺 🎻')),
  _Cat(Ic.car, 'Travel & Places', _sp('🚗 🚕 🚙 🚌 🚓 🚑 🚒 🚚 🚜 🚲 ✈️ 🚀 🛸 🚁 ⛵ 🚢 🚂 🚇 🏠 🏢 🏰 🗼 🗽 ⛪ 🌋 🗺️ ⛺ 🌃 🌆 🌉')),
  _Cat(Ic.bulb, 'Objects', _sp('⌚ 📱 💻 ⌨️ 🖥️ 💾 📷 📹 🎥 📞 📺 📻 ⏰ 🔋 🔌 💡 🔦 💰 💳 💎 🔧 🔨 ⚙️ 🧲 🔮 💊 🧬 🔬 🔭 📚 📖 ✏️ 📝 📌 📎 ✂️ 🔒 🔑')),
  _Cat(Ic.heart, 'Symbols', _sp('❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 💕 💞 💓 💗 💖 💘 💝 ✨ 🌟 💫 💥 💢 💦 💤 ✅ ❌ ❓ ❗ ⚠️ ♻️ ➕ ➖ ✖️ ➗ 💯 🔔 🔕 ▶️ ⏸️ ⏹️ 🔀 🔁 ⬆️ ⬇️ ⬅️ ➡️')),
  _Cat(Ic.flag, 'Flags', _sp('🏁 🚩 🎌 🏴 🏳️ 🇺🇳 🇨🇳 🇺🇸 🇯🇵 🇰🇷 🇬🇧 🇫🇷 🇩🇪 🇮🇹 🇪🇸 🇷🇺 🇧🇷 🇮🇳 🇨🇦 🇦🇺 🇲🇽 🇹🇷 🇺🇦')),
];

const _emojiKeys = <String, String>{
  'smile': '😀 😃 😄 🙂 😊',
  'happy': '😀 😊 🥳 😄',
  'laugh': '😂 🤣 😆',
  'love': '😍 🥰 😘 ❤️ 💕',
  'heart': '❤️ 🧡 💛 💚 💙 💜 💖',
  'cat': '🐱',
  'dog': '🐶',
  'fire': '🔥',
  'party': '🥳 🎉',
  'cry': '😭 😢',
  'sad': '😞 😔 😢 😭',
  'angry': '😠 😡 🤬',
  'cool': '😎',
  'think': '🤔',
  'sleep': '😴',
  'food': '🍕 🍔 🍟 🌮',
  'star': '⭐ 🌟 ✨',
  'thumb': '👍 👎',
  'ok': '👌 ✅',
  'pray': '🙏',
  'clap': '👏',
  'hand': '👋 🤚 ✋',
  'eye': '👀',
  'money': '💰 🤑',
  'car': '🚗 🚕',
  'plane': '✈️',
  'music': '🎧 🎸 🎹',
  'game': '🎮',
  'ball': '⚽ 🏀',
  'coffee': '☕',
  'beer': '🍺 🍻',
  'cake': '🎂 🍰',
  'rocket': '🚀',
  'ghost': '👻',
  'robot': '🤖',
  'skull': '💀',
  'sun': '🌞',
  'moon': '🌙 🌝',
  'flag': '🏁 🚩',
};

List<String> _searchEmoji(String q) {
  final s = q.trim().toLowerCase();
  if (s.isEmpty) return const [];
  final out = <String>[];
  for (final e in _emojiKeys.entries) {
    if (e.key.contains(s) || s.contains(e.key)) {
      for (final x in e.value.split(' ')) {
        if (!out.contains(x)) out.add(x);
      }
    }
  }
  for (final c in _emojiCats) {
    if (c.title.toLowerCase().contains(s)) {
      for (final x in c.items) {
        if (!out.contains(x)) out.add(x);
      }
    }
  }
  return out;
}

// EmojiView port: one continuous emoji grid, a sticker grid that holds the
// user's own library, and a telegram style bottom bar that carries the category
// strip, the two tabs and the backspace key.
class EmojiPanel extends StatefulWidget {
  const EmojiPanel({super.key, required this.ctl, this.onLibrary});
  final TextEditingController ctl;

  /// a sticker of the user library, picked in the sticker tab
  final void Function(UserSticker s)? onLibrary;

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<EmojiPanel> {
  int _tab = 0;
  bool _search = false;
  final TextEditingController _q = TextEditingController();
  final ScrollController _es = ScrollController();
  final ScrollController _strip = ScrollController();
  int _cat = 0;
  Timer? _rep;
  OverlayEntry? _pv;
  double _w = 360;

  /// favourites only, filters the library section of the sticker tab
  bool _favs = false;

  /// one of the user's own categories, null shows them all
  String? _libCat;

  @override
  void initState() {
    super.initState();
    _es.addListener(() => _track(_es, _emojiOffsets, _cat, (i) => _cat = i));
  }

  @override
  void dispose() {
    _rep?.cancel();
    _pv?.remove();
    _q.dispose();
    _es.dispose();
    _strip.dispose();
    super.dispose();
  }

  List<_Cat> get _cats {
    final r = context.store.recentEmoji;
    return [if (r.isNotEmpty) _Cat(Ic.clock, context.l.stickerRecent, r), ..._emojiCats];
  }

  /// Offset of every section in the emoji grid. There are no headers any more,
  /// the strip at the bottom is what names the section, so a section is exactly
  /// the height of its rows.
  List<double> get _emojiOffsets {
    final cell = _w / 8;
    var y = 0.0;
    final o = <double>[];
    for (final c in _cats) {
      o.add(y);
      y += (c.items.length / 8).ceil() * cell;
    }
    return o;
  }

  /// The user library: favourites first, then what was used last. The AI saving
  /// a sticker or the settings page changing one rebuilds this off the hub, so
  /// the panel never shows a stale list.
  List<UserSticker> get _mine {
    final h = Store.read(context).human;
    if (h == null) return const [];
    final l = h.stickers.search('', category: _libCat, favorites: _favs);
    return [...l]..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return (b.lastUsed == 0 ? 0 : b.lastUsed).compareTo(a.lastUsed == 0 ? 0 : a.lastUsed);
      });
  }

  void _track(ScrollController sc, List<double> offs, int cur, void Function(int) set) {
    if (!sc.hasClients || offs.isEmpty) return;
    var idx = 0;
    for (var i = 0; i < offs.length; i++) {
      if (sc.offset + 4 >= offs[i]) idx = i;
    }
    if (idx != cur) {
      setState(() => set(idx));
      if (!_strip.hasClients) return;
      // keep the active icon in the middle of the strip rather than at its
      // left edge, the way the telegram strip follows the grid
      final lane = _strip.position.viewportDimension;
      _strip.animateTo((6 + idx * 36 + 18 - lane / 2).clamp(0.0, _strip.position.maxScrollExtent), duration: const Duration(milliseconds: 200), curve: TgCurves.easeOut);
    }
  }

  void _jump(ScrollController sc, double y) {
    if (!sc.hasClients) return;
    sc.animateTo(y.clamp(0.0, sc.position.maxScrollExtent), duration: const Duration(milliseconds: 320), curve: TgCurves.easeOutQuint);
  }

  void _emoji(String e) {
    insertAtCursor(widget.ctl, e);
    context.store.pushEmoji(e);
    // the recent category grows with every pick, so the offsets and the strip
    // both have to be measured again
    if (mounted) setState(() {});
    HapticFeedback.selectionClick();
  }

  void _holdDelete() {
    backspaceAtCursor(widget.ctl);
    _rep?.cancel();
    _rep = Timer.periodic(const Duration(milliseconds: 90), (_) => backspaceAtCursor(widget.ctl));
  }

  void _preview(Widget child) {
    _pv?.remove();
    _pv = OverlayEntry(builder: (_) => _Preview(child: child));
    Overlay.of(context, rootOverlay: true).insert(_pv!);
    HapticFeedback.mediumImpact();
  }

  void _endPreview() {
    _pv?.remove();
    _pv = null;
  }

  void _sendLib(UserSticker s) {
    widget.onLibrary?.call(s);
    // the library reorders on use, and the sender marks it used before this runs
    if (mounted) setState(() {});
  }

  void _add() => addStickerFlow(context).then((_) => mounted ? setState(() {}) : null);

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final h = Store.read(context).human;
    return ColoredBox(
      color: p.bar,
      child: LayoutBuilder(builder: (context, box) {
        _w = box.maxWidth;
        Widget body = Stack(children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _search ? _results(p) : (_tab == 0 ? _emojiGrid(p) : _stickerGrid(p)),
            ),
          ),
          // the search field rides over the top of the grid, the grid gives way
          // for it with its own top padding
          if (_search)
            Positioned(left: 0, right: 0, top: 0, height: 40, child: ColoredBox(color: p.bar, child: _searchField(p))),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(duration: const Duration(milliseconds: 220), curve: TgCurves.easeOut, offset: Offset(0, _search ? 1.2 : 0), child: _bottom(p)),
          ),
        ]);
        // the sticker tab is driven by the library, which lives on the hub
        return h == null ? body : ListenableBuilder(listenable: h, builder: (_, __) => body);
      }),
    );
  }

  // ------------------------------------------------------------- bottom bar

  Widget _bottom(Pal p) {
    return Container(
      height: 48,
      decoration: BoxDecoration(color: p.bar, border: Border(top: BorderSide(color: p.divider, width: .5))),
      child: Row(children: [
        Tap(scale: .88, onTap: () => setState(() => _search = true), child: SizedBox(width: 46, height: 48, child: Center(child: TgIcon(Ic.search, color: p.glassIcon, size: 22)))),
        Expanded(child: _tab == 0 ? _emojiStrip(p) : _libStrip(p)),
        _tabIcon(p, 0, Ic.smile),
        _tabIcon(p, 1, Ic.sticker),
        if (_tab == 0)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => backspaceAtCursor(widget.ctl),
            onLongPressStart: (_) => _holdDelete(),
            onLongPressEnd: (_) => _rep?.cancel(),
            onLongPressCancel: () => _rep?.cancel(),
            child: SizedBox(width: 44, height: 48, child: Center(child: TgIcon(Ic.backspace, color: p.glassIcon, size: 24, stroke: 1.8))),
          ),
      ]),
    );
  }

  Widget _tabIcon(Pal p, int i, Ic ic) {
    final sel = _tab == i;
    return Tap(
      scale: .9,
      onTap: () {
        if (_tab == i) return;
        setState(() {
          _tab = i;
          _cat = 0;
          if (_strip.hasClients) _strip.jumpTo(0);
        });
      },
      // the size lives outside the animated box: the two strips share their
      // list slots, and a container that animates its own constraints would
      // try to interpolate a tight width against an unbounded one
      child: SizedBox(
        width: 36,
        height: 36,
        child: _pill(p, sel, .38, BorderRadius.circular(12), TgIcon(ic, color: sel ? p.accent : p.glassIcon, size: 23, stroke: 1.8)),
      ),
    );
  }

  /// a rounded highlight that fades in and out with [on]. The tint is a share of
  /// the accent, a full fill would shout next to the glyph it sits behind.
  Widget _pill(Pal p, bool on, double tint, BorderRadius radius, Widget child) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: TgCurves.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: on ? p.accent.withAlpha((255 * tint).round()) : const Color(0x00000000), borderRadius: radius),
        child: child,
      );

  Widget _emojiStrip(Pal p) {
    final cats = _cats;
    return ListView(
      controller: _strip,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      children: [
        for (var i = 0; i < cats.length; i++)
          Tap(scale: .9, onTap: () => _jump(_es, _emojiOffsets[i]), child: _stripIcon(p, cats[i].icon, i == _cat)),
      ],
    );
  }

  Widget _stripIcon(Pal p, Ic ic, bool on) => SizedBox(
        width: 36,
        height: 36,
        child: _pill(p, on, .38, BorderRadius.circular(12), TgIcon(ic, color: on ? p.accent : p.glassIcon, size: 22, stroke: 1.9)),
      );

  /// the sticker tab has no packs, its strip is the library's own filters: add,
  /// everything, favourites, then one pill per category the user made
  Widget _libStrip(Pal p) {
    final l = context.l;
    final cats = Store.read(context).human?.stickers.categories ?? const <String>[];
    return ListView(
      controller: _strip,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      children: [
        Tap(scale: .9, onTap: _add, child: _stripIcon(p, Ic.plus, false)),
        const SizedBox(width: 4),
        _stripChip(p, l.searchFilterAll, _libCat == null && !_favs, () => setState(() {
              _favs = false;
              _libCat = null;
            })),
        _stripChip(p, '★ ${l.stickerFavorites}', _favs, () => setState(() => _favs = !_favs)),
        for (final c in cats) _stripChip(p, c, _libCat == c, () => setState(() => _libCat = _libCat == c ? null : c)),
      ],
    );
  }

  Widget _stripChip(Pal p, String label, bool on, VoidCallback tap) => Tap(
        scale: .94,
        onTap: tap,
        child: SizedBox(
          height: 36,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: TgCurves.easeOut,
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? p.accent : p.gray, borderRadius: BorderRadius.circular(12)),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: on ? (p.dark ? const Color(0xFF0F1A24) : const Color(0xFFFFFFFF)) : p.subtitle, fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
          ),
        ),
      );

  // ---------------------------------------------------------------- search

  Widget _searchField(Pal p) {
    return Row(children: [
      Tap(
        scale: .88,
        onTap: () => setState(() {
          _search = false;
          _q.clear();
        }),
        child: SizedBox(width: 44, height: 40, child: Center(child: TgIcon(Ic.back, color: p.glassIcon, size: 22))),
      ),
      Expanded(
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: p.gray, borderRadius: BorderRadius.circular(16)),
          child: TgEdit(controller: _q, hint: context.l.searchGeneric, autofocus: true, onChanged: (_) => setState(() {}), style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400), hintStyle: TextStyle(color: p.hint, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
        ),
      ),
      const SizedBox(width: 10),
    ]);
  }

  // ------------------------------------------------------------ emoji grid

  Widget _emojiGrid(Pal p) {
    final cats = _cats;
    return CustomScrollView(
      key: const ValueKey('eg'),
      controller: _es,
      physics: const ClampingScrollPhysics(),
      slivers: [
        for (final c in cats)
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _Cell(onTap: () => _emoji(c.items[i]), onLongPress: () => _preview(Text(c.items[i], style: const TextStyle(fontSize: 128, decoration: TextDecoration.none))), onHoldEnd: _endPreview, child: Center(child: Text(c.items[i], style: const TextStyle(fontSize: 27, decoration: TextDecoration.none)))),
              childCount: c.items.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 52)),
      ],
    );
  }

  // ---------------------------------------------------------- sticker grid

  Widget _libCell(UserSticker s) => _Cell(
        onTap: () => _sendLib(s),
        onLongPress: () => _preview(SizedBox(width: 190, height: 190, child: stickerView(s, 190))),
        onHoldEnd: _endPreview,
        child: Center(child: stickerView(s, _w / 5 - 10)),
      );

  Widget _stickerGrid(Pal p) {
    final mine = _mine;
    return CustomScrollView(
      key: const ValueKey('sg'),
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _setHeader(p, mine.length)),
        if (mine.isEmpty)
          SliverToBoxAdapter(child: _emptyLibrary(p))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
              delegate: SliverChildBuilderDelegate((_, i) => _libCell(mine[i]), childCount: mine.length),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 52)),
      ],
    );
  }

  /// the sticker set header of the tab, the way telegram names a set: a rounded
  /// tile, the name, and how much is in it
  Widget _setHeader(Pal p, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: p.gray, borderRadius: BorderRadius.circular(12)),
          child: Center(child: TgIcon(Ic.sticker, color: p.glassIcon, size: 22, stroke: 1.7)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(L10n.current.stickerMyStickers, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 15, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
            Text('$count', style: TextStyle(color: p.subtitle, fontSize: 12, height: 1.3, decoration: TextDecoration.none)),
          ]),
        ),
      ]),
    );
  }

  Widget _emptyLibrary(Pal p) {
    final l = context.l;
    final ink = p.dark ? const Color(0xFF0F1A24) : const Color(0xFFFFFFFF);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 28),
      child: Column(children: [
        Container(width: 66, height: 66, decoration: BoxDecoration(color: p.gray, borderRadius: BorderRadius.circular(20)), child: Center(child: TgIcon(Ic.sticker, color: p.glassIcon, size: 30, stroke: 1.7))),
        const SizedBox(height: 14),
        Text(l.stickerEmptyPanel, textAlign: TextAlign.center, style: TextStyle(color: p.subtitle, fontSize: 14, height: 1.35, decoration: TextDecoration.none)),
        const SizedBox(height: 16),
        Tap(
          scale: .96,
          onTap: _add,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(20)),
            child: Text(l.actionAdd, style: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
          ),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------- search

  Widget _results(Pal p) {
    if (_tab == 0) {
      final list = _searchEmoji(_q.text);
      if (_q.text.trim().isEmpty || list.isEmpty) {
        return _noResult(p);
      }
      return GridView.builder(
        key: const ValueKey('rs'),
        padding: const EdgeInsets.fromLTRB(0, 42, 0, 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final e = list[i];
          return _Cell(onTap: () => _emoji(e), onLongPress: () => _preview(Text(e, style: const TextStyle(fontSize: 128, decoration: TextDecoration.none))), onHoldEnd: _endPreview, child: Center(child: Text(e, style: const TextStyle(fontSize: 27, decoration: TextDecoration.none))));
        },
      );
    }
    // the library matches on name, emotion, tag and category
    final q = _q.text;
    final mine = _mine.where((s) => s.matches(q)).toList();
    if (q.trim().isEmpty || mine.isEmpty) {
      return _noResult(p);
    }
    return CustomScrollView(
      key: const ValueKey('rs'),
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 42, 4, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
            delegate: SliverChildBuilderDelegate((_, i) => _libCell(mine[i]), childCount: mine.length),
          ),
        ),
      ],
    );
  }

  Widget _noResult(Pal p) => Center(child: Text(context.l.emojiNothingFound, style: TextStyle(color: p.subtitle, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)));
}

/// One panel cell. A tap acts, a hold opens the preview and releasing closes
/// it, and the press paints a rounded highlight the way the telegram grid does
/// instead of scaling the glyph down.
class _Cell extends StatefulWidget {
  const _Cell({required this.child, this.onTap, this.onLongPress, this.onHoldEnd});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// the finger came off after a hold, the preview closes here
  final VoidCallback? onHoldEnd;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _down = false;

  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPressDown: (_) => _set(true),
      onLongPress: widget.onLongPress,
      onLongPressEnd: (_) {
        _set(false);
        widget.onHoldEnd?.call();
      },
      onLongPressCancel: () {
        _set(false);
        widget.onHoldEnd?.call();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: _down ? 0 : 200),
        curve: TgCurves.easeOut,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: _down ? p.selector : const Color(0x00000000), borderRadius: BorderRadius.circular(12)),
        child: widget.child,
      ),
    );
  }
}

// ContentPreviewViewer style peek while the finger is held on a sticker
class _Preview extends StatelessWidget {
  const _Preview({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: TgCurves.easeOutBack,
        builder: (_, t, __) => Stack(children: [
          Positioned.fill(child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8 * t.clamp(0.0, 1.0), sigmaY: 8 * t.clamp(0.0, 1.0)), child: ColoredBox(color: Color.fromRGBO(0, 0, 0, .35 * t.clamp(0.0, 1.0))))),
          Center(child: Transform.scale(scale: .4 + .6 * t, child: child)),
        ]),
      ),
    );
  }
}
