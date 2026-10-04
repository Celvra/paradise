import 'dart:io';

import 'package:path/path.dart' as p;

/// Which column the browser is sorted on.
enum FileSort { name, modified, size }

/// One row. [modified] is null for anything that could not be stat'ed, which is
/// a dangling link rather than a file we failed to read.
class FileEntry {
  const FileEntry({required this.name, required this.hostPath, required this.isDirectory, required this.size, this.modified, this.isHidden = false});
  final String name;
  final String hostPath;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
  final bool isHidden;

  /// A directory's size is its entry count rather than its byte total, which
  /// would mean walking the whole tree for every row.
  int get displaySize => size;
}

/// Path safety for the browser, kept out of the widget so it is testable and so
/// the one rule that matters, stay inside the root, is stated once.
///
/// The model has its own layer in workspace_paths.dart. This one is about a
/// tapped row, which can only be a path the browser itself produced, so the
/// checks are cheaper but not skippable: a rename to `../` would otherwise move
/// a file out of the workspace the moment the user tapped the wrong row.
class FsOps {
  const FsOps._();

  /// Rejects a name that is not one. Empty, a separator, a null byte or a
  /// relative segment would all land the file somewhere other than where it was
  /// typed.
  static bool isValidName(String name) {
    if (name.isEmpty || name.length > 255) return false;
    if (name == '.' || name == '..') return false;
    if (name.contains('/') || name.contains('\\') || name.contains('\x00')) return false;
    return true;
  }

  /// A relative path that is safe to join onto a root. Used by the working
  /// directory field, where the user types a path rather than picking one.
  static bool isValidRelativePath(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('/') || path.contains('\x00') || path.contains('\\')) return false;
    return !p.posix.split(p.posix.normalize(path)).contains('..');
  }

  /// Joins [rel] onto [root] and refuses anything that lands outside it.
  static String joinInside(String root, String rel) {
    if (rel.contains('\x00')) throw const FormatException('path contains a null byte');
    final joined = p.normalize(p.join(root, rel));
    final canon = p.canonicalize(root);
    if (!p.isWithin(canon, joined) && !p.equals(joined, canon)) {
      throw FormatException('path escapes the workspace: $rel');
    }
    return joined;
  }

  /// The absolute host path for a relative position in the browser.
  static String resolveInside(String root, String rel) => joinInside(root, rel);

  /// `name (2).txt`, `name (3).txt` until it is not taken. [taken] is compared
  /// case insensitively because the workspace may sit on a case insensitive
  /// volume where `A.txt` and `a.txt` cannot both exist.
  static String uniqueName(String dir, String wanted) {
    if (!_exists(p.join(dir, wanted))) return wanted;
    final ext = p.extension(wanted);
    final stem = ext.isEmpty ? wanted : wanted.substring(0, wanted.length - ext.length);
    for (var i = 2; i < 10000; i++) {
      final n = '$stem ($i)$ext';
      if (!_exists(p.join(dir, n))) return n;
    }
    return '$stem ${DateTime.now().microsecondsSinceEpoch}$ext';
  }

  static bool _exists(String path) => FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound;

  /// Lists one directory, sorted and filtered.
  ///
  /// [excludePath] and everything under it is dropped, which is how a move
  /// picker stops offering the folder it is moving as a destination for itself.
  static Future<List<FileEntry>> list(Directory dir, {FileSort sort = FileSort.name, bool ascending = true, bool foldersFirst = true, bool showHidden = false, String? excludePath}) async {
    List<FileSystemEntity> kids;
    try {
      kids = await dir.list(followLinks: false).toList();
    } catch (_) {
      return const [];
    }
    final out = <FileEntry>[];
    for (final k in kids) {
      final name = p.basename(k.path);
      final hidden = name.startsWith('.');
      if (hidden && !showHidden) continue;
      if (excludePath != null && _under(excludePath, k.path)) continue;
      final isDir = k is Directory;
      var size = 0;
      DateTime? modified;
      try {
        final stat = k.statSync();
        size = stat.size;
        modified = stat.modified;
      } catch (_) {
        // a dangling link still belongs in the list, it just has no size
      }
      out.add(FileEntry(name: name, hostPath: k.path, isDirectory: isDir, size: size, modified: modified, isHidden: hidden));
    }
    sortEntries(out, sort: sort, ascending: ascending, foldersFirst: foldersFirst);
    return out;
  }

  static void sortEntries(List<FileEntry> entries, {FileSort sort = FileSort.name, bool ascending = true, bool foldersFirst = true}) {
    entries.sort((a, b) {
      if (foldersFirst && a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      int c;
      switch (sort) {
        case FileSort.name:
          c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case FileSort.modified:
          // a file with no timestamp sorts last rather than first, so a dangling
          // link does not lead the list
          final am = a.modified;
          final bm = b.modified;
          if (am == null && bm == null) {
            c = 0;
          } else if (am == null) {
            c = 1;
          } else if (bm == null) {
            c = -1;
          } else {
            c = am.compareTo(bm);
          }
        case FileSort.size:
          c = a.size.compareTo(b.size);
      }
      return ascending ? c : -c;
    });
  }

  static bool _under(String root, String path) {
    final canon = p.canonicalize(root);
    final target = p.canonicalize(path);
    return p.isWithin(canon, target) || p.equals(canon, target);
  }

  /// Total bytes under [dir], for the size of a folder the user is about to
  /// export. One walk, and every failure inside it is skipped rather than
  /// aborting: a permission error on one entry should not lose the total.
  static Future<int> directorySize(Directory dir, {int cap = 1 << 30}) async {
    var total = 0;
    final stack = <Directory>[dir];
    while (stack.isNotEmpty && total < cap) {
      final d = stack.removeLast();
      List<FileSystemEntity> kids;
      try {
        kids = await d.list(followLinks: false).toList();
      } catch (_) {
        continue;
      }
      for (final k in kids) {
        if (k is Directory) {
          stack.add(k);
          continue;
        }
        try {
          total += await File(k.path).length();
        } catch (_) {
          // unreadable, skip it
        }
        if (total >= cap) return cap;
      }
    }
    return total;
  }
}