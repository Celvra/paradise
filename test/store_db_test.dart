import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The store on SQLite: the automatic upgrade from the legacy blob, and the
/// per chat flush that replaces the one whole list rewrite.
///
/// Every test builds its own device: a temp directory holding the database
/// file, plus a mock preferences map. A boot on the same directory is a
/// restart of the same install, a boot on a fresh one is a second device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final tempDirs = <Directory>[];

  // The save is on a 400ms debounce, so a test that wants the flush has to
  // outlive it. A real wait, not a pump, because the flush is a plain Timer.
  Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 500));

  Directory device = Directory.systemTemp;
  Future<Store> boot(Map<String, Object> prefs, {String? path}) async {
    await flush(); // let a previous store's in flight save land or die
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues(prefs);
    return Store.load(dbPath: path ?? p.join(device.path, 'paradise.db'));
  }

  /// A restart of the same install: the preferences the last store wrote are
  /// carried over, the way a real device keeps them, while the database stays.
  Future<Store> restart() async {
    final sp = await SharedPreferences.getInstance();
    final carried = {for (final k in sp.getKeys()) k: sp.get(k)!};
    return boot(carried);
  }

  setUp(() async {
    device = await Directory.systemTemp.createTemp('store_db_test');
    tempDirs.add(device);
  });

  tearDownAll(() async {
    for (final dir in tempDirs) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  });

  final legacy = <String, Object>{
    'chats': jsonEncode([
      {
        'id': 'c1',
        'persona': {'name': 'Her', 'prompt': 'x', 'color': 0},
        'msgs': [
          {'id': 'm1', 'out': false, 'text': 'hello', 'time': 1},
          {'id': 'm2', 'out': true, 'text': 'hi', 'time': 2},
        ],
        'unread': 2,
      },
      {
        'id': 'c2',
        'persona': {'name': 'Him', 'prompt': 'y', 'color': 1},
        'msgs': <dynamic>[],
        'unread': 0,
      },
    ]),
  };

  test('a legacy blob is migrated, and the key is gone afterwards', () async {
    final s = await boot(legacy);

    expect(s.chats.map((c) => c.id), ['c1', 'c2']);
    // the history came along, into memory and into rows
    expect(s.chats.first.msgs.map((m) => m.text), ['hello', 'hi']);
    expect(SharedPreferences.getInstance().then((sp) => sp.getString('chats')), completion(isNull));
  });

  test('the upgrade survives a restart, and adds nothing on the way back', () async {
    final first = await boot(legacy);
    await flush();

    final second = await boot({});
    expect(second.chats.map((c) => c.id), first.chats.map((c) => c.id));
    expect(second.chats.first.msgs.map((m) => m.text), ['hello', 'hi']);
  });

  test('an interrupted upgrade finds the blob again and finishes the job', () async {
    // the blob back in prefs, as if a first attempt moved the chats across
    // and died before dropping the key: migrateFrom's replace inserts make
    // the second pass idempotent, and only then is the key removed
    await boot(legacy);
    await flush();
    SharedPreferences.getInstance().then((sp) => sp.setString('chats', legacy['chats']! as String));

    final second = await boot({});
    expect(second.chats.map((c) => c.id), containsAll(['c1', 'c2']));
    expect(second.chats.where((c) => c.id == 'c1'), hasLength(1));
    expect(second.chats.first.msgs, hasLength(2));
  });

  test('edits after the upgrade reach the database, one chat at a time', () async {
    final s = await boot(legacy);
    await flush();

    s.chats.last.msgs.add(Msg(id: 'm3', out: true, text: 'new', time: 3));
    s.chats.last.touch();
    await flush();

    // a fresh store over an empty prefs map: everything it has comes from the
    // database, so the message being there proves the row was written
    final again = await boot({});
    expect(again.chats.last.msgs.map((m) => m.text), ['new']);
    // the untouched chat kept its own history
    expect(again.chats.first.msgs.map((m) => m.text), ['hello', 'hi']);
  });

  test('deleting a chat takes its rows with it', () async {
    final s = await boot(legacy);
    await flush();

    s.deleteChat(s.chats.first);
    await flush();

    final again = await boot({});
    expect(again.chats.map((c) => c.id), ['c2']);
  });

  test('a user who deleted everything is not handed the starter chats', () async {
    await boot({'chats': '[]'});
    await flush();

    final again = await restart();
    expect(again.chats, isEmpty);
  });

  test('a true first launch starts empty and stays stable across restarts', () async {
    // starter chats moved into the onboarding, so a fresh store is empty; the
    // restart round trip must still keep whatever the user later creates
    final s = await boot({});
    expect(s.chats, isEmpty);
    s.createChat('Later', 'p');
    await flush();

    final again = await restart();
    expect(again.chats.single.persona.name, 'Later');
  });

  test('a new chat lands after the migrated ones', () async {
    final s = await boot(legacy);
    await flush();

    final c = s.createChat('Later', 'z');
    await flush();

    final again = await boot({});
    expect(again.chats.map((e) => e.id), ['c1', 'c2', c.id]);
  });

  test('without a database the blob path still works', () async {
    // an unusable path makes ChatDb.open throw, which is the stand in for a
    // platform where the plugin does not exist
    final fallback = await boot(legacy, path: '/dev/null/not/a/database.db');
    expect(fallback.chats.map((c) => c.id), ['c1', 'c2']);
    fallback.deleteChat(fallback.chats.first);
    await flush();
    expect(fallback.chats.map((c) => c.id), ['c2']);
  });
}
