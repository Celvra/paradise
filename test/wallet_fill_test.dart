import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/ui/media_bubbles.dart';

/// Relative luminance per WCAG, to check the white ink on the fill.
double lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) => (math.max(lum(a), lum(b)) + 0.05) / (math.min(lum(a), lum(b)) + 0.05);

void main() {
  final telegramRed = const Color(0xFFC13025);
  final telegramBlue = const Color(0xFF1479BE);
  final settled = const Color(0xFFA5A8AC);
  final white = const Color(0xFFFFFFFF);

  test('without a wallpaper colour a pending card is still telegram blue or red', () {
    for (final p in [Pal.day, Pal.night]) {
      expect(walletFill(p, red: true, done: false).last, telegramRed);
      expect(walletFill(p, red: false, done: false).last, telegramBlue);
      expect(walletFill(p, red: true, done: true).first, settled);
      expect(walletFill(p, red: false, done: true).first, settled);
    }
  });

  test('a pending card takes the wallpaper colour, red packet or not', () {
    for (final seed in [const Color(0xFFE91E63), const Color(0xFF3F51B5), const Color(0xFF00C853), const Color(0xFFFFC107)]) {
      for (final stock in [Pal.day, Pal.night]) {
        for (final grad in BubbleGrad.values) {
          final p = stock.withAccent(seed, grad: grad);
          final where = '${stock.dark ? 'night' : 'day'} $grad';
          for (final red in [true, false]) {
            expect(walletFill(p, red: red, done: false), p.outGrad, reason: 'a pending card ignored the seed in $where');
            // the card follows the outgoing bubble, ink and all, so it has to
            // clear the same bar against the fill's worst stop
            final ink = walletInk(p).ink;
            for (final stop in p.outGrad) {
              expect(contrast(ink, stop), greaterThan(4.5), reason: 'ink on the card is too thin in $where');
            }
          }
          // settling is neutral whatever the theme is doing
          expect(walletFill(p, red: true, done: true).first, settled, reason: 'a settled card followed the seed in $where');
        }
      }
    }
  });

  test('the ink on the telegram fills stays white', () {
    // the day palette's ink is black, which would be wrong on telegram red
    for (final p in [Pal.day, Pal.night]) {
      expect(walletInk(p).ink, white);
      expect(contrast(white, walletFill(p, red: true, done: false).last), greaterThan(4.5));
      expect(contrast(white, walletFill(p, red: false, done: false).last), greaterThan(4.5));
    }
  });
}