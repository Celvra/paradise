import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/oii/oii_codec.dart';

/// The oii value codec must round-trip every JSON shape the backup carries,
/// especially hostile chat text: interpolation braces, quotes, emoji,
/// newlines and comment markers must come back byte identical.
void main() {
  Object? rt(Object? v) => oiiDecodeValue(oiiEncodeValue(v));

  test('scalars round-trip', () {
    expect(rt(null), isNull);
    expect(rt(true), isTrue);
    expect(rt(false), isFalse);
    expect(rt(0), 0);
    expect(rt(-42), -42);
    expect(rt(9223372036854775807), 9223372036854775807);
    expect(rt(1.5), 1.5);
    expect(rt(0.1), 0.1);
    expect(rt(1e21), 1e21);
    expect((rt(double.nan) as double).isNaN, isTrue);
    expect(rt(double.infinity), double.infinity);
    expect(rt(double.negativeInfinity), double.negativeInfinity);
    expect(rt(''), '');
    expect(rt('plain'), 'plain');
  });

  test('hostile strings ride raw and come back identical', () {
    const nasties = [
      'hello {name}, you have {count} messages',
      'unclosed { brace',
      '}',
      '{}',
      'say "hi" \\ bye',
      'line1\nline2\r\nline3\tend',
      'emoji 🎉 mixed 中文 and عربي',
      '// not a comment',
      '/* nor this */',
      '/-nor this',
      'trailing quote"',
      '"leading quote',
      '#hash and #"hashquote"# inside',
      'null true false 123 bare?',
      '  spaces around  ',
      'msg with \x00 null byte',
      'snowman \u2603 escape',
    ];
    for (final s in nasties) {
      expect(rt(s), s, reason: 'round-trip of "$s"');
      // raw strings never interpolate, so no braces may leak as bare text
      final enc = oiiEncodeValue(s);
      expect(enc.startsWith('#'), isTrue, reason: 'strings must be raw: $enc');
    }
  });

  test('maps use the (map) tag so pair arrays stay arrays', () {
    expect(rt({}), {});
    expect(
      rt({
        'a': 1,
        'b': 'x',
        'n': null,
      }),
      {'a': 1, 'b': 'x', 'n': null},
    );
    // a genuine array of pairs must NOT decode as a map
    expect(
      rt([
        [1, 2],
        [3, 4],
      ]),
      [
        [1, 2],
        [3, 4],
      ],
    );
    // nesting both ways
    final doc = {
      'msgs': [
        {
          'id': 'm1',
          'text': 'hi {there}',
          'data': {'title': 'gift "x"', 'n': 3},
        },
      ],
      'meta': {'at': 123},
    };
    expect(rt(doc), doc);
  });

  test('doc round-trips one node', () {
    final fields = <String, Object?>{
      'kind': 'lib3.backup',
      'version': 2,
      'tags': ['a', 'b'],
      'nested': {
        'x': 1,
      },
    };
    final text = oiiEncodeDoc('backup', fields);
    expect(text, contains('backup ['));
    final back = oiiDecodeDoc(text);
    expect(back.name, 'backup');
    expect(back.fields, fields);
  });

  test('garbage fails loudly', () {
    expect(() => oiiDecodeValue(''), throwsFormatException);
    expect(() => oiiDecodeValue('hello'), throwsFormatException, reason: 'bare words are refused');
    expect(() => oiiDecodeValue('[1, 2'), throwsFormatException);
    expect(() => oiiDecodeValue('(map)[["a"]]'), throwsFormatException, reason: 'pairs need two items');
    expect(() => oiiDecodeValue('[1] trailing'), throwsFormatException);
    expect(() => oiiDecodeDoc('backup [ version: ]'), throwsFormatException);
    expect(() => oiiEncodeValue(DateTime.now()), throwsArgumentError);
    expect(() => oiiEncodeValue({1: 'x'}), throwsArgumentError, reason: 'non-string keys');
    expect(() => oiiEncodeDoc('has space', {}), throwsArgumentError);
  });
}
