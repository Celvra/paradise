import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/app_info.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/about_deps.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/l10n/gen/l10n_zh.dart';
import 'package:paradise/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

// The about screen used to be a dialog with the licence, the repository, the
// two projects this one was modelled on and all twenty seven dependencies
// inside one scrollable paragraph. These check the page replaced it: every
// address is its own target, and the dependency list is a row per package
// rather than one string nobody can edit.
void main() {
  Future<void> openAbout(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({'chats': '[]'});
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    // the tests drive in-app screens, not the wizard
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);
    await t.tap(find.text('Settings').last);
    await settle(t, 800);
    // The settings list is taller than the fold, so the About row may not have
    // been built yet and ensureVisible cannot find it. Drag the settings list
    // itself, located through a row that is on screen, until About is in view.
    final list = find.ancestor(of: find.text('Data and Storage'), matching: find.byType(ListView));
    await t.dragUntilVisible(find.text('About'), list, const Offset(0, -220));
    await settle(t, 400);
    final row = find.text('About').last;
    await t.ensureVisible(row);
    await settle(t, 400);
    await t.tap(row);
    await settle(t, 800);
  }

  testWidgets('the about entry opens a page, not a dialog', (t) async {
    await openAbout(t);
    // the settings row and the page both name the build, and they are the only
    // two places it appears
    expect(find.text('Version $appVersion'), findsNWidgets(2));
    // the repository, the community and the QQ group are rows now
    expect(find.text('Source code'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('QQ group'), findsOneWidget);
    // the thanks block ends with the contributors list, fetched live
    expect(find.text('Contributors'), findsOneWidget);
  });

  testWidgets('the licences row opens the dependency list', (t) async {
    await openAbout(t);
    // the row is the last block of the page, below the fold on a short viewport
    final row = find.text('Open source licenses');
    await t.dragUntilVisible(row, find.byType(ListView).last, const Offset(0, -220));
    await settle(t, 400);
    await t.tap(row);
    await settle(t, 800);
    // one row per package, each carrying name, version and licence
    expect(find.text('${aboutDeps.first.name} ${aboutDeps.first.version}'), findsOneWidget);
    expect(find.text(aboutDeps.first.licence), findsWidgets);
    expect(find.text(aboutDeps.first.purpose(AppLocalizationsEn())), findsOneWidget);
  });

  test('every listed dependency has a localised purpose in all three languages', () {
    // a package added to the list without its strings would print an empty
    // line on the licences page, and an empty line reads as a layout bug
    for (final dep in aboutDeps) {
      expect(dep.purpose(AppLocalizationsEn()), isNotEmpty, reason: dep.name);
      expect(dep.purpose(AppLocalizationsZh()), isNotEmpty, reason: dep.name);
      expect(dep.purpose(AppLocalizationsZhHant()), isNotEmpty, reason: dep.name);
    }
  });

  test('the licences are listed alphabetically and no package is listed twice', () {
    final names = aboutDeps.map((d) => d.name).toList();
    expect(names.toSet().length, names.length);
    final sorted = [...names]..sort();
    expect(names, sorted);
  });
}