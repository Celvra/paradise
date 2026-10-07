import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Automatic backup policy and the place it writes to.
///
/// The policy is deliberately pure: [AutoBackup] decides *when*, the store
/// decides *what* (it owns exportBackupString) and a [BackupSink] decides
/// *where*. All three can be tested without each other.
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
abstract class BackupSink {
  Future<void> write(String content);
  Future<String?> read();
}

class DirBackupSink implements BackupSink {
  DirBackupSink(this.dir);

  final Directory dir;

  File get _file => File('${dir.path}/paradise_autobackup.json');

  @override
  Future<void> write(String content) async {
    if (!await dir.exists()) await dir.create(recursive: true);
    await _file.writeAsString(content, flush: true);
  }

  @override
  Future<String?> read() async {
    final f = _file;
    if (!await f.exists()) return null;
    try {
      return await f.readAsString();
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
  Future<void> write(String content) async {
    if (_broken) return (await _fb()).write(content);
    try {
      await _ch.invokeMethod<int>('write', content);
    } on MissingPluginException {
      _broken = true;
      return (await _fb()).write(content);
    } on PlatformException {
      // MediaStore refused (old api, revoked collection...): keep a private
      // copy rather than no copy
      return (await _fb()).write(content);
    }
  }

  @override
  Future<String?> read() async {
    if (_broken) return (await _fb()).read();
    try {
      final s = await _ch.invokeMethod<String>('read');
      return s;
    } on MissingPluginException {
      _broken = true;
      return (await _fb()).read();
    } on PlatformException {
      return (await _fb()).read();
    }
  }
}
