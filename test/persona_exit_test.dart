import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/main.dart';
import 'package:paradise/ui/persona_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every way out of the persona editor has to pass the discard confirmation:
/// the close button, the system back and the right-swipe gesture.
Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('system back on a dirty editor asks before discarding', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);
    store.createChat('Her', 'be kind');
    await settle(t, 400);

    await t.tap(find.text('Her').first);
    await settle(t, 900);
    await t.tap(find.text('Her').last);
    await settle(t, 900);
    await t.tap(find.text('Edit').last);
    await settle(t, 900);
    expect(find.byType(PersonaCardPage), findsOneWidget);

    // type something so the editor counts as dirty; scope to the page or the
    // chat input underneath would swallow the text
    final nameField = find.descendant(of: find.byType(PersonaCardPage), matching: find.byType(EditableText)).first;
    await t.enterText(nameField, 'Her renamed');
    await settle(t, 200);

    final l = AppLocalizationsEn();
    // system back: the route pop attempt must hit the confirm dialog
    Navigator.of(t.element(find.byType(PersonaCardPage))).maybePop();
    await settle(t, 900);
    expect(find.text(l.accountDiscardTitle), findsOneWidget, reason: 'back on dirty editor must ask');

    // declining keeps the editor open with the text intact
    await t.tap(find.text(l.actionCancel));
    await settle(t, 900);
    expect(find.byType(PersonaCardPage), findsOneWidget);
    expect(find.text('Her renamed'), findsWidgets);

    // a second back and a confirm this time actually leaves
    Navigator.of(t.element(find.byType(PersonaCardPage))).maybePop();
    await settle(t, 900);
    expect(find.text(l.accountDiscardTitle), findsOneWidget);
    await t.tap(find.text(l.actionDiscard));
    await settle(t, 900);
    expect(find.byType(PersonaCardPage), findsNothing);
  });

  testWidgets('a right-swipe on a dirty editor asks before popping', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);
    store.createChat('Her', 'be kind');
    await settle(t, 400);

    await t.tap(find.text('Her').first);
    await settle(t, 900);
    await t.tap(find.text('Her').last);
    await settle(t, 900);
    await t.tap(find.text('Edit').last);
    await settle(t, 900);

    final nameField = find.descendant(of: find.byType(PersonaCardPage), matching: find.byType(EditableText)).first;
    await t.enterText(nameField, 'swipe test');
    await settle(t, 200);

    final l = AppLocalizationsEn();
    // a committed right swipe: past a third of the width the gesture would
    // have popped silently before the confirm hook existed. starts on the
    // preview cover: a drag that begins on a text field is claimed by the
    // field's own selection gestures. moves in steps like a real finger,
    // a single-jump drag is treated as a fling and never settles the arena
    final g = await t.startGesture(const Offset(6, 150));
    await g.moveBy(const Offset(60, 0));
    await g.moveBy(const Offset(120, 0));
    await g.moveBy(const Offset(120, 0));
    await g.up();
    await settle(t, 900);
    expect(find.text(l.accountDiscardTitle), findsOneWidget, reason: 'swipe on dirty editor must ask');

    await t.tap(find.text(l.actionCancel));
    await settle(t, 900);
    expect(find.byType(PersonaCardPage), findsOneWidget, reason: 'declining the swipe keeps the editor');
    expect(find.text('swipe test'), findsWidgets);
  });

  testWidgets('a clean editor leaves without asking', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);
    store.createChat('Her', 'be kind');
    await settle(t, 400);

    await t.tap(find.text('Her').first);
    await settle(t, 900);
    await t.tap(find.text('Her').last);
    await settle(t, 900);
    await t.tap(find.text('Edit').last);
    await settle(t, 900);

    // no edits: back pops straight away, no dialog
    Navigator.of(t.element(find.byType(PersonaCardPage))).maybePop();
    await settle(t, 900);
    expect(find.byType(PersonaCardPage), findsNothing);
    expect(find.text(AppLocalizationsEn().accountDiscardTitle), findsNothing);
  });
}
