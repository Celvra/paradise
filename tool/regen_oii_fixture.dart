/// Regenerates the oii contract fixture that the dart and rust readers share.
///
/// The fixture is what makes "these backup files are real oii" a checked claim
/// rather than a comment: `test/oii_contract_test.dart` asserts this codec
/// still emits exactly these bytes and still reads them back, and
/// `packages/oii_bridge/native/src/lib.rs` parses the same files with the real
/// oii parser and folds them to the same data.
///
/// Run it only when the encoding is meant to change, and read the diff: every
/// existing backup on a user's device is written in whatever is committed here.
///
///     dart run tool/regen_oii_fixture.dart
library;

import 'dart:convert';
import 'dart:io';

import '../lib/data/oii/oii_codec.dart';

/// A chat document holding every shape the codec has to get right. Anything
/// removed from here stops being covered on both sides, so keep it broad and
/// keep it ugly.
Map<String, Object?> fixtureFields() => <String, Object?>{
      'id': 'c1',
      // every string hazard in one field: `{var}` interpolation, quotes, a
      // bare hash, the `"#` sequence that forces a longer raw string, a
      // newline
      'title': 'a {b} c "q" d # e "# f\ng',
      'muted': false,
      'unread': 3,
      'ratio': 1.5,
      'pinned': null,
      'tags': ['a', 'b', ''],
      'empty_list': <Object?>[],
      'settings': <String, Object?>{
        'theme': 'dark',
        'font': 12,
        // a nested map that is not the last pair
        'nested': <String, Object?>{
          'a': 1,
          'b': [true, null],
        },
        // and one that is, three deep, which is the shape that reads worst
        'deep': <String, Object?>{
          'one': <String, Object?>{
            'two': <String, Object?>{'three': 4},
            'after': 5,
          },
          'tail': 6,
        },
      },
      'empty_map': <String, Object?>{},
      'messages': [
        {'role': 'user', 'text': 'hi'},
        {'role': 'bot', 'text': 'yo'},
      ],
      'unicode': '中文 🎉',
    };

const _oiiPath = 'packages/oii_bridge/testdata/backup_doc.oii';
const _jsonPath = 'packages/oii_bridge/testdata/backup_doc.json';

void main() {
  final fields = fixtureFields();
  File(_oiiPath).writeAsStringSync(oiiEncodeDoc('chat', fields));
  File(_jsonPath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(fields)}\n');

  // refuse to write a fixture the dart decoder cannot read back, so a broken
  // encoder fails here rather than in the middle of the rust suite
  final back = oiiDecodeDoc(File(_oiiPath).readAsStringSync());
  if (back.name != 'chat') {
    throw StateError('decoded name is "${back.name}"');
  }
  if (jsonEncode(back.fields) != jsonEncode(fields)) {
    stderr.writeln('round trip mismatch');
    stderr.writeln(jsonEncode(back.fields));
    exit(1);
  }
  stdout.writeln('wrote $_oiiPath and $_jsonPath');
}