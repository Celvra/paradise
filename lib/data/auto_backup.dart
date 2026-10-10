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

  bool shouldRun(DateTime now,
      {required bool dataChanged, int minGapMs = 45000}) {
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
        final open = DateTime(
            now.year, now.month, now.day, windowStart ~/ 60, windowStart % 60);
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
/// A sink moves opaque archive bytes. Each successful write replaces the
/// fixed-name backup, staging the new bytes first so a failed write cannot
/// truncate the previous copy.
abstract class BackupSink {
  Future<void> write(List<int> bytes);
  Future<List<int>?> read();
  Future<bool> exists();
}

const autoBackupFileName = 'paradise_autobackup.zip';

/// Backward compatible alias for the staged MediaStore/directory writer.
const autoBackupName = autoBackupFileName;

/// Dated remote copies (PR #15) have independent retention from the local
/// fixed-name automatic backup.
String remoteBackupFileName(DateTime at) {
  String p(int v) => v.toString().padLeft(2, '0');
  return 'paradise-${at.year}${p(at.month)}${p(at.day)}.$autoBackupExt';
}
const autoBackupLegacyJson = 'paradise_autobackup.json';
const autoBackupPrefix = 'paradise_autobackup-';
const autoBackupExt = 'zip';
const autoBackupMime = 'application/zip';

/// Name produced by older builds; still accepted when reading old backups.
String legacyAutoBackupFileName(DateTime at) {
  String p(int v) => v.toString().padLeft(2, '0');
  final s =
      '${at.year}${p(at.month)}${p(at.day)}-${p(at.hour)}${p(at.minute)}${p(at.second)}';
  return '$autoBackupPrefix$s.$autoBackupExt';
}

final _legacyZipName = RegExp(r'^paradise_autobackup-\d{8}-\d{6}\.zip$');

class DirBackupSink implements BackupSink {
  DirBackupSink(this.dir);

  final Directory dir;

  List<File> _oldArchives() {
    if (!dir.existsSync()) return const [];
    final out = dir
        .listSync()
        .whereType<File>()
        .where((f) => _legacyZipName.hasMatch(f.uri.pathSegments.last))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return out;
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (!await dir.exists()) await dir.create(recursive: true);
    // A temporary directory guarantees a unique staging path on the same file
    // system. Never open the only good backup for writing; rename over it only
    // after the new file has been flushed and closed.
    final staging = await dir.createTemp('.paradise_autobackup-');
    try {
      final temp = File('${staging.path}/$autoBackupName');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename('${dir.path}/$autoBackupName');
    } finally {
      try {
        await staging.delete(recursive: true);
      } catch (_) {
        // The staging directory is ours, but cleanup must not mask a write.
      }
    }
    // Migration cleanup is best effort and must never touch other directories,
    // fixed-name JSON, or unrelated files with a similar prefix.
    for (final old in _oldArchives()) {
      try {
        await old.delete();
      } catch (_) {
        // The new fixed-name archive is already safe.
      }
    }
  }

  @override
  Future<List<int>?> read() async {
    for (final file in [
      File('${dir.path}/$autoBackupName'),
      ..._oldArchives(),
      File('${dir.path}/$autoBackupLegacyJson')
    ]) {
      try {
        if (await file.exists()) return await file.readAsBytes();
      } catch (_) {
        // A missing or unreadable file must not hide older readable backups.
      }
    }
    return null;
  }

  @override
  Future<bool> exists() => File('${dir.path}/$autoBackupName').exists();
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
    return _fallback ??= DirBackupSink(
        Directory('${(await getApplicationDocumentsDirectory()).path}/backup'));
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (_broken) return (await _fb()).write(bytes);
    try {
      await _ch.invokeMethod<int>(
          'write', bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
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

  @override
  Future<bool> exists() async {
    if (_broken) return (await _fb()).exists();
    try {
      return await _ch.invokeMethod<bool>('exists') ?? false;
    } on MissingPluginException {
      _broken = true;
      return (await _fb()).exists();
    } on PlatformException {
      return (await _fb()).exists();
    }
  }
}

/// Where the full zip backup lands. Same two shapes as [BackupSink]: the
/// MediaStore one survives an uninstall, the directory one is the fallback
/// and the test seam.
abstract class FullBackupSink {
  Future<void> write(Uint8List bytes);
  Future<Uint8List?> read();
  Future<bool> exists();
}

class DirFullBackupSink implements FullBackupSink {
  DirFullBackupSink(this.dir);

  final Directory dir;

  File get _file => File('${dir.path}/paradise_full.zip');

  @override
  Future<void> write(Uint8List bytes) async {
    if (!await dir.exists()) await dir.create(recursive: true);
    await _file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> read() async {
    final f = _file;
    if (!await f.exists()) return null;
    try {
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> exists() => _file.exists();
}

class MediaStoreFullBackupSink implements FullBackupSink {
  static const _ch = MethodChannel('paradise/backup');

  FullBackupSink? _fallback;
  bool _broken = false;

  Future<FullBackupSink> _fb() async {
    return _fallback ??= DirFullBackupSink(Directory('${(await getApplicationDocumentsDirectory()).path}/backup'));
  }

  @override
  Future<void> write(Uint8List bytes) async {
    if (_broken) return (await _fb()).write(bytes);
    try {
      await _ch.invokeMethod<int>('writeFull', bytes);
    } on MissingPluginException {
      _broken = true;
      return (await _fb()).write(bytes);
    } on PlatformException {
      return (await _fb()).write(bytes);
    }
  }

  @override
  Future<Uint8List?> read() async {
    if (_broken) return (await _fb()).read();
    try {
      return await _ch.invokeMethod<Uint8List>('readFull');
    } on MissingPluginException {
      _broken = true;
      return (await _fb()).read();
    } on PlatformException {
      return (await _fb()).read();
    }
  }

  @override
  Future<bool> exists() async {
    if (_broken) return (await _fb()).exists();
    try {
      return await _ch.invokeMethod<bool>('existsFull') ?? false;
    } on MissingPluginException {
      _broken = true;
      return (await _fb()).exists();
    } on PlatformException {
      return (await _fb()).exists();
    }
  }
}
