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
}
