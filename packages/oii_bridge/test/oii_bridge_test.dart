import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oii_bridge/oii_bridge.dart';

// Needs the built library. `flutter test` inside the package runs the hook,
// but the test runner does not dlopen the bundled asset into the process, so
// point the loader at it explicitly:
//   LD_LIBRARY_PATH=$PWD/build/native_assets/linux flutter test
// from the app the flutter tool bundles it and process() finds the symbols.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parse and eval round trip through the bridge', () async {
    final engine = await OiiEngine.spawn();
    addTearDown(engine.dispose);

    final parsed = await engine.parse('fun main() [ return 40 + 2 ]');
    expect(parsed.ok, isTrue, reason: parsed.diagnostics.join('\n'));

    final out = await engine.eval('main');
    expect(out.ok, isTrue, reason: out.error);
    expect(out.value, 42);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('host call crosses into dart and back', () async {
    final engine = await OiiEngine.spawn();
    addTearDown(engine.dispose);

    final seen = <List<Object?>>[];
    engine.registerHost('double', (args) {
      seen.add(args);
      return (args.first as num) * 2;
    });

    final parsed = await engine.parse('fun main() [ return double(21) ]');
    expect(parsed.ok, isTrue, reason: parsed.diagnostics.join('\n'));

    final out = await engine.eval('main');
    expect(out.ok, isTrue, reason: out.error);
    expect(out.value, 42);
    expect(seen, hasLength(1));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('async host call resolves after a delay', () async {
    final engine = await OiiEngine.spawn();
    addTearDown(engine.dispose);

    engine.registerHost('slow_double', (args) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return (args.first as num) * 2;
    });

    final parsed = await engine.parse('fun main() [ return slow_double(21) ]');
    expect(parsed.ok, isTrue, reason: parsed.diagnostics.join('\n'));

    final out = await engine.eval('main');
    expect(out.ok, isTrue, reason: out.error);
    expect(out.value, 42);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('describe folds the plugin node without an engine', () {
    final r = oiiDescribe('plugin [\n  name: "demo"\n  desc: "does things"\n]\nfun main() [ return 1 ]');
    expect(r.ok, isTrue, reason: r.diagnostics.join('\n'));
    expect(r.plugin['name'], 'demo');
    expect(r.plugin['desc'], 'does things');
    expect(r.funcs.map((f) => f['name']), contains('main'));
  });

  // The end to end half of the backup contract: this reads the same fixture the
  // app's own encoder produced and the dart side of the contract pins, and
  // checks that the oii parser agrees with it about what the file holds.
  test('the shared backup fixture is real oii and folds to the same data', () {
    final source = File('testdata/backup_doc.oii').readAsStringSync();
    final expected = jsonDecode(File('testdata/backup_doc.json').readAsStringSync());

    final r = oiiValidateBackupDoc(source);
    expect(r.ok, isTrue, reason: r.error);
    expect(r.name, 'chat');
    // field by field rather than by encoded bytes: the rust side hands back a
    // sorted map and json keeps insertion order, and neither order is wrong
    expect(r.data, expected);
  });

  test('a map folds to an object and a pair array stays an array', () {
    final r = oiiValidateBackupDoc('chat [ m: (map)[[#"a"#, 1]], pairs: [[#"a"#, 1]] ]');
    expect(r.ok, isTrue, reason: r.error);
    expect(r.data['m'], {'a': 1});
    expect(r.data['pairs'], [
      ['a', 1],
    ]);
  });

  test('a broken document comes back as an error, not a crash', () {
    // the shape a truncated or hand edited file has
    final r = oiiValidateBackupDoc('chat [ id: ]');
    expect(r.ok, isFalse);
    expect(r.error, isNotEmpty);

    // and one the encoder would never write, which still has to be refused
    final nested = oiiValidateBackupDoc('chat [ m: (map)[[#"a"#, 1]] inner [ x: 1 ] ]');
    expect(nested.ok, isFalse);
    expect(nested.error, contains('child nodes'));
  });
}
