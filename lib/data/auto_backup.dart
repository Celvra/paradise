import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Automatic backup policy and the place it writes to.
///
/// The policy is deliberately pure: [AutoBackup] decides *when*, the store
/// decides *what* (it owns the archive) and a [BackupSink] decides *where*.
/// All three can be tested without each other.
///
/// Modes:
///   change   – run shortly after real data changes (the default)
///   interval – run when at least [intervalMin] minutes passed since lastAt
///   window   – run once a day while now is inside [windowStart, windowEnd)
///   off      – never
class AutoBackup {
  String mode = 'change';
  int intervalMin = 720;
  int windowStart = 180; // 03:00
  int windowEnd = 300; // 05:00

  /// Last successful write, ms epoch.
  int lastAt = 0;

  /// Content fingerprint at lastAt, so the change mode can skip re-writing
  /// identical data.
  int lastHash = 0;

  bool get enabled => mode != 'off';

  bool shouldRun(DateTime now, {required bool dataChanged, int minGapMs = 45000}) {
    switch (mode) {
      case 'change':
        // the store debounces dirty marks; this gap keeps one editing burst
        // from producing a backup per keystroke flush
        return dataChanged && now.millisecondsSinceEpoch - lastAt >= minGapMs;
      case 'interval':
        return now.millisecondsSinceEpoch - lastAt >= intervalMin * 60000;
      case 'window':
        if (windowEnd <= windowStart) return false;
        final mins = now.hour * 60 + now.minute;
        if (mins < windowStart || mins >= windowEnd) return false;
        // once per day: inside the window, only run if we have not written
        // since the window opened today
        final open = DateTime(now.year, now.month, now.day, windowStart ~/ 60, windowStart % 60);
        return lastAt < open.millisecondsSinceEpoch;
      default:
        return false;
    }
  }

  void noteSuccess(DateTime at, int hash) {
    lastAt = at.millisecondsSinceEpoch;
    lastHash = hash;
  }
}

/// Where an automatic backup lands. Two shapes: the MediaStore one, which
/// survives an uninstall because the file lives in the shared Downloads
/// collection, and a plain directory one, which is the fallback on platforms
/// without that channel and in tests.
///
/// A sink moves opaque archive bytes. It never overwrites: every write is a new
/// file, so the copy taken before a bad edit is still there after it. The
/// address used to be a fixed name that each write erased first, which turned a
/// single mistyped import into an unrecoverable one because the only good copy
/// had already been replaced.
abstract class BackupSink {
  Future<void> write(List<int> bytes);
  Future<List<int>?> read();
}

/// Shared naming for a sink: a sortable timestamp between a stable prefix and
/// extension, so "the newest file" is also the lexicographically greatest one.
String autoBackupFileName(DateTime at) {
  String p(int v) => v.toString().padLeft(2, '0');
  final s = '${at.year}${p(at.month)}${p(at.day)}-${p(at.hour)}${p(at.minute)}${p(at.second)}';
  return '$autoBackupPrefix$s.$autoBackupExt';
}

const autoBackupPrefix = 'paradise_autobackup-';
const autoBackupExt = 'zip';
const autoBackupMime = 'application/zip';

/// How many archives a directory sink keeps. The change mode fires after every
/// editing burst, so an unbounded history is a disk leak dressed up as safety;
/// a rolling window keeps the last few restores and drops the rest.
const autoBackupKeep = 20;

class DirBackupSink implements BackupSink {
  DirBackupSink(this.dir, {this.keep = autoBackupKeep});

  final Directory dir;

  /// Newest archives retained. Zero keeps every one.
  final int keep;

  /// Every archive in the directory, newest first. Sorted by name because the
  /// timestamp is the name, so the order survives a clock that jumps rather
  /// than trusting each file's mtime.
  List<File> _archives() {
    if (!dir.existsSync()) return const [];
    final out = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith(autoBackupPrefix) && f.path.endsWith('.$autoBackupExt'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return out;
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/${autoBackupFileName(DateTime.now())}');
    await file.writeAsBytes(bytes, flush: true);
    if (keep <= 0) return;
    final all = _archives();
    for (final old in all.skip(keep)) {
      try {
        await old.delete();
      } catch (_) {
        // a file we cannot delete is harmless; never let it fail the write
      }
    }
  }

  @override
  Future<List<int>?> read() async {
    final all = _archives();
    if (all.isEmpty) return null;
    try {
      return await all.first.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}

/// MediaStore-backed sink (Android). A backup that only lives in app-private
/// storage dies with the app, which is the failure the auto backup exists to
/// prevent; Downloads via MediaStore is the one place a modern Android app can
/// write without storage permission that outlives an uninstall. Any channel
/// failure drops to the private directory sink: a fragile private backup still
/// beats none.
class MediaStoreBackupSink implements BackupSink {
  static const _ch = MethodChannel('paradise/backup');

  BackupSink? _fallback;
  bool _broken = false;

  Future<BackupSink> _fb() async {
    return _fallback ??= DirBackupSink(Directory('${(await getApplicationDocumentsDirectory()).path}/backup'));
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (_broken) return (await _fb()).write(bytes);
    try {
      await _ch.invokeMethod<int>('write', bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
    } on MissingPluginException {
      _broken = true;
      return (await _fb()).write(bytes);
    } on PlatformException {
      // MediaStore refused (old api, revoked collection...): keep a private
      // copy rather than no copy
      return (await _fb()).write(bytes);
    }
  }

  @override
  Future<List<int>?> read() async {
    if (_broken) return (await _fb()).read();
    try {
      return await _ch.invokeMethod<Uint8List>('read');
    } on MissingPluginException {
      _broken = true;
      return (await _fb()).read();
    } on PlatformException {
      return (await _fb()).read();
    }
  }
}
