import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/db.dart';
import 'package:paradise/data/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The database has to hold a chat history that SharedPreferences could not: a
/// few hundred thousand messages, written one at a time, read a page at a time.
void main() {
  setUpAll(() {
    // the ffi factory rather than the global openDatabase, so production code
    // stays free of a test only parameter
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ChatDb db;

  setUp(() async {
    // in memory, so each test starts empty and nothing touches the device
    db = await ChatDb.open(path: inMemoryDatabasePath);
  });

  tearDown(() => db.close());

  Chat chat(String id, {int unread = 0, String draft = ''}) => Chat(
        id: id,
        persona: Persona(name: 'p$id', prompt: 'x', color: 0),
        unread: unread,
        draft: draft,
      );

  Msg msg(String text) => Msg(id: text, out: false, text: text, time: 1);

  group('schema', () {
    test('a chat with no messages round trips its metadata', () async {
      await db.saveChat(chat('a', unread: 3, draft: 'hi'), 0);

      final loaded = await db.loadChats();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'a');
      expect(loaded.first.unread, 3);
      expect(loaded.first.draft, 'hi');
      expect(loaded.first.msgs, isEmpty);
      expect(await db.count('a'), 0);
    });

    test('messages round trip in order', () async {
      await db.saveChat(chat('a'), 0);
      for (var i = 0; i < 5; i++) {
        await db.putMsg('a', i.toDouble(), msg('m$i'));
      }

      final page = await db.page('a', 0, 10);
      expect(page.map((m) => m.text), ['m0', 'm1', 'm2', 'm3', 'm4']);
      expect(await db.count('a'), 5);
    });

    test('a page is a window, not the whole history', () async {
      await db.saveChat(chat('a'), 0);
      for (var i = 0; i < 1000; i++) {
        await db.putMsg('a', i.toDouble(), msg('m$i'));
      }

      expect((await db.page('a', 0, 10)).map((m) => m.text), ['m0', 'm1', 'm2', 'm3', 'm4', 'm5', 'm6', 'm7', 'm8', 'm9']);
      expect((await db.page('a', 500, 3)).map((m) => m.text), ['m500', 'm501', 'm502']);
      expect((await db.page('a', 995, 10)).map((m) => m.text), ['m995', 'm996', 'm997', 'm998', 'm999']);
      // past the end is empty rather than an error, the tail of a list is read
      // past its length all the time
      expect(await db.page('a', 1000, 10), isEmpty);
    });

    test('deleting a chat takes its messages with it', () async {
      // ON DELETE CASCADE, so any path that removes a chat cannot leak rows
      await db.saveChat(chat('a'), 0);
      await db.putMsg('a', 0, msg('x'));
      await db.deleteChat('a');

      expect(await db.loadChats(), isEmpty);
      expect(await db.count('a'), 0);
    });
  });

  group('ordinals', () {
    test('an append is bracketed by nothing on either side of the tail', () async {
      await db.saveChat(chat('a'), 0);
      // empty: nowhere to sit between
      expect(await db.bracket('a', 0), (null, null));

      await db.putMsg('a', 0, msg('only'));
      // the end of the list, so before is the last row and after is nothing
      expect(await db.bracket('a', 1), (0.0, null));
      // the front of the list, so nothing before and the first row after
      expect(await db.bracket('a', 0), (null, 0.0));
      expect(await db.lastOrd('a'), 0.0);
    });

    test('inserting into the middle splits the gap instead of shifting rows', () async {
      // this is the whole reason the ordinal is fractional: renumbering a long
      // history on every mid insert is the thing we are trying to avoid
      await db.saveChat(chat('a'), 0);
      await db.putMsg('a', 0, msg('first'));
      await db.putMsg('a', 1, msg('last'));

      final (before, after) = await db.bracket('a', 1);
      expect(before, 0.0);
      expect(after, 1.0);
      await db.putMsg('a', (before! + after!) / 2, msg('middle'));

      expect((await db.page('a', 0, 10)).map((m) => m.text), ['first', 'middle', 'last']);
    });

    test('renumbering makes the sequence dense again', () async {
      await db.saveChat(chat('a'), 0);
      await db.putMsg('a', 0, msg('a'));
      await db.putMsg('a', 0.5, msg('b'));
      await db.putMsg('a', 1, msg('c'));
      await db.renumber('a');

      final (before, after) = await db.bracket('a', 1);
      expect(before, 0.0);
      expect(after, 1.0);
      expect((await db.page('a', 0, 10)).map((m) => m.text), ['a', 'b', 'c']);
    });
  });

  group('migration', () {
    test('a preferences blob lands in the database', () async {
      final blob = jsonEncode([
        {
          'id': 'c1',
          'persona': {'name': 'p', 'prompt': 'x', 'color': 0},
          'msgs': [
            {'id': 'm1', 'out': false, 'text': 'hello', 'time': 1},
            {'id': 'm2', 'out': true, 'text': 'hi', 'time': 2},
          ],
          'unread': 2,
        },
        {
          'id': 'c2',
          'persona': {'name': 'q', 'prompt': 'y', 'color': 1},
          'msgs': <dynamic>[],
          'unread': 0,
        },
      ]);

      expect(await db.migrateFrom(blob), 2);
      final chats = await db.loadChats();
      expect(chats.map((c) => c.id), ['c1', 'c2']);
      expect(chats.first.unread, 2);
      expect((await db.page('c1', 0, 10)).map((m) => m.text), ['hello', 'hi']);
      expect(await db.count('c2'), 0);
    });

    test('a corrupt blob migrates nothing instead of throwing', () async {
      expect(await db.migrateFrom('{not json'), 0);
      expect(await db.loadChats(), isEmpty);
    });

    test('a record that is not a chat is skipped, not fatal', () async {
      // the old loader cleared every chat if one record failed, which is how a
      // single bad row used to cost the whole history
      final blob = jsonEncode([
        'garbage',
        {'no_id': true},
        {
          'id': 'c1',
          'persona': {'name': 'p', 'prompt': 'x', 'color': 0},
          'msgs': [
            'not a message',
            {'id': 'm1', 'out': false, 'text': 'kept', 'time': 1},
          ],
          'unread': 0,
        },
      ]);

      expect(await db.migrateFrom(blob), 1);
      expect((await db.page('c1', 0, 10)).map((m) => m.text), ['kept']);
    });
  });
}