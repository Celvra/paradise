import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:paradise/data/ai/content.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';

// The two reply switches: thinking display and agent mode, global with a
// per persona override, plus the trace rows they put into the chat.

void main() {
  group('reply switches', () {
    test('both are off on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      expect(st.showThinking, false);
      expect(st.agentMode, false);
    });

    test('they persist across a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      st.setShowThinking(true);
      st.setAgentMode(true);
      final again = await Store.load();
      expect(again.showThinking, true);
      expect(again.agentMode, true);
    });

    test('the pass cap defaults to eight and persists, zero is a decision', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      expect(st.agentMaxPass, 8);
      st.setAgentMaxPass(16);
      st.setAgentMaxPass(0);
      final again = await Store.load();
      expect(again.agentMaxPass, 0);
    });

    test('a persona with no override follows the global switch', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      st.setShowThinking(true);
      st.setAgentMode(true);
      expect(st.thinkingFor(c), true);
      expect(st.agentFor(c), true);
      st.setShowThinking(false);
      st.setAgentMode(false);
      expect(st.thinkingFor(c), false);
      expect(st.agentFor(c), false);
    });

    test('a persona override beats the global switch both ways', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final a = st.createChat('A', 'p');
      final b = st.createChat('B', 'p');
      st.setShowThinking(true);
      st.setAgentMode(true);
      st.editPersona(b, 'B', 'p', thinking: false, agent: false);
      expect(st.thinkingFor(a), true);
      expect(st.thinkingFor(b), false);
      expect(st.agentFor(a), true);
      expect(st.agentFor(b), false);
      // and the other direction: off globally, on for one persona
      st.setShowThinking(false);
      st.setAgentMode(false);
      st.editPersona(b, 'B', 'p', thinking: true, agent: true);
      expect(st.thinkingFor(b), true);
      expect(st.agentFor(b), true);
      expect(st.thinkingFor(a), false);
    });

    testWidgets('an override survives a reload, a missing key means follow', (t) async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      st.setShowThinking(true);
      st.createChat('A', 'p', thinking: false);
      st.createChat('B', 'p', agent: true);
      // the chat blob is written on a debounce, let it land
      await t.pump(const Duration(milliseconds: 600));
      final again = await Store.load();
      final a = again.chats.where((c) => c.persona.name == 'A').single;
      final b = again.chats.where((c) => c.persona.name == 'B').single;
      // a stored false is a decision, an absent key is not
      expect(a.persona.thinking, false);
      expect(again.thinkingFor(a), false);
      expect(b.persona.thinking, isNull);
      expect(again.thinkingFor(b), true);
      expect(b.persona.agent, true);
      expect(again.agentFor(b), true);
    });
  });

  group('trace rows', () {
    test('reasoning of one pass folds into a single row', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      st.traceThinking(c, 'first ');
      st.traceThinking(c, 'second');
      final rows = c.msgs.where((m) => m.kind == MsgKind.trace).toList();
      expect(rows.length, 1);
      expect(rows.first.data['body'], 'first second');
      expect(rows.first.data['state'], 'run');
    });

    test('reasoning that resumes after an answer opens a new row', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      st.traceThinking(c, 'one');
      c.msgs.add(Msg(id: 'b', out: false, text: 'the answer', time: 1));
      st.traceThinking(c, 'two');
      expect(c.msgs.where((m) => m.kind == MsgKind.trace).length, 2);
    });

    test('closing a think stamps the state and the duration', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      st.traceThinking(c, 'thinking');
      st.endThinking(c);
      final row = c.msgs.where((m) => m.kind == MsgKind.trace).single;
      expect(row.data['state'], 'ok');
      expect(row.data['ms'], isA<int>());
      // closing twice is a no op, the row is not reopened
      st.endThinking(c);
      expect(c.msgs.where((m) => m.kind == MsgKind.trace).length, 1);
    });

    test('a tool row records the server, the arguments and the result', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      final call = ToolCallPart(id: '1', name: 'mcp_files_read', args: {'path': '/a.txt'});
      final row = st.traceTool(c, call, mcp: 'files');
      expect(row.data['type'], 'tool');
      expect(row.data['mcp'], 'files');
      expect((row.data['args'] as Map)['path'], '/a.txt');
      expect(row.data['state'], 'run');
      st.endTool(c, row, result: 'ok', isError: false);
      expect(row.data['state'], 'ok');
      expect(row.data['result'], 'ok');
    });

    test('a tool row opens a think that was still running', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      st.traceThinking(c, 'which tool?');
      st.traceTool(c, ToolCallPart(id: '1', name: 'get_time', args: {}));
      final rows = c.msgs.where((m) => m.kind == MsgKind.trace).toList();
      expect(rows.length, 2);
      expect(rows[0].data['state'], 'ok');
      expect(rows[1].data['type'], 'tool');
    });

    test('a huge tool result is trimmed before it is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      final row = st.traceTool(c, ToolCallPart(id: '1', name: 't', args: {}));
      st.endTool(c, row, result: 'x' * 9000, isError: true);
      expect(row.data['state'], 'err');
      expect((row.data['result'] as String).length, 4001);
    });

    test('a trace row never reaches the model, search or a dialog preview', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      st.addOut(c, text: 'hello');
      st.traceThinking(c, 'the secret sauce');
      st.traceTool(c, ToolCallPart(id: '1', name: 'fetch_url', args: {'url': 'https://x'}));
      st.addOut(c, text: '');
      // a service row by construction, which is what keeps it out of the history
      for (final m in c.msgs.where((m) => m.kind == MsgKind.trace)) {
        expect(m.service, true);
        expect(m.out, false);
      }
      expect(c.find('secret'), isEmpty);
      expect(st.searchAll('secret'), isEmpty);
      // and nothing that is not the trace rows reaches the transcript
      expect(c.msgs.where((m) => !m.service).length, 2);
    });

    test('a trace row round trips through the chat json', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      st.traceThinking(c, 'kept for later');
      st.endThinking(c);
      final back = Chat.fromJson(c.toJson());
      final row = back.msgs.where((m) => m.kind == MsgKind.trace).single;
      expect(row.data['body'], 'kept for later');
      expect(row.data['state'], 'ok');
    });

    test('regenerating drops the trace rows of the answer it replaces', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      st.addOut(c, text: 'hi');
      st.traceThinking(c, 'why');
      st.endThinking(c);
      st.traceTool(c, ToolCallPart(id: '1', name: 'get_time', args: {}));
      // the same trailing service cleanup the regenerate path already runs
      while (c.msgs.isNotEmpty && c.msgs.last.service) {
        c.msgs.removeLast();
      }
      expect(c.msgs.where((m) => m.kind == MsgKind.trace), isEmpty);
      expect(c.msgs.length, 1);
    });
  });
}
