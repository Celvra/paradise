import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../core/anim.dart';
import '../../core/overlays.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../tg_cells.dart' show TgCheckCell, rectOf, showMenuAt;
import '../../data/models.dart' show fileSize;
import '../../data/workspace/app_dirs.dart';
import '../../l10n/x.dart';
import 'file_browser_ops.dart';
import 'file_preview_page.dart';
import 'preview_file_type.dart';
import 'workspace_prompts.dart';

/// A file browser over one directory.
///
/// Two callers: the workspace file list and the per chat attachments, so the
/// root is a parameter rather than something this reaches for. [modelPathOf]
/// turns a host path into the path the model would write, which is what the
/// copy-path item copies.
class FileBrowser extends StatefulWidget {
  const FileBrowser({
    super.key,
    required this.root,
    required this.title,
    this.modelPathOf,
    this.readOnly = false,
    this.initialPath = '',
    this.emptyIcon = Ic.folderOpen,
    this.emptyTitle,
    this.emptyHint,
    this.onOpenTerminal,
    this.showToolbar = true,
    this.actions = const [],
  });

  /// The directory the browser is rooted at. Never changes for a given widget,
  /// which is why there is a key convention instead of a didUpdateWidget dance.
  final Directory root;

  final String title;

  /// Model vocabulary for a host path. Null means copy-path copies the real one,
  /// which is correct for a linked folder the user picked themselves.
  final String? Function(String hostPath)? modelPathOf;

  final bool readOnly;
  final String initialPath;
  final Ic emptyIcon;
  final String? emptyTitle;
  final String? emptyHint;
  final VoidCallback? onOpenTerminal;

  /// The page hides its own toolbar and takes these instead, so the actions sit
  /// in the app bar rather than in a second row.
  final bool showToolbar;

  /// Appended after the browser's own actions.
  final List<Widget> actions;

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  /// The path relative to [FileBrowser.root], empty at the top. Kept as
  /// segments rather than one string so going up is a truncate.
  final List<String> _stack = [];
  List<FileEntry> _entries = [];
  Object? _error;
  bool _loading = true;
  bool _hidden = false;
  FileSort _sort = FileSort.name;
  bool _ascending = true;
  bool _foldersFirst = true;

  /// Guards against a slow listing landing after the user moved on. Without it
  /// a tap into a deep tree can leave the row count from the previous folder.
  int _generation = 0;

  /// The new-item button, so its menu opens under the button rather than under
  /// the browser.
  final GlobalKey _newKey = GlobalKey();

  String get _rel => _stack.join('/');
  Directory get _dir => Directory(_abs(_rel));

  String _abs(String rel) =>
      rel.isEmpty ? widget.root.path : FsOps.joinInside(widget.root.path, rel);

  /// Breadcrumbs, the root itself first. The last one is where a tap lands.
  List<(String, String)> get _crumbList {
    final out = <(String, String)>[('root', '')];
    for (var i = 0; i < _stack.length; i++) {
      out.add((_stack[i], _stack.sublist(0, i + 1).join('/')));
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPath.isNotEmpty) {
      _stack.addAll(FsOps.isValidRelativePath(widget.initialPath)
          ? widget.initialPath.split('/').where((e) => e.isNotEmpty)
          : const <String>[]);
    }
    _reload();
  }

  @override
  void didUpdateWidget(FileBrowser old) {
    super.didUpdateWidget(old);
    // a different root is a different browser as far as the user is concerned,
    // and the caller is expected to give it a new key, so only the path moves
    if (widget.initialPath != old.initialPath &&
        widget.initialPath.isNotEmpty) {
      _stack
        ..clear()
        ..addAll(FsOps.isValidRelativePath(widget.initialPath)
            ? widget.initialPath.split('/').where((e) => e.isNotEmpty)
            : const <String>[]);
      _reload();
    }
  }

  Future<void> _reload() async {
    final mine = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await FsOps.list(_dir,
          sort: _sort,
          ascending: _ascending,
          foldersFirst: _foldersFirst,
          showHidden: _hidden);
      if (!mounted || mine != _generation) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || mine != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _open(FileEntry e) async {
    if (!e.isDirectory) {
      await showFilePreview(context, File(e.hostPath),
          modelPathOf: widget.modelPathOf);
      return;
    }
    setState(() => _stack.add(e.name));
    await _reload();
  }

  /// The hardware back button goes up one folder rather than closing the page,
  /// which is what a file manager does and what a user with a full stack of
  /// folders expects.
  Future<void> _up() async {
    if (_stack.isEmpty) return;
    setState(() => _stack.removeLast());
    await _reload();
  }

  // ------------------------------------------------------------------ actions

  Future<void> _newFolder() async {
    final name = await askName(context,
        title: context.l.wsNewFolder, initial: 'new folder');
    if (name == null || !mounted) return;
    final taken = {for (final e in _entries) e.name.toLowerCase()};
    final target = uniqueName(name, taken);
    try {
      await Directory(p.join(_dir.path, target)).create();
      await _reload();
    } catch (e) {
      if (mounted) showBulletin(context, '$e');
    }
  }

  Future<void> _newFile() async {
    final name = await askName(context,
        title: context.l.wsNewFile, initial: 'untitled.md');
    if (name == null || !mounted) return;
    final taken = {for (final e in _entries) e.name.toLowerCase()};
    final target = uniqueName(name, taken);
    try {
      await File(p.join(_dir.path, target)).writeAsString('');
      await _reload();
    } catch (e) {
      if (mounted) showBulletin(context, '$e');
    }
  }

  Future<void> _import() async {
    // this version of the plugin takes no allowMultiple, so importing is one
    // file at a time and the picker comes back up for the next
    final picked = await fp.FilePicker.pickFiles(type: fp.FileType.any);
    if (picked.isEmpty) return;
    var n = 0;
    for (final f in picked) {
      final from = f.path;
      if (from == null) continue;
      try {
        final target = p.join(_dir.path, safeFileName(p.basename(from)));
        await File(from).copy(FsOps.uniqueName(_dir.path, target));
        n++;
      } catch (_) {
        // one bad file should not abandon the rest of the batch
      }
    }
    if (!mounted) return;
    if (n > 0) {
      showBulletin(context, '$n');
      await _reload();
    }
  }

  Future<void> _exportZip() async {
    // zipped in a temp directory first: streaming straight into the destination
    // would leave a half written archive there if the walk failed
    final scratch = await Directory.systemTemp.createTemp('ws_zip');
    final name =
        safeFileName(widget.title.isEmpty ? 'workspace' : widget.title);
    final out = File(p.join(scratch.path, '$name.zip'));
    try {
      await _zip(widget.root.path, out);
      if (!mounted) return;
      await shareFile(context, out, '$name.zip');
    } catch (e) {
      if (mounted) showBulletin(context, '$e');
    } finally {
      // the archive is in the cache, the OS will get it, but an export the user
      // abandoned should not sit there
      if (await scratch.exists()) await scratch.delete(recursive: true);
    }
  }

  /// Zips [dir] into [out].
  ///
  /// Built in memory in one pass rather than streamed, because the archive
  /// package's encoder takes a whole Archive and a workspace is a directory the
  /// user already has. A cap stops a multi-gigabyte workspace from taking the
  /// app down: past it the export fails loudly instead of half succeeding.
  static Future<void> _zip(String dir, File out,
      {int cap = 256 * 1024 * 1024}) async {
    final archive = Archive();
    var total = 0;
    final entries = await FsOps.list(Directory(dir), showHidden: true);
    for (final e in entries) {
      if (e.isDirectory) continue;
      try {
        final bytes = await File(e.hostPath).readAsBytes();
        total += bytes.length;
        if (total > cap)
          throw const FormatException(
              'workspace is too large to export as one zip');
        archive.addFile(ArchiveFile.noCompress(e.name, bytes.length, bytes));
      } catch (_) {
        // unreadable, leave it out rather than failing the whole export
      }
    }
    await out.writeAsBytes(ZipEncoder().encode(archive));
  }

  Future<void> _rename(FileEntry e) async {
    final name =
        await askName(context, title: context.l.wsRename, initial: e.name);
    if (name == null || name == e.name || !mounted) return;
    try {
      await File(e.hostPath).rename(p.join(_dir.path, name));
      await _reload();
    } catch (err) {
      if (mounted) showBulletin(context, '$err');
    }
  }

  Future<void> _delete(FileEntry e) async {
    final ok = await askConfirm(
      context,
      title: e.isDirectory
          ? context.l.wsDeleteFolderTitle
          : context.l.wsDeleteFileTitle,
      message: e.name,
      confirmLabel: context.l.wsDelete,
    );
    if (!ok || !mounted) return;
    try {
      if (e.isDirectory) {
        await Directory(e.hostPath).delete(recursive: true);
      } else {
        await File(e.hostPath).delete();
      }
      await _reload();
    } catch (err) {
      if (mounted) showBulletin(context, '$err');
    }
  }

  Future<void> _copyPath(FileEntry e) async {
    final model = widget.modelPathOf?.call(e.hostPath) ?? e.hostPath;
    copyWithToast(context, model, context.l.wsCopiedPath);
  }

  /// [anchor] is the row's own context. Anchoring to `context` here puts the
  /// menu at the bottom corner of the list, which is nowhere near the row that
  /// was tapped.
  Future<void> _rowActions(FileEntry e, BuildContext anchor) async {
    final l = context.l;
    await showTgMenu(
      context,
      anchor: rectOf(anchor),
      items: [
        if (!e.isDirectory)
          MenuItem(
              l.wsPreview,
              Ic.eye,
              () => showFilePreview(context, File(e.hostPath),
                  modelPathOf: widget.modelPathOf)),
        if (!widget.readOnly) MenuItem(l.wsRename, Ic.pencil, () => _rename(e)),
        MenuItem(l.wsCopyPath, Ic.link, () => _copyPath(e)),
        MenuItem(l.wsShare, Ic.share,
            () => shareFile(context, File(e.hostPath), e.name)),
        if (!widget.readOnly) MenuItem.gap(),
        if (!widget.readOnly)
          MenuItem(l.wsDelete, Ic.trash, () => _delete(e), danger: true),
      ],
    );
  }

  Future<void> _sortSheet() async {
    final l = context.l;
    final r = await WsSheet.open<
        ({FileSort sort, bool ascending, bool foldersFirst})>(
      context,
      (c) => StatefulBuilder(
        builder: (c, set) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _sortRow(l.wsSortName, _sort == FileSort.name, () {
              set(() {
                if (_sort == FileSort.name) {
                  _ascending = !_ascending;
                } else {
                  _sort = FileSort.name;
                  _ascending = true;
                }
              });
              _reload();
            }),
            _sortRow(l.wsSortModified, _sort == FileSort.modified, () {
              set(() {
                if (_sort == FileSort.modified) {
                  _ascending = !_ascending;
                } else {
                  _sort = FileSort.modified;
                  _ascending = false;
                }
              });
              _reload();
            }),
            _sortRow(l.wsSortSize, _sort == FileSort.size, () {
              set(() {
                if (_sort == FileSort.size) {
                  _ascending = !_ascending;
                } else {
                  _sort = FileSort.size;
                  _ascending = false;
                }
              });
              _reload();
            }),
            TgCheckCell(
                title: l.wsFoldersFirst,
                value: _foldersFirst,
                onChanged: (v) {
                  set(() => _foldersFirst = v);
                  _reload();
                }),
          ],
        ),
      ),
      title: l.wsSort,
    );
    if (r == null) return;
    setState(() {
      _sort = r.sort;
      _ascending = r.ascending;
      _foldersFirst = r.foldersFirst;
    });
    await _reload();
  }

  Widget _sortRow(String title, bool active, VoidCallback onTap) {
    final p = context.p;
    return Tap(
      onTap: onTap,
      highlight: true,
      child: SizedBox(
        height: 50,
        child: Row(children: [
          const SizedBox(width: 21),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: p.title,
                      fontSize: 16,
                      decoration: TextDecoration.none))),
          if (active)
            TgIcon(_ascending ? Ic.up : Ic.down, color: p.accent, size: 20),
          const SizedBox(width: 21),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------------ toolbar

  /// The action row. Returned rather than built so a page with its own app bar
  /// can put these in it and the browser draws no second row.
  List<Widget> toolbarActions(BuildContext context) => [
        TgIconButton(
            icon: Ic.list, tooltip: context.l.wsSort, onTap: _sortSheet),
        TgIconButton(
            icon: Ic.hidden,
            tooltip: context.l.wsShowHidden,
            active: _hidden,
            onTap: () {
              setState(() => _hidden = !_hidden);
              _reload();
            }),
        if (!widget.readOnly)
          TgIconButton(
              key: _newKey,
              icon: Ic.plus,
              tooltip: context.l.wsNew,
              onTap: _newSheet),
        if (widget.onOpenTerminal != null)
          TgIconButton(
              icon: Ic.terminal,
              tooltip: context.l.wsOpenTerminal,
              onTap: widget.onOpenTerminal),
        ...widget.actions,
      ];

  Future<void> _newSheet() async {
    final l = context.l;
    await showMenuAt(
      context,
      _newKey,
      [
        MenuItem(l.wsNewFile, Ic.file, _newFile),
        MenuItem(l.wsNewFolder, Ic.folder, _newFolder),
        MenuItem(l.wsImport, Ic.download, _import),
        if (widget.root.parent.path.isNotEmpty)
          MenuItem(l.wsExportZip, Ic.storage, _exportZip),
      ],
    );
  }

  Widget _toolbar() => Container(
        height: 48,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: toolbarActions(context)),
        ),
      );

  Widget _crumbs(Pal p) {
    final crumbs = _crumbList;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: crumbs.length,
        separatorBuilder: (_, __) =>
            Center(child: TgIcon(Ic.chevron, color: p.subtitle, size: 14)),
        itemBuilder: (c, i) {
          final (label, rel) = crumbs[i];
          final last = i == crumbs.length - 1;
          return Center(
            child: Tap(
              onTap: last
                  ? null
                  : () {
                      setState(() {
                        _stack
                          ..clear()
                          ..addAll(
                              rel.isEmpty ? const <String>[] : rel.split('/'));
                      });
                      _reload();
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  i == 0 ? widget.title : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: last ? p.title : p.accent,
                      fontSize: 14.5,
                      fontWeight: last ? FontWeight.w500 : FontWeight.w400,
                      decoration: TextDecoration.none),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return PopScope(
      // the browser consumes back while it has somewhere to go up to
      canPop: _stack.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _up();
      },
      child: Column(children: [
        _crumbs(p),
        Container(height: .5, color: p.divider),
        if (widget.showToolbar) _toolbar(),
        Expanded(child: _body(p)),
      ]),
    );
  }

  Widget _body(Pal p) {
    if (_loading)
      return Center(
          child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: p.subtitle)));
    if (_error != null) {
      return WsEmpty(
        icon: Ic.info,
        title: '$_error',
        action: TgButton(label: context.l.actionRetry, onTap: _reload),
      );
    }
    if (_entries.isEmpty) {
      return WsEmpty(
        icon: widget.emptyIcon,
        title: widget.emptyTitle ??
            (_rel.isEmpty ? context.l.wsEmpty : context.l.wsEmptyDir),
        hint: widget.emptyHint ?? (_rel.isEmpty ? context.l.wsEmptyHint : null),
      );
    }
    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(left: 62, right: 12),
          child: Container(height: .5, color: p.divider)),
      itemBuilder: (c, i) => _row(p, _entries[i], c),
    );
  }

  Widget _row(Pal p, FileEntry e, BuildContext c) {
    final style = fileTypeStyle(e.name);
    final sub = e.isDirectory ? null : '${fileSize(e.size)}';
    return Tap(
      highlight: true,
      onTap: () => _open(e),
      onLongPress: widget.readOnly ? null : () => _rowActions(e, c),
      child: SizedBox(
        height: 58,
        child: Row(children: [
          SizedBox(
            width: 52,
            child: Center(
              child: e.isDirectory
                  ? TgIcon(Ic.folder, color: p.icon, size: 24)
                  : TgIcon(style.icon, color: p.icon, size: 22),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: p.title,
                        fontSize: 16,
                        decoration: TextDecoration.none)),
                if (sub != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(sub,
                          style: TextStyle(
                              color: p.subtitle,
                              fontSize: 13,
                              decoration: TextDecoration.none))),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ]),
      ),
    );
  }
}

/// Hands a file to another app.
///
/// There is no share sheet on this platform without pulling a plugin in for
/// one method, so this writes the path to the clipboard and says where it is.
/// The path is already what the user would have to type, and on this app's own
/// files it is a real file they can reach.
Future<void> shareFile(BuildContext context, File file, String name) async {
  copyWithToast(context, file.path, name);
}
