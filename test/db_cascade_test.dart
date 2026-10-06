import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/db.dart';
import 'package:paradise/data/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Repro for the parent-table REPLACE + FK cascade delete hazard.
///
/// messages.chat_id REFERENCES chats(id) ON DELETE CASCADE. SQLite's
/// ConflictAlgorithm.replace is "INSERT OR REPLACE", which under
/// foreign_keys=ON *deletes* the conflicting chats row first, and the cascade
/// wipes every messages row of that chat before the new head row lands.
/// The saveChat transaction then re-inserts the surviving rows (full
/// rewrite), so the net effect is hidden — but the incremental path only
/// writes the dirty rows, so a head-only flush (dirty == {}) must lose every
/// message of the chat.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ChatDb db;

  setUp(() async {
    db = await ChatDb.open(path: inMemoryDatabasePath);
  });

  tearDown(() => db.close());

  Chat chat(String id) => Chat(id: id, persona: Persona(name: 'p$id', prompt: 'x', color: 0));

  Msg msg(String text) => Msg(id: text, out: false, text: text, time: 1);

  test('head-only flush (dirty == {}) does not lose the message rows', () async {
    final c = chat('a');
    for (var i = 0; i < 5; i++) {
      c.msgs.add(msg('m$i'));
    }
    await db.saveChat(c, 0, msgs: c.msgs);

    // A draft keystroke writes only the head.
    c.draft = 'typed';
    await db.saveChat(c, 0, msgs: c.msgs, dirty: const <int>{});

    final page = await db.page('a', 0, 30);
    expect(page.length, 5, reason: 'a head-only write must not cascade the messages away');
    expect((await db.loadChats()).single.draft, 'typed');
  });

  test('incremental row flush does not lose the untouched rows', () async {
    final c = chat('a');
    for (var i = 0; i < 5; i++) {
      c.msgs.add(msg('m$i'));
    }
    await db.saveChat(c, 0, msgs: c.msgs);

    c.msgs[2].text = 'changed';
    await db.saveChat(c, 0, msgs: c.msgs, dirty: const {2});

    final page = await db.page('a', 0, 30);
    expect(page.length, 5, reason: 'the chats REPLACE must not cascade the whole history away');
    expect(page[2].text, 'changed');
  });
}
