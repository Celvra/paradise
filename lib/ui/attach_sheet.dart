import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/widgets.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:image_picker/image_picker.dart' as ip;
import 'package:photo_manager/photo_manager.dart' as pm;

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'media_bubbles.dart';

typedef _Item = ({MsgKind kind, Map<String, dynamic> data, String text});

// ChatAttachAlert port gallery file location music poll and contact behind glass tabs
Future<void> showAttachSheet(BuildContext context, {required Chat chat, String? replyId}) {
  return showTgSheet<void>(context, (_) => _AttachSheet(chat: chat, replyId: replyId));
}

class _Pick {
  _Pick.asset(pm.AssetEntity a)
      : asset = a,
        path = null,
        key = a.id;
  _Pick.file(String p)
      : asset = null,
        path = p,
        key = p;
  final pm.AssetEntity? asset;
  final String? path;
  final String key;
}

// only the gallery stays reachable, everything else moved behind the upload
// card at the top of it, the tabs below are kept for the ai to hand files back
class _AttachSheet extends StatefulWidget {
  const _AttachSheet({required this.chat, required this.replyId});
  final Chat chat;
  final String? replyId;

  @override
  State<_AttachSheet> createState() => _AttachSheetState();
}

class _AttachSheetState extends State<_AttachSheet> {
  int _tab = 0;
  final List<_Pick> _sel = [];
  final TextEditingController _cap = TextEditingController();

  @override
  void dispose() {
    _cap.dispose();
    super.dispose();
  }

  void _send(List<_Item> items) {
    if (items.isEmpty) return;
    Store.read(context).sendBatch(widget.chat, items, reply: widget.replyId);
    Navigator.of(context).pop();
  }

  void _toggle(_Pick p) {
    setState(() {
      final i = _sel.indexWhere((e) => e.key == p.key);
      if (i >= 0) {
        _sel.removeAt(i);
      } else if (_sel.length < 10) {
        _sel.add(p);
      }
    });
  }

  Future<void> _camera() async {
    try {
      final x = await ip.ImagePicker().pickImage(source: ip.ImageSource.camera, imageQuality: 92);
      if (x != null && mounted) setState(() => _sel.add(_Pick.file(x.path)));
    } catch (_) {
      if (mounted) showBulletin(context, context.l.attachCameraUnavailable);
    }
  }

  Future<void> _sendPhotos() async {
    final items = <_Item>[];
    for (var i = 0; i < _sel.length; i++) {
      final s = _sel[i];
      String? path = s.path;
      if (s.asset != null) path = (await s.asset!.originFile)?.path;
      if (path == null) continue;
      items.add((kind: MsgKind.photo, data: {'path': path, 'name': path.split('/').last}, text: items.isEmpty ? _cap.text : ''));
    }
    if (!mounted) return;
    _send(items);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final h = math.min(MediaQuery.of(context).size.height * .7, 620.0);
    final cap = _tab == 0 && _sel.isNotEmpty;
    return TgSheet(
      child: SizedBox(
        height: h,
        child: Column(children: [
          SizedBox(
            height: 44,
            child: Row(children: [
              const SizedBox(width: 18),
              Expanded(child: Text(l.attachTabGallery, style: TextStyle(color: p.title, fontSize: 20, fontWeight: FontWeight.w500, decoration: TextDecoration.none))),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: cap ? Padding(key: ValueKey(_sel.length), padding: const EdgeInsets.only(right: 18), child: Text(l.attachSelected(_sel.length), style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none))) : const SizedBox(key: ValueKey('n')),
              ),
            ]),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(key: ValueKey(_tab), child: _body()),
            ),
          ),
          // nothing to send means nothing to show down here, a single tab row
          // has no one left to switch to
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: TgCurves.easeOutQuint,
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .5), end: Offset.zero).animate(a), child: c)),
            child: cap ? _captionBar(p) : const SizedBox(key: ValueKey('none')),
          ),
        ]),
      ),
    );
  }

  Widget _body() {
    switch (_tab) {
      case 0:
        return _Gallery(sel: _sel, onToggle: _toggle, onCamera: _camera, onUpload: _send);
      case 1:
        return _Files(music: false, onSend: _send);
      case 2:
        return _LocationTab(onSend: _send);
      case 3:
        return _Files(music: true, onSend: _send);
      case 4:
        return _PollTab(onSend: _send);
      default:
        return _ContactsTab(onSend: _send);
    }
  }

  Widget _captionBar(Pal p) {
    final l = L10n.current;
    return Padding(
      key: const ValueKey('cap'),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: p.gray, borderRadius: BorderRadius.circular(22)),
            child: TgEdit(controller: _cap, hint: l.attachCaptionHint, maxLines: 4, style: TextStyle(color: p.title, fontSize: 17, height: 1.25, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
          ),
        ),
        const SizedBox(width: 8),
        Tap(
          scale: .9,
          onTap: _sendPhotos,
          child: SizedBox(
            width: 52,
            height: 48,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(left: 0, top: 2, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: p.send, shape: BoxShape.circle), child: Center(child: TgIcon(Ic.send, color: const Color(0xFFFFFFFF), size: 26)))),
              Positioned(
                right: 0,
                top: -4,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_sel.length),
                  tween: Tween(begin: .6, end: 1),
                  duration: const Duration(milliseconds: 220),
                  curve: TgCurves.easeOutBack,
                  builder: (_, t, child) => Transform.scale(scale: t, child: child),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.sheet, borderRadius: BorderRadius.circular(11), border: Border.all(color: p.accent, width: 1.5)),
                    child: Text('${_sel.length}', style: TextStyle(color: p.accent, fontSize: 12, fontWeight: FontWeight.w600, height: 1.1, decoration: TextDecoration.none)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// gallery grid with a camera tile and numbered selection circles
class _Gallery extends StatefulWidget {
  const _Gallery({required this.sel, required this.onToggle, required this.onCamera, required this.onUpload});
  final List<_Pick> sel;
  final void Function(_Pick) onToggle;
  final VoidCallback onCamera;
  final void Function(List<_Item>) onUpload;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  List<pm.AssetEntity> _assets = [];
  bool _loading = true;
  bool _denied = false;
  final Map<String, Future<Uint8List?>> _thumbs = {};

  /// The album is read in pages as the grid scrolls. Asking for a fixed
  /// 150 items meant anyone with a real camera library simply never saw
  /// anything older than their last few hundred shots, and there was no way to
  /// reach the rest from the UI.
  pm.AssetPathEntity? _album;
  final _scroll = ScrollController();
  static const _pageSize = 120;
  var _page = 0;
  var _loadingMore = false;
  var _reachedEnd = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || _reachedEnd) return;
    // a screen and a half ahead of the thumb, so the next page is usually
    // already there by the time the reader gets to it
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _load() async {
    try {
      final ps = await pm.PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      // The order has to be asked for. photo_manager leaves `orders` empty by
      // default, which hands the decision to the platform, and the platforms do
      // not agree: the same call came back oldest first here. A picker is
      // always newest first, so say so rather than hope.
      final filter = pm.FilterOptionGroup(
        orders: [const pm.OrderOption(type: pm.OrderOptionType.createDate, asc: false)],
      );
      final paths = await pm.PhotoManager.getAssetPathList(type: pm.RequestType.image, onlyAll: true, filterOption: filter);
      if (paths.isEmpty) {
        if (mounted) setState(() => _reachedEnd = true);
        return;
      }
      // the "all" album should be the only one, but its position is not
      // guaranteed across OEM skins, so take whichever holds the most
      final album = await _biggest(paths);
      if (album == null) {
        if (mounted) setState(() => _reachedEnd = true);
        return;
      }
      _album = album;
      final list = await album.getAssetListPaged(page: 0, size: _pageSize);
      _page = 1;
      if (!mounted) return;
      setState(() {
        _assets = list;
        // a short first page means there is nothing behind it
        _reachedEnd = list.length < _pageSize;
      });
    } catch (_) {
      if (mounted) setState(() => _denied = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Picks the album holding the most assets. photo_manager exposes the count
  /// only as a future, so this cannot be a reduce over a synchronous getter.
  Future<pm.AssetPathEntity?> _biggest(List<pm.AssetPathEntity> paths) async {
    pm.AssetPathEntity? best;
    var bestCount = -1;
    for (final p in paths) {
      try {
        final n = await p.assetCountAsync;
        if (n > bestCount) {
          bestCount = n;
          best = p;
        }
      } catch (_) {
        // an album that cannot be counted is not worth showing
      }
    }
    return best ?? (paths.isEmpty ? null : paths.first);
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (album == null || _loadingMore || _reachedEnd) return;
    setState(() => _loadingMore = true);
    try {
      final list = await album.getAssetListPaged(page: _page, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _assets.addAll(list);
        _page++;
        if (list.length < _pageSize) _reachedEnd = true;
      });
    } catch (_) {
      // a failed page must not spin forever, stop here and let the reader pick
      // from what already arrived
      if (mounted) setState(() => _reachedEnd = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // the upload card, this is the only way left to send anything that is not a photo
  Future<void> _upload() async {
    try {
      final files = await fp.FilePicker.pickFiles(type: fp.FileType.any);
      final items = <_Item>[];
      for (final f in files) {
        final path = f.path;
        if (path == null) continue;
        final size = await f.length() ?? 0;
        items.add((kind: MsgKind.file, data: {'path': path, 'name': f.name, 'size': size}, text: ''));
      }
      widget.onUpload(items);
    } catch (_) {
      if (mounted) showBulletin(context, context.l.attachPickerFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    // the upload card never waits on the album, it is the way out when the
    // photo permission is refused
    return Column(children: [
      _bigRow(p, Ic.file, l.attachUploadFiles, l.attachUploadFilesSub, _upload),
      Expanded(
        child: Builder(
          builder: (context) {
            if (_loading) return Center(child: Text(l.attachLoading, style: TextStyle(color: p.subtitle, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)));
            if (_denied) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TgIcon(Ic.image, color: p.hint, size: 56, stroke: 1.4),
                  const SizedBox(height: 12),
                  Text(l.attachPhotoPermission, style: TextStyle(color: p.title, fontSize: 17, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                  const SizedBox(height: 16),
                  SizedBox(width: 180, child: TgButton(label: l.attachOpenSettings, onTap: pm.PhotoManager.openSetting)),
                ]),
              );
            }
            return GridView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
              // the trailing slot is the page spinner, so the camera tile keeps
              // index 0 and the assets shift by one exactly as before
              itemCount: _assets.length + 1 + (_loadingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Tap(
                    scale: .96,
                    onTap: widget.onCamera,
                    child: ColoredBox(
                      color: p.gray,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        TgIcon(Ic.camera, color: p.accent, size: 34, stroke: 1.6),
                        const SizedBox(height: 6),
                        Text(l.attachCamera, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                      ]),
                    ),
                  );
                }
                if (i > _assets.length) {
                  return Center(child: Text(l.attachLoading, style: TextStyle(color: p.hint, fontSize: 12, decoration: TextDecoration.none, fontWeight: FontWeight.w400)));
                }
                return _tile(p, _assets[i - 1]);
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _tile(Pal p, pm.AssetEntity a) {
    final idx = widget.sel.indexWhere((e) => e.key == a.id);
    final on = idx >= 0;
    return GestureDetector(
      onTap: () => widget.onToggle(_Pick.asset(a)),
      child: Stack(fit: StackFit.expand, children: [
        ColoredBox(color: p.gray),
        AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: TgCurves.easeOut,
          scale: on ? .86 : 1,
          child: FutureBuilder<Uint8List?>(
            future: _thumb(a),
            builder: (_, s) => s.data == null ? const SizedBox.shrink() : Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
        Positioned(top: 6, right: 6, child: _Check(n: on ? idx + 1 : null)),
      ]),
    );
  }

  /// Thumbnails are cached by asset id so a rebuild does not re-read them, but
  /// paging through a long library would otherwise keep every page's bytes
  /// alive at once. Oldest entries go first, which is what the reader is
  /// furthest away from, and anything still on screen is refetched if it comes
  /// back around.
  static const _thumbCap = 600;

  Future<Uint8List?> _thumb(pm.AssetEntity a) {
    final hit = _thumbs[a.id];
    if (hit != null) return hit;
    if (_thumbs.length >= _thumbCap) {
      _thumbs.remove(_thumbs.keys.first);
    }
    return _thumbs[a.id] = a.thumbnailDataWithSize(const pm.ThumbnailSize.square(260));
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.n});
  final int? n;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: TgCurves.easeOutBack,
      scale: n == null ? .92 : 1.05,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: n == null ? const Color(0x33000000) : p.accent, border: Border.all(color: const Color(0xFFFFFFFF), width: 1.6)),
        child: n == null ? null : Text('$n', style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.1, decoration: TextDecoration.none)),
      ),
    );
  }
}

Widget _bigRow(Pal p, Ic ic, String title, String sub, VoidCallback? onTap, {Color? color}) {
  return Tap(
    highlight: true,
    onTap: onTap,
    child: SizedBox(
      height: 64,
      child: Row(children: [
        const SizedBox(width: 16),
        Container(width: 44, height: 44, decoration: BoxDecoration(color: color ?? p.accent, shape: BoxShape.circle), child: Center(child: TgIcon(ic, color: const Color(0xFFFFFFFF), size: 24, stroke: 1.8))),
        const SizedBox(width: 14),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: p.title, fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 14, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
          ]),
        ),
      ]),
    ),
  );
}

// file and music tabs browse the device or resend something shared before
class _Files extends StatelessWidget {
  const _Files({required this.music, required this.onSend});
  final bool music;
  final void Function(List<_Item>) onSend;

  Future<void> _browse(BuildContext context) async {
    try {
      final files = await fp.FilePicker.pickFiles(type: music ? fp.FileType.audio : fp.FileType.any);
      final items = <_Item>[];
      for (final f in files) {
        final path = f.path;
        if (path == null) continue;
        final size = await f.length() ?? 0;
        items.add((kind: music ? MsgKind.music : MsgKind.file, data: {'path': path, 'name': f.name, 'size': size}, text: ''));
      }
      onSend(items);
    } catch (_) {
      if (context.mounted) showBulletin(context, context.l.attachPickerFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final st = context.store;
    final kind = music ? MsgKind.music : MsgKind.file;
    final seen = <String>{};
    final recent = <Msg>[];
    for (final c in st.chats) {
      for (final m in c.msgs.reversed) {
        final path = m.data['path'] as String?;
        if (m.kind == kind && path != null && seen.add(path) && File(path).existsSync()) recent.add(m);
      }
    }
    return ListView(physics: const ClampingScrollPhysics(), children: [
      _bigRow(p, music ? Ic.music : Ic.file, music ? l.attachBrowseAudio : l.attachBrowseFiles, music ? l.attachPickSongs : l.attachPickDocs, () => _browse(context), color: music ? const Color(0xFFF45255) : p.accent),
      if (recent.isNotEmpty) Container(height: 32, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.centerLeft, color: p.gray, child: Text(l.searchRecent, style: TextStyle(color: p.accent, fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none))),
      for (final m in recent.take(30))
        Tap(
          highlight: true,
          onTap: () => onSend([(kind: kind, data: Map<String, dynamic>.from(m.data), text: '')]),
          child: SizedBox(
            height: 56,
            child: Row(children: [
              const SizedBox(width: 16),
              Container(width: 40, height: 40, decoration: BoxDecoration(color: p.gray, borderRadius: BorderRadius.circular(10)), child: Center(child: TgIcon(music ? Ic.music : Ic.file, color: p.subtitle, size: 22, stroke: 1.7))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${m.data['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                  Text(fileSize((m.data['size'] as num?) ?? 0), style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                ]),
              ),
              const SizedBox(width: 16),
            ]),
          ),
        ),
    ]);
  }
}

// location tab finds a fix then offers to send it the map is a painted stand in
class _LocationTab extends StatefulWidget {
  const _LocationTab({required this.onSend});
  final void Function(List<_Item>) onSend;

  @override
  State<_LocationTab> createState() => _LocationTabState();
}

class _LocationTabState extends State<_LocationTab> with SingleTickerProviderStateMixin {
  geo.Position? _pos;
  String? _err;
  bool _busy = true;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) throw L10n.current.attachLocationOff;
      var perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) perm = await geo.Geolocator.requestPermission();
      if (perm == geo.LocationPermission.denied || perm == geo.LocationPermission.deniedForever) throw L10n.current.attachLocationDenied;
      final pos = await geo.Geolocator.getCurrentPosition(locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.high));
      if (mounted) setState(() => _pos = pos);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final pos = _pos;
    return Column(children: [
      Expanded(
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => CustomPaint(size: Size.infinite, painter: MapPainter(dark: p.dark, accent: p.accent, t: _pulse.value, located: pos != null)),
          ),
        ),
      ),
      _bigRow(
        p,
        Ic.pinLoc,
        pos != null ? l.attachSendLocation : (_busy ? l.attachLocating : l.attachLocationUnavailable),
        pos != null ? l.attachLocationAccuracy(pos.accuracy.round()) : (_err ?? l.attachLocationWaiting),
        pos != null
            ? () => widget.onSend([(kind: MsgKind.location, data: {'lat': double.parse(pos.latitude.toStringAsFixed(6)), 'lng': double.parse(pos.longitude.toStringAsFixed(6)), 'acc': pos.accuracy.round()}, text: '')])
            : (_busy ? null : _locate),
        color: pos != null ? p.accent : p.hint,
      ),
      const SizedBox(height: 6),
    ]);
  }
}

// contacts tab with a live filter field
class _ContactsTab extends StatefulWidget {
  const _ContactsTab({required this.onSend});
  final void Function(List<_Item>) onSend;

  @override
  State<_ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<_ContactsTab> {
  final List<({String name, String phone})> _all = [];
  final TextEditingController _q = TextEditingController();
  bool _loading = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final st = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
      if (st != fc.PermissionStatus.granted && st != fc.PermissionStatus.limited) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      final list = await fc.FlutterContacts.getAll(properties: {fc.ContactProperty.phone});
      for (final c in list) {
        final name = c.displayName ?? '';
        if (name.isEmpty) continue;
        _all.add((name: name, phone: c.phones.isEmpty ? '' : c.phones.first.number));
      }
      _all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      if (mounted) setState(() => _denied = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    if (_loading) return Center(child: Text(l.attachLoading, style: TextStyle(color: p.subtitle, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)));
    if (_denied) {
      return Center(child: Text(l.attachContactsPermission, textAlign: TextAlign.center, style: TextStyle(color: p.subtitle, fontSize: 16, height: 1.3, decoration: TextDecoration.none, fontWeight: FontWeight.w400)));
    }
    final q = _q.text.trim().toLowerCase();
    final list = _all.where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || c.phone.contains(q)).toList();
    return Column(children: [
      Container(
        height: 40,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: p.gray, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          TgIcon(Ic.search, color: p.hint, size: 20),
          const SizedBox(width: 10),
          Expanded(child: TgEdit(controller: _q, hint: l.attachSearchContacts, onChanged: (_) => setState(() {}), style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400), hintStyle: TextStyle(color: p.hint, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400))),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? Center(child: Text(l.attachNoContacts, style: TextStyle(color: p.subtitle, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)))
            : ListView.builder(
                physics: const ClampingScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  return Tap(
                    highlight: true,
                    onTap: () => widget.onSend([(kind: MsgKind.contact, data: {'name': c.name, 'phone': c.phone}, text: '')]),
                    child: SizedBox(
                      height: 56,
                      child: Row(children: [
                        const SizedBox(width: 14),
                        Avatar(name: c.name, color: c.name.hashCode.abs(), size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                            Text(c.phone.isEmpty ? l.attachNoPhone : c.phone, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                          ]),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

// poll builder question options and the three switches like ChatAttachAlertPollLayout
class _PollTab extends StatefulWidget {
  const _PollTab({required this.onSend});
  final void Function(List<_Item>) onSend;

  @override
  State<_PollTab> createState() => _PollTabState();
}

class _PollTabState extends State<_PollTab> {
  final TextEditingController _q = TextEditingController();
  final List<TextEditingController> _opts = [TextEditingController(), TextEditingController()];
  bool _anon = true;
  bool _multi = false;
  bool _quiz = false;
  int _correct = -1;

  @override
  void dispose() {
    _q.dispose();
    for (final o in _opts) {
      o.dispose();
    }
    super.dispose();
  }

  List<String> get _texts => _opts.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();

  bool get _valid => _q.text.trim().isNotEmpty && _texts.length >= 2 && (!_quiz || (_correct >= 0 && _correct < _opts.length && _opts[_correct].text.trim().isNotEmpty));

  void _create() {
    final keep = <int>[for (var i = 0; i < _opts.length; i++) if (_opts[i].text.trim().isNotEmpty) i];
    final texts = [for (final i in keep) _opts[i].text.trim()];
    final correct = _quiz ? keep.indexOf(_correct) : null;
    widget.onSend([
      (
        kind: MsgKind.poll,
        data: {'q': _q.text.trim(), 'opts': texts, 'votes': List<int>.filled(texts.length, 0), 'mine': <int>[], 'multi': _multi && !_quiz, 'quiz': _quiz, 'anon': _anon, 'correct': correct},
        text: '',
      )
    ]);
  }

  Widget _label(Pal p, String t) => Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 6), child: Text(t, style: TextStyle(color: p.accent, fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none)));

  Widget _switchRow(Pal p, String t, bool v, ValueChanged<bool> on) => Tap(highlight: true, onTap: () => on(!v), child: SizedBox(height: 50, child: Row(children: [const SizedBox(width: 18), Expanded(child: Text(t, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400))), TgSwitch(value: v, onChanged: on), const SizedBox(width: 16)])));

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final style = TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
    final hint = TextStyle(color: p.hint, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
    return ListView(physics: const ClampingScrollPhysics(), padding: const EdgeInsets.only(bottom: 12), children: [
      _label(p, l.attachPollQuestionLabel),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4), child: TgEdit(controller: _q, hint: l.attachPollQuestion, maxLines: 3, style: style, hintStyle: hint, onChanged: (_) => setState(() {}))),
      _label(p, l.attachPollOptionsLabel),
      for (var i = 0; i < _opts.length; i++)
        Enter(
          key: ObjectKey(_opts[i]),
          child: SizedBox(
            height: 46,
            child: Row(children: [
              const SizedBox(width: 10),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _quiz
                    ? Tap(
                        scale: .85,
                        onTap: () => setState(() => _correct = i),
                        child: SizedBox(
                          width: 34,
                          height: 46,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: _correct == i ? const Color(0xFF46AA36) : const Color(0x00000000), border: Border.all(color: _correct == i ? const Color(0xFF46AA36) : p.hint, width: 1.6)),
                              child: _correct == i ? Center(child: TgIcon(Ic.check, color: const Color(0xFFFFFFFF), size: 14, stroke: 2.2)) : null,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(width: 8),
              ),
              Expanded(child: TgEdit(controller: _opts[i], hint: l.attachPollOption(i + 1), style: style, hintStyle: hint, onChanged: (_) => setState(() {}))),
              if (_opts.length > 2)
                Tap(
                  scale: .85,
                  onTap: () => setState(() {
                    _opts.removeAt(i).dispose();
                    if (_correct == i) _correct = -1;
                    if (_correct > i) _correct--;
                  }),
                  child: SizedBox(width: 48, height: 46, child: Center(child: TgIcon(Ic.close, color: p.hint, size: 18))),
                )
              else
                const SizedBox(width: 18),
            ]),
          ),
        ),
      if (_opts.length < 10)
        Tap(
          highlight: true,
          onTap: () => setState(() => _opts.add(TextEditingController())),
          child: SizedBox(height: 48, child: Row(children: [const SizedBox(width: 18), TgIcon(Ic.plus, color: p.accent, size: 22, stroke: 1.9), const SizedBox(width: 14), Text(l.attachPollAddOption, style: TextStyle(color: p.accent, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400))])),
        ),
      _label(p, l.attachPollSettingsLabel),
      _switchRow(p, l.attachPollAnonymous, _anon, (v) => setState(() => _anon = v)),
      AnimatedSize(duration: const Duration(milliseconds: 220), curve: TgCurves.easeOutQuint, child: _quiz ? const SizedBox(width: double.infinity) : _switchRow(p, l.attachPollMultiple, _multi, (v) => setState(() => _multi = v))),
      _switchRow(p, l.attachPollQuiz, _quiz, (v) => setState(() {
            _quiz = v;
            if (!v) _correct = -1;
          })),
      Padding(padding: const EdgeInsets.fromLTRB(18, 6, 18, 0), child: Text(_quiz ? l.attachPollQuizHint : l.attachPollFooter, style: TextStyle(color: p.subtitle, fontSize: 13, height: 1.3, decoration: TextDecoration.none, fontWeight: FontWeight.w400))),
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: TgButton(label: l.attachPollCreate, enabled: _valid, onTap: _create)),
    ]);
  }
}
