import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:paradise/core/theme.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/ui/trace_view.dart';

// Where the step row actually starts on screen. The header keeps its own rail
// indent, the body of an open step does not, and both are pinned by measured
// coordinates rather than by eye.

Future<void> settle(WidgetTester t, [int ms = 400]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// The left edge of a widget on screen, the thing the eye actually lines up.
double leftOf(WidgetTester t, Finder finder) {
  final box = t.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero).dx;
}

Widget wrap(Widget child) => ThemeScope(controller: themeCtl, child: Directionality(textDirection: TextDirection.ltr, child: MediaQuery(data: const MediaQueryData(), child: child)));

Msg think({String body = 'a long reason', String state = 'ok', int ms = 1200}) => Msg(
      id: 't1',
      out: false,
      text: '',
      time: 1,
      service: true,
      kind: MsgKind.trace,
      data: {'type': 'think', 'body': body, 't0': 0, 'state': state, 'ms': ms},
    );

void main() {
  testWidgets('the header keeps the rail indent it shipped with', (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);

    await t.pumpWidget(wrap(TraceView(msg: think(), titleKey: const Key('stepTitle'), panelKey: const Key('stepPanel'))));
    await settle(t);

    // 12 of row padding, 26 of rail column, 9 of gap
    expect(leftOf(t, find.byKey(const Key('stepTitle'))), 47.0);
    // and collapsed there is no body at all
    expect(find.byKey(const Key('stepPanel')), findsNothing);
  });

  testWidgets('an opened body starts at the row, not past the icon', (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);

    await t.pumpWidget(wrap(TraceView(msg: think(), titleKey: const Key('stepTitle'), panelKey: const Key('stepPanel'))));
    await settle(t);
    await t.tap(find.byKey(const Key('stepTitle')));
    await settle(t, 600);

    // the title is untouched at 47, the body comes back to the row's own 12 so
    // an open step uses the width the icon column was taking
    expect(leftOf(t, find.byKey(const Key('stepTitle'))), 47.0);
    expect(leftOf(t, find.byKey(const Key('stepPanel'))), 12.0);
  });

  testWidgets('a running step opens by itself and folds when it lands', (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);

    final running = think(state: 'run', ms: 0)..data['state'] = 'run';
    await t.pumpWidget(wrap(TraceView(msg: running, panelKey: const Key('stepPanel'))));
    await settle(t);
    // the preview shows without a tap, that is the whole point of the switch
    expect(find.byKey(const Key('stepPanel')), findsOneWidget);

    // the row is a different Msg when the step closes, like a fresh message
    await t.pumpWidget(wrap(TraceView(msg: think(), panelKey: const Key('stepPanel'))));
    await settle(t, 600);
    expect(find.byKey(const Key('stepPanel')), findsNothing);
  });
}
