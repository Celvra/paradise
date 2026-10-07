import 'package:flutter_test/flutter_test.dart';

import 'package:paradise/core/perf.dart';
import 'package:paradise/data/db.dart';
import 'package:paradise/data/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Guards for the streaming performance work: the incremental flush, the
/// per-message fan-out, the delta buffer and the highlight cache.
///
/// These assert the *mechanisms*, not timings — a wall clock assertion is flaky
/// on shared CI and says nothing about whether the write amplification came
/// back. Kelivo takes the same line: its perf benchmarks print numbers and are
/// named out of the default glob so they can never fail a build, while the
/// invariants that matter (scan visits, parse counts) are asserted in the real
/// suite.
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

  Chat chat(String id, {String draft = ''}) => Chat(
        id: id,
        persona: Persona(name: 'p$id', prompt: 'x', color: 0),
        draft: draft,
      );

  Msg msg(String text, {String id = ''}) => Msg(id: id.isEmpty ? text : id, out: false, text: text, time: 1);

  test('DB head serialization matches the full chat without msgs', () {
    final c = chat('a', draft: 'waiting')..msgs.add(msg('body'));
    final full = c.toJson();
    expect(full['msgs'], hasLength(1));
    full.remove('msgs');
    expect(c.toJson(includeMessages: false), full);
  });

  group('incremental save', () {
    test('a dirty subset rewrites only those rows', () async {
      final c = chat('a');
      for (var i = 0; i < 20; i++) {
        c.msgs.add(msg('m$i'));
      }
      await db.saveChat(c, 0, msgs: c.msgs);

      // Change one message and write only its row.
      c.msgs[7].text = 'changed';
      await db.saveChat(c, 0, msgs: c.msgs, dirty: {7});

      final page = await db.page('a', 0, 30);
      expect(page.length, 20, reason: 'the incremental path must not drop rows');
      expect(page[7].text, 'changed');
      expect(page[6].text, 'm6', reason: 'neighbours must be untouched');
      expect(page[8].text, 'm8');
    });

    test('an incremental write touches only the rows it names', () async {
      final c = chat('a');
      for (var i = 0; i < 5; i++) {
        c.msgs.add(msg('m$i'));
      }
      await db.saveChat(c, 0, msgs: c.msgs);

      // Write index 0 incrementally and nothing else. Every other row has to
      // come back exactly as it went in, which is the point of tracking
      // ordinals at all. The store handles a structural change such as a
      // delete by marking the chat for a full rewrite instead, so this only
      // pins the narrow behaviour of the incremental write itself.
      c.msgs[0].text = 'head';
      await db.saveChat(c, 0, msgs: c.msgs, dirty: {0});

      final page = await db.page('a', 0, 30);
      expect(page.length, 5, reason: 'the untouched rows must survive');
      expect(page.first.text, 'head');
      expect(page[1].text, 'm1');
      expect(page[4].text, 'm4');
    });

    test('an empty dirty set writes the head and no message rows', () async {
      final c = chat('a', draft: 'first');
      c.msgs.add(msg('keep'));
      await db.saveChat(c, 0, msgs: c.msgs);

      c.draft = 'second';
      await db.saveChat(c, 0, msgs: c.msgs, dirty: const <int>{});

      final loaded = await db.loadChats();
      expect(loaded.single.draft, 'second');
      expect((await db.page('a', 0, 10)).single.text, 'keep');
    });

    test('a null dirty set still rewrites the whole history', () async {
      final c = chat('a');
      for (var i = 0; i < 4; i++) {
        c.msgs.add(msg('m$i'));
      }
      await db.saveChat(c, 0, msgs: c.msgs);

      // Replacing the list wholesale is the restore / migration case.
      c.msgs
        ..clear()
        ..addAll([msg('only')]);
      await db.saveChat(c, 0, msgs: c.msgs);

      expect((await db.page('a', 0, 10)).map((m) => m.text), ['only']);
    });

    test('a large dirty set falls back to the full rewrite', () async {
      final c = chat('a');
      for (var i = 0; i < 10; i++) {
        c.msgs.add(msg('m$i'));
      }
      await db.saveChat(c, 0, msgs: c.msgs);

      // Every row changed, so the delete-and-reinsert is cheaper than ten
      // individual upserts; the threshold is 25% of the list.
      for (var i = 0; i < 10; i++) {
        c.msgs[i].text = 'x$i';
      }
      await db.saveChat(c, 0, msgs: c.msgs, dirty: {0, 1, 2, 3, 4, 5, 6, 7, 8, 9});

      final page = await db.page('a', 0, 20);
      expect(page.length, 10);
      expect(page.map((m) => m.text).toList(), [for (var i = 0; i < 10; i++) 'x$i']);
    });
  });

  group('schema is durable under the pragmas', () {
    test('the connection contract is in force', () async {
      // The pragmas are set in onConfigure; if a refactor moves them somewhere
      // a transaction cannot see, this fails rather than silently reverting to
      // two fsyncs per commit.
      //
      // journal_mode is deliberately not asserted: an in memory database
      // cannot use WAL at all and SQLite reports "memory" for it. The file
      // backed case is covered by the store tests, which open a real file.
      expect(await db.pragma('synchronous'), 1, reason: 'synchronous = NORMAL');
      expect(await db.pragma('foreign_keys'), 1, reason: 'the cascade depends on it');
      expect(await db.pragma('wal_autocheckpoint'), 1000);
    });
  });

  group('ByteLruCache', () {
    test('evicts by bytes, not by entry count', () {
      final cache = ByteLruCache<String, String>(maxBytes: 100, sizeOf: (k, v) => v.length);
      for (var i = 0; i < 20; i++) {
        cache.put('k$i', 'x' * 10);
      }
      expect(cache.bytes, lessThanOrEqualTo(100));
      expect(cache.length, lessThanOrEqualTo(10));
      expect(cache.evictions, greaterThan(0));
    });

    test('refuses an entry larger than the whole budget instead of emptying', () {
      final cache = ByteLruCache<String, String>(maxBytes: 50, sizeOf: (k, v) => v.length);
      cache.put('small', 'x' * 10);
      cache.put('huge', 'x' * 500);
      expect(cache.get('small'), isNotNull, reason: 'the oversized put must not evict');
      expect(cache.get('huge'), isNull);
    });

    test('get refreshes recency', () {
      // 25 bytes of room fits two 10 byte entries and forces the third to
      // evict, which is what makes the recency order observable at all
      final cache = ByteLruCache<String, String>(maxBytes: 25, sizeOf: (k, v) => v.length);
      cache.put('a', 'x' * 10);
      cache.put('b', 'x' * 10);
      cache.get('a'); // a is now the newer of the two
      cache.put('c', 'x' * 10); // must evict b, not a
      expect(cache.get('a'), isNotNull, reason: 'a was read, so it is not the coldest');
      expect(cache.get('b'), isNull);
      expect(cache.get('c'), isNotNull);
    });
  });

  group('StreamTextBuffer', () {
    test('accumulates without rebuilding the prefix per delta', () {
      final buf = StreamTextBuffer();
      for (final d in ['a', 'b', 'c']) {
        buf.add(d);
      }
      expect(buf.value, 'abc');
      expect(buf.length, 3);
    });

    test('reading twice does not double the text', () {
      final buf = StreamTextBuffer()..add('ab');
      expect(buf.value, 'ab');
      expect(buf.value, 'ab', reason: 'the snapshot must be reused, not re-appended');
    });

    test('setting replaces everything pending', () {
      final buf = StreamTextBuffer()
        ..add('stale')
        ..value = 'fresh';
      expect(buf.value, 'fresh');
      buf.add('!');
      expect(buf.value, 'fresh!');
    });

    test('an empty buffer reports empty', () {
      final buf = StreamTextBuffer();
      expect(buf.isEmpty, isTrue);
      buf.add('');
      expect(buf.isEmpty, isTrue);
    });
  });

  group('StreamBus', () {
    test('a revision is stable per id and bumps in place', () {
      final bus = StreamBus();
      final a = bus.revisionOf('a');
      final b = bus.revisionOf('b');
      expect(identical(bus.revisionOf('a'), a), isTrue, reason: 'same notifier per id');
      expect(a.value, 0);
      bus.bump('a');
      expect(a.value, 1);
      expect(b.value, 0, reason: 'other messages must not be touched');
    });

    test('bumping an unknown id is a no-op rather than an allocation', () {
      final bus = StreamBus();
      bus.bump('never-seen');
      expect(bus.has('never-seen'), isFalse);
    });

    test('drop releases the notifier', () {
      final bus = StreamBus();
      final n = bus.revisionOf('a');
      var fired = 0;
      n.addListener(() => fired++);
      bus.drop('a');
      bus.bump('a');
      expect(fired, 0);
      expect(bus.has('a'), isFalse);
    });

    test('clear keeps the named ids', () {
      final bus = StreamBus();
      final keep = bus.revisionOf('keep');
      bus.revisionOf('drop');
      bus.clear(keep: {'keep'});
      expect(bus.has('keep'), isTrue);
      expect(bus.has('drop'), isFalse);
      bus.bump('keep');
      expect(keep.value, 1);
    });
  });
}
