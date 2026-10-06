import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The structural changes a chat can go through, each one checked against a
/// real reload. Every one of these has to end with the database matching the
/// list that was on screen, because a row that survives a delete is a message
/// the user thought they removed coming back on the next launch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final tempDirs = <Directory>[];
  Directory device = Directory.systemTemp;

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 500));

  setUp(() async {
    device = await Directory.systemTemp.createTemp('store_struct_test');
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

  Future<Store> boot() => Store.load(dbPath: '${device.path}\\paradise.db');

  /// Fills a chat with [n] messages and waits for them to land on disk.
  Future<Store> seeded(int n) async {
    final s = await boot();
    final c = s.createChat('a', 'x');
    for (var i = 0; i < n; i++) {
      c.msgs.add(Msg(id: 'm$i', out: false, text: 'body $i', time: i + 1));
    }
    c.touch();
    await settle();
    return s;
  }

  test('deleting a message removes its row, not just its list entry', () async {
    final s = await seeded(6);
    final c = s.chats.single;
    expect(c.msgs.length, 6);

    s.deleteMsg(c, c.msgs[2]);
    expect(c.msgs.length, 5, reason: 'the list is the source of truth on screen');
    await settle();

    final again = await boot();
    final reloaded = again.chats.single;
    expect(reloaded.msgs.length, 5,
        reason: 'a deleted message must not come back on the next launch');
    expect(reloaded.msgs.map((m) => m.text).toList(),
        ['body 0', 'body 1', 'body 3', 'body 4', 'body 5'],
        reason: 'the survivors must keep their order and their text');
  });

  test('deleting the last message removes its row', () async {
    final s = await seeded(3);
    final c = s.chats.single;

    s.deleteMsg(c, c.msgs.last);
    await settle();

    final again = await boot();
    expect(again.chats.single.msgs.map((m) => m.text).toList(), ['body 0', 'body 1']);
  });

  test('a message appended after a delete is still written', () async {
    final s = await seeded(4);
    final c = s.chats.single;

    s.deleteMsg(c, c.msgs[1]);
    c.msgs.add(Msg(id: 'later', out: true, text: 'later', time: 99));
    c.touch();
    await settle();

    final again = await boot();
    expect(again.chats.single.msgs.map((m) => m.text).toList(),
        ['body 0', 'body 2', 'body 3', 'later']);
  });
}
