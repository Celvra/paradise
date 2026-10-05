import 'package:flutter/material.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/main.dart';
import 'package:paradise/ui/dialogs_page.dart';
import 'package:paradise/ui/onboarding/onboarding_page.dart';

/// The step illustrations loop forever, so pumpAndSettle would time out.
/// Pump a bounded span instead: enough for the 260ms page transition and the
/// 220ms selection tweens, not the repeating art.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

Future<Store> _boot(WidgetTester t, {bool onboarded = false}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.load();
  final ai = await AiConfig.load();
  store.attachAi(ai);
  store.onboarded = onboarded;
  await t.pumpWidget(TgApp(store: store, ai: ai));
  await _settle(t);
  return store;
}

/// Walks the wizard from the brand page to the persona page. The privacy step
/// is the odd one out: it advances through its Agree button, not Next.
Future<void> _walkToPersonas(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.tap(find.text(i == 2 ? 'Agree and start' : 'Next').first);
    await _settle(t);
  }
}

void main() {
  testWidgets('a finished store opens straight on the dialogs', (t) async {
    final store = await _boot(t, onboarded: true);
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(DialogsPage), findsOneWidget);
    expect(store.onboarded, true);
  });

  testWidgets('a fresh store opens the wizard', (t) async {
    final store = await _boot(t);
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.byType(DialogsPage), findsNothing);
    expect(store.onboarded, false);
  });

  testWidgets('the wizard opens on the brand page with the version', (t) async {
    await _boot(t);
    expect(find.text('Paradise'), findsWidgets);
    expect(find.text('v1.0.1'), findsOneWidget);

    await t.tap(find.text('Next').first);
    await _settle(t);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('agreeing to privacy advances, and the last step finishes', (t) async {
    final store = await _boot(t);
    // brand -> permissions -> privacy
    await t.tap(find.text('Next').first);
    await _settle(t);
    await t.tap(find.text('Next').first);
    await _settle(t);

    expect(find.text('Agree and start'), findsOneWidget);
    await t.tap(find.text('Agree and start'));
    await _settle(t);
    // agreeing advances to the theme step, it does not finish the wizard
    expect(store.onboarded, false);

    // theme -> model -> workspace -> human -> self -> personas is five Nexts
    for (var i = 0; i < 5; i++) {
      await t.tap(find.text('Next').first);
      await _settle(t);
    }
    await t.tap(find.text('Start').first);
    await _settle(t);

    expect(store.onboarded, true);
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(DialogsPage), findsOneWidget);
  });

  testWidgets('declining the privacy keeps the wizard open', (t) async {
    final store = await _boot(t);
    await t.tap(find.text('Next').first);
    await _settle(t);
    await t.tap(find.text('Next').first);
    await _settle(t);

    await t.tap(find.text('Not now'));
    await _settle(t);
    await t.tap(find.text('OK'));
    await _settle(t);

    expect(store.onboarded, false);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('skip finishes the wizard from any step', (t) async {
    final store = await _boot(t);
    await t.tap(find.text('Skip'));
    await _settle(t);
    expect(store.onboarded, true);
    expect(find.byType(DialogsPage), findsOneWidget);
  });

  testWidgets('the persona step creates one chat per pick with its greeting', (t) async {
    final store = await _boot(t);
    await _walkToPersonas(t);

    // the list builds lazily: scroll each pick into view first. The wizard
    // wraps each step in a PageView, itself a Scrollable, so the list is the
    // last one.
    await t.scrollUntilVisible(find.text('Mimi'), 160, scrollable: find.byType(Scrollable).last);
    await _settle(t);
    await t.tap(find.text('Mimi').first);
    await _settle(t);
    await t.scrollUntilVisible(find.text('Ada'), 160, scrollable: find.byType(Scrollable).last);
    await _settle(t);
    await t.tap(find.text('Ada').first);
    await _settle(t);

    await t.tap(find.text('Start').first);
    await _settle(t);
    // let the chat save debounce (400ms) fire before the tree is torn down
    await t.pump(const Duration(milliseconds: 700));
    await _settle(t);

    expect(store.onboarded, true);
    expect(store.chats.length, 2);
    final names = store.chats.map((c) => c.persona.name).toSet();
    expect(names.contains('Mimi'), true);
    expect(names.contains('Ada'), true);
    for (final c in store.chats) {
      expect(c.msgs, isNotEmpty);
    }
    final ada = store.chats.firstWhere((c) => c.persona.name == 'Ada');
    expect(ada.persona.thinking, true);
    expect(ada.persona.agent, true);
    expect(ada.persona.examples, isNotEmpty);
    final mimi = store.chats.firstWhere((c) => c.persona.name == 'Mimi');
    expect(mimi.persona.thinking, isNull);
    expect(mimi.persona.agent, isNull);
  });

  testWidgets('the relay one-tap stores the public key and builds a chain', (t) async {
    final store = await _boot(t);
    final cfg = store.aiConfig;
    expect(cfg.keyOf('relay'), isEmpty);

    // Drive the relay switch directly: it does a real network fetch with a
    // 10s timeout, and a widget tap would strand that timer inside the fake
    // clock. In the test sandbox sockets are blocked, so the fetch fails fast
    // and the key plus the auto-only fallback chain still land, which is the
    // offline behavior a real user on a dead network gets.
    await t.runAsync(() => cfg.enableRelay());
    await _settle(t);
    expect(cfg.keyOf('relay'), 'public');
    expect(cfg.settings.chain.where((n) => n.providerId == 'relay'), isNotEmpty);
    expect(cfg.settings.chain.first.modelId, 'auto');
  });
}
