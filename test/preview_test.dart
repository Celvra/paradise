import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/main.dart';
import 'package:paradise/ui/bubble.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Global rect of the nth preview bubble, in screen coordinates.
Rect rectOf(WidgetTester t, int nth) {
  final box = t.renderObject<RenderBox>(find.byType(BubbleView).at(nth));
  return box.localToGlobal(Offset.zero) & box.size;
}

void main() {
  testWidgets('preview bubbles render at every text size and the outgoing one stays right', (t) async {
    SharedPreferences.setMockInitialValues({});
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
    await settle(t, 700);
    await t.tap(find.text('Chat Appearance'));
    await settle(t, 700);

    expect(find.byType(BubbleView), findsNWidgets(2));

    for (final size in [12.0, 16.0, 22.0, 26.0, 30.0]) {
      store.setTextSize(size);
      await settle(t, 200);

      final incoming = rectOf(t, 0);
      final outgoing = rectOf(t, 1);

      // the outgoing bubble sits to the right of the incoming one
      expect(outgoing.left, greaterThan(incoming.left), reason: 'outgoing should be right of incoming at $size');
      // and the gap between the two bubbles is small, they are one column not two
      expect(outgoing.left - incoming.right, lessThan(120), reason: 'column should stay tight at $size');
    }
    for (final r in [0.0, 8.0, 17.0]) {
      store.setRadius(r);
      await settle(t, 200);
    }
    expect(t.takeException(), isNull);
  });
}