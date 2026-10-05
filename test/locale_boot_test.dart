import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/main.dart';
import 'package:paradise/l10n/x.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester t, [int ms = 400]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Booting the real app in each shipped language must not throw while it paints
/// a date or a number, which is where intl would blow up on a missing locale.
void main() {
  for (final tag in [null, 'en', 'zh', 'zh_Hant']) {
    testWidgets('app boots and formats dates under $tag', (t) async {
      SharedPreferences.setMockInitialValues(tag == null ? {} : {'locale': tag});
      t.view.physicalSize = const Size(1080, 2200);
      t.view.devicePixelRatio = 2.75;
      final store = await Store.load();
      final ai = await AiConfig.load();
      store.attachAi(ai);
      // the tests drive in-app screens, not the wizard
      store.onboarded = true;
      await t.pumpWidget(TgApp(store: store, ai: ai));
      await settle(t, 800);
      // the separator and the settings counters both go through intl
      expect(store.localeTag, tag);
      expect(() => L10n.date('E').format(DateTime(2026, 1, 4)), returnsNormally);
      expect(() => L10n.number('#,##0').format(1234), returnsNormally);
      // ignore: avoid_print
      print('$tag -> intl:${L10n.localeTag} E=${L10n.date('E').format(DateTime(2026, 1, 4))} n=${L10n.number('#,##0').format(1234)}');
      // Traditional has to reach intl as a tag that actually carries the
      // traditional symbols. Asking for zh_Hant does not throw, it quietly
      // falls back to zh and hands back the simplified shaped 周日.
      if (tag == 'zh_Hant') expect(L10n.date('E').format(DateTime(2026, 1, 4)), '週日');
      if (tag == 'zh') expect(L10n.date('E').format(DateTime(2026, 1, 4)), '周日');
    });
  }
}
