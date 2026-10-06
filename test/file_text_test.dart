import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/file_text.dart';

Future<String> _tmp(String name, List<int> bytes) async {
  final f = File('${Directory.systemTemp.path}/paradise_file_text_test_$name');
  await f.writeAsBytes(bytes, flush: true);
  addTearDown(() => f.deleteSync());
  return f.path;
}

void main() {
  test('plain text file injects in full', () async {
    final path = await _tmp('a.txt', utf8.encode('hello world\n第二行'));
    final s = sampleTextFile(path, 40000);
    expect(s, isNotNull);
    expect(s!.text, 'hello world\n第二行');
    expect(s.omittedChars, 0);
    expect(s.usedChars, s.text.length);
  });

  test('unknown text-like extension still injects', () async {
    final path = await _tmp('a.srt', utf8.encode('1\n00:00:01,000 --> 00:00:02,000\nhello'));
    expect(sampleTextFile(path, 40000), isNotNull);
  });

  test('binary extension is rejected even when bytes look textual', () async {
    final path = await _tmp('a.pdf', utf8.encode('%PDF-1.4 fake but text-shaped'));
    expect(sampleTextFile(path, 40000), isNull);
  });

  test('binary content without a binary extension is rejected', () async {
    final path = await _tmp('a.binlog', List<int>.filled(4096, 0));
    expect(sampleTextFile(path, 40000), isNull);
  });

  test('empty file injects nothing', () async {
    final path = await _tmp('a.txt', []);
    expect(sampleTextFile(path, 40000), isNull);
  });

  test('oversized file yields a head and tail with an omission marker', () async {
    final big = StringBuffer();
    for (var i = 0; i < 20000; i++) {
      big.writeln('line $i padding padding padding');
    }
    final path = await _tmp('big.log', utf8.encode(big.toString()));
    final s = sampleTextFile(path, 10000);
    expect(s, isNotNull);
    expect(s!.text.contains('bytes omitted'), isTrue);
    expect(s.text.startsWith('line 0'), isTrue);
    expect(s.text.contains('line 19999'), isTrue);
    expect(s.usedChars <= 10000 + 40, isTrue);
    expect(s.omittedChars, greaterThan(0));
  });

  test('files over the hard ceiling are not sampled at all', () async {
    // real bytes rather than a seek-and-write sparse file: antivirus on
    // Windows holds new temp files for a moment, and a second open for
    // writing races that lock (access denied, errno 5)
    final path = await _tmp('huge.log', List.filled(sampleMaxBytes + 1024, 0x41));
    expect(File(path).lengthSync(), greaterThan(sampleMaxBytes));
    expect(sampleTextFile(path, 40000), isNull);
  });

  test('utf-8 content split across the head/tail boundary stays decodable', () async {
    final text = '中' * 5000 + 'tail-marker-尾巴';
    final path = await _tmp('cjk.txt', utf8.encode(text));
    final s = sampleTextFile(path, 3000);
    expect(s, isNotNull);
    expect(s!.text.contains('tail-marker'), isTrue);
    expect(s.text.contains('bytes omitted'), isTrue);
  });

  test('classify helpers', () {
    expect(isBinaryExt('a.zip'), isTrue);
    expect(isBinaryExt('a.JPG'), isTrue);
    expect(isBinaryExt('a.txt'), isFalse);
    expect(isBinaryExt('no_extension'), isFalse);
  });
}
