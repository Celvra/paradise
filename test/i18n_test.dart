import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/l10n/gen/l10n_zh.dart';
import 'package:paradise/main.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

List<String> texts(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((e) => e.data)
    .whereType<String>()
    .where((e) => e.trim().isNotEmpty)
    .toList();

/// The point of the exercise: a reader who picks Chinese must actually get
/// Chinese on screen, not the english fallback.
void main() {
  for (final tag in ['zh', 'zh_Hant']) {
    testWidgets('picking $tag paints translated UI, not english', (t) async {
      SharedPreferences.setMockInitialValues({'locale': tag});
      t.view.physicalSize = const Size(1080, 2200);
      t.view.devicePixelRatio = 2.75;
      final store = await Store.load();
      final ai = await AiConfig.load();
      store.attachAi(ai);
      store.createChat('Coder', 'be brief');
      // the tests drive in-app screens, not the wizard
      store.onboarded = true;
      await t.pumpWidget(TgApp(store: store, ai: ai));
      await settle(t, 900);

      final shown = texts(t);
      final l = tag == 'zh' ? AppLocalizationsZh() : AppLocalizationsZhHant();
      // the tab bar and the settings header both come from the arb
      expect(shown, contains(l.tabChats));
      expect(shown, contains(l.tabSettings));
      expect(shown, contains(l.tabProfile));

      // and none of the english source strings leaked through
      for (final en in ['Chats', 'Settings', 'Profile', 'Search', 'Online']) {
        expect(shown, isNot(contains(en)), reason: '$en leaked into $tag');
      }
    });
  }

  testWidgets('the settings language sheet lists the shipped languages', (t) async {
    SharedPreferences.setMockInitialValues({'locale': 'zh'});
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    // the tests drive in-app screens, not the wizard
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t, 700);
    // the settings tab lives at the bottom bar, the last 设置 is the tab itself
    await t.tap(find.text('设置').last);
    await settle(t, 900);
    await t.tap(find.text('语言'));
    await settle(t, 800);
    final shown = texts(t);
    // a language always names itself, so these three stay as they are
    expect(shown, contains('English'));
    expect(shown, contains('简体中文'));
    expect(shown, contains('繁體中文'));
    // japanese was dropped, it must not be offered any more
    expect(shown, isNot(contains('日本語')));
  });
}
