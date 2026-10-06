import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Flush-timing guards for the bounded-staleness writer: a stream of changes
/// must flush mid-run rather than only at idle, and a head-only change must
/// neither lose message rows nor need to encode them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final tempDirs = <Directory>[];
  Directory device = Directory.systemTemp;

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 500));

  setUp(() async {
    device = await Directory.systemTemp.createTemp('store_flush_test');
    tempDirs.add(device);
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    for (final dir in tempDirs) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  });

  test('deltas every 50ms flush mid-stream, not only at the end', () async {
    final store = await Store.load(dbPath: device.path + '\\paradise.db');
    final c = store.createChat('a', 'x');
    c.msgs.add(Msg(id: 'seed', out: true, text: 'q', time: 0));
    await settle();

    // 24 touches at 50ms = 1.2s of steady pressure. The old reset debounce
    // (400ms restart per change) never fired under this pattern; a bounded
    // staleness writer must have written at least once before the end.
    for (var i = 0; i < 24; i++) {
      c.msgs.add(Msg(id: 'm$i', out: false, text: 'd$i', time: i + 1));
      c.touch();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await settle();

    final boot = await Store.load(dbPath: device.path + '\\paradise.db');
    final reloaded = boot.chats.firstWhere((x) => x.id == c.id);
    expect(reloaded.msgs.length, greaterThan(5),
        reason: 'the writer must flush during the stream, not only at idle');
  });

  test('a head-only change keeps the message rows and persists the draft', () async {
    final store = await Store.load(dbPath: device.path + '\\paradise.db');
    final c = store.createChat('a', 'x');
    for (var i = 0; i < 20; i++) {
      c.msgs.add(Msg(id: 'm$i', out: false, text: 'body $i', time: i));
    }
    await settle();

    c.draft = 'typed draft';
    c.touch();
    await settle();

    final boot = await Store.load(dbPath: device.path + '\\paradise.db');
    final reloaded = boot.chats.firstWhere((x) => x.id == c.id);
    expect(reloaded.draft, 'typed draft');
    expect(reloaded.msgs.length, 20, reason: 'a head write must not drop message rows');
  });
}
