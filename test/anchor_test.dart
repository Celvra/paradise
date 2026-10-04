import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/overlays.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/core/ui_kit.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/l10n/x.dart';
import 'package:paradise/ui/tg_cells.dart';
import 'package:paradise/ui/workspace/workspace_prompts.dart';

// Where a menu opens from. The bug this guards against is a menu anchored to
// the page instead of the button, which puts it in the bottom corner of the
// screen with no visible connection to the thing that was tapped.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => L10n.sync(AppLocalizationsEn()));

  testWidgets('a keyed anchor is the button, not the page', (t) async {
    final pageKey = GlobalKey();
    final buttonKey = GlobalKey();

    await t.pumpWidget(MaterialApp(
      home: ThemeScope(
        controller: themeCtl,
        child: Scaffold(
          key: pageKey,
          body: Stack(children: [
            Positioned(
              right: 8,
              top: 60,
              child: SizedBox(
                key: buttonKey,
                width: 38,
                height: 38,
                child: TgIconButton(icon: Ic.more, onTap: () {}),
              ),
            ),
          ]),
        ),
      ),
    ));

    final page = rectOf(t.element(find.byKey(pageKey)));
    final button = anchorRect(buttonKey);

    expect(button.width, lessThan(page.width / 4));
    expect(button.top, greaterThan(40));
    expect(button.top, lessThan(120));
    // and the two are nowhere near each other, which is the whole point
    expect(button.top - page.top, greaterThan(20));
  });

  testWidgets('an anchor with no widget yet is zero rather than a throw',
      (_) async {
    expect(anchorRect(GlobalKey()), Rect.zero);
  });

  testWidgets('showMenuAt places the popup under the button', (t) async {
    final buttonKey = GlobalKey();

    await t.pumpWidget(MaterialApp(
      home: ThemeScope(
        controller: themeCtl,
        child: Scaffold(
          body: Stack(children: [
            Positioned(
              right: 8,
              top: 60,
              child: SizedBox(
                key: buttonKey,
                width: 38,
                height: 38,
                child: TgIconButton(
                    icon: Ic.more,
                    onTap: () async {
                      await showMenuAt(
                          t.element(find.byKey(buttonKey)), buttonKey, [
                        const MenuItem('one', Ic.check, _noop),
                        const MenuItem('two', Ic.check, _noop),
                      ]);
                    }),
              ),
            ),
          ]),
        ),
      ),
    ));

    await t.tap(find.byType(TgIconButton));
    await t.pumpAndSettle();

    final button = anchorRect(buttonKey);
    // one of the menu's own labels exists, and it sits below the button rather
    // than at the bottom of the screen
    expect(find.text('one'), findsOneWidget);
    final one = t.getRect(find.text('one'));
    expect(one.top, greaterThan(button.bottom - 1));
    expect(one.top, lessThan(button.bottom + 80));
  });

  testWidgets('a menu anchored low opens upward instead of off screen',
      (t) async {
    final buttonKey = GlobalKey();

    await t.pumpWidget(MaterialApp(
      home: ThemeScope(
        controller: themeCtl,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 700)),
          child: Scaffold(
            body: Stack(children: [
              Positioned(
                right: 8,
                // near the bottom, where there is no room below
                bottom: 6,
                child: SizedBox(
                  key: buttonKey,
                  width: 38,
                  height: 38,
                  child: TgIconButton(
                      icon: Ic.more,
                      onTap: () async {
                        await showMenuAt(
                            t.element(find.byKey(buttonKey)), buttonKey, [
                          const MenuItem('a', Ic.check, _noop),
                          const MenuItem('b', Ic.check, _noop),
                          const MenuItem('c', Ic.check, _noop),
                        ]);
                      }),
                ),
              ),
            ]),
          ),
        ),
      ),
    ));

    await t.tap(find.byType(TgIconButton));
    await t.pumpAndSettle();

    expect(find.text('a'), findsOneWidget);
    final button = anchorRect(buttonKey);
    final a = t.getRect(find.text('a'));
    // above the button rather than below it and off the bottom
    expect(a.bottom, lessThanOrEqualTo(button.top + 1));
  });
}

void _noop() {}
