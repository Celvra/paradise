import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/ui/wallpaper.dart';

/// The sizes worth checking: the settings preview, a phone chat, and a box too
/// small to hold a doodle at all, since a clamp that inverts throws.
const _sizes = <Size>[
  Size(400, 172),
  Size(360, 640),
  Size(1080, 2400),
  Size(31, 172),
  Size(400, 9),
  Size(8, 8),
  Size(0, 0),
];

void main() {
  test('every doodle stays inside the box the wallpaper is painted into', () {
    // This is what the pattern got wrong: the jitter is measured from the cell
    // origin, so the last row and column hung past the edge and the frame cut
    // them in half. On a chat that runs off screen, but the settings preview is a
    // short frame and it read as the pattern spilling out of the box.
    for (final size in _sizes) {
      final doodles = WallPainter.pattern(size);
      for (final d in doodles) {
        final where = '$size at ${d.at}';
        expect(d.at.dx - d.s, greaterThanOrEqualTo(0), reason: 'crossed the left edge of $where');
        expect(d.at.dy - d.s, greaterThanOrEqualTo(0), reason: 'crossed the top edge of $where');
        expect(d.at.dx + d.s, lessThanOrEqualTo(size.width), reason: 'crossed the right edge of $where');
        expect(d.at.dy + d.s, lessThanOrEqualTo(size.height), reason: 'crossed the bottom edge of $where');
      }
    }
  });

  test('the pattern is laid out afresh per box and never a pile in one corner', () {
    // The clamping moves doodles rather than dropping them, so the tiling has to
    // stay even. A corner pile is what skipping the edge doodles would leave.
    const size = Size(400, 172);
    final left = WallPainter.pattern(size);
    final right = WallPainter.pattern(size);
    // a fixed seed, so a chat and its preview are the same wallpaper rather than
    // two unrelated ones
    expect(left.length, right.length);
    for (var i = 0; i < left.length; i++) {
      expect(left[i].at, right[i].at, reason: 'doodle $i moved between two calls');
      expect(left[i].s, right[i].s);
      expect(left[i].kind, right[i].kind);
    }

    // one cell of 64 across the width, and they must not all land on the last one
    expect(left.length, greaterThanOrEqualTo(20));
    final columns = left.map((d) => (d.at.dx / 64).floor()).toSet();
    expect(columns.length, greaterThanOrEqualTo(6), reason: 'the tiles collapsed into too few columns');

    // every cell of the grid contributes, so the fix cannot be a blank margin
    final rows = left.map((d) => (d.at.dy / 64).floor()).toSet();
    expect(rows, {0, 1, 2});
  });

  testWidgets('the preview frame paints the wallpaper at its own size', (t) async {
    // The preview is a short box in the settings page, and the wallpaper has to
    // be laid out for that box rather than for the chat it is standing in for.
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 400,
          height: 172,
          child: ChatWallpaper(path: '', blur: false, colors: Pal.day.wall, accent: Pal.day.accent, phase: 0),
        ),
      ),
    ));

    final painted = t.renderObject<RenderBox>(find.byType(CustomPaint));
    expect(painted.size, const Size(400, 172));
    expect(WallPainter.pattern(painted.size).length, greaterThan(0));
  });
}