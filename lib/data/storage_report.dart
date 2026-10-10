import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'store.dart';

/// What the app is using on this device, split by kind.
///
/// Sizes are read from the filesystem each time the page opens rather than
/// cached: the numbers are the point of the screen, and a stale byte count is
/// worse than a short wait. Every walk is best effort, a directory that cannot
/// be listed costs that row and never the report.
enum StorageKind { chat, media, stickers, wallpaper, backup, workspace, database, cache, other }

/// One row. [name] is only set for the per chat rows, where the label is the
/// assistant's own name rather than a translated category.
class StorageEntry {
  StorageEntry(this.kind, this.bytes, {this.name = ''});

  final StorageKind kind;
  final int bytes;
  final String name;
}

class StorageReport {
  StorageReport(this.entries);

  final List<StorageEntry> entries;

  int get total => entries.fold(0, (a, e) => a + e.bytes);

  int bytesOf(StorageKind kind) => entries.where((e) => e.kind == kind).fold(0, (a, e) => a + e.bytes);

  /// The chat rows, biggest first, so the heaviest assistant is the first line.
  List<StorageEntry> get chats {
    final l = entries.where((e) => e.kind == StorageKind.chat).toList()
      ..sort((a, b) => b.bytes.compareTo(a.bytes));
    return l;
  }

  /// Every group row that holds something, in a fixed order the page labels
  /// from [StorageKind]. An empty kind is dropped rather than shown as a zero
  /// the user has to read past.
  List<StorageEntry> get groups {
    const order = [
      StorageKind.media,
      StorageKind.stickers,
      StorageKind.wallpaper,
      StorageKind.backup,
      StorageKind.workspace,
      StorageKind.database,
      StorageKind.cache,
      StorageKind.other,
    ];
    final out = <StorageEntry>[];
    for (final k in order) {
      final n = bytesOf(k);
      if (n > 0) out.add(StorageEntry(k, n));
    }
    return out;
  }

}

/// Top level entries under the app documents dir, and the kind each counts as.
/// Anything not listed falls into [StorageKind.other], so a directory a later
/// build adds still shows up in the total rather than vanishing from it.
const _dirKinds = <String, StorageKind>{
  'ai_images': StorageKind.media,
  'ai_videos': StorageKind.media,
  'ai_files': StorageKind.media,
  'ai_voice': StorageKind.media,
  'restored_assets': StorageKind.media,
  'stickers': StorageKind.stickers,
  'stickers_thumbs': StorageKind.stickers,
  'wallpapers': StorageKind.wallpaper,
  'backup': StorageKind.backup,
  'workspaces': StorageKind.workspace,
  'sessions': StorageKind.workspace,
  'environment': StorageKind.workspace,
  'skills': StorageKind.workspace,
  'workspace-tmp': StorageKind.cache,
};

/// Measures the device and returns the rows. Never throws.
Future<StorageReport> buildStorageReport(Store store) async {
  final entries = <StorageEntry>[];

  // Per assistant chat records: the text and the small json around it, measured
  // on the model the store already holds. Attachment bytes are counted where
  // they actually sit on disk, under media, so nothing is counted twice.
  for (final c in store.chats) {
    var n = 0;
    for (final m in c.msgs) {
      n += utf8.encode(m.text).length;
      n += _smallDataBytes(m.data);
    }
    n += utf8.encode(c.persona.name).length + utf8.encode(c.persona.prompt).length;
    entries.add(StorageEntry(StorageKind.chat, n, name: c.persona.name));
  }

  // The documents tree, bucketed by its top level entry.
  try {
    final root = await getApplicationDocumentsDirectory();
    if (await root.exists()) {
      final bucket = <StorageKind, int>{};
      await for (final e in root.list(followLinks: false)) {
        final kind = _dirKinds[p.basename(e.path)] ?? StorageKind.other;
        bucket[kind] = (bucket[kind] ?? 0) + await _sizeOf(e);
      }
      bucket.forEach((k, v) => entries.add(StorageEntry(k, v)));
    }
  } catch (_) {
    // an unreadable tree costs the group rows, not the page
  }

  // The database sits in its own directory, with a journal and a wal beside it.
  try {
    final d = Directory(await getDatabasesPath());
    var n = 0;
    if (await d.exists()) {
      await for (final e in d.list(followLinks: false)) {
        if (e is File && p.basename(e.path).startsWith('paradise.db')) n += await e.length();
      }
    }
    if (n > 0) entries.add(StorageEntry(StorageKind.database, n));
  } catch (_) {
    // no database on this platform, or the plugin did not answer
  }

  // The temporary directory is the cache: speech clips, thumbnails, scratch.
  try {
    final tmp = await getTemporaryDirectory();
    if (await tmp.exists()) {
      final n = await _sizeOf(tmp);
      if (n > 0) entries.add(StorageEntry(StorageKind.cache, n));
    }
  } catch (_) {
    // no temporary directory to measure
  }

  return StorageReport(entries);
}

/// Deletes what the cache covers and returns the bytes it freed.
///
/// Only the temporary directory is touched. Chats, media, stickers, backups and
/// the restored assets all survive: the last are not cache even though a restore
/// wrote them, because a persona avatar or a sticker points at one.
Future<int> clearCache() async {
  var freed = 0;
  try {
    final tmp = await getTemporaryDirectory();
    if (await tmp.exists()) {
      await for (final e in tmp.list(followLinks: false)) {
        freed += await _sizeOf(e);
        try {
          await e.delete(recursive: true);
        } catch (_) {
          // one item that refuses to go is not worth failing the sweep
        }
      }
    }
  } catch (_) {
    // nothing to clear
  }
  return freed;
}

/// Bytes of a file or a whole directory tree. Links are not followed, so a loop
/// cannot make this run forever.
Future<int> _sizeOf(FileSystemEntity e) async {
  try {
    if (e is File) return await e.length();
    if (e is! Directory) return 0;
    var n = 0;
    await for (final c in e.list(followLinks: false)) {
      n += await _sizeOf(c);
    }
    return n;
  } catch (_) {
    return 0;
  }
}

/// Rough size of a message's non text payload, so a row that carries a caption
/// plus a path counts for something without pulling the file in.
int _smallDataBytes(Map<String, dynamic> data) {
  if (data.isEmpty) return 0;
  try {
    return utf8.encode(jsonEncode(data)).length;
  } catch (_) {
    return 0;
  }
}
