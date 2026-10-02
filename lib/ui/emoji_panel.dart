import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../data/human/sticker_lib.dart';
import 'human_data_pages.dart' show stickerView, addStickerFlow;

import '../core/anim.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/stickers.dart';
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
  final sel = v.selection;
  if (!sel.isValid) {
    if (v.text.isEmpty) return;
    final t = v.text.characters.skipLast(1).toString();
    c.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
    return;
  }
  if (!sel.isCollapsed) {
    c.value = TextEditingValue(text: v.text.replaceRange(sel.start, sel.end, ''), selection: TextSelection.collapsed(offset: sel.start));
    return;
  }
  if (sel.start == 0) return;
  final before = v.text.substring(0, sel.start).characters.skipLast(1).toString();
  c.value = TextEditingValue(text: before + v.text.substring(sel.start), selection: TextSelection.collapsed(offset: before.length));
}

class _Cat {
  const _Cat(this.icon, this.title, this.items);
  final String icon;
  final String title;
  final List<String> items;
}

List<String> _sp(String s) => s.split(' ');

final _emojiCats = <_Cat>[
  _Cat('😀', 'Smileys & People', _sp('😀 😃 😄 😁 😆 😅 😂 🤣 🥲 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🥸 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🫡 🤭 🫢 🤫 🫠 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪 😵 🤐 🥴 🤢 🤮 🤧 😷 🤒 🤕 🤑 🤠 😈 👿 👹 👺 🤡 💩 👻 💀 👽 👾 🤖 🎃')),
  _Cat('👋', 'Gestures', _sp('👋 🤚 ✋ 🖖 👌 🤌 🤏 ✌️ 🤞 🫰 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ 👍 👎 ✊ 👊 🤛 🤜 👏 🙌 🫶 👐 🤲 🤝 🙏 ✍️ 💅 🤳 💪 🦾 🧠 👀 👅 👄')),
  _Cat('🐱', 'Animals & Nature', _sp('🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🙈 🙉 🙊 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🦇 🐺 🐗 🐴 🦄 🐝 🐛 🦋 🐌 🐞 🐜 🐢 🐍 🦎 🐙 🦑 🦀 🐠 🐟 🐬 🐳 🦈 🐊 🐘 🦒 🦓 🐪 🌵 🌲 🌳 🌴 🌱 🍀 🍁 🍂 🌺 🌸 🌼 🌻 🌞 🌝 🌙 ⭐ 🌈 ☁️ ❄️ 🔥 💧 🌊')),
  _Cat('🍕', 'Food & Drink', _sp('🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🥑 🥦 🥕 🌽 🥔 🍞 🥐 🥨 🧀 🥚 🍳 🥞 🥓 🍗 🍔 🍟 🍕 🌭 🌮 🌯 🥗 🍝 🍜 🍲 🍣 🍤 🍙 🍚 🍦 🍩 🍪 🎂 🍰 🍫 🍬 🍿 ☕ 🍵 🥤 🍺 🍻 🥂 🍷 🍸')),
  _Cat('⚽', 'Activities', _sp('⚽ 🏀 🏈 ⚾ 🎾 🏐 🏉 🎱 🏓 🏸 🥊 🥋 ⛳ 🏹 🎣 🛹 ⛸️ 🎿 🏂 🏆 🥇 🥈 🥉 🎮 🎲 🧩 🎯 🎳 🎨 🎭 🎬 🎤 🎧 🎸 🎹 🥁 🎷 🎺 🎻')),
  _Cat('🚗', 'Travel & Places', _sp('🚗 🚕 🚙 🚌 🚓 🚑 🚒 🚚 🚜 🚲 ✈️ 🚀 🛸 🚁 ⛵ 🚢 🚂 🚇 🏠 🏢 🏰 🗼 🗽 ⛪ 🌋 🗺️ ⛺ 🌃 🌆 🌉')),
  _Cat('💡', 'Objects', _sp('⌚ 📱 💻 ⌨️ 🖥️ 💾 📷 📹 🎥 📞 📺 📻 ⏰ 🔋 🔌 💡 🔦 💰 💳 💎 🔧 🔨 ⚙️ 🧲 🔮 💊 🧬 🔬 🔭 📚 📖 ✏️ 📝 📌 📎 ✂️ 🔒 🔑')),
  _Cat('❤️', 'Symbols', _sp('❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 💕 💞 💓 💗 💖 💘 💝 ✨ 🌟 💫 💥 💢 💦 💤 ✅ ❌ ❓ ❗ ⚠️ ♻️ ➕ ➖ ✖️ ➗ 💯 🔔 🔕 ▶️ ⏸️ ⏹️ 🔀 🔁 ⬆️ ⬇️ ⬅️ ➡️')),
  _Cat('🏁', 'Flags', _sp('🏁 🚩 🎌 🏴 🏳️ 🇺🇳 🇨🇳 🇺🇸 🇯🇵 🇰🇷 🇬🇧 🇫🇷 🇩🇪 🇮🇹 🇪🇸 🇷🇺 🇧🇷 🇮🇳 🇨🇦 🇦🇺 🇲🇽 🇹🇷 🇺🇦')),
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

// EmojiView port: an 8 column emoji grid, a 5 column sticker grid that opens
// with the user's own library (emoji, images and GIFs) and a bottom tab row
class EmojiPanel extends StatefulWidget {
  const EmojiPanel({super.key, required this.ctl, required this.onSticker, this.onLibrary});
  final TextEditingController ctl;
  final void Function(String emoji) onSticker;

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
  final ScrollController _ss = ScrollController();
  final ScrollController _strip = ScrollController();
  int _cat = 0;
  int _pack = 0;
  Timer? _rep;
  OverlayEntry? _pv;
  double _w = 360;

  /// favourites only, filters the library section of the sticker tab
  var _favs = false;

  @override
  void initState() {
    super.initState();
    _es.addListener(() => _track(_es, _emojiOffsets, _cat, (i) => _cat = i));
    _ss.addListener(() => _track(_ss, _stickerOffsets, _pack, (i) => _pack = i));
  }

  @override
  void dispose() {
    _rep?.cancel();
    _pv?.remove();
    _q.dispose();
    _es.dispose();
    _ss.dispose();
    _strip.dispose();
    super.dispose();
  }

  List<_Cat> get _cats {
    final r = context.store.recentEmoji;
    return [if (r.isNotEmpty) _Cat('🕘', 'Recent', r), ..._emojiCats];
  }

  List<double> get _emojiOffsets {
    final cell = (_w - 10) / 8;
    var y = 0.0;
    final o = <double>[];
    for (final c in _cats) {
      o.add(y);
      y += 32 + (c.items.length / 8).ceil() * cell;
    }
    return o;
  }

  List<StickerPack> get _packs {
    final r = context.store.recentStickers;
    return [if (r.isNotEmpty) StickerPack('Recent', '🕘', [for (final e in r) Sticker(e, '')]), ...stickerPacks];
  }

  /// The user library, the built in GIF tab lives here now.
  List<UserSticker> get _mine {
    final h = Store.read(context).human;
    if (h == null) return const [];
    final l = h.stickers.search('', favorites: _favs);
    return [...l]..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return (b.lastUsed == 0 ? 0 : b.lastUsed).compareTo(a.lastUsed == 0 ? 0 : a.lastUsed);
      });
  }

  /// height of the library header, it carries the filter chips
  static const _mineHeadH = 64.0;

  /// height of the one line hint shown while the library is empty, kept fixed so
  /// the strip can still jump to the right section
  static const _mineEmptyH = 34.0;

  List<double> get _stickerOffsets {
    final cell = _w / 5;
    final mine = _mine;
    var y = 0.0;
    final o = <double>[];
    o.add(y);
    y += _mineHeadH + (mine.isEmpty ? _mineEmptyH : (mine.length / 5).ceil() * cell);
    for (final c in _packs) {
      o.add(y);
      y += 32 + (c.items.length / 5).ceil() * cell;
    }
    return o;
  }

  void _track(ScrollController sc, List<double> offs, int cur, void Function(int) set) {
    if (!sc.hasClients || offs.isEmpty) return;
    var idx = 0;
    for (var i = 0; i < offs.length; i++) {
      if (sc.offset + 4 >= offs[i]) idx = i;
    }
    if (idx != cur) {
      setState(() => set(idx));
      if (_strip.hasClients) _strip.animateTo((idx * 40.0 - 120).clamp(0.0, _strip.position.maxScrollExtent), duration: const Duration(milliseconds: 200), curve: TgCurves.easeOut);
    }
  }

  void _jump(ScrollController sc, double y) {
    if (sc.hasClients) sc.animateTo(y.clamp(0.0, sc.position.maxScrollExtent), duration: const Duration(milliseconds: 320), curve: TgCurves.easeOutQuint);
  }

  void _emoji(String e) {
    insertAtCursor(widget.ctl, e);
    context.store.pushEmoji(e);
    HapticFeedback.selectionClick();
  }

  void _sticker(String e) {
    context.store.pushSticker(e);
    widget.onSticker(e);
  }

  void _holdDelete() {
    backspaceAtCursor(widget.ctl);
    _rep?.cancel();
    _rep = Timer.periodic(const Duration(milliseconds: 90), (_) => backspaceAtCursor(widget.ctl));
  }

  void _preview(String e) {
    _pv?.remove();
    _pv = OverlayEntry(builder: (_) => _Preview(emoji: e));
    Overlay.of(context, rootOverlay: true).insert(_pv!);
    HapticFeedback.mediumImpact();
  }

  void _endPreview() {
    _pv?.remove();
    _pv = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return ColoredBox(
      color: p.bar,
      child: LayoutBuilder(builder: (context, box) {
        _w = box.maxWidth;
        return Stack(children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _search ? _results(p) : (_tab == 0 ? _emojiGrid(p) : _stickerGrid(p)),
            ),
          ),
          Positioned(left: 0, right: 0, top: 0, height: 40, child: ColoredBox(color: p.bar, child: _search ? _searchField(p) : _strip_(p))),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(duration: const Duration(milliseconds: 220), curve: TgCurves.easeOut, offset: Offset(0, _search ? 1.2 : 0), child: _bottom(p)),
          ),
        ]);
      }),
    );
  }

  Widget _strip_(Pal p) {
    // the sticker tab leads with the user's own library, that is where the
    // GIFs and the memes live now
    final icons = _tab == 0 ? [for (final c in _cats) c.icon] : ['🗂', for (final c in _packs) c.icon];
    final cur = _tab == 0 ? _cat : _pack + 1;
    return ListView(
      controller: _strip,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      children: [
        for (var i = 0; i < icons.length; i++)
          Tap(
            scale: .88,
            onTap: () => _jump(_tab == 0 ? _es : _ss, (_tab == 0 ? _emojiOffsets : _stickerOffsets)[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: TgCurves.easeOut,
              width: 38,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: i == cur ? p.accent.withAlpha(34) : const Color(0x00000000), borderRadius: BorderRadius.circular(17)),
              child: AnimatedScale(duration: const Duration(milliseconds: 220), curve: TgCurves.easeOutBack, scale: i == cur ? 1.12 : .95, child: Text(icons[i], style: const TextStyle(fontSize: 20, decoration: TextDecoration.none))),
            ),
          ),
      ],
    );
  }

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
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: p.gray, borderRadius: BorderRadius.circular(15)),
          child: TgEdit(controller: _q, hint: L10n.current.searchGeneric, autofocus: true, onChanged: (_) => setState(() {}), style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400), hintStyle: TextStyle(color: p.hint, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
        ),
      ),
      const SizedBox(width: 10),
    ]);
  }

  Widget _header(Pal p, String t) => Container(height: 32, padding: const EdgeInsets.only(left: 12), alignment: Alignment.centerLeft, child: Text(t.toUpperCase(), style: TextStyle(color: p.subtitle, fontSize: 12, fontWeight: FontWeight.w500, decoration: TextDecoration.none)));

  Widget _emojiGrid(Pal p) {
    final cats = _cats;
    return CustomScrollView(
      key: const ValueKey('eg'),
      controller: _es,
      physics: const ClampingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
        for (final c in cats) ...[
          SliverToBoxAdapter(child: _header(p, c.title)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
              delegate: SliverChildBuilderDelegate(
                (_, i) => Tap(scale: .8, onTap: () => _emoji(c.items[i]), child: Center(child: Text(c.items[i], style: const TextStyle(fontSize: 26, decoration: TextDecoration.none)))),
                childCount: c.items.length,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 52)),
      ],
    );
  }

  Widget _stickerCell(Sticker s) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _sticker(s.emoji),
        onLongPressStart: (_) => _preview(s.emoji),
        onLongPressEnd: (_) => _endPreview(),
        onLongPressCancel: _endPreview,
        child: Center(child: Text(s.emoji, style: const TextStyle(fontSize: 46, decoration: TextDecoration.none))),
      );

  // the sender marks it used, doing it here as well would count it twice
  Widget _libCell(UserSticker s) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onLibrary?.call(s),
        child: Center(child: stickerView(s, _w / 5 - 12)),
      );

  // the library is the first section of the sticker tab, it holds the emoji,
  // the images and the GIFs the user or the assistant saved
  Widget _mineHead(Pal p) {
    Widget chip(String label, bool on, VoidCallback t) => Tap(
          scale: .94,
          onTap: t,
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? p.accent.withAlpha(34) : const Color(0x00000000), borderRadius: BorderRadius.circular(16)),
            child: Text(label, style: TextStyle(color: on ? p.accent : p.subtitle, fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
          ),
        );
    return SizedBox(
      height: _mineHeadH,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: Center(child: Text(L10n.current.stickerMyStickers.toUpperCase(), style: TextStyle(color: p.subtitle, fontSize: 12, fontWeight: FontWeight.w500, decoration: TextDecoration.none)))),
        SizedBox(
          height: 30,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            chip(L10n.current.searchFilterAll, !_favs, () => setState(() => _favs = false)),
            chip('★ ${L10n.current.stickerFavorites}', _favs, () => setState(() => _favs = true)),
            chip('+ ${L10n.current.actionAdd}', false, () => addStickerFlow(context).then((_) => mounted ? setState(() {}) : null)),
          ]),
        ),
      ]),
    );
  }

  Widget _stickerGrid(Pal p) {
    final packs = _packs;
    final mine = _mine;
    return CustomScrollView(
      key: const ValueKey('sg'),
      controller: _ss,
      physics: const ClampingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
        SliverToBoxAdapter(child: _mineHead(p)),
        if (mine.isEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: _mineEmptyH,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                child: Text(L10n.current.stickerEmptyPanel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.hint, fontSize: 13, height: 1.2, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
              ),
            ),
          )
        else
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
            delegate: SliverChildBuilderDelegate((_, i) => _libCell(mine[i]), childCount: mine.length),
          ),
        for (final c in packs) ...[
          SliverToBoxAdapter(child: _header(p, c.title)),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
            delegate: SliverChildBuilderDelegate((_, i) => _stickerCell(c.items[i]), childCount: c.items.length),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 52)),
      ],
    );
  }

  Widget _results(Pal p) {
    if (_tab == 0) {
      final list = _searchEmoji(_q.text);
      if (_q.text.trim().isEmpty || list.isEmpty) {
        return Center(child: Text(_q.text.trim().isEmpty ? context.l.emojiSearchHint : context.l.emojiNothingFound, style: TextStyle(color: p.subtitle, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)));
      }
      return GridView.builder(
        key: const ValueKey('rs'),
        padding: const EdgeInsets.fromLTRB(5, 44, 5, 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final e = list[i];
          return Tap(scale: .8, onTap: () => _emoji(e), child: Center(child: Text(e, style: const TextStyle(fontSize: 26, decoration: TextDecoration.none))));
        },
      );
    }
    // the sticker tab looks in the packs and in the library at once
    final q = _q.text;
    final packed = searchStickers(q);
    final mine = Store.read(context).human?.stickers.search(q) ?? const <UserSticker>[];
    if (q.trim().isEmpty || (packed.isEmpty && mine.isEmpty)) {
      return Center(child: Text(q.trim().isEmpty ? context.l.emojiSearchHint : context.l.emojiNothingFound, style: TextStyle(color: p.subtitle, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)));
    }
    return CustomScrollView(
      key: const ValueKey('rs'),
      physics: const ClampingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
        if (mine.isNotEmpty) ...[
          SliverToBoxAdapter(child: _header(p, L10n.current.stickerMyStickers)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
              delegate: SliverChildBuilderDelegate((_, i) => _libCell(mine[i]), childCount: mine.length),
            ),
          ),
        ],
        if (packed.isNotEmpty) ...[
          SliverToBoxAdapter(child: _header(p, L10n.current.stickerTabAll)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
              delegate: SliverChildBuilderDelegate((_, i) => _stickerCell(packed[i]), childCount: packed.length),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    );
  }

  Widget _bottom(Pal p) {
    Widget tab(int i, Ic ic) {
      final sel = _tab == i;
      return Tap(
        scale: .9,
        onTap: () => setState(() => _tab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: TgCurves.easeOut,
          width: 56,
          height: 34,
          decoration: BoxDecoration(color: sel ? p.accent.withAlpha(34) : const Color(0x00000000), borderRadius: BorderRadius.circular(17)),
          child: Center(child: TgIcon(ic, color: sel ? p.accent : p.glassIcon, size: 24, stroke: 1.8)),
        ),
      );
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(color: p.bar, border: Border(top: BorderSide(color: p.divider, width: .5))),
      child: Row(children: [
        Tap(scale: .88, onTap: () => setState(() => _search = true), child: SizedBox(width: 56, height: 48, child: Center(child: TgIcon(Ic.search, color: p.glassIcon, size: 22)))),
        Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [tab(0, Ic.smile), const SizedBox(width: 8), tab(1, Ic.sticker)])),
        SizedBox(
          width: 56,
          height: 48,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _tab == 0 ? 1 : 0,
            child: IgnorePointer(
              ignoring: _tab != 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => backspaceAtCursor(widget.ctl),
                onLongPressStart: (_) => _holdDelete(),
                onLongPressEnd: (_) => _rep?.cancel(),
                onLongPressCancel: () => _rep?.cancel(),
                child: Center(child: TgIcon(Ic.backspace, color: p.glassIcon, size: 24, stroke: 1.8)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ContentPreviewViewer style peek while the finger is held on a sticker
class _Preview extends StatelessWidget {
  const _Preview({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: TgCurves.easeOutBack,
        builder: (_, t, __) => Stack(children: [
          Positioned.fill(child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8 * t.clamp(0.0, 1.0), sigmaY: 8 * t.clamp(0.0, 1.0)), child: ColoredBox(color: Color.fromRGBO(0, 0, 0, .35 * t.clamp(0.0, 1.0))))),
          Center(child: Transform.scale(scale: .4 + .6 * t, child: Text(emoji, style: const TextStyle(fontSize: 168, decoration: TextDecoration.none)))),
        ]),
      ),
    );
  }
}
