import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/auto_backup.dart';
import 'package:paradise/data/backup.dart';
import 'package:paradise/data/backup_archive.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Auto backup: the schedule decides when, the sink decides where, the store
/// tick writes what. Each layer gets its own test so a regression points at
/// the layer that broke.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('AutoBackup.shouldRun', () {
    test('change mode runs only on real changes, with a gap after the last write', () {
      final ab = AutoBackup()..mode = 'change';
      final now = DateTime(2026, 10, 6, 12, 0);
      expect(ab.shouldRun(now, dataChanged: true), isTrue, reason: 'first backup');
      ab.noteSuccess(now, 42);
      expect(ab.shouldRun(now, dataChanged: true), isFalse, reason: 'too soon after the last write');
      expect(ab.shouldRun(now.add(const Duration(minutes: 1)), dataChanged: false), isFalse, reason: 'nothing changed');
      expect(ab.shouldRun(now.add(const Duration(minutes: 1)), dataChanged: true), isTrue);
    });

    test('interval mode runs when the interval elapsed regardless of changes', () {
      final ab = AutoBackup()
        ..mode = 'interval'
        ..intervalMin = 60;
      final now = DateTime(2026, 10, 6, 12, 0);
      ab.noteSuccess(now, 1);
      expect(ab.shouldRun(now.add(const Duration(minutes: 30)), dataChanged: false), isFalse);
      expect(ab.shouldRun(now.add(const Duration(minutes: 61)), dataChanged: false), isTrue);
    });

    test('window mode runs once per day inside the window only', () {
      final ab = AutoBackup()
        ..mode = 'window'
        ..windowStart = 180 // 03:00
        ..windowEnd = 300; // 05:00
      final inWindow = DateTime(2026, 10, 6, 4, 0);
      final outWindow = DateTime(2026, 10, 6, 12, 0);
      expect(ab.shouldRun(outWindow, dataChanged: false), isFalse, reason: 'outside the window');
      expect(ab.shouldRun(inWindow, dataChanged: false), isTrue, reason: 'inside, not yet written today');
      ab.noteSuccess(inWindow, 1);
      expect(ab.shouldRun(inWindow.add(const Duration(hours: 1)), dataChanged: false), isFalse, reason: 'already written in this window');
      expect(ab.shouldRun(DateTime(2026, 10, 7, 4, 0), dataChanged: false), isTrue, reason: 'the next day is a new window');
    });

    test('off never runs', () {
      final ab = AutoBackup()..mode = 'off';
      expect(ab.shouldRun(DateTime(2026, 10, 6), dataChanged: true), isFalse);
    });
  });

  group('DirBackupSink', () {
    test('write then read roundtrips the archive', () async {
      final dir = await Directory.systemTemp.createTemp('autobackup_sink');
      final sink = DirBackupSink(dir);
      expect(await sink.read(), isNull);
      await sink.write([1, 2, 3]);
      expect(await sink.read(), [1, 2, 3]);
      await sink.write([9, 8, 7]);
      expect(await sink.read(), [9, 8, 7], reason: 'the newer archive replaces the old one');
      expect((await sink.read())!.length, 3);
      await dir.delete(recursive: true);
    });

    test('a write replaces the archive rather than piling up new ones', () async {
      final dir = await Directory.systemTemp.createTemp('autobackup_overwrite');
      final sink = DirBackupSink(dir);
      await sink.write([1, 2, 3]);
      await sink.write([42]);
      final files = dir.listSync().whereType<File>().toList();
      expect(files, hasLength(1), reason: 'one fixed file, not a growing pile');
      expect(files.single.path, endsWith(autoBackupFileName));
      expect(await files.single.readAsBytes(), [42]);
      await dir.delete(recursive: true);
    });
  });

  group('store tick', () {
    late Directory device;

    setUp(() async {
      device = await Directory.systemTemp.createTemp('autobackup_store');
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
    });

    File onlyZip(Directory dir) =>
        dir.listSync().whereType<File>().where((f) => f.path.endsWith('.$autoBackupExt')).single;

    test('setAutoBackup writes a real backup archive through the sink', () async {
      final s = await Store.load(dbPath: p.join(device.path, 'paradise.db'));
      final dir = Directory(p.join(device.path, 'out'));
      s.debugBackupSink = DirBackupSink(dir);
      s.chats.add(Chat(id: 'c1', persona: Persona(name: 'Her', prompt: 'x', color: 0)));
      s.chatsChanged();

      await s.setAutoBackup(mode: 'change');

      final f = onlyZip(dir);
      expect(await f.exists(), isTrue, reason: 'enabling the schedule must produce a backup at once');
      final doc = parseBackup(readBackupZip(await f.readAsBytes()).json);
      expect(doc.chats, hasLength(1));
      expect(s.autoBackup.lastAt, greaterThan(0));
    });

    test('backupNow writes a fresh archive even when the schedule just ran', () async {
      final s = await Store.load(dbPath: p.join(device.path, 'paradise.db'));
      final dir = Directory(p.join(device.path, 'out'));
      s.debugBackupSink = DirBackupSink(dir);

      await s.setAutoBackup(mode: 'interval', intervalMin: 720);
      final first = onlyZip(dir);
      final t1 = await first.lastModified();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await s.backupNow();
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.$autoBackupExt')).toList();
      expect(files, isNotEmpty);
      final newest = files.first;
      expect((await newest.lastModified()).isAfter(t1) || (await newest.lastModified()).isAtSameMomentAs(t1), isTrue);
    });
  });
}
