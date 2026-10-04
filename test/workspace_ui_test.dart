import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/anim.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/core/ui_kit.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/ai/content.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/data/workspace/workspace_metadata.dart';
import 'package:paradise/l10n/x.dart';
import 'package:paradise/ui/human_data_pages.dart';
import 'package:paradise/ui/tool_descriptions.dart';
import 'package:paradise/ui/trace_view.dart';
import 'package:paradise/data/workspace/workspace_tools.dart';
import 'package:paradise/ui/human_data_pages.dart' show kBuiltinTools, kWorkspaceTools;
import 'package:paradise/ui/workspace/preview_file_type.dart';
import 'package:paradise/ui/workspace/preview_kind.dart';
import 'package:paradise/ui/workspace/ws_trace_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_paths.dart';

// The row a workspace tool leaves in the transcript. It is the only place the
// user sees that something on the device changed, so what it does and does not
// show is the whole feature.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Future<void> boot() async {
    await useTempDocsDir('ws_ui');
    L10n.sync(AppLocalizationsEn());
  }


  Msg row(WorkspaceToolMeta? ws, {String tool = 'write_file', String result = '', String state = 'ok', String chatId = 'c1'}) {
    final m = Msg(
      id: 'r1',
      out: false,
      time: DateTime.now().millisecondsSinceEpoch,
      text: '',
      service: true,
      kind: MsgKind.trace,
    );
    m.data.addAll({
      'type': 'tool',
      'tool': tool,
      'args': {'path': '/workspace/a.txt'},
      'result': result,
      'chatId': chatId,
      't0': DateTime.now().millisecondsSinceEpoch - 1200,
      'ms': 1200,
      'state': state,
      if (ws != null) 'ws': ws.toJson(),
    });
    return m;
  }

  Widget wrap(Widget child, {double width = 380}) => MaterialApp(
        home: ThemeScope(
          controller: themeCtl,
          child: MediaQuery(data: MediaQueryData(size: Size(width, 800)), child: SizedBox(width: width, child: child)),
        ),
      );

  setUp(boot);

  /// A finished step folds itself away, so the panel is behind a tap. That is the
  /// behaviour and not a test artefact, so every panel test opens it first.
  Future<void> open(WidgetTester t) async {
    // the header is the tap target, not the whole row, and the row is only as
    // tall as its folded header so its centre is below it
    await t.tap(find.byType(Tap).first);
    await t.pumpAndSettle();
  }

  group('the panel', () {
    testWidgets('a write shows its path, its counts and its diff', (t) async {
      final m = row(WorkspaceToolMeta(
        tool: 'edit_file',
        path: '/workspace/notes.md',
        diff: '@@ -1,2 +1,2 @@\n one\n-two\n+TWO\n',
        added: 1,
        removed: 1,
        files: const [WorkspaceToolFile(modelPath: '/workspace/notes.md')],
      ));
      await t.pumpWidget(wrap(TraceView(msg: m)));
      await t.pumpAndSettle();
      await open(t);
      // the title and the path line both name it, which is the point
      expect(find.textContaining('notes.md'), findsNWidgets(2));
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('−1'), findsOneWidget);
      expect(find.text('-two'), findsOneWidget);
      expect(find.text('+TWO'), findsOneWidget);
    });

    testWidgets('the diff hunk headers are not repeated in the body', (t) async {
      final m = row(WorkspaceToolMeta(
        tool: 'edit_file',
        path: '/workspace/a.txt',
        diff: '--- a/workspace/a.txt\n+++ b/workspace/a.txt\n@@ -1 +1 @@\n-a\n+b\n',
      ));
      await t.pumpWidget(wrap(TraceView(msg: m)));
      await t.pumpAndSettle();
      await open(t);
      expect(find.textContaining('@@'), findsNothing);
      expect(find.textContaining('--- a/'), findsNothing);
    });

    testWidgets('a read shows the line count and no diff', (t) async {
      final m = row(
        WorkspaceToolMeta(tool: 'read_file', path: '/workspace/big.txt', lines: 412),
        tool: 'read_file',
      );
      await t.pumpWidget(wrap(TraceView(msg: m)));
      await t.pumpAndSettle();
      await open(t);
      expect(find.textContaining('412'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('a search lists the files it matched', (t) async {
      final m = row(
        WorkspaceToolMeta(
          tool: 'grep',
          count: 3,
          files: const [
            WorkspaceToolFile(modelPath: '/workspace/src/a.dart'),
            WorkspaceToolFile(modelPath: '/workspace/src/b.dart'),
            WorkspaceToolFile(modelPath: '/workspace/test/c.dart'),
          ],
        ),
        tool: 'grep',
      );
      await t.pumpWidget(wrap(TraceView(msg: m)));
      await t.pumpAndSettle();
      await open(t);
      expect(find.text('a.dart'), findsOneWidget);
      expect(find.text('b.dart'), findsOneWidget);
      expect(find.text('c.dart'), findsOneWidget);
    });

    testWidgets('a refusal is tinted and says so in the title', (t) async {
      final m = row(
        WorkspaceToolMeta(tool: 'write_file', status: 'denied', code: 'write_refused', path: '/workspace/a.txt'),
        result: '{"error":"write_refused"}',
        state: 'err',
      );
      await t.pumpWidget(wrap(TraceView(msg: m)));
      await t.pumpAndSettle();
      await open(t);
      expect(find.textContaining('refused'), findsWidgets);
    });

    testWidgets('a non exact match is called out next to the counts', (t) async {
      final m = row(WorkspaceToolMeta(
        tool: 'edit_file',
        path: '/workspace/a.dart',
        diff: '-a\n+b\n',
        added: 1,
        removed: 1,
        strategy: 'line-trimmed',
      ));
      await t.pumpWidget(wrap(TraceView(msg: m)));
      await t.pumpAndSettle();
      await open(t);
      expect(find.text('line-trimmed'), findsOneWidget);
    });

    testWidgets('a non workspace tool still renders the generic body', (t) async {
      final m = row(null, tool: 'fetch_url', result: 'page text');
      await t.pumpWidget(wrap(TraceView(msg: m)));
      await t.pumpAndSettle();
      await open(t);
      // the generic path is the json argument dump, not the workspace layout
      expect(find.textContaining('page text'), findsOneWidget);
    });

    testWidgets('an ordinary think is unaffected', (t) async {
      final m = Msg(id: 'r2', out: false, time: 0, text: '', service: true, kind: MsgKind.trace)
        ..data.addAll({'type': 'think', 'body': 'pondering', 'state': 'ok', 'ms': 100, 't0': 0});
      await t.pumpWidget(wrap(TraceView(msg: m)));
      await t.pumpAndSettle();
      await open(t);
      expect(find.textContaining('pondering'), findsOneWidget);
    });
  });

  group('titles', () {
    test('a write names the file it touched', () {
      expect(WsTraceBody.titleFor(WorkspaceToolMeta(tool: 'write_file', path: '/workspace/report.md'), 'write_file'), 'Write · report.md');
      expect(WsTraceBody.titleFor(WorkspaceToolMeta(tool: 'read_file', path: '/workspace/report.md'), 'read_file'), 'Read · report.md');
      expect(WsTraceBody.titleFor(WorkspaceToolMeta(tool: 'list_dir', path: '/workspace'), 'list_dir'), 'List · workspace');
    });

    test('a refusal reads as a refusal, not as a write that happened', () {
      expect(WsTraceBody.titleFor(WorkspaceToolMeta(tool: 'write_file', status: 'denied', path: '/workspace/a.txt'), 'write_file'), 'refused');
    });

    test('a tool with no path falls back to its verb alone', () {
      expect(WsTraceBody.titleFor(WorkspaceToolMeta(tool: 'glob'), 'glob'), 'Find');
      expect(WsTraceBody.titleFor(WorkspaceToolMeta(tool: 'grep'), 'grep'), 'Search');
    });

    test('an unknown tool keeps its raw name', () {
      expect(WsTraceBody.titleFor(WorkspaceToolMeta(tool: 'shell'), 'shell'), 'shell');
    });
  });

  group('chips', () {
    testWidgets('a chip reports the model path it was given', (t) async {
      String? opened;
      await t.pumpWidget(
        wrap(Material(
          child: WsTraceBody(
            meta: WorkspaceToolMeta(
              tool: 'grep',
              count: 1,
              files: const [WorkspaceToolFile(modelPath: '/workspace/deep/nested/file.dart')],
            ),
            result: '',
            running: false,
            onOpenFile: (p) => opened = p,
          ),
        )),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('file.dart'));
      expect(opened, '/workspace/deep/nested/file.dart');
    });

    testWidgets('a chip with no handler is inert rather than throwing', (t) async {
      await t.pumpWidget(
        wrap(Material(
          child: WsTraceBody(
            meta: WorkspaceToolMeta(tool: 'grep', count: 1, files: const [WorkspaceToolFile(modelPath: '/workspace/a.dart')]),
            result: '',
            running: false,
          ),
        )),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('a.dart'));
      // no exception is the assertion
      expect(t.takeException(), isNull);
    });

    testWidgets('a long list is capped and says how many were dropped', (t) async {
      await t.pumpWidget(
        wrap(Material(
          child: WsTraceBody(
            meta: WorkspaceToolMeta(tool: 'glob', count: 40, files: [for (var i = 0; i < 40; i++) WorkspaceToolFile(modelPath: '/workspace/f$i.dart')]),
            result: '',
            running: false,
          ),
        )),
      );
      await t.pumpAndSettle();
      expect(find.text('+28'), findsOneWidget);
    });
  });

  group('metadata', () {
    test('a row written today reads back the same tomorrow', () {
      final m = WorkspaceToolMeta(
        tool: 'edit_file',
        path: '/workspace/a.dart',
        diff: '-a\n+b\n',
        added: 1,
        removed: 2,
        strategy: 'block-anchor',
        created: true,
        bytes: 4096,
        count: 7,
        truncated: true,
        lines: 99,
        files: const [WorkspaceToolFile(modelPath: '/workspace/a.dart', role: WorkspaceFileRole.modified)],
      );
      final back = WorkspaceToolMeta.fromJson(Map<String, dynamic>.from(m.toJson()));
      expect(back.diff, m.diff);
      expect(back.added, 1);
      expect(back.removed, 2);
      expect(back.strategy, 'block-anchor');
      expect(back.created, isTrue);
      expect(back.bytes, 4096);
      expect(back.count, 7);
      expect(back.truncated, isTrue);
      expect(back.lines, 99);
      expect(back.files.single.role, WorkspaceFileRole.modified);
    });

    test('an unknown role degrades to referenced rather than throwing', () {
      final f = WorkspaceToolFile.fromJson({'path': '/a', 'r': 'something-new'});
      expect(f.role, WorkspaceFileRole.referenced);
    });

    test('a changed file is a changed file', () {
      expect(const WorkspaceToolFile(modelPath: '/a', role: WorkspaceFileRole.created).isChanged, isTrue);
      expect(const WorkspaceToolFile(modelPath: '/a', role: WorkspaceFileRole.modified).isChanged, isTrue);
      expect(const WorkspaceToolFile(modelPath: '/a').isChanged, isFalse);
    });
  });

  group('preview routing', () {
    test('an extension picks the renderer', () {
      expect(previewKindFor('a.png'), PreviewKind.image);
      expect(previewKindFor('a.md'), PreviewKind.markdown);
      expect(previewKindFor('a.html'), PreviewKind.html);
      expect(previewKindFor('a.csv'), PreviewKind.csv);
      expect(previewKindFor('a.dart'), PreviewKind.code);
    });

    test('an unknown extension is text unless the bytes say otherwise', () {
      expect(previewKindFor('README'), PreviewKind.code);
      expect(previewKindFor('README', sniffedText: false), PreviewKind.binary);
    });

    test('a dotfile with no extension is still code', () {
      expect(previewKindFor('.gitignore'), PreviewKind.code);
      expect(previewLanguage('.gitignore'), 'shell');
      expect(previewLanguage('.bashrc'), 'shell');
    });

    test('a language is only guessed where one exists', () {
      expect(previewLanguage('a.dart'), 'dart');
      expect(previewLanguage('a.tsx'), 'typescript');
      expect(previewLanguage('a.unknownext'), isNull);
      expect(previewLanguage('noextension'), isNull);
    });

    test('html and csv are not handed to a highlighter that has no grammar for them', () {
      expect(previewLanguage('a.html'), 'xml');
      expect(previewLanguage('a.csv'), 'plaintext');
    });

    test('the icon matches the kind', () {
      expect(fileTypeIcon('a.png'), isNot(fileTypeIcon('a.dart')));
      expect(fileTypeIcon('a.pdf'), isNot(fileTypeIcon('a.zip')));
      // an extensionless file is still recognised as text by its name
      expect(fileTypeIcon('LICENSE'), fileTypeIcon('README'));
      expect(fileTypeIcon('LICENSE'), fileTypeIcon('LICENSE'));
      // and something with no signal at all falls back rather than going blank
      expect(fileTypeIcon('x.qqq'), Ic.file);
    });
  });

  group('tool descriptions', () {
    // a tool with no description renders as a name over a blank line, which reads
    // as a bug rather than as a missing string. this is what stops that
    test('every tool on the tools page has one', () {
      final l = AppLocalizationsEn();
      for (final t in kBuiltinTools) {
        expect(toolDescription(l, t), isNotNull, reason: '$t has no description');
        expect(toolDescription(l, t)!.trim(), isNotEmpty, reason: '$t has an empty description');
      }
    });

    test('every workspace gated tool has a row on the tools page', () {
      // a tool missing from kBuiltinTools gets no permission row and silently
      // falls back to the default, which for a local tool is allow
      expect(kBuiltinTools.where(kWorkspaceTools.contains).toSet(), kWorkspaceTools);
      expect(kWorkspaceTools, WorkspaceTools.toolNames);
      for (final t in kWorkspaceTools) {
        expect(toolDescription(AppLocalizationsEn(), t), isNotNull, reason: '$t has no description');
      }
    });

    test('an mcp tool with no description falls back to its name, not to nothing', () {
      expect(mcpToolDescription('fetch', ''), 'fetch');
      expect(mcpToolDescription('fetch', '   '), 'fetch');
      expect(mcpToolDescription('fetch', 'a\nb'), 'a b');
    });

    test('an mcp server with no address says so', () {
      final l = AppLocalizationsEn();
      expect(mcpServerDescription('', 3, l), contains(l.toolNoUrl));
      expect(mcpServerDescription('https://x', 3, l), contains('https://x'));
      expect(mcpServerDescription('https://x', 3, l), contains(l.toolCountSuffix(3)));
    });

    test('an unknown tool has no description rather than a wrong one', () {
      expect(toolDescription(AppLocalizationsEn(), 'rm_rf'), isNull);
    });
  });

  group('the store wiring a row needs', () {
    test('a trace row carries its chat so a file can be resolved later', () async {
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      final m = st.traceTool(c, ToolCallPart(id: 'x', name: 'read_file', args: const {'path': '/workspace/a.txt'}));
      expect(m.data['chatId'], c.id);
      // and it survives the round trip, which is the whole reason for writing it
      final back = Msg.fromJson(Map<String, dynamic>.from(m.toJson()));
      expect(back.data['chatId'], c.id);
    });
  });
}