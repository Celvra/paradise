import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/core/ui_kit.dart';

/// The pill is laid out in fractions of the row rather than measured off the
/// labels, so the only things that can go wrong are that it is not the full
/// height of the track and that it does not sit over the selected label. Both
/// are invisible in a screenshot but obvious on the device.

/// The pill is the only Positioned child, so it is the first DecoratedBox the
/// finder meets under the Stack.
Finder pill() => find.descendant(
      of: find.byType(Stack),
      matching: find.byType(DecoratedBox),
    );

void main() {
  Future<void> pump(WidgetTester t, int index) => t.pumpWidget(ThemeScope(
        controller: themeCtl,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SizedBox(width: 300, child: TgSegmented(labels: const ['a', 'b', 'c'], index: index, onChanged: (_) {}))),
        ),
      ));

  Rect pillRect(WidgetTester t) => t.renderObject<RenderBox>(pill()).localToGlobal(Offset.zero) & t.renderObject<RenderBox>(pill()).size;

/// The pill's box relative to the control's own box, so the assertions do not
/// care where the test happens to centre it.
Rect pillInTrack(WidgetTester t) {
  final track = t.renderObject<RenderBox>(find.byType(TgSegmented)).localToGlobal(Offset.zero);
  return pillRect(t).shift(-track);
}

  testWidgets('the pill fills the track height', (t) async {
    await pump(t, 0);
    await t.pump(const Duration(milliseconds: 300));

    final track = t.renderObject<RenderBox>(find.byType(TgSegmented)).size;
    final p = pillInTrack(t);
    // the container is 34 tall with 2 of padding, and the pill must not shrink
    // to the height of the labels inside it
    expect(track.height, 34);
    expect(p.height, closeTo(30, 0.01));
    expect(p.top, closeTo(2, 0.01));
  });

  testWidgets('the pill sits over the selected label', (t) async {
    await pump(t, 0);
    await t.pump(const Duration(milliseconds: 300));
    // the track is 300 wide with 2 of padding either side, so a third is
    // 296 / 3 and the first one starts at 2
    final first = pillInTrack(t);
    expect(first.left, closeTo(2, 0.01));
    expect(first.width, closeTo(98.67, 0.01));

    await pump(t, 2);
    await t.pump(const Duration(milliseconds: 300));
    final last = pillInTrack(t);
    expect(last.left, closeTo(199.33, 0.01));
    expect(last.width, closeTo(98.67, 0.01));
    // and it lands inside the track rather than off the end
    expect(last.right, lessThanOrEqualTo(298.01));
  });
}