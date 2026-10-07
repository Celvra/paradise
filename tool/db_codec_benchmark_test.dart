// Run explicitly: flutter test tool/db_codec_benchmark_test.dart --reporter expanded
// Kept outside test/ so wall-clock measurements never run in the normal suite.
// This measures Dart's backup OII codec, NOT the Rust oii_bridge. On Linux,
// sqflite_common_ffi is not the Android platform-channel SQLite implementation.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/db.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/oii/oii_codec.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('message serialization and SQLite baseline (informational only)', () async {
    const count = 300;
    final messages = [
      for (var i = 0; i < count; i++)
        Msg(
          id: 'm$i',
          out: i.isEven,
          text: i.isEven
              ? 'hello {name} 中文 🎉, say "hi" /- $i'
              : '${'A longer assistant reply with {unexpanded} text. 中文 🎉 ' * 20}$i',
          time: 1700000000000 + i,
          reply: i.isEven ? null : 'm${i - 1}',
          kind: i % 10 == 0 ? MsgKind.trace : MsgKind.text,
          data: i % 10 == 0
              ? {
                  'tool': 'search',
                  'args': {'query': 'hello $i', 'limit': 3},
                  'results': [null, true, '"#']
                }
              : {},
        ),
    ];
    final chat = Chat(id: 'bench', persona: Persona(name: 'bench', prompt: 'x', color: 0), msgs: messages);
    final maps = [for (final m in messages) m.toJson()];
    final jsonTexts = [for (final m in maps) jsonEncode(m)];
    final oiiTexts = [for (final m in maps) oiiEncodeDoc('msg', m)];
    for (var i = 0; i < count; i++) {
      final fromJson = Msg.fromJson(jsonDecode(jsonTexts[i]) as Map<String, dynamic>);
      final fromOii = Msg.fromJson(Map<String, dynamic>.from(oiiDecodeDoc(oiiTexts[i]).fields));
      expect(fromJson.text, messages[i].text);
      expect(fromOii.text, messages[i].text);
      expect(jsonEncode(fromOii.toJson()), jsonTexts[i], reason: 'OII must preserve nested data and nulls');
    }

    // Warm up every stage, then report medians rather than asserting on timing.
    // Prebuilding maps and texts separates object conversion from text codecs.
    var sink = 0;
    void bench(String name, void Function(int) operation, {String unit = 'msg'}) {
      const repeats = 15;
      void run() {
        for (var repeat = 0; repeat < repeats; repeat++) {
          for (var i = 0; i < count; i++) {
            operation(i);
          }
        }
      }

      run();
      final times = <int>[];
      for (var round = 0; round < 3; round++) {
        final watch = Stopwatch()..start();
        run();
        times.add(watch.elapsedMicroseconds);
      }
      times.sort();
      print('${name.padRight(29)} ${(times[1] / (count * repeats)).toStringAsFixed(2)} us/$unit');
    }

    print('$count messages: JSON ${jsonTexts.fold<int>(0, (n, t) => n + utf8.encode(t).length)} bytes, '
        'OII ${oiiTexts.fold<int>(0, (n, t) => n + utf8.encode(t).length)} bytes');
    bench('Msg.toJson', (i) => sink += messages[i].toJson().length);
    bench('jsonEncode(map)', (i) => sink += jsonEncode(maps[i]).length);
    bench('Msg -> JSON (DB write)', (i) => sink += jsonEncode(messages[i].toJson()).length);
    bench('jsonDecode(text)', (i) => sink += (jsonDecode(jsonTexts[i]) as Map).length);
    bench('Msg.fromJson(map)', (i) => sink += Msg.fromJson(maps[i]).text.length);
    bench('OII encode doc (Dart)', (i) => sink += oiiEncodeDoc('msg', maps[i]).length);
    bench('Msg -> OII (Dart)', (i) => sink += oiiEncodeDoc('msg', messages[i].toJson()).length);
    bench('OII decode doc (Dart)', (i) => sink += oiiDecodeDoc(oiiTexts[i]).fields.length);
    bench('JSON -> Msg end-to-end',
        (i) => sink += Msg.fromJson(jsonDecode(jsonTexts[i]) as Map<String, dynamic>).text.length);
    bench('OII -> Msg end-to-end',
        (i) => sink += Msg.fromJson(Map<String, dynamic>.from(oiiDecodeDoc(oiiTexts[i]).fields)).text.length);
    bench('Chat head old (discard msgs)', (_) => sink += (chat.toJson()..remove('msgs')).length, unit: 'chat');
    bench('Chat head (no msgs)', (_) => sink += chat.toJson(includeMessages: false).length, unit: 'chat');
    print('sink (prevent unused results): $sink');

    // File-backed, so WAL/transactions are exercised. This is still Linux FFI,
    // not an Android device result; do not treat it as an Android speedup claim.
    final base = Directory('/tmp/opencode');
    final dir = await (await base.exists() ? base : Directory.systemTemp).createTemp('para-db-bench-');
    try {
      final db = await ChatDb.open(path: '${dir.path}/paradise.db');
      try {
        await db.saveChat(chat, 0, msgs: messages); // warm up SQLite
        final fullTimes = <int>[];
        final loadTimes = <int>[];
        for (var round = 0; round < 3; round++) {
          final full = Stopwatch()..start();
          await db.saveChat(chat, 0, msgs: messages);
          fullTimes.add(full.elapsedMicroseconds);
          final load = Stopwatch()..start();
          final loaded = await db.loadMsgs(chat.id);
          loadTimes.add(load.elapsedMicroseconds);
          expect(loaded.length, count);
        }
        fullTimes.sort();
        loadTimes.sort();
        print('SQLite full save ($count rows)  ${(fullTimes[1] / 1000).toStringAsFixed(1)} ms');
        print('SQLite load ($count rows)       ${(loadTimes[1] / 1000).toStringAsFixed(1)} ms');
        const flushes = 30;
        final headOnly = Stopwatch()..start();
        for (var i = 0; i < flushes; i++) {
          await db.saveChat(chat, 0, msgs: messages, dirty: const <int>{});
        }
        print('SQLite head-only flush        ${(headOnly.elapsedMicroseconds / flushes).toStringAsFixed(0)} us/flush');
        final incremental = Stopwatch()..start();
        for (var i = 0; i < flushes; i++) {
          messages.last.text = '${messages.last.text}x';
          await db.saveChat(chat, 0, msgs: messages, dirty: {count - 1});
        }
        print(
            'SQLite incremental (1 dirty)   ${(incremental.elapsedMicroseconds / flushes).toStringAsFixed(0)} us/flush');
      } finally {
        await db.close();
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
