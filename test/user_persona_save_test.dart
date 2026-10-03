import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/main.dart';
import 'package:paradise/ui/tg_cells.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// The persona card editors in My Account.
///
/// The save row is only armed once something actually changed, and the arms are
/// read off the three text controllers. Typing does not reach the section on
/// its own, so the row used to stay dead after an edit: the text was in the
/// field, the store never saw it, and there was no other way out of the page.
void main() {
  Future<Store> boot(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({
      'chats': '[]',
      'userName': 'Mingxi',
      'userPersonas': jsonEncode([
        {'id': 'p1', 'name': 'Mingxi', 'title': '', 'description': 'a tester', 'color': 4},
      ]),
      'activePersona': 'p1',
      'defaultPersona': 'p1',
    });
    // a tall viewport, the section plus the account blocks above it do not
    // fit on the phone sized one the other tests use
    t.view.physicalSize = const Size(1080, 3400);
    t.view.devicePixelRatio = 2.0;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);
    await t.tap(find.text('Settings').last);
    await settle(t, 800);
    await t.tap(find.text('My Account'));
    await settle(t, 800);
    // the card section lives below the bio and the photo rows. the settings
    // page underneath keeps its own scrollable alive, so aim at the last one
    await t.scrollUntilVisible(find.text('Save Card'), 200, scrollable: find.byType(Scrollable).last);
    await settle(t, 400);
    expect(find.text('Save Card'), findsOneWidget);
    return store;
  }

  /// The three editors of the card in hand, after the account name and bio
  Finder cardField(int i) => find.byType(EditableText).at(i + 2);

  Finder saveRow() => find.widgetWithText(TgActionRow, 'Save Card');

  VoidCallback? saveTap(WidgetTester t) => t.widget<TgActionRow>(saveRow()).onTap;

  testWidgets('typing into the card arms the save row and the row stores it', (t) async {
    final store = await boot(t);
    expect(saveTap(t), isNull, reason: 'nothing changed yet, so the row stays asleep');

    await t.enterText(cardField(0), 'Mingxi Ren');
    await settle(t, 200);

    expect(saveTap(t), isNotNull, reason: 'an edit has to wake the save row');
    await t.tap(saveRow());
    await settle(t, 200);
    expect(store.activePersona.name, 'Mingxi Ren');
  });

  testWidgets('the title and the description reach the store as well', (t) async {
    final store = await boot(t);

    await t.enterText(cardField(1), 'Freelancer');
    await t.enterText(cardField(2), 'lives in aarch64 linux');
    await settle(t, 200);

    expect(saveTap(t), isNotNull);
    await t.tap(saveRow());
    await settle(t, 200);
    expect(store.activePersona.title, 'Freelancer');
    expect(store.activePersona.description, 'lives in aarch64 linux');
  });

  testWidgets('a saved card goes back to sleep and survives a reload', (t) async {
    await boot(t);
    await t.enterText(cardField(0), 'Mingxi Ren');
    await settle(t, 200);
    await t.tap(saveRow());
    await settle(t, 200);

    expect(saveTap(t), isNull, reason: 'nothing is pending after a save');

    final reloaded = await Store.load();
    expect(reloaded.activePersona.name, 'Mingxi Ren');
  });

  testWidgets('switching cards keeps the edit on the card it was typed into', (t) async {
    final store = await boot(t);
    await t.enterText(cardField(0), 'Mingxi Ren');
    await settle(t, 200);

    // a second card, then switch to it without pressing save
    await t.tap(find.text('New card'));
    await settle(t, 400);
    await t.enterText(cardField(0), 'Second');
    await settle(t, 200);
    await t.tap(saveRow());
    await settle(t, 200);

    // back to the first card in the strip, its own text is still there
    expect(store.personas.length, 2);
    expect(store.personas.first.name, 'Mingxi Ren');
    expect(store.personas.last.name, 'Second');
  });
}