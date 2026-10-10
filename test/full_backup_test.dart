import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/full_backup.dart';
import 'package:paradise/data/auto_backup.dart' show fullBackupName;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// The full snapshot is the one backup that must scale to the whole data
/// directory: a workspace environment under docs is gigabytes, so the build
/// streams file by file into a zip on disk instead of holding the archive in
/// the heap, and the ticks that trigger it cannot afford to also fold the
/// previous snapshot back in.
void main() {
  group('buildToFile', () {
    late Directory docs;
    late Directory dbDir;
    late Directory tmp;

    setUp(() async {
      docs = await Directory.systemTemp.createTemp('fullbackup_docs');
      dbDir = await Directory.systemTemp.createTemp('fullbackup_db');
      tmp = await Directory.systemTemp.createTemp('fullbackup_tmp');
    });

    tearDown(() async {
      for (final d in [docs, dbDir, tmp]) {
        try {
          await d.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('carries the docs tree, the database and a prefs dump', () async {
      await File(p.join(docs.path, 'paradise.db-note.txt')).writeAsString('hi');
      await Directory(p.join(docs.path, 'avatars')).create();
      await File(p.join(docs.path, 'avatars', 'a.png')).writeAsBytes([1, 2, 3, 4]);
      await File(p.join(dbDir.path, 'paradise.db')).writeAsBytes(List.filled(64, 7));
      await File(p.join(dbDir.path, 'paradise.db-wal')).writeAsBytes([9, 9]);

      final zip = await FullBackup.buildToFile(
        docs: docs,
        dbDir: dbDir,
        prefs: const {'apiKey': 'sk-test', 'theme': 2},
        tmp: tmp,
      );

      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final names = archive.files.where((f) => f.isFile).map((f) => f.name).toSet();
      expect(names, contains(FullBackup.prefsEntry));
      expect(names, contains('docs/paradise.db-note.txt'));
      expect(names, contains('docs/avatars/a.png'));
      expect(names, contains('db/paradise.db'));
      expect(names, contains('db/paradise.db-wal'));
      expect(names, isNot(contains('db/paradise.db-shm')));

      final prefs = archive.files.firstWhere((f) => f.name == FullBackup.prefsEntry);
      expect(jsonDecode(utf8.decode(prefs.content)), {'apiKey': 'sk-test', 'theme': 2});
    });

    test('a large file streams through without buffering it whole', () async {
      // an in-memory Archive would need these bytes twice (raw + zip); the
      // streaming encoder writes straight to the temp file, so a 32MB entry
      // costs a buffer, not 64MB of heap
      final big = File(p.join(docs.path, 'big.bin'));
      final rnd = math.Random(7);
      final bytes = List<int>.generate(32 * 1024 * 1024, (_) => rnd.nextInt(256));
      await big.writeAsBytes(bytes, flush: true);

      final zip = await FullBackup.buildToFile(docs: docs, dbDir: dbDir, prefs: {}, tmp: tmp);

      expect(await zip.exists(), isTrue);
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final entry = archive.files.firstWhere((f) => f.name == 'docs/big.bin');
      expect(entry.size, bytes.length);
      expect(entry.content.length, bytes.length, reason: 'random bytes come back whole');
    });

    test('the previous snapshot is never folded into the next one', () async {
      final backupDir = Directory(p.join(docs.path, 'backup'));
      await backupDir.create();
      await File(p.join(backupDir.path, fullBackupName)).writeAsBytes(List.filled(4096, 1));
      await File(p.join(backupDir.path, 'paradise_autobackup.json')).writeAsString('{}');

      final zip = await FullBackup.buildToFile(docs: docs, dbDir: dbDir, prefs: {}, tmp: tmp);

      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      expect(archive.files.where((f) => f.isFile).map((f) => f.name),
          isNot(anyOf(contains(fullBackupName), contains('paradise_autobackup.json'))));
    });

    test('isBackupArtifact only matches our own outputs', () {
      expect(FullBackup.isBackupArtifact('backup/paradise_full.zip'), isTrue);
      expect(FullBackup.isBackupArtifact('backup/paradise_full-1700000000.zip'), isTrue);
      expect(FullBackup.isBackupArtifact('backup/paradise_autobackup.json'), isTrue);
      expect(FullBackup.isBackupArtifact('backup/keep_me.txt'), isFalse);
      expect(FullBackup.isBackupArtifact('paradise_full_notes.md'), isFalse,
          reason: 'a user file that merely starts with the prefix is not an artifact');
      expect(FullBackup.isBackupArtifact('workspace/environments/arch/rootfs/libc.so'), isFalse);
    });
  });

  group('runFullBackupJob', () {
    test('builds from paths and a prefs dump, as an isolate would', () async {
      final docs = await Directory.systemTemp.createTemp('fullbackup_job_docs');
      final dbDir = await Directory.systemTemp.createTemp('fullbackup_job_db');
      final tmp = await Directory.systemTemp.createTemp('fullbackup_job_tmp');
      try {
        await File(p.join(docs.path, 'note.txt')).writeAsString('one');
        await File(p.join(dbDir.path, 'paradise.db')).writeAsBytes([1, 2]);
        final zip = await runFullBackupJob(FullBackupJob(
          docsPath: docs.path,
          dbDirPath: dbDir.path,
          tmpPath: tmp.path,
          prefs: {'k': 'v'},
        ));
        expect(zip, isNotNull);
        final archive = ZipDecoder().decodeBytes(await zip!.readAsBytes());
        final names = archive.files.where((f) => f.isFile).map((f) => f.name).toSet();
        expect(names, containsAll({'docs/note.txt', 'db/paradise.db', FullBackup.prefsEntry}));
      } finally {
        for (final d in [docs, dbDir, tmp]) {
          try {
            await d.delete(recursive: true);
          } catch (_) {}
        }
      }
    });
  });

  group('restore', () {
    test('puts files and prefs back exactly', () async {
      final docs = await Directory.systemTemp.createTemp('fullbackup_src_docs');
      final dbDir = await Directory.systemTemp.createTemp('fullbackup_src_db');
      final tmp = await Directory.systemTemp.createTemp('fullbackup_src_tmp');
      final targetDocs = await Directory.systemTemp.createTemp('fullbackup_dst_docs');
      final targetDb = await Directory.systemTemp.createTemp('fullbackup_dst_db');
      try {
        await File(p.join(docs.path, 'hello.txt')).writeAsString('world');
        await File(p.join(dbDir.path, 'paradise.db')).writeAsBytes([4, 5, 6]);
        await File(p.join(dbDir.path, 'paradise.db-wal')).writeAsBytes([7, 8]);

        final zip = await FullBackup.buildToFile(
          docs: docs,
          dbDir: dbDir,
          prefs: {'token': 'abc', 'count': 3},
          tmp: tmp,
        );

        SharedPreferences.setMockInitialValues({'stale': 'gone'});
        final sp = await SharedPreferences.getInstance();
        final n = await FullBackup.restore(await zip.readAsBytes(), docs: targetDocs, dbDir: targetDb, sp: sp);
        expect(n, 3, reason: 'hello + db + wal; the prefs ride outside the count');
        expect(await File(p.join(targetDocs.path, 'hello.txt')).readAsString(), 'world');
        expect(await File(p.join(targetDb.path, 'paradise.db')).readAsBytes(), [4, 5, 6]);
        expect(await File(p.join(targetDb.path, 'paradise.db-wal')).readAsBytes(), [7, 8]);
        expect(await File(p.join(targetDocs.path, FullBackup.prefsEntry)).exists(), isFalse);
        expect(sp.getString('token'), 'abc');
        expect(sp.getInt('count'), 3);
        expect(sp.containsKey('stale'), isFalse, reason: 'exact restore drops unknown keys');
      } finally {
        for (final d in [docs, dbDir, tmp, targetDocs, targetDb]) {
          try {
            await d.delete(recursive: true);
          } catch (_) {}
        }
      }
    });
  });
}
