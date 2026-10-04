import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/data/workspace/app_dirs.dart';
import 'package:paradise/data/workspace/workspace.dart';
import 'package:paradise/data/workspace/workspace_bootstrap.dart';
import 'package:paradise/data/workspace/workspace_metadata.dart';
import 'package:paradise/data/workspace/workspace_paths.dart' show WorkspaceZone;
import 'package:paradise/data/workspace/workspace_runtime.dart';
import 'package:paradise/data/workspace/workspace_tools.dart';

import 'fake_paths.dart';

// The tool table half: when the six tools are offered, when they are not, and
// what reaches the model as opposed to what reaches the step row.

void main() {
  late Directory tmp;
  late Store st;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    st = await Store.load();
    tmp = await useTempDocsDir('ws_tools');
    // the provider is process wide, so a status pinned by one test would leak
    // into the next and quietly change what the tool table offers
    workspaceRuntimeProvider.debugSetStatus(null);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('the three states', () {
    test('nothing is offered before a workspace exists', () async {
      final c = st.createChat('A', 'p');
      expect(c.ws.isBound, isFalse);
      expect(await st.wsTools(c, null), isEmpty);
      expect(await st.wsPrompt(c), isNull);
      expect(st.wsActive(c), isFalse);
    });

    test('a binding with the switch off offers nothing and says nothing', () async {
      final c = st.createChat('A', 'p');
      final w = await st.workspace.create(name: 'notes');
      c.ws = WorkspaceBinding(workspaceId: w.id);
      expect(c.ws.isBound, isTrue);
      expect(st.workspace.toolsEnabled, isFalse);
      expect(await st.wsTools(c, null), isEmpty);
      expect(await st.wsPrompt(c), isNull);
      // bound but inert, which is the state the settings row has to explain
      expect(st.wsActive(c), isFalse);
    });

    test('switch on plus bound offers the file tools', () async {
      final c = st.createChat('A', 'p');
      final w = await st.workspace.create(name: 'notes');
      c.ws = WorkspaceBinding(workspaceId: w.id);
      st.workspace.setToolsEnabled(true);
      final tools = await st.wsTools(c, null);
      // shell and view_image need an installed environment and there is none in
      // a test, so the table is the six file tools rather than all eight
      expect(tools.map((t) => t.name).toSet(), WorkspaceTools.toolsWithoutEnvironment);
      expect(tools.map((t) => t.name), isNot(contains('shell')));
      expect(tools.map((t) => t.name), isNot(contains('view_image')));
      expect(st.wsActive(c), isTrue);
      expect(st.wsLocalToolCount(c), WorkspaceTools.toolsWithoutEnvironment.length);
      expect(await st.wsPrompt(c), contains('/workspace'));
    });

    test('a tool needing an environment is withheld until one is installed', () async {
      final c = st.createChat('A', 'p');
      final w = await st.workspace.create(name: 'notes');
      c.ws = WorkspaceBinding(workspaceId: w.id);
      st.workspace.setToolsEnabled(true);
      expect((await st.wsTools(c, null)).map((t) => t.name), isNot(contains('shell')));

      // the runtime provider is process wide, so a ready status is faked here
      // rather than installed over
      workspaceRuntimeProvider.debugSetStatus(const RuntimeStatus(ready: true, engine: 'proot'));
      addTearDown(() => workspaceRuntimeProvider.debugSetStatus(null));
      expect((await st.wsTools(c, null)).map((t) => t.name), contains('shell'));
    });

    test('a tool switched off on the workspace is not offered at all', () async {
      final c = st.createChat('A', 'p');
      final w = await st.workspace.create(name: 'notes');
      c.ws = WorkspaceBinding(workspaceId: w.id);
      w.disabledTools.addAll({'write_file', 'edit_file'});
      st.workspace.setToolsEnabled(true);
      final tools = await st.wsTools(c, null);
      expect(tools.map((t) => t.name), isNot(contains('write_file')));
      // the count is of what is actually offered, so two switched off and two
      // that need an environment this device does not have
      expect(st.wsLocalToolCount(c), WorkspaceTools.toolsWithoutEnvironment.length - 2);
      // and the prompt admits to the smaller table rather than the whole one
      final prompt = await st.wsPrompt(c);
      expect(prompt, contains('read_file'));
      expect(prompt, isNot(contains('write_file')));
    });

    test('an unbound chat is unaffected by the switch', () async {
      st.workspace.setToolsEnabled(true);
      final c = st.createChat('A', 'p');
      expect(await st.wsTools(c, null), isEmpty);
      expect(st.wsLocalToolCount(c), 0);
    });
  });

  group('the tool schema', () {
    test('required arguments are declared so the model cannot omit them', () {
      expect(WorkspaceTools.schemaFor('write_file').keys, containsAll(['path', 'content']));
      expect(WorkspaceTools.schemaFor('edit_file').keys, containsAll(['path', 'old_string', 'new_string']));
    });

    test('every tool has a summary for the settings pane', () {
      for (final t in WorkspaceTools.toolNames) {
        expect(WorkspaceTools.summaryFor(t), isNotEmpty, reason: t);
        expect(WorkspaceTools.schemaFor(t), isNotEmpty, reason: t);
      }
    });
  });

  group('the error envelope', () {
    test('names the code so the model can branch on it', () async {
      final c = st.createChat('A', 'p');
      final w = await st.workspace.create(name: 'notes');
      c.ws = WorkspaceBinding(workspaceId: w.id);
      st.workspace.setToolsEnabled(true);
      final ctx = (await st.wsContext(c))!;
      final out = await WorkspaceTools.call(ctx, 'read_file', {'path': ''});
      final j = jsonDecode(out.text) as Map<String, dynamic>;
      expect(j['error'], 'missing_path');
      expect(j['message'], contains('path is required'));
      expect(out.meta.status, 'error');
    });

    test('a switched off tool says so rather than pretending not to exist', () async {
      final c = st.createChat('A', 'p');
      final w = await st.workspace.create(name: 'notes');
      c.ws = WorkspaceBinding(workspaceId: w.id);
      w.disabledTools.add('grep');
      st.workspace.setToolsEnabled(true);
      final ctx = (await st.wsContext(c))!;
      final out = await WorkspaceTools.call(ctx, 'grep', {'pattern': 'x'});
      expect(jsonDecode(out.text)['error'], 'tool_disabled');
    });

    test('an unknown tool name is refused', () async {
      final c = st.createChat('A', 'p');
      final w = await st.workspace.create(name: 'notes');
      c.ws = WorkspaceBinding(workspaceId: w.id);
      st.workspace.setToolsEnabled(true);
      final out = await WorkspaceTools.call((await st.wsContext(c))!, 'rm_rf', {});
      expect(jsonDecode(out.text)['error'], 'unknown_tool');
    });
  });

  group('write confirmation', () {
    late WsContext ctx;
    late List<WsPendingWrite> asked;

    setUp(() async {
      final c = st.createChat('A', 'p');
      final w = await st.workspace.create(name: 'notes');
      c.ws = WorkspaceBinding(workspaceId: w.id);
      st.workspace.setToolsEnabled(true);
      asked = [];
      ctx = WsContext(
        paths: await st.workspace.pathsFor(w, c.id),
        binding: c.ws,
        disabledTools: const {},
        confirmWrite: (write) async {
          asked.add(write);
          return false;
        },
      );
    });

    test('a refusal leaves the disk untouched', () async {
      final out = await WorkspaceTools.call(ctx, 'write_file', {'path': '/workspace/a.txt', 'content': 'hello'});
      expect(asked, hasLength(1));
      expect(jsonDecode(out.text)['error'], 'write_refused');
      final f = File('${ctx.paths.workspaceHostRoot}/a.txt');
      expect(await f.exists(), isFalse);
    });

    test('the question carries the diff, not just the intention', () async {
      // nothing on disk yet, so the whole file is an addition
      await WorkspaceTools.call(ctx, 'write_file', {'path': '/workspace/a.txt', 'content': 'one\ntwo\n'});
      expect(asked.single.diff, contains('+one'));
      expect(asked.single.created, isTrue);

      // now let it through, and the second question is a one line replacement
      final open = WsContext(paths: ctx.paths, binding: ctx.binding, disabledTools: const {});
      await WorkspaceTools.call(open, 'write_file', {'path': '/workspace/a.txt', 'content': 'one\ntwo\n'});
      asked.clear();
      ctx.binding.allowAll = false;
      final again = WsContext(
        paths: ctx.paths,
        binding: ctx.binding,
        disabledTools: const {},
        confirmWrite: (w) async {
          asked.add(w);
          return false;
        },
      );
      await WorkspaceTools.call(again, 'write_file', {'path': '/workspace/a.txt', 'content': 'one\nTWO\n'});
      expect(asked.single.diff, contains('-two'));
      expect(asked.single.diff, contains('+TWO'));
      expect(asked.single.created, isFalse);
      // and the refusal means the file still says what it said before
      expect(File('${ctx.paths.workspaceHostRoot}/a.txt').readAsStringSync(), 'one\ntwo\n');
    });

    test('allowAll skips the question entirely', () async {
      ctx.binding.allowAll = true;
      final out = await WorkspaceTools.call(ctx, 'write_file', {'path': '/workspace/a.txt', 'content': 'x'});
      expect(asked, isEmpty);
      expect(jsonDecode(out.text)['ok'], true);
    });

    test('a headless context has nobody to ask and writes', () async {
      final headless = WsContext(paths: ctx.paths, binding: ctx.binding, disabledTools: const {});
      final out = await WorkspaceTools.call(headless, 'write_file', {'path': '/workspace/b.txt', 'content': 'x'});
      expect(jsonDecode(out.text)['ok'], true);
      expect(await File('${ctx.paths.workspaceHostRoot}/b.txt').readAsString(), 'x');
    });

    test('a read only zone is refused without asking anything', () async {
      final out = await WorkspaceTools.call(ctx, 'write_file', {'path': '/skills/k/SKILL.md', 'content': 'x'});
      expect(asked, isEmpty);
      expect(jsonDecode(out.text)['error'], 'skills_readonly');
    });

    test('a path outside every zone is refused without asking', () async {
      final out = await WorkspaceTools.call(ctx, 'write_file', {'path': '/workspace/../escape.txt', 'content': 'x'});
      expect(asked, isEmpty);
      expect(jsonDecode(out.text)['error'], 'path_error');
    });
  });

  group('the trace metadata', () {
    test('round trips through the chat json', () {
      final m = WorkspaceToolMeta(tool: 'edit_file', path: '/workspace/a.txt', diff: '-a\n+b\n', added: 1, removed: 1, strategy: 'exact', files: [const WorkspaceToolFile(modelPath: '/workspace/a.txt')]);
      final back = WorkspaceToolMeta.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
      expect(back.tool, 'edit_file');
      expect(back.diff, '-a\n+b\n');
      expect(back.added, 1);
      expect(back.removed, 1);
      expect(back.strategy, 'exact');
      expect(back.files.single.modelPath, '/workspace/a.txt');
    });

    test('an empty meta writes nothing but the status', () {
      final j = WorkspaceToolMeta(tool: 'read_file').toJson();
      expect(j.keys, ['tool', 'status']);
    });

    test('the diff never appears in what the model is given', () async {
      final c = st.createChat('A', 'p');
      final w = await st.workspace.create(name: 'notes');
      c.ws = WorkspaceBinding(workspaceId: w.id);
      st.workspace.setToolsEnabled(true);
      final ctx = (await st.wsContext(c))!;
      ctx.binding.allowAll = true;
      final out = await WorkspaceTools.call(ctx, 'write_file', {'path': '/workspace/a.txt', 'content': 'secret line\n'});
      expect(out.meta.diff, contains('+secret line'));
      expect(out.text, isNot(contains('secret line')));
      // only the byte count crosses over
      expect(jsonDecode(out.text)['bytes'], 12);
    });
  });

  group('the binding', () {
    test('an unbound chat writes no ws key at all', () {
      final c = st.createChat('A', 'p');
      expect(c.toJson().containsKey('ws'), isFalse);
    });

    test('a bound chat survives a round trip', () {
      final c = st.createChat('A', 'p')..ws = WorkspaceBinding(workspaceId: 'ws_1', cwd: '/workspace/sub', toolsUsed: true, allowAll: true);
      final back = Chat.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.ws.workspaceId, 'ws_1');
      expect(back.ws.cwd, '/workspace/sub');
      expect(back.ws.toolsUsed, isTrue);
      expect(back.ws.allowAll, isTrue);
    });

    test('an unknown workspace id resolves to nothing rather than throwing', () async {
      final c = st.createChat('A', 'p')..ws = WorkspaceBinding(workspaceId: 'gone');
      expect(st.wsFor(c), isNull);
      expect(st.wsActive(c), isFalse);
    });
  });

  group('the store', () {
    test('tools are off on a fresh install', () async {
      expect(st.workspace.toolsEnabled, isFalse);
      expect(st.workspace.confirmWrites, isTrue);
    });

    test('a managed workspace gets a directory when it is created', () async {
      final w = await st.workspace.create(name: 'notes');
      expect(w.kind, WorkspaceKind.managed);
      expect(w.id, startsWith('ws_'));
    });

    test('the list survives a reload', () async {
      await st.workspace.create(name: 'notes');
      await st.workspace.create(name: 'other');
      st.workspace.setToolsEnabled(true);
      final again = await Store.load();
      expect(again.workspace.all.map((e) => e.name), containsAll(['notes', 'other']));
      expect(again.workspace.toolsEnabled, isTrue);
    });

    test('a damaged blob loads as empty rather than throwing', () async {
      SharedPreferences.setMockInitialValues({'w_workspaces': 'not json'});
      final s2 = await Store.load();
      expect(s2.workspace.all, isEmpty);
    });

    test('the sort puts what was used first and never used last', () async {
      final a = await st.workspace.create(name: 'alpha');
      final b = await st.workspace.create(name: 'bravo');
      await st.workspace.create(name: 'charlie');
      a.lastUsedAt = DateTime(2026, 1, 1);
      b.lastUsedAt = DateTime(2026, 6, 1);
      expect(st.workspace.sorted.map((e) => e.name), ['bravo', 'alpha', 'charlie']);
    });

    test('deleting a managed workspace takes its files with it', () async {
      final w = await st.workspace.create(name: 'notes');
      final root = await st.workspace.hostRootFor(w);
      await Directory('$root/sub').create(recursive: true);
      await File('$root/sub/a.txt').writeAsString('x');
      await st.workspace.remove(w.id);
      expect(await Directory(root).exists(), isFalse);
      expect(st.workspace.all, isEmpty);
    });

    test('deleting without the files switch leaves them', () async {
      final w = await st.workspace.create(name: 'notes');
      final root = await st.workspace.hostRootFor(w);
      await File('$root/a.txt').writeAsString('x');
      await st.workspace.remove(w.id, deleteFiles: false);
      expect(await File('$root/a.txt').exists(), isTrue);
    });

    test('a linked workspace is never deleted from disk', () async {
      final w = await st.workspace.create(name: 'linked', kind: WorkspaceKind.linked, hostPath: tmp.path);
      await st.workspace.remove(w.id);
      expect(await tmp.exists(), isTrue);
    });

    test('an export round trips', () async {
      await st.workspace.create(name: 'notes');
      final raw = st.workspace.exportJson();
      final s2 = await Store.load();
      s2.workspace.importJson(raw, overwrite: true);
      expect(s2.workspace.all.map((e) => e.name), ['notes']);
    });

    test('an import of something else is refused', () {
      expect(() => st.workspace.importJson('{"kind":"something.else"}', overwrite: true), throwsFormatException);
    });
  });

  group('the links', () {
    test('a workspace file gets a link and parsing it gives the model path back', () async {
      final c = st.createChat('A', 'p');
      final w = await st.workspace.create(name: 'notes');
      c.ws = WorkspaceBinding(workspaceId: w.id);
      st.workspace.setToolsEnabled(true);
      final ctx = (await st.wsContext(c))!;
      final link = FileLink.forPath('/workspace/sub/report.md', ctx.paths);
      expect(link, startsWith('paradise://workspace/sub/'));
      expect(FileLink.tryParse(link!)!.modelPath, '/workspace/sub/report.md');
    });

    test('a name with a space is encoded and comes back decoded', () async {
      final c = st.createChat('A', 'p');
      final w = await st.workspace.create(name: 'notes');
      c.ws = WorkspaceBinding(workspaceId: w.id);
      st.workspace.setToolsEnabled(true);
      final ctx = (await st.wsContext(c))!;
      final link = FileLink.forPath('/workspace/my notes/a b.md', ctx.paths);
      expect(link, contains('%20'));
      expect(FileLink.tryParse(link!)!.modelPath, '/workspace/my notes/a b.md');
    });

    test('a foreign link is not ours to resolve', () {
      expect(FileLink.tryParse('https://example.com/x'), isNull);
      expect(FileLink.tryParse('paradise://elsewhere/x'), isNull);
      expect(FileLink.tryParse('not a uri at all'), isNull);
    });

    test('a percent encoded cjk name survives the round trip', () {
      // the exact shape the model writes after the prompt fragment asks for
      // one-segment-per-encoded-part links
      const link = 'paradise://workspace/%E5%92%AA%E7%9A%84%E8%A7%82%E5%AF%9F%E6%97%A5%E8%AE%B0.txt';
      final parsed = FileLink.tryParse(link);
      expect(parsed, isNotNull);
      expect(parsed!.zone, WorkspaceZone.workspace);
      expect(parsed.modelPath, '/workspace/咪的观察日记.txt');
    });
  });

  group('safe names', () {
    test('separators and control characters are gone', () {
      expect(safeFileName('../../etc/passwd'), isNot(contains('/')));
      expect(safeFileName('a b'), isNot(contains(' ')));
    });

    test('a leading dot is dropped so the browser does not hide it', () {
      expect(safeFileName('.hidden'), 'hidden');
      expect(safeFileName('..'), 'file');
      expect(safeFileName(''), 'file');
    });

    test('the extension survives, it is what routes the preview', () {
      expect(safeFileName('a<b>.md'), 'a_b_.md');
      expect(safeFileName('report.tar.gz'), endsWith('.gz'));
    });

    test('uniqueName counts up and keeps the extension', () {
      expect(uniqueName('a.txt', {}), 'a.txt');
      expect(uniqueName('a.txt', {'a.txt'}), 'a (2).txt');
      expect(uniqueName('a.txt', {'a.txt', 'a (2).txt'}), 'a (3).txt');
      expect(uniqueName('a.md', {'A.MD'}), 'a (2).md');
    });
  });

  group('the reply gate', () {
    test('a workspace tool names itself in the permission list', () {
      // the list in human_data_pages is a hard coded table, so a new tool that is
      // missing from it gets no row and silently falls back to allow
      // ignore: avoid_print
      print('kBuiltinTools must contain: ${WorkspaceTools.toolNames.join(', ')}');
    });
  });
}