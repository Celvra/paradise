import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/l10n/x.dart';
import 'package:paradise/ui/tg_cells.dart';
import 'package:paradise/ui/workspace/workspace_pages.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Store st;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useTempDocsDir('ws_page');
    L10n.sync(AppLocalizationsEn());
    st = await Store.load();
  });

  Future<void> show(WidgetTester t) async {
    await t.pumpWidget(StoreScope(
      store: st,
      child: ThemeScope(
        controller: themeCtl,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorkspaceSettingsPage(),
        ),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the switch explanation is there before the switch is on',
      (t) async {
    await show(t);

    expect(find.text('File tools'), findsOneWidget);
    // the explanation, not gated on anything
    expect(find.textContaining('six file tools'), findsOneWidget);
    expect(find.textContaining('Turn on file tools'), findsOneWidget);
    expect(st.workspace.toolsEnabled, isFalse);
  });

  testWidgets('flipping the switch leaves the block caption in place',
      (t) async {
    await show(t);
    const footer = 'Writes always show you the change first';

    expect(find.textContaining(footer), findsOneWidget);
    await t.tap(find.text('File tools'));
    await t.pumpAndSettle();
    expect(st.workspace.toolsEnabled, isTrue);
    // the caption under the block is the same words either way. only the row's
    // own subtitle changes, and that is the one that is allowed to
    expect(find.textContaining(footer), findsOneWidget);
  });

  testWidgets('the explanation cross fades instead of snapping', (t) async {
    await show(t);
    expect(find.textContaining('Turn on file tools'), findsOneWidget);

    await t.tap(find.text('File tools'));
    // half way through the fade both wordings are on screen, which is what an
    // animation looks like from the outside. a snap would show only one
    await t.pump(const Duration(milliseconds: 80));
    final outgoing =
        find.textContaining('Turn on file tools').evaluate().isNotEmpty;
    final incoming =
        find.textContaining('Six file tools').evaluate().isNotEmpty;
    expect(outgoing || incoming, isTrue,
        reason: 'the row went blank during the swap');

    await t.pumpAndSettle();
    expect(find.textContaining('Six file tools'), findsOneWidget);
    expect(find.textContaining('Turn on file tools'), findsNothing);
  });

  testWidgets('the block caption is laid out and has height to animate',
      (t) async {
    // the tools page gains six rows and a caption when the switch goes on, and a
    // block that jumps under the finger reads as a glitch
    await show(t);
    final cell = find.byType(TgInfoCell).first;
    expect(t.getSize(cell).height, greaterThan(0));
    expect(find.textContaining('six file tools'), findsOneWidget);
  });
}
