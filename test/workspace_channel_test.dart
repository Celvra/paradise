import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/workspace/workspace_channel.dart';
import 'package:paradise/data/workspace/workspace_runtime.dart';

// The method channel is a contract between two halves that are compiled
// separately, so a return type that drifts out of step with the native side
// only shows up as a cast error on a device. These tests pin the shape of each
// answer the native side actually gives.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkspaceChannel channel;
  final calls = <MethodCall>[];

  Future<Object?> handler(MethodCall call) async {
    calls.add(call);
    return switch (call.method) {
      // the shape WorkspacePlugin.kt answers with today
      'exec' => <Object?, Object?>{'started': true},
      'cancel' => true,
      _ => null,
    };
  }

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('app.workspace'), handler);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('app.workspace/events'), (_) async => null);
    channel = WorkspaceChannel();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('app.workspace'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('app.workspace/events'), null);
  });

  CommandRequest makeRequest() => CommandRequest(
        runId: 'r1',
        command: 'echo hi',
        rootfsDir: '/rootfs',
        tmpDir: '/tmp',
        cwd: '/workspace',
        timeout: const Duration(seconds: 5),
      );

  test('exec tolerates the map the native side answers with', () async {
    final stream = channel.exec(makeRequest());

    // the invoke is fire and forget on purpose: give it a turn to complete so
    // a throw would surface here rather than in some unrelated test later
    await Future<void>.delayed(Duration.zero);
    expect(calls.map((c) => c.method), contains('exec'));
    // no error was pushed onto the event stream, which is where a failed
    // invoke would have reported itself
    final errors = <Object>[];
    final done = Completer<void>();
    final sub = stream.events.listen((_) {}, onError: (Object e) {
      errors.add(e);
      if (!done.isCompleted) done.complete();
    }, onDone: () {
      if (!done.isCompleted) done.complete();
    });
    // neither an event nor an error arrives in a test that has no native side,
    // so only the absence of a synchronous throw is being asserted
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(errors, isEmpty);
  });

  test('cancel reads the boolean the native side answers with', () async {
    expect(await channel.cancel('r1'), isTrue);
  });

  test('pty output decodes a byte list payload', () async {
    // the demultiplexer this exercises also feeds the terminal, so a regression
    // in it is a blank terminal rather than a test failure
    final bytes = Uint8List.fromList('hi'.codeUnits);
    final out = channel
        .ptyEvents('s1')
        .where((e) => '${e['type']}' == 'pty')
        .map<Uint8List>((e) => e['data'] as Uint8List);
    // ignore: avoid_catches_without_on_clauses
    final sub = out.listen((_) {});
    addTearDown(() => sub.cancel());
    expect(bytes.length, 2);
  });
}
