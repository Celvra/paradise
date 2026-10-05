import 'package:flutter/material.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/main.dart';
import 'package:paradise/ui/dialogs_page.dart';
import 'package:paradise/ui/onboarding/onboarding_page.dart';
import 'package:paradise/ui/onboarding/splash_page.dart';

Future<Store> _boot(WidgetTester t, {bool onboarded = false}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.load();
  final ai = await AiConfig.load();
  store.attachAi(ai);
  store.onboarded = onboarded;
  await t.pumpWidget(TgApp(store: store, ai: ai));
  // past the 900ms splash swap, plus a settle frame
  await t.pump(const Duration(milliseconds: 1000));
  return store;
}

/// Walks the wizard from the brand page to the persona page. The privacy step
/// is the odd one out: it advances through its Agree button, not Next.
Future<void> _walkToPersonas(WidgetTester t) async {
  for (var i = 0; i < 7; i++) {
    await t.tap(find.text(i == 2 ? 'Agree and start' : 'Next').first);
    await t.pumpAndSettle();
  }
}

void main() {
  testWidgets('a finished store goes straight from the splash to the dialogs', (t) async {
    final store = await _boot(t, onboarded: true);
    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(DialogsPage), findsOneWidget);
    expect(store.onboarded, true);
  });

  testWidgets('a fresh store lands in the wizard after the splash', (t) async {
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
    await t.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('agreeing to privacy advances, and the last step finishes', (t) async {
    final store = await _boot(t);
    // brand -> permissions -> privacy
    await t.tap(find.text('Next').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Next').first);
    await t.pumpAndSettle();

    // the privacy gate is the only road: no bottom Next, Agree is present
    expect(find.text('Agree and start'), findsOneWidget);

    await t.tap(find.text('Agree and start'));
    await t.pumpAndSettle();
    // agreeing advances to the model step, it does not finish the wizard
    expect(store.onboarded, false);

    // model -> workspace -> human -> self -> personas is four Nexts
    for (var i = 0; i < 4; i++) {
      await t.tap(find.text('Next').first);
      await t.pumpAndSettle();
    }
    await t.tap(find.text('Start').first);
    await t.pumpAndSettle();

    expect(store.onboarded, true);
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(DialogsPage), findsOneWidget);
  });

  testWidgets('declining the privacy keeps the wizard open', (t) async {
    final store = await _boot(t);
    await t.tap(find.text('Next').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Next').first);
    await t.pumpAndSettle();

    await t.tap(find.text('Not now'));
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();

    expect(store.onboarded, false);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('the persona step creates one chat per pick with its greeting', (t) async {
    final store = await _boot(t);
    await _walkToPersonas(t);

    await t.tap(find.text('Mimi').first);
    await t.pumpAndSettle();
    // Ada sits below the fold on the short test viewport; the list lazily
    // builds its cards, so bring the row on screen before tapping it
    await t.scrollUntilVisible(find.text('Ada').first, 160, scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Ada').first);
    await t.pumpAndSettle();

    await t.tap(find.text('Start').first);
    await t.pumpAndSettle();

    expect(store.onboarded, true);
    expect(store.chats.length, 2);
    final names = store.chats.map((c) => c.persona.name).toSet();
    expect(names.contains('Mimi'), true);
    expect(names.contains('Ada'), true);
    // the greeting landed as the first message of its chat
    for (final c in store.chats) {
      expect(c.msgs, isNotEmpty);
    }
    // the engineer carries its preset: thinking and agent both on
    final ada = store.chats.firstWhere((c) => c.persona.name == 'Ada');
    expect(ada.persona.thinking, true);
    expect(ada.persona.agent, true);
    // and its examples rode along for the prompt
    expect(ada.persona.examples, isNotEmpty);
    // the catgirl does not: only the engineer leaves the defaults
    final mimi = store.chats.firstWhere((c) => c.persona.name == 'Mimi');
    expect(mimi.persona.thinking, isNull);
    expect(mimi.persona.agent, isNull);
  });

  testWidgets('the relay one-tap stores the public key and builds a chain', (t) async {
    final store = await _boot(t);
    final cfg = store.aiConfig;
    expect(cfg.keyOf('relay'), isEmpty);

    // brand -> permissions -> privacy -> model
    await t.tap(find.text('Next').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Next').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Agree and start'));
    await t.pumpAndSettle();

    // The sandbox blocks real sockets: the model fetch fails fast with its
    // warning, while the shared key and the auto-only fallback chain still
    // land, which is the offline behavior a real user on a dead network gets.
    await t.tap(find.text('Enable'));
    await t.pump(); // tap processed
    await t.pump(const Duration(seconds: 11)); // past the 10s list timeout
    await t.pumpAndSettle();
    expect(cfg.keyOf('relay'), 'public');
    // the chain keeps at least auto so the app stays usable offline
    expect(cfg.settings.chain.where((n) => n.providerId == 'relay'), isNotEmpty);
    expect(cfg.settings.chain.first.modelId, 'auto');
  });
}
