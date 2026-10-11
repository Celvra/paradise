/// The dart half of the oii contract.
///
/// `packages/oii_bridge/testdata/backup_doc.{oii,json}` is shared with the
/// rust crate, which parses it with the real oii parser. Between the two tests
/// the file has to be genuinely oii: this side pins the bytes the codec emits
/// and the values it reads back, and `packages/oii_bridge/native/src/lib.rs`
/// pins that oii agrees.
///
/// Regenerate the fixture with `dart run tool/regen_oii_fixture.dart` when the
/// encoding is meant to change; never edit the fixture by hand, or the test
/// below stops saying anything.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/oii/oii_codec.dart';

const _oiiPath = 'packages/oii_bridge/testdata/backup_doc.oii';
const _jsonPath = 'packages/oii_bridge/testdata/backup_doc.json';

/// The fixture's expected value, straight from the json side. The test reads
/// it rather than restating it, so there is one place to change.
Map<String, Object?> _expected() =>
    jsonDecode(File(_jsonPath).readAsStringSync()) as Map<String, Object?>;

void main() {
  test('the encoder still emits the shared fixture byte for byte', () {
    final want = File(_oiiPath).readAsStringSync();
    expect(oiiEncodeDoc('chat', _expected()), want);
  });

  test('the decoder still reads the shared fixture back', () {
    final doc = oiiDecodeDoc(File(_oiiPath).readAsStringSync());
    expect(doc.name, 'chat');
    expect(jsonEncode(doc.fields), jsonEncode(_expected()));
  });

  test('encoding is stable, so a file survives decode then encode', () {
    final once = oiiEncodeDoc('chat', _expected());
    expect(oiiEncodeDoc('chat', oiiDecodeDoc(once).fields), once);
  });

  test('every string in the fixture survives the round trip', () {
    // the fixture packs the interpolation, quote and hash hazards into `title`,
    // so a codec that stops escaping them shows up here first
    final fields = oiiDecodeDoc(File(_oiiPath).readAsStringSync()).fields;
    expect(fields['title'], 'a {b} c "q" d # e "# f\ng');
    expect(fields['unicode'], '中文 🎉');
  });

  test('a map stays a map and a pair array stays an array', () {
    // the whole reason the codec tags its maps: without the tag a reader
    // cannot tell `{a: 1}` from `[["a", 1]]`
    final doc = oiiDecodeDoc(File(_oiiPath).readAsStringSync());
    final settings = doc.fields['settings'];
    expect(settings, isA<Map<String, Object?>>());
    expect(settings, isNot(isA<List<Object?>>()));
    expect(oiiDecodeValue('[[#"a"#, 1]]'), [
      ['a', 1],
    ]);
  });

  test('a map nested last, and three deep, survives', () {
    // this is the shape a hand written probe test gets wrong; it is here
    // because the rust side folds it too and the two must agree
    final deep = <String, Object?>{
      'one': {
        'two': {'three': 4},
        'after': 5,
      },
      'tail': 6,
    };
    final doc = oiiDecodeDoc(oiiEncodeDoc('chat', {'settings': deep}));
    expect(jsonEncode(doc.fields['settings']), jsonEncode(deep));
  });

  test('non-finite doubles stay non-finite on this side', () {
    // the one known divergence: serde_json has no nan or infinity, so the rust
    // reader folds these to null while this one keeps them
    final doc = oiiDecodeDoc(
        oiiEncodeDoc('chat', {'a': double.nan, 'b': double.infinity}));
    expect((doc.fields['a']! as double).isNaN, isTrue);
    expect(doc.fields['b'], double.infinity);
  });
}