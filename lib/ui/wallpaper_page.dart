import 'dart:io';

import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../data/wallpaper.dart';
import '../l10n/x.dart';

// Chat wallpaper: one picture for everything, with any single conversation
// allowed to take over or to opt out. The picker and the colours pulled off the
// picture live together here so the settings page and the chat header menu
// cannot drift apart.

/// The tail of a stored wallpaper path, with the microsecond prefix the copy
/// step adds stripped off. Shared so the settings row and the picker sheet name
/// the same picture the same way.
String wallpaperFileName(String path) {
  final base = path.split('/').last;
  final cut = base.indexOf('_');
  return cut > 0 && cut < base.length - 1 ? base.substring(cut + 1) : base;
}

/// Opens the picker. Pass [chat] for the per conversation sheet, leave it null
/// for the global one.
Future<void> openWallpaperSheet(BuildContext context, {Chat? chat}) => showTgSheet<void>(
      context,
      (_) => _WallpaperSheet(chat: chat),
    );

class _WallpaperSheet extends StatefulWidget {
  const _WallpaperSheet({this.chat});
  final Chat? chat;

  @override
  State<_WallpaperSheet> createState() => _WallpaperSheetState();
}

class _WallpaperSheetState extends State<_WallpaperSheet> {
  var _busy = false;

  Store get _store => Store.read(context);

  /// What this sheet is currently showing, with the follow-global state already
  /// resolved, so the tick lands on the row that matches the screen.
  String get _effective => widget.chat?.wallpaperPath ?? _store.wallpaperPath;

  Future<void> _choose() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await pickWallpaper();
      if (picked == null || !mounted) return;
      final chat = widget.chat;
      final previous = chat == null ? _store.wallpaperPath : chat.wallpaperPath;
      if (chat == null) {
        _store.setWallpaper(picked);
      } else {
        _store.setChatWallpaper(chat, picked);
      }
      // only once the new path is stored, so the file being dropped is certain
      // to be unreferenced
      if (previous != null && previous.isNotEmpty) await dropWallpaperFile(previous);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear({required bool followGlobal}) async {
    final chat = widget.chat;
    final previous = chat == null ? _store.wallpaperPath : chat.wallpaperPath;
    if (chat == null) {
      if (_store.wallpaperPath.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      _store.setWallpaper('');
    } else {
      _store.setChatWallpaper(chat, followGlobal ? null : '');
    }
    if (previous != null) await dropWallpaperFile(previous);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final chat = widget.chat;
    final current = _effective;
    return TgSheet(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Text(chat == null ? l.wallpaperRow : l.wallpaperChatTitle, style: TextStyle(color: p.title, fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
        ),
        _row(
          p,
          l.wallpaperDefault,
          subtitle: l.wallpaperNone,
          selected: current.isEmpty,
          onTap: () => _clear(followGlobal: false),
        ),
        if (chat != null)
          _row(
            p,
            l.wallpaperFollowGlobal,
            subtitle: _store.wallpaperPath.isEmpty ? l.wallpaperNone : _nameOf(_store.wallpaperPath),
            selected: chat.wallpaperPath == null,
            onTap: () => _clear(followGlobal: true),
          ),
        _row(
          p,
          _busy ? l.attachLoading : l.wallpaperChoose,
          subtitle: current.isEmpty ? null : _nameOf(current),
          selected: false,
          onTap: _busy ? null : _choose,
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  static String _nameOf(String path) => wallpaperFileName(path);

  Widget _row(Pal p, String title, {String? subtitle, required bool selected, VoidCallback? onTap}) => Tap(
        scale: .99,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: selected ? p.accent.withAlpha(28) : p.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? p.accent : const Color(0x00000000), width: .6)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none)),
                if (subtitle != null) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none)),
              ]),
            ),
            if (selected) TgIcon(Ic.check, color: p.accent, size: 20, stroke: 2.2),
          ]),
        ),
      );
}

/// The colours lifted off the current wallpaper, offered as a row of swatches.
///
/// Extraction runs once per path and is kept in a map keyed by that path, so
/// opening the settings page again does not decode the picture a second time.
/// It is deliberately not cached across a wallpaper change: a stale row of
/// swatches belonging to the previous picture would be worse than a redraw.
class WallpaperSwatches extends StatefulWidget {
  const WallpaperSwatches({super.key, required this.path});
  final String path;

  static final Map<String, List<Color>> _cache = {};

  @override
  State<WallpaperSwatches> createState() => _WallpaperSwatchesState();
}

class _WallpaperSwatchesState extends State<WallpaperSwatches> {
  List<Color>? _colors;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WallpaperSwatches old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _colors = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    if (path.isEmpty || !File(path).existsSync()) {
      if (mounted) setState(() => _colors = const []);
      return;
    }
    final hit = WallpaperSwatches._cache[path];
    if (hit != null) {
      if (mounted) setState(() => _colors = hit);
      return;
    }
    final colors = await wallpaperSwatches(path);
    WallpaperSwatches._cache[path] = colors;
    if (mounted && widget.path == path) setState(() => _colors = colors);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final st = context.store;
    final colors = _colors;
    if (colors == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Text(l.attachLoading, style: TextStyle(color: p.subtitle, fontSize: 14, decoration: TextDecoration.none)),
      );
    }
    if (colors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Text(l.wallpaperNoColors, style: TextStyle(color: p.subtitle, fontSize: 14, decoration: TextDecoration.none)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(spacing: 12, runSpacing: 12, children: [
        _swatch(p, null, selected: st.wallpaperColor == null),
        for (final c in colors) _swatch(p, c, selected: st.wallpaperColor == c.toARGB32()),
      ]),
    );
  }

  Widget _swatch(Pal p, Color? c, {required bool selected}) => Tap(
        scale: .9,
        onTap: () => context.store.setWallpaperColor(c?.toARGB32()),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c ?? p.gray,
            border: Border.all(color: selected ? p.accent : const Color(0x00000000), width: 2.5),
          ),
          // the "no colour" swatch is the stock accent rather than a blank, so
          // the row always shows what picking it would do
          child: c == null ? Center(child: TgIcon(Ic.close, color: p.subtitle, size: 18, stroke: 2)) : null,
        ),
      );
}
