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

  static Future<ChatDb> open({String? path}) async {
    final db = await openDatabase(
      path ?? _file,
      version: _version,
      onConfigure: (db) async {
        // onConfigure, not onCreate: foreign_keys is a no-op inside a
        // transaction and onCreate runs in one, so setting it there turns the
        // cascade below off without saying so
        await db.execute('PRAGMA foreign_keys = ON');
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
  Future<void> saveChat(Chat c, int ord, {List<Msg>? msgs}) async {
    final head = c.toJson()..remove('msgs');
    await _db.transaction((txn) async {
      await txn.insert(
        'chats',
        {'id': c.id, 'ord': ord, 'head': jsonEncode(head)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (msgs == null) return;
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