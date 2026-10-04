import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/data/workspace/workspace.dart';
import 'package:paradise/data/workspace/workspace_bootstrap.dart';
import 'package:paradise/data/workspace/workspace_runtime.dart';
import 'package:paradise/data/workspace/workspace_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_paths.dart';

// The shell tool. No environment runs here: the runner is injected, so what is
// under test is what the tool does with the outcome, which is where the logic
// that can be wrong actually is.

void main() {
  late Directory tmp;
  late Store st;
  late WsContext ctx;
  late Chat chat;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    st = await Store.load();
    tmp = await useTempDocsDir('ws_shell');
    final c = st.createChat('A', 'p');
    chat = c;
    final w = await st.workspace.create(name: 'notes');
    c.ws = WorkspaceBinding(workspaceId: w.id);
    st.workspace.setToolsEnabled(true);
    ctx = (await st.wsContext(c))!;
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Runs the tool against a fixed outcome, so nothing here needs an
  /// environment.
  Future<WsResult> call(Map<String, dynamic> args, ShellOutcome outcome) =>
      WorkspaceTools.shell(ctx, args, (_) async => outcome);

  Map<String, dynamic> jsonOf(WsResult r) => jsonDecode(r.text) as Map<String, dynamic>;

  group('the schema', () {
    test('shell declares a command and bounds its timeout', () {
      final s = WorkspaceTools.schemaFor('shell');
      expect(s.keys, containsAll(['command', 'cwd', 'timeout_seconds']));
    });

    test('shell is the only tool that needs an environment besides view_image', () {
      for (final t in WorkspaceTools.toolsWithoutEnvironment) {
        expect(WorkspaceTools.needsEnvironment(t), isFalse, reason: t);
      }
      expect(WorkspaceTools.needsEnvironment('shell'), isTrue);
      expect(WorkspaceTools.needsEnvironment('view_image'), isTrue);
    });
  });

  group('the outcome', () {
    test('a successful command reports its exit code and duration', () async {
      final r = await call({'command': 'ls'}, const ShellOutcome(exitCode: 0, duration: Duration(milliseconds: 120)));
      final j = jsonOf(r);
      expect(j['exit_code'], 0);
      expect(j['duration_ms'], 120);
      expect(r.meta.status, 'ok');
    });

    test('a failed command is an error and still returns its output', () async {
      final r = await call({'command': 'false'}, const ShellOutcome(exitCode: 1, duration: Duration(milliseconds: 5), stderr: 'boom'));
      final j = jsonOf(r);
      expect(j['exit_code'], 1);
      expect(j['stderr'], 'boom');
      expect(r.meta.status, 'error');
    });

    test('a timeout is reported as a timeout, not as an exit code', () async {
      final r = await call({'command': 'sleep 999'}, const ShellOutcome(exitCode: -1, duration: Duration(hours: 1), timedOut: true));
      final j = jsonOf(r);
      expect(j['timed_out'], isTrue);
      expect(j['exit_code'], -1);
    });

    test('a cancel is reported as a cancel', () async {
      final r = await call({'command': 'sleep 999'}, const ShellOutcome(exitCode: -1, duration: Duration(seconds: 2), cancelled: true));
      expect(jsonOf(r)['cancelled'], isTrue);
    });

    test('an empty command is refused before anything runs', () async {
      final r = await call({'command': '   '}, const ShellOutcome(exitCode: 0, duration: Duration.zero));
      expect(jsonOf(r)['error'], 'missing_command');
    });

    test('the timeout is clamped into a range the device will honour', () async {
      final seen = <Duration>[];
      await WorkspaceTools.shell(ctx, {'command': 'x', 'timeout_seconds': 999999}, (r) async {
        seen.add(r.timeout);
        return const ShellOutcome(exitCode: 0, duration: Duration.zero);
      });
      expect(seen.single.inSeconds, 3600);

      seen.clear();
      await WorkspaceTools.shell(ctx, {'command': 'x', 'timeout_seconds': 0}, (r) async {
        seen.add(r.timeout);
        return const ShellOutcome(exitCode: 0, duration: Duration.zero);
      });
      expect(seen.single.inSeconds, 1);
    });
  });

  group('changed files', () {
    test('a command that wrote a file reports it in model vocabulary', () async {
      File? seen;
      final r = await WorkspaceTools.shell(ctx, {'command': 'build'}, (req) async {
        seen = File('${ctx.paths.workspaceHostRoot}/out.txt');
        await seen!.writeAsString('built');
        return const ShellOutcome(exitCode: 0, duration: Duration(milliseconds: 30));
      });
      final j = jsonOf(r);
      expect(j['changed_files'], ['/workspace/out.txt']);
      expect(r.meta.count, 1);
      expect(r.meta.files.single.modelPath, '/workspace/out.txt');
    });

    test('a command that wrote nothing reports nothing rather than an empty list', () async {
      final r = await WorkspaceTools.shell(ctx, {'command': 'true'}, (_) async => const ShellOutcome(exitCode: 0, duration: Duration.zero));
      expect(jsonOf(r).containsKey('changed_files'), isFalse);
      expect(r.meta.count, 0);
    });

    test('a hidden file is not reported, because every build has one', () async {
      await WorkspaceTools.shell(ctx, {'command': 'build'}, (_) async {
        await Directory('${ctx.paths.workspaceHostRoot}/.git').create();
        await File('${ctx.paths.workspaceHostRoot}/.git/config').writeAsString('x');
        await File('${ctx.paths.workspaceHostRoot}/src.txt').writeAsString('x');
        return const ShellOutcome(exitCode: 0, duration: Duration.zero);
      });
      final r = await WorkspaceTools.shell(ctx, {'command': 'again'}, (_) async => const ShellOutcome(exitCode: 0, duration: Duration.zero));
      // the second run changed nothing, which is the point: the first run's
      // hidden files must not show up as fresh changes on it
      expect(jsonOf(r).containsKey('changed_files'), isFalse);
    });
  });

  group('output length', () {
    test('a long output keeps its tail, because that is where the error is', () async {
      final long = List.generate(2000, (i) => 'line $i').join('\n');
      final r = await call({'command': 'log'}, ShellOutcome(exitCode: 0, duration: Duration.zero, stdout: long));
      final out = jsonOf(r)['stdout'] as String;
      expect(out.length, lessThan(long.length));
      expect(out, contains('characters earlier'));
      expect(out.trimRight(), endsWith('line 1999'));
    });

    test('a short output is passed through whole', () async {
      final r = await call({'command': 'echo hi'}, const ShellOutcome(exitCode: 0, duration: Duration.zero, stdout: 'hi\n'));
      expect(jsonOf(r)['stdout'], 'hi\n');
    });
  });

  group('the prompt fragment', () {
    test('shell is not advertised while no environment is installed', () async {
      final prompt = await st.wsPrompt(chat);
      expect(prompt, isNotNull);
      expect(prompt, isNot(contains('shell')));
    });

    test('shell is advertised once an environment is ready', () async {
      workspaceRuntimeProvider.debugSetStatus(const RuntimeStatus(ready: true, engine: 'proot'));
      addTearDown(() => workspaceRuntimeProvider.debugSetStatus(null));
      final prompt = await st.wsPrompt(chat);
      expect(prompt, contains('shell'));
      expect(prompt, contains('Linux environment'));
    });

    test('the citation syntax is in the fragment either way', () async {
      final prompt = await st.wsPrompt(chat);
      expect(prompt, contains('paradise://workspace/'));
      expect(prompt, contains('percent encoded'));
    });
  });

  group('the table', () {
    test('shell is withheld while no environment is installed', () async {
      expect((await st.wsTools(chat)).map((t) => t.name), isNot(contains('shell')));
    });

    test('shell is offered once one is', () async {
      workspaceRuntimeProvider.debugSetStatus(const RuntimeStatus(ready: true, engine: 'proot'));
      addTearDown(() => workspaceRuntimeProvider.debugSetStatus(null));
      final names = (await st.wsTools(chat)).map((t) => t.name);
      expect(names, containsAll(['shell', 'view_image']));
      expect(names, hasLength(WorkspaceTools.toolNames.length));
    });

    test('the local tool count matches what is actually offered', () async {
      workspaceRuntimeProvider.debugSetStatus(const RuntimeStatus(ready: true, engine: 'proot'));
      addTearDown(() => workspaceRuntimeProvider.debugSetStatus(null));
      expect(st.wsLocalToolCount(chat), (await st.wsTools(chat)).length);
    });

    test('a switched off tool is still not offered with an environment present', () async {
      workspaceRuntimeProvider.debugSetStatus(const RuntimeStatus(ready: true, engine: 'proot'));
      addTearDown(() => workspaceRuntimeProvider.debugSetStatus(null));
      st.workspace.byId(chat.ws.workspaceId)!.disabledTools.add('shell');
      expect((await st.wsTools(chat)).map((t) => t.name), isNot(contains('shell')));
    });
  });

  group('the guest environment', () {
    test('a command gets a PATH and a locale, not the host environment', () {
      expect(WorkspaceTools.guestEnv['PATH'], contains('/usr/bin'));
      expect(WorkspaceTools.guestEnv['LANG'], 'C.UTF-8');
      expect(WorkspaceTools.guestEnv['HOME'], '/root');
    });
  });
}
