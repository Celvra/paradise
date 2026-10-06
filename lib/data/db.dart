import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Message history on SQLite.
///
/// This used to be one SharedPreferences key holding the whole chat list as a
/// single json blob. Two things were wrong with that at scale, and both were
/// measured rather than guessed: every message rewrote the entire blob, so
/// encoding alone cost 478ms at 47 MiB and extrapolates to about ten seconds at
/// a gigabyte, and the blob was parsed in a try/catch that cleared every chat,
/// so one record that failed to parse threw away the lot.
///
/// The shape here is deliberately plain. A chat's metadata is one row, and its
/// messages are rows keyed by a fractional ordinal, so inserting into the middle
/// of a long history costs one row instead of renumbering everything after it.
class ChatDb {
  ChatDb._(this._db);

  final Database _db;

  static const _file = 'paradise.db';
  static const _version = 1;

  /// Pages SQLite keeps in the write-ahead log before it checkpoints back into
  /// the database file. Kelivo pins the same 1000-page cadence explicitly
  /// (`AppDatabase.walAutoCheckpointPages`) rather than trusting the default,
  /// so the cost of a checkpoint is a known quantity rather than a surprise
  /// during a streaming flush.
  static const _walAutoCheckpointPages = 1000;

  /// Ceiling on retained journal/WAL storage after a checkpoint. Kelivo's
  /// `journalSizeLimitBytes` is 16 MiB and this matches it: it is not a promise
  /// that a live WAL never exceeds the value, only that a checkpointed one does
  /// not keep the space.
  static const _journalSizeLimitBytes = 16 << 20;

  static const _busyTimeoutMillis = 5000;

  static Future<ChatDb> open({String? path}) async {
    final db = await openDatabase(
      path ?? _file,
      version: _version,
      onConfigure: (db) async {
        // Every pragma below is best effort, and they do not all go through the
        // same call. Both halves of that are load bearing.
        //
        // journal_mode answers with a row (the mode it settled on), and
        // Android's SQLiteDatabase.execSQL refuses any statement that returns
        // rows: `execute` throws "Queries can be performed using SQLiteDatabase
        // query or rawQuery methods only", onConfigure propagates it, and
        // openDatabase closes the connection. That took the whole database down
        // with it, and because the chat blob is deleted once it has been
        // migrated there was no fallback left, so the app came up with no
        // history at all — the data was on disk the whole time, unread.
        // rawQuery is the call that accepts a result set.
        //
        // Wrapped, all of them, because a device whose SQLite rejects a knob
        // must not lose the history over it. foreign_keys is the one that
        // costs something when it does not take (messages outlive their chat),
        // so it goes first and on its own; everything after it is tuning.
        //
        // onConfigure, not onCreate: foreign_keys is a no-op inside a
        // transaction and onCreate runs in one, so setting it there turns the
        // cascade off without saying so.
        try {
          await db.execute('PRAGMA foreign_keys = ON');
        } catch (_) {}
        // WAL is ported from kelivo's AppDatabase setup. The default rollback
        // journal fsyncs the journal and the database on every committing
        // transaction, and the store commits one chat per streaming flush, so
        // the default put a synchronous disk barrier in the path of every
        // checkpoint. Under WAL, `synchronous = NORMAL` still guarantees crash
        // consistency — a power loss can only drop transactions since the last
        // checkpoint, and the chat is rewritten in full by the next flush — so
        // it removes the per-write fsync without trading away the record.
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL');
        } catch (_) {}
        for (final p in const [
          'PRAGMA synchronous = NORMAL',
          'PRAGMA busy_timeout = $_busyTimeoutMillis',
          'PRAGMA wal_autocheckpoint = $_walAutoCheckpointPages',
          'PRAGMA journal_size_limit = $_journalSizeLimitBytes',
          // A 64 MiB page cache for the connection. The history is read whole
          // per chat, so a warmer cache turns a re-entered conversation into a
          // memory read instead of a set of page faults against the file.
          'PRAGMA cache_size = -65536',
        ]) {
          try {
            await db.execute(p);
          } catch (_) {}
        }
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE chats (
            id    TEXT PRIMARY KEY,
            ord   INTEGER NOT NULL,
            head  TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            chat_id TEXT    NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
            ord     REAL    NOT NULL,
            data    TEXT    NOT NULL,
            PRIMARY KEY (chat_id, ord)
          )
        ''');
      },
    );
    return ChatDb._(db);
  }

  Future<void> close() => _db.close();

  /// Reads a SQLite pragma back.
  ///
  /// Exposed so a test can prove the connection contract actually took effect.
  /// The pragmas are set in `onConfigure`, and a refactor that moved them
  /// somewhere a transaction cannot observe would otherwise revert to the
  /// default two-fsync commit with nothing failing. Kelivo reads its contract
  /// back the same way (`ChatDatabaseRepository` asserts journal_mode and
  /// synchronous after opening).
  Future<Object?> pragma(String name) async {
    final rows = await _db.rawQuery('PRAGMA $name');
    return rows.isEmpty ? null : rows.first.values.first;
  }

  // ---- chats -------------------------------------------------------------

  /// Loads every chat's metadata with its messages still unread.
  ///
  /// Ordering is by [ord], which is what the list was before, so the sidebar
  /// does not reshuffle itself the first time after the migration. A head that
  /// fails to parse is skipped rather than fatal: one bad row costs one chat,
  /// not the history, which is the failure that killed the blob loader.
  Future<List<Chat>> loadChats() async {
    final rows = await _db.query('chats', orderBy: 'ord ASC');
    final out = <Chat>[];
    for (final r in rows) {
      try {
        final head = jsonDecode(r['head']! as String) as Map<String, dynamic>;
        out.add(Chat.fromJson({...head, 'msgs': <dynamic>[]}));
      } catch (_) {}
    }
    return out;
  }

  /// The list position of every chat, keyed by id. [loadChats] returns chats
  /// already in this order; the caller keeps the number so a chat written
  /// later lands back in the same slot.
  Future<Map<String, int>> chatOrds() async {
    final rows = await _db.query('chats', columns: ['id', 'ord'], orderBy: 'ord ASC');
    return {for (final r in rows) r['id']! as String: (r['ord']! as num).toInt()};
  }

  Future<int> maxChatOrd() async {
    final r = await _db.rawQuery('SELECT MAX(ord) AS m FROM chats');
    return (r.first['m'] as num?)?.toInt() ?? -1;
  }

  /// Loads every message of a chat, oldest first. The store holds a chat's
  /// whole history in memory, so this is the load path rather than a paging
  /// one; a row that does not parse is skipped, not fatal.
  Future<List<Msg>> loadMsgs(String chatId) async {
    final rows = await _db.query('messages', columns: ['data'], where: 'chat_id = ?', whereArgs: [chatId], orderBy: 'ord ASC');
    final out = <Msg>[];
    for (final r in rows) {
      try {
        out.add(Msg.fromJson(jsonDecode(r['data']! as String) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  /// Writes a chat's metadata, leaving its messages alone.
  ///
  /// With [msgs] set, the whole message list is rewritten in the same
  /// transaction, which is how the store persists a chat: one chat per flush,
  /// never the whole list, and never a half saved chat.
  ///
  /// [dirty] is the incremental path and is what a streaming flush uses. The
  /// full rewrite above is O(history) per save: deleting and re-inserting every
  /// row of a 2000 message chat costs 2000 encodes and 2000 row writes, and the
  /// store flushes once per streamed chunk. With [dirty] only the ordinals whose
  /// messages actually changed are written, so a chunk that grew one bubble
  /// costs one encode and one row. This mirrors kelivo's
  /// `_replaceMessageParts`, which rewrites the parts of the one revision that
  /// changed rather than the conversation. A null [dirty] keeps the old
  /// whole-list behaviour, which is still the right answer for a restore, a
  /// migration or a reorder, where every row is genuinely new.
  Future<void> saveChat(Chat c, int ord, {List<Msg>? msgs, Set<int>? dirty}) async {
    final head = c.toJson()..remove('msgs');
    await _db.transaction((txn) async {
      // UPSERT, not INSERT OR REPLACE. `replace` resolves an id conflict by
      // deleting the old chats row first, and messages.chat_id carries ON
      // DELETE CASCADE, so every message of the chat is wiped before the new
      // head lands. The full rewrite path hid this by re-inserting all rows
      // inside the same transaction; the incremental and head-only paths write
      // only their own rows and lost the rest. `ON CONFLICT DO UPDATE` keeps
      // the parent row alive, which keeps the children alive.
      await txn.rawInsert(
        'INSERT INTO chats (id, ord, head) VALUES (?, ?, ?) '
        'ON CONFLICT(id) DO UPDATE SET ord = excluded.ord, head = excluded.head',
        [c.id, ord, jsonEncode(head)],
      );
      if (msgs == null) return;
      // An explicitly empty set means "the head changed, the messages did not"
      // (a draft keystroke, a mute toggle). There is nothing to write, and
      // skipping the delete-and-reinsert is the whole point of tracking rows at
      // all: the old code rewrote every message of the chat for a keystroke.
      if (dirty != null && dirty.isEmpty) return;
      final incremental = dirty != null && dirty.length * 4 < msgs.length;
      if (incremental) {
        final batch = txn.batch();
        // The full rewrite below keys rows by dense index (0..n-1), so the
        // incremental path has to use the same ordinal or the two would
        // disagree about which row a message lives in.
        for (final i in dirty) {
          if (i < 0 || i >= msgs.length) continue;
          batch.insert(
            'messages',
            {'chat_id': c.id, 'ord': i.toDouble(), 'data': jsonEncode(msgs[i].toJson())},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        return;
      }
      await txn.delete('messages', where: 'chat_id = ?', whereArgs: [c.id]);
      final batch = txn.batch();
      for (var i = 0; i < msgs.length; i++) {
        batch.insert(
          'messages',
          {'chat_id': c.id, 'ord': i.toDouble(), 'data': jsonEncode(msgs[i].toJson())},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> saveChatOrder(Map<String, int> ords) async {
    final batch = _db.batch();
    ords.forEach((id, ord) => batch.update('chats', {'ord': ord}, where: 'id = ?', whereArgs: [id]));
    await batch.commit(noResult: true);
  }

  Future<void> deleteChat(String id) => _db.delete('chats', where: 'id = ?', whereArgs: [id]);

  // ---- messages ----------------------------------------------------------

  Future<int> count(String chatId) async {
    final r = await _db.rawQuery('SELECT COUNT(*) AS n FROM messages WHERE chat_id = ?', [chatId]);
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// The [limit] messages starting at [from], oldest first.
  Future<List<Msg>> page(String chatId, int from, int limit) async {
    final rows = await _db.query(
      'messages',
      columns: ['data'],
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'ord ASC',
      limit: limit,
      offset: from,
    );
    return rows.map((r) => Msg.fromJson(jsonDecode(r['data']! as String) as Map<String, dynamic>)).toList();
  }

  /// The ordinal the next appended message should take.
  ///
  /// Fractional so that inserting between two messages can split the gap rather
  /// than shift every row after it. A double runs out of room after about 50
  /// such inserts in the same gap, which [renumber] exists to clean up.
  Future<double> lastOrd(String chatId) async {
    final r = await _db.rawQuery('SELECT MAX(ord) AS m FROM messages WHERE chat_id = ?', [chatId]);
    return (r.first['m'] as num?)?.toDouble() ?? 0;
  }

  /// The two ordinals bracketing position [from], so a new row can land between
  /// them. Returns (before, after); the pair is (null, null) on an empty chat and
  /// (ord, null) when [from] is the end, which is the append case.
  Future<(double?, double?)> bracket(String chatId, int from) async {
    final before = await _ordAt(chatId, from - 1);
    final after = from <= 0 ? await _ordAt(chatId, 0) : await _ordAt(chatId, from);
    return (before, after);
  }

  Future<double?> _ordAt(String chatId, int offset) async {
    // SQLite reads a negative OFFSET as zero, so an insert at the front would
    // come back bracketed by the first message twice instead of by nothing
    if (offset < 0) return null;
    final rows = await _db.rawQuery(
      'SELECT ord FROM messages WHERE chat_id = ? ORDER BY ord ASC LIMIT 1 OFFSET ?',
      [chatId, offset],
    );
    return rows.isEmpty ? null : (rows.first['ord'] as num).toDouble();
  }

  Future<void> putMsg(String chatId, double ord, Msg m) async {
    await _db.insert(
      'messages',
      {'chat_id': chatId, 'ord': ord, 'data': jsonEncode(m.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMsg(String chatId, double ord) =>
      _db.delete('messages', where: 'chat_id = ? AND ord = ?', whereArgs: [chatId, ord]);

  Future<void> clearMsgs(String chatId) => _db.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);

  /// Rewrites every ordinal to a dense sequence, which is the answer to a gap
  /// that has been split too many times to split again.
  ///
  /// Two passes, because renumbering in place collides with itself: moving 0.5
  /// onto 1 fails the primary key while the old 1 is still there. Pushing
  /// everything negative first moves the whole set clear of the target range, so
  /// the second pass cannot collide either. Doing it with updates rather than a
  /// delete and reinsert keeps the message bodies untouched, which at this size
  /// is the expensive part.
  Future<void> renumber(String chatId) async {
    await _db.transaction((txn) async {
      final rows = await txn.query('messages', columns: ['ord'], where: 'chat_id = ?', whereArgs: [chatId], orderBy: 'ord ASC');
      if (rows.isEmpty) return;
      // Shift the whole set above the range the second pass writes into. A
      // uniform shift keeps the values distinct from each other, and picking it
      // off the row count keeps the shifted set clear of [0, n) whatever the
      // ordinals had grown to.
      final shift = rows.length.toDouble() + 1;
      await txn.rawUpdate('UPDATE messages SET ord = ord + ? WHERE chat_id = ?', [shift, chatId]);
      final batch = txn.batch();
      for (var i = 0; i < rows.length; i++) {
        final moved = (rows[i]['ord'] as num).toDouble() + shift;
        batch.update('messages', {'ord': i.toDouble()}, where: 'chat_id = ? AND ord = ?', whereArgs: [chatId, moved]);
      }
      await batch.commit(noResult: true);
    });
  }

  // ---- migration ---------------------------------------------------------

  /// Moves a SharedPreferences chat blob into the database, once.
  ///
  /// The blob is only removed by the caller once the migration has been
  /// verified, so an interrupted first run finds it still there rather than
  /// discovering an empty database and an empty blob.
  Future<int> migrateFrom(String blob) async {
    final List decoded;
    try {
      decoded = jsonDecode(blob) as List;
    } catch (_) {
      return 0;
    }
    var moved = 0;
    // one transaction for the lot: a half migrated history is worse than either
    // state, and this runs once on a cold start
    await _db.transaction((txn) async {
      for (var i = 0; i < decoded.length; i++) {
        final raw = decoded[i];
        if (raw is! Map) continue;
        final map = raw.cast<String, dynamic>();
        final id = map['id'];
        if (id is! String) continue;
        await txn.insert('chats', {
          'id': id,
          'ord': i,
          'head': jsonEncode({...map, 'msgs': <dynamic>[]}),
        });
        final msgs = map['msgs'];
        if (msgs is! List) continue;
        for (var k = 0; k < msgs.length; k++) {
          final m = msgs[k];
          if (m is! Map) continue;
          await txn.insert('messages', {
            'chat_id': id,
            'ord': k.toDouble(),
            'data': jsonEncode(m.cast<String, dynamic>()),
          });
        }
        moved++;
      }
    });
    return moved;
  }
}