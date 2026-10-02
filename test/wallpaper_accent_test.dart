import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/theme.dart';

/// Relative luminance per WCAG, used only to measure the pairs below.
double lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final x = lum(a), y = lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Angular distance between two hues in degrees, the short way round.
double hueGap(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

/// Largest single channel difference, 0 to 255.
///
/// Used instead of comparing saturation, which is useless near white and near
/// black: at a lightness of 0.99 one channel of rounding moves the read back
/// saturation from 0.03 to something close to 1.
int channelGap(Color a, Color b) {
  var worst = 0;
  for (final pair in [
    [a.r, b.r],
    [a.g, b.g],
    [a.b, b.b],
  ]) {
    final d = ((pair[0] - pair[1]) * 255).abs().round();
    if (d > worst) worst = d;
  }
  return worst;
}

void main() {
  // every hue at a couple of saturations, including the awkward ones: pure
  // yellow and cyan are the brightest a colour gets and the easiest to make
  // unreadable text on
  final seeds = <Color>[
    for (var h = 0; h < 360; h += 15)
      for (final s in [0.25, 0.55, 0.95]) HSLColor.fromAHSL(1, h.toDouble(), s, 0.5).toColor(),
    const Color(0xFFFFFFFF),
    const Color(0xFF000000),
    const Color(0xFF808080),
  ];

  test('the outgoing bubble keeps its text readable in day mode', () {
    for (final seed in seeds) {
      for (final grad in BubbleGrad.values) {
        final p = Pal.day.withAccent(seed, grad: grad);
        // day bubbles carry black text
        for (final stop in p.outGrad) {
          final c = contrast(p.textOut, stop);
          expect(c, greaterThan(4.5),
              reason: 'seed ${seed.toARGB32().toRadixString(16)} $grad gave stop '
                  '${stop.toARGB32().toRadixString(16)} at contrast $c');
        }
      }
    }
  });

  test('the outgoing bubble keeps its text readable in night mode', () {
    for (final seed in seeds) {
      for (final grad in BubbleGrad.values) {
        final p = Pal.night.withAccent(seed, grad: grad);
        // night bubbles carry white text
        for (final stop in p.outGrad) {
          final c = contrast(p.textOut, stop);
          expect(c, greaterThan(4.5),
              reason: 'seed ${seed.toARGB32().toRadixString(16)} $grad gave stop '
                  '${stop.toARGB32().toRadixString(16)} at contrast $c');
        }
      }
    }
  });

  test('the bubble ink stays readable on the darkest stop', () {
    // The clock, the sent ticks, the quote rule and the sender name all sit on
    // the bubble rather than beside it, so they get the bottom stop as their
    // worst surface. Day solves the ink against it; a level that did not would
    // sink the timestamp into the bottom of the gradient.
    for (final seed in seeds) {
      for (final grad in BubbleGrad.values) {
        final day = Pal.day.withAccent(seed, grad: grad);
        for (final stop in day.outGrad) {
          for (final ink in [day.timeOut, day.checkOut, day.lineOut, day.nameOut]) {
            final c = contrast(ink, stop);
            expect(c, greaterThan(4.5),
                reason: 'day seed ${seed.toARGB32().toRadixString(16)} $grad put '
                    '${ink.toARGB32().toRadixString(16)} on '
                    '${stop.toARGB32().toRadixString(16)} at contrast $c');
          }
        }
        final night = Pal.night.withAccent(seed, grad: grad);
        for (final stop in night.outGrad) {
          for (final ink in [night.timeOut, night.checkOut, night.lineOut, night.nameOut]) {
            expect(contrast(ink, stop), greaterThan(4.5),
                reason: 'night seed ${seed.toARGB32().toRadixString(16)} $grad');
          }
        }
      }
    }
  });

  test('each level is a wider gradient than the one below it', () {
    final seed = const Color(0xFFE91E63);
    // the stops have to actually separate, otherwise the picker is offering
    // three identical bubbles
    double span(Pal p) => lum(p.outGrad.first) - lum(p.outGrad.last);
    for (final stock in [Pal.day, Pal.night]) {
      final byLevel = {for (final g in BubbleGrad.values) g: span(stock.withAccent(seed, grad: g))};
      for (final g in BubbleGrad.values) {
        expect(byLevel[g]!, greaterThan(0),
            reason: '$g produced a flat bubble in ${stock.dark ? 'night' : 'day'}');
        if (g != BubbleGrad.values.first) {
          expect(byLevel[g]!, greaterThan(byLevel[BubbleGrad.values[g.index - 1]]!),
              reason: '$g is not wider than the level below it');
        }
      }
    }
  });

  test('the accent reads against the bar it sits on', () {
    for (final seed in seeds) {
      expect(contrast(Pal.day.withAccent(seed).accent, Pal.day.bar), greaterThan(2.0));
      expect(contrast(Pal.night.withAccent(seed).accent, Pal.night.bar), greaterThan(2.0));
    }
  });

  test('the tinted slots hold the luminance they shipped with', () {
    // This is the invariant the whole scheme rests on. WCAG contrast is a
    // function of the two luminances, so a slot that keeps its luminance keeps
    // every contrast ratio it was hand tuned for, and no pairing can drift into
    // illegibility. A retuned role would show up here as a drift well past 0.01.
    const slots = [0, 1, 2, 3, 4, 5, 6, 11, 12, 13, 14, 16, 17, 18, 21, 28, 31, 33, 35, 36, 37, 39, 40, 41, 42, 43, 44, 45, 48, 49];
    for (final stock in [Pal.day, Pal.night]) {
      for (final seed in seeds) {
        final p = stock.withAccent(seed);
        for (final i in slots) {
          final drift = (lum(p.c[i]) - lum(stock.c[i])).abs();
          expect(drift, lessThan(0.01),
              reason: 'slot $i in ${stock.dark ? 'night' : 'day'} for seed '
                  '${seed.toARGB32().toRadixString(16)} drifted by $drift');
        }
      }
    }
  });

  test('the accent family lands on the seed hue', () {
    // Only the mid tone, high chroma roles are checked this way, and only against
    // the seed hue rather than each other. Hue recovery through 8 bit quantisation
    // is not a property of the palette: a slot as dark as the night wallpaper
    // has single digit channels, where half a step of rounding swings the hue by
    // fifteen degrees, and the faint structural roles are worse still. Those are
    // covered by the luminance bound and the channel gap instead.
    const family = [18, 31, 33, 40];
    for (final seed in seeds) {
      final hue = HSLColor.fromColor(seed).hue;
      for (final stock in [Pal.day, Pal.night]) {
        final p = stock.withAccent(seed);
        for (final i in family) {
          final gap = hueGap(HSLColor.fromColor(p.c[i]).hue, hue);
          expect(gap, lessThan(2.5),
              reason: 'slot $i in ${stock.dark ? 'night' : 'day'} sits $gap degrees '
                  'off the seed for ${seed.toARGB32().toRadixString(16)}');
        }
      }
    }
  });

  test('no slot carrying a real share of the seed was left untouched', () {
    const slots = [11, 16, 18, 31, 33, 35, 36, 39, 40, 42, 43, 44, 45];
    for (final seed in seeds) {
      for (final stock in [Pal.day, Pal.night]) {
        final p = stock.withAccent(seed);
        for (final i in slots) {
          expect(p.c[i], isNot(stock.c[i]),
              reason: 'slot $i in ${stock.dark ? 'night' : 'day'} did not move for '
                  '${seed.toARGB32().toRadixString(16)}');
        }
      }
    }
  });

  test('the faint tints stay faint', () {
    // A trace of the hue on the structural roles, which is what makes a tinted
    // surface rather than a coloured one. The measured worst case is 23 of 255,
    // and much past that stops being a tint and starts being a colour.
    const faint = [0, 1, 2, 3, 5, 12, 21, 37, 41, 48];
    for (final seed in seeds) {
      for (final stock in [Pal.day, Pal.night]) {
        final p = stock.withAccent(seed);
        for (final i in faint) {
          expect(channelGap(p.c[i], stock.c[i]), lessThan(26),
              reason: 'slot $i in ${stock.dark ? 'night' : 'day'} swung too far for '
                  '${seed.toARGB32().toRadixString(16)}');
        }
      }
    }
  });

  test('body copy and the semantic reds stay exactly as shipped', () {
    // text has to read as text, and a delete button that turned yellow is a
    // delete button nobody taps
    const untouched = [7, 15, 19, 20, 26, 27, 38, 46, 47];
    for (final stock in [Pal.day, Pal.night]) {
      final p = stock.withAccent(const Color(0xFFE91E63));
      for (final i in untouched) {
        expect(p.c[i], stock.c[i], reason: 'slot $i moved in ${stock.dark ? 'night' : 'day'}');
      }
    }
  });

  test('the alpha of a tinted slot survives', () {
    // the translucent surfaces are translucent because something behind them
    // shows through; solving them opaque would turn every sheet into a slab
    for (final seed in seeds) {
      for (final stock in [Pal.day, Pal.night]) {
        final p = stock.withAccent(seed);
        for (final i in [4, 15, 35, 36, 37, 38, 39, 46, 47]) {
          expect(p.c[i].a, closeTo(stock.c[i].a, 0.001),
              reason: 'slot $i in ${stock.dark ? 'night' : 'day'} changed opacity');
        }
      }
    }
  });

  test('no ink lost contrast against the surface it sits on', () {
    // Measured against what each pair shipped at rather than against a fixed bar.
    // The quote rule on a day bubble already went out at 2.85:1, so demanding 3
    // would be inventing a requirement the stock palette never met. Holding the
    // luminance is what makes this hold, so it is the thing worth asserting.
    const onBar = [3, 4, 8, 12, 13, 14, 49];
    const onPage = [3, 4, 8, 12, 13, 14, 49];
    const onBubble = [26, 31, 33];
    for (final seed in seeds) {
      for (final stock in [Pal.day, Pal.night]) {
        final p = stock.withAccent(seed);
        final where = stock.dark ? 'night' : 'day';
        void pair(int ink, int surface) {
          final before = contrast(stock.c[ink], stock.c[surface]);
          final after = contrast(p.c[ink], p.c[surface]);
          expect(after, greaterThan(before * 0.97),
              reason: 'slot $ink on slot $surface in $where fell from $before to '
                  '$after for ${seed.toARGB32().toRadixString(16)}');
        }
        for (final i in onBar) {
          pair(i, 2);
        }
        for (final i in onPage) {
          pair(i, 0);
        }
        for (final i in onBubble) {
          pair(i, 21);
        }
      }
    }
  });

  test('the roles that carry text clear 3:1 on the bar', () {
    // a real floor for the roles that are actually body copy, unlike the quote
    // rule above which is a one pixel line and never claimed it
    const onBar = [3, 4, 12, 13, 14, 49];
    for (final seed in seeds) {
      for (final stock in [Pal.day, Pal.night]) {
        final p = stock.withAccent(seed);
        for (final i in onBar) {
          expect(contrast(p.c[i], p.bar), greaterThan(3.0),
              reason: 'slot $i in ${stock.dark ? 'night' : 'day'} for seed '
                  '${seed.toARGB32().toRadixString(16)}');
        }
      }
    }
  });

  test('the bubble gradient runs light to dark', () {
    // BubblePainter feeds these to a top-to-bottom gradient, so a reversed list
    // would show up as a bubble lit from below
    for (final stock in [Pal.day, Pal.night]) {
      for (final grad in BubbleGrad.values) {
        final stops = stock.withAccent(const Color(0xFF3F51B5), grad: grad).outGrad;
        for (var i = 1; i < stops.length; i++) {
          expect(lum(stops[i - 1]), greaterThan(lum(stops[i])),
              reason: 'stop $i is not darker than the one above it');
        }
      }
    }
  });

  test('the persona covers follow the accent hue', () {
    // The covers used to be seven fixed hue pairs, the one surface in the app
    // that ignored the wallpaper. They are derived now, so they have to land on
    // the accent's hue rather than merely near it.
    for (final seed in seeds) {
      for (final stock in [Pal.day, Pal.night]) {
        final p = stock.withAccent(seed);
        final hue = HSLColor.fromColor(p.accent).hue;
        for (var i = 0; i < avatarColorCount; i++) {
          for (final stop in p.avatar(i)) {
            expect(hueGap(HSLColor.fromColor(stop).hue, hue), lessThan(3.0),
                reason: 'cover $i in ${stock.dark ? 'night' : 'day'} for seed '
                    '${seed.toARGB32().toRadixString(16)}');
          }
        }
      }
    }
  });

  test('the seven persona covers stay distinct from each other', () {
    // This is why the covers are a lightness ladder and not seven copies of the
    // accent. If the rungs collapsed, the colour picker would show seven
    // identical swatches and a persona could no longer be told apart.
    for (final seed in seeds) {
      for (final stock in [Pal.day, Pal.night]) {
        final p = stock.withAccent(seed);
        final tops = [for (var i = 0; i < avatarColorCount; i++) p.avatar(i).first];
        for (var i = 0; i < tops.length; i++) {
          for (var j = i + 1; j < tops.length; j++) {
            expect(channelGap(tops[i], tops[j]), greaterThanOrEqualTo(6),
                reason: 'covers $i and $j collapsed in ${stock.dark ? 'night' : 'day'} '
                    'for ${seed.toARGB32().toRadixString(16)}');
          }
        }
      }
    }
  });

  test('white on a persona cover reads no worse than the fixed gradients did', () {
    // The white name sits directly on the cover. The seven fixed gradients this
    // replaced bottomed out at 1.68:1 on a yellow, so that is the bar rather than
    // a figure invented here.
    for (final seed in seeds) {
      for (final stock in [Pal.day, Pal.night]) {
        final p = stock.withAccent(seed);
        for (var i = 0; i < avatarColorCount; i++) {
          for (final stop in p.avatar(i)) {
            expect(contrast(const Color(0xFFFFFFFF), stop), greaterThan(1.68),
                reason: 'cover $i in ${stock.dark ? 'night' : 'day'} for seed '
                    '${seed.toARGB32().toRadixString(16)}');
          }
        }
      }
    }
  });

  test('an unsaturated seed still yields a distinct accent', () {
    // a grey seed would otherwise come out as the stock blue and look broken
    final p = Pal.day.withAccent(const Color(0xFF7A7A7A));
    expect(p.accent, isNot(Pal.day.accent));
    expect(contrast(p.textOut, p.outGrad.first), greaterThan(4.5));
  });
}
