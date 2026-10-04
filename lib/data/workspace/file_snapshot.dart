import 'dart:io';

import 'package:path/path.dart' as p;

/// A cheap record of what a directory looked like at one moment.
///
/// Used to answer "what did that command change", which is the only way the
/// model learns that a build wrote files. It reports creations and modifications
/// but not deletions: a file that is gone has no mtime to compare and looking
/// for it would mean walking the tree twice per command.
class FileSnapshot {
  const FileSnapshot(this.entries);

  /// host path to mtime in milliseconds.
  final Map<String, int> entries;

  /// Twenty thousand entries is about a large source tree. Past that the walk
  /// stops rather than spending a second of a tool call on bookkeeping.
  static const int defaultMaxEntries = 20000;

  static Future<FileSnapshot> capture(List<Directory> roots, {int maxEntries = defaultMaxEntries}) async {
    final out = <String, int>{};
    for (final root in roots) {
      if (!await root.exists()) continue;
      await _walk(root, out, maxEntries);
    }
    return FileSnapshot(out);
  }

  static Future<void> _walk(Directory dir, Map<String, int> out, int cap) async {
    final stack = <Directory>[dir];
    while (stack.isNotEmpty) {
      if (out.length >= cap) return;
      final d = stack.removeLast();
      List<FileSystemEntity> kids;
      try {
        kids = await d.list(followLinks: false).toList();
      } catch (_) {
        // unreadable directory, skip it rather than abandoning the whole capture
        continue;
      }
      for (final k in kids) {
        final name = p.basename(k.path);
        // hidden directories hold build state and vcs data, and hashing them
        // would be most of the cost for no useful answer
        if (name.startsWith('.')) continue;
        if (k is Directory) {
          stack.add(k);
          continue;
        }
        try {
          out[k.path] = k.statSync().modified.millisecondsSinceEpoch;
        } catch (_) {
          // vanished between listing and stat
        }
        if (out.length >= cap) return;
      }
    }
  }

  /// Paths that appeared or whose mtime moved. Sorted so the model reads them in
  /// a stable order across two runs of the same command.
  List<String> changedSince(FileSnapshot after, {String? relativeTo, int cap = 50}) {
    final out = <String>[];
    for (final entry in after.entries.entries) {
      final before = entries[entry.key];
      if (before == null || before != entry.value) out.add(entry.key);
    }
    out.sort();
    final names = relativeTo == null ? out : [for (final f in out) p.posix.joinAll(p.split(p.relative(f, from: relativeTo)))];
    return names.take(cap).toList();
  }

  /// True when either side hit the cap, which means the answer is incomplete and
  /// the caller should say so rather than report a short list as the whole one.
  bool truncated(FileSnapshot other) => entries.length >= defaultMaxEntries || other.entries.length >= defaultMaxEntries;
}