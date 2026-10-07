import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/full_backup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('build then restore round trips docs, database and prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    await sp.setString('paradise.key.deepseek', 'sk-secret');
    await sp.setBool('dark', true);
    await sp.setStringList('recentEmoji', ['😋', '🎉']);

    final dirs = <Directory>[];
    Future<Directory> temp(String name) async {
      final d = await Directory.systemTemp.createTemp(name);
      dirs.add(d);
      return d;
    }

    addTearDown(() async {
      for (final d in dirs) {
        try {
          await d.delete(recursive: true);
        } catch (_) {}
      }
    });

    // the "old install"
    final srcDocs = await temp('fb-src-docs');
    final srcDb = await temp('fb-src-db');
    await File('${srcDocs.path}/personas.json').writeAsString('[{"id":"p1"}]');
    await Directory('${srcDocs.path}/avatars').create();
    await File('${srcDocs.path}/avatars/a.png').writeAsBytes([1, 2, 3]);
    // a stale private fallback copy must not ride along
    await Directory('${srcDocs.path}/backup').create();
    await File('${srcDocs.path}/backup/paradise_autobackup.json').writeAsString('{}');
    await File('${srcDb.path}/paradise.db').writeAsBytes([9, 9, 9]);
    await File('${srcDb.path}/paradise.db-wal').writeAsBytes([8]);

    final zip = await FullBackup.build(docs: srcDocs, dbDir: srcDb, sp: sp);
    expect(zip.length, greaterThan(0));

    // the "new install": same prefs object, mutated to prove the restore
    // overwrites instead of merging
    await sp.setString('paradise.key.deepseek', 'changed');
    await sp.setInt('stale_key', 1);
    final dstDocs = await temp('fb-dst-docs');
    final dstDb = await temp('fb-dst-db');

    final n = await FullBackup.restore(zip, docs: dstDocs, dbDir: dstDb, sp: sp);
    // personas.json, avatars/a.png, paradise.db, paradise.db-wal; the prefs
    // entry and the skipped private fallback do not count
    expect(n, 4);
    expect(await File('${dstDocs.path}/personas.json').readAsString(), '[{"id":"p1"}]');
    expect(await File('${dstDocs.path}/avatars/a.png').readAsBytes(), [1, 2, 3]);
    expect(await File('${dstDb.path}/paradise.db').readAsBytes(), [9, 9, 9]);
    expect(await File('${dstDb.path}/paradise.db-wal').readAsBytes(), [8]);
    expect(await Directory('${dstDocs.path}/backup').exists(), isFalse);
    expect(sp.getString('paradise.key.deepseek'), 'sk-secret');
    expect(sp.getBool('dark'), isTrue);
    expect(sp.getStringList('recentEmoji'), ['😋', '🎉']);
    expect(sp.containsKey('stale_key'), isFalse);
  });

  test('zip slip entries never leave the target directory', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final archive = Archive()
      ..addFile(ArchiveFile('../../evil.txt', 4, utf8.encode('evil')))
      ..addFile(ArchiveFile('/abs.txt', 3, utf8.encode('abs')))
      ..addFile(ArchiveFile('docs/ok.txt', 2, utf8.encode('ok')));
    final zip = ZipEncoder().encodeBytes(archive);

    final dstDocs = await Directory.systemTemp.createTemp('fb-slip-docs');
    final dstDb = await Directory.systemTemp.createTemp('fb-slip-db');
    addTearDown(() async {
      try {
        await dstDocs.delete(recursive: true);
      } catch (_) {}
      try {
        await dstDb.delete(recursive: true);
      } catch (_) {}
      try {
        await File('${dstDocs.parent.path}/evil.txt').delete();
      } catch (_) {}
    });

    final n = await FullBackup.restore(zip, docs: dstDocs, dbDir: dstDb, sp: sp);
    expect(n, 1);
    expect(await File('${dstDocs.path}/ok.txt').readAsString(), 'ok');
    expect(await File('${dstDocs.parent.path}/evil.txt').exists(), isFalse);
  });
}
