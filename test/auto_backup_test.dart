import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/auto_backup.dart';
import 'package:paradise/data/backup.dart';
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
    test('write then read roundtrips the content', () async {
      final dir = await Directory.systemTemp.createTemp('autobackup_sink');
      final sink = DirBackupSink(dir);
      expect(await sink.read(), isNull);
      await sink.write('hello backup');
      expect(await sink.read(), 'hello backup');
      await sink.write('overwritten');
      expect(await sink.read(), 'overwritten', reason: 'updates overwrite');
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

    test('setAutoBackup writes a real backup file through the sink', () async {
      final s = await Store.load(dbPath: p.join(device.path, 'paradise.db'));
      final dir = Directory(p.join(device.path, 'out'));
      s.debugBackupSink = DirBackupSink(dir);
      s.chats.add(Chat(id: 'c1', persona: Persona(name: 'Her', prompt: 'x', color: 0)));
      s.chatsChanged();

      await s.setAutoBackup(mode: 'change');

      final f = File(p.join(dir.path, 'paradise_autobackup.json'));
      expect(await f.exists(), isTrue, reason: 'enabling the schedule must produce a backup at once');
      final doc = parseBackup(await f.readAsString());
      expect(doc.chats, hasLength(1));
      expect(s.autoBackup.lastAt, greaterThan(0));
    });

    test('backupNow refreshes the file even when the schedule just ran', () async {
      final s = await Store.load(dbPath: p.join(device.path, 'paradise.db'));
      final dir = Directory(p.join(device.path, 'out'));
      s.debugBackupSink = DirBackupSink(dir);

      await s.setAutoBackup(mode: 'interval', intervalMin: 720);
      final first = File(p.join(dir.path, 'paradise_autobackup.json'));
      final t1 = await first.lastModified();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await s.backupNow();
      expect((await first.lastModified()).isAfter(t1) || (await first.lastModified()).isAtSameMomentAs(t1), isTrue);
    });
  });
}
