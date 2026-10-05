import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/main.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/l10n/gen/l10n_zh.dart';

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

void main() {
  testWidgets('switching the language repaints the open screen at once', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    // the tests drive in-app screens, not the wizard
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t, 900);

    // start in english
    expect(texts(t), contains(AppLocalizationsEn().tabChats));

    // switch to chinese from the settings screen, the way a reader would
    await t.tap(find.text(AppLocalizationsEn().tabSettings).last);
    await settle(t, 900);
    await t.tap(find.text(AppLocalizationsEn().settingsLanguage));
    await settle(t, 800);
    await t.tap(find.text('简体中文'));
    await settle(t, 900);

    // the sheet closes and the screen underneath must already be chinese
    expect(store.localeTag, 'zh');
    final shown = texts(t);
    expect(shown, contains(AppLocalizationsZh().tabChats));
    expect(shown, isNot(contains(AppLocalizationsEn().tabChats)));
  });
}
