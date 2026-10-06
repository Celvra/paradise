import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/db.dart';
import 'package:paradise/data/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// The surface sqflite's own ffi backend is built on, so a test can wrap it.
import 'package:sqflite_common_ffi/src/sqflite_import.dart'
    show SqfliteInvokeHandler, buildDatabaseFactory;

/// Open-time pragmas, and the Android rules that govern them.
///
/// The bug these lock down: __ `PRAGMA journal_mode = WAL` answers with a row,
/// and Android's `SQLiteDatabase.execSQL` refuses any statement that returns
/// rows. Running it through `db.execute()` therefore threw inside
/// `onConfigure`, `openDatabase` closed the connection, and `ChatDb.open`
/// failed. Since the legacy chat blob is deleted once it has been migrated,
/// `_loadChats` had nothing left to fall back on and the app came up with an
/// empty chat list while every message sat unread in the database.
///
/// None of that is reproducible with the ffi backend on its own: its `execute`
/// is happy to run a statement that returns rows, so every other test in this
/// suite passes either way. These do not; they reproduce the platform rule.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  final real = databaseFactoryFfi as SqfliteInvokeHandler;

  /// The statements Android rejects through `execute`, i.e. the ones that
  /// produce a result set. journal_mode is the one this codebase sets that
  /// answers with a row; a new pragma that does would be added here.
  ///
  /// Only the rows-returning one is rejected by default, which is what Android
  /// actually does. `PRAGMA user_version`, for instance, sqflite runs itself to
  /// track the schema and it answers with a row too, but it goes through the
  /// plugin's own query path and never hits this.
  const onConfigurePragmas = [
    'foreign_keys',
    'journal_mode',
    'synchronous',
    'busy_timeout',
    'wal_autocheckpoint',
    'journal_size_limit',
    'cache_size',
  ];

  String? pragmaName(String sql) {
    final m = RegExp(r'^\s*pragma\s+([a-z_]+)', caseSensitive: false).firstMatch(sql);
    return m?.group(1)?.toLowerCase();
  }

  bool answersWithARow(String sql) => pragmaName(sql) == 'journal_mode';

  String? pragmaOf(Object? arguments) {
    if (arguments is! Map) return null;
    for (final v in arguments.values) {
      if (v is String && pragmaName(v) != null) return v;
    }
    return null;
  }

  /// The ffi factory, but with Android's execSQL rule applied to `execute`.
  /// [allOnConfigure] widens it from the row-returning pragma to every pragma
  /// `onConfigure` sets, which is the harsher device the guards there are for.
  DatabaseFactory androidStrict({bool allOnConfigure = false}) => buildDatabaseFactory(
        tag: allOnConfigure ? 'android-strict-all' : 'android-strict',
        invokeMethod: (method, [arguments]) {
          // 'execute' is methodExecute from sqflite's own protocol; the name is
          // spelled out rather than imported because the constant lives on an
          // internal library.
          if (method == 'execute') {
            final sql = pragmaOf(arguments);
            final name = sql == null ? null : pragmaName(sql);
            if (sql != null && (allOnConfigure ? onConfigurePragmas.contains(name) : answersWithARow(sql))) {
              throw Exception(
                'unknown error (code 0 SQLITE_OK): Queries can be performed '
                'using SQLiteDatabase query or rawQuery methods only.',
              );
            }
          }
          return real.invokeMethod(method, arguments);
        },
      );

  Chat chat(String id) => Chat(id: id, persona: Persona(name: 'p', prompt: 'x', color: 0));
  Msg msg(String text) => Msg(id: text, out: false, text: text, time: 1);

  group('android strict execSQL', () {
    test('the stand in really does reject a row-returning pragma', () async {
      // without this the two tests below could pass against a factory that
      // rejects nothing, and prove nothing
      final db = await androidStrict().openDatabase(inMemoryDatabasePath);
      await expectLater(
        () => db.execute('PRAGMA journal_mode = WAL'),
        throwsA(isA<Exception>()),
      );
      // and a pragma that answers with nothing still goes through execute
      await db.execute('PRAGMA foreign_keys = ON');
      await db.close();
    });

    test('the database opens and the history survives', () async {
      final dir = await Directory.systemTemp.createTemp('chatdb-open');
      final path = '${dir.path}/paradise.db';
      databaseFactory = androidStrict();
      try {
        final db = await ChatDb.open(path: path);
        await db.saveChat(chat('a'), 0, msgs: [msg('one'), msg('two')]);
        await db.close();

        // a second open is what a relaunch does, and it is the one that used to
        // hand back nothing
        final again = await ChatDb.open(path: path);
        final chats = await again.loadChats();
        expect(chats, hasLength(1));
        expect(chats.first.id, 'a');
        expect(await again.loadMsgs('a'), hasLength(2));
        await again.close();
      } finally {
        databaseFactory = databaseFactoryFfi;
        await dir.delete(recursive: true);
      }
    });

    test('a device that rejects the tuning pragmas still reaches the history', () async {
      final dir = await Directory.systemTemp.createTemp('chatdb-open');
      final path = '${dir.path}/paradise.db';
      databaseFactory = androidStrict(allOnConfigure: true);
      try {
        final db = await ChatDb.open(path: path);
        await db.saveChat(chat('b'), 0, msgs: [msg('kept')]);
        await db.close();

        final again = await ChatDb.open(path: path);
        expect(await again.loadMsgs('b'), hasLength(1));
        await again.close();
      } finally {
        databaseFactory = databaseFactoryFfi;
        await dir.delete(recursive: true);
      }
    });

    test('being tolerant does not mean the settings were dropped', () async {
      // Tolerating a refused pragma is only acceptable if the ones that do land
      // still land, so read them back the way the connection contract is read
      // back anywhere else. On a file, not in memory: an in-memory database can
      // only ever report journal_mode = memory.
      final dir = await Directory.systemTemp.createTemp('chatdb-open');
      databaseFactory = androidStrict();
      try {
        final db = await ChatDb.open(path: '${dir.path}/paradise.db');
        addTearDown(db.close);
        expect(await db.pragma('journal_mode'), 'wal');
        expect(await db.pragma('synchronous'), 1);
        expect(await db.pragma('foreign_keys'), 1);
      } finally {
        databaseFactory = databaseFactoryFfi;
        await dir.delete(recursive: true);
      }
    });

    test('the stand in models the platform, not our own mistake', () {
      // Guards the guard. A fixture that refuses the wrong statements passes
      // for a reason that has nothing to do with Android, and then proves
      // nothing, so the predicate it refuses on is pinned here.
      expect(answersWithARow('PRAGMA journal_mode = WAL'), isTrue);
      expect(answersWithARow('PRAGMA journal_mode'), isTrue);
      expect(answersWithARow('PRAGMA synchronous = NORMAL'), isFalse);
      expect(answersWithARow('PRAGMA foreign_keys = ON'), isFalse);
      expect(answersWithARow('PRAGMA busy_timeout = 5000'), isFalse);
      expect(answersWithARow('CREATE TABLE t (id TEXT)'), isFalse);
    });
  });
}