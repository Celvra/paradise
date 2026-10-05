import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/ui/canvas_cards.dart';

void main() {
  group('parseCardAlign', () {
    test('reads the three tool values', () {
      expect(parseCardAlign('left'), CardAlign.left);
      expect(parseCardAlign('center'), CardAlign.center);
      expect(parseCardAlign('right'), CardAlign.right);
    });
    test('missing, empty or unknown values fall back to center', () {
      expect(parseCardAlign(null), CardAlign.center);
      expect(parseCardAlign(''), CardAlign.center);
      expect(parseCardAlign('middle'), CardAlign.center);
      expect(parseCardAlign(' LEFT '), CardAlign.left);
    });
  });

  group('withSourceLine', () {
    const src = '#set page()\n#cetz.canvas({\n  stroke: olor\n})';
    test('quotes the offending line for a line:col error', () {
      final out = withSourceLine('3:10 unknown variable: olor', src);
      expect(out, '3:10 unknown variable: olor | line 3: stroke: olor');
    });
    test('leaves errors without a leading line:column untouched', () {
      const e = 'document has no pages';
      expect(withSourceLine(e, src), e);
    });
    test('leaves an out-of-range line untouched', () {
      const e = '99:1 boom';
      expect(withSourceLine(e, src), e);
    });
  });

  group('wrapCetz', () {
    test('bare drawing body gets canvas, import and theme lines', () {
      final out = wrapCetz('circle((0,0), radius: 1)', dark: false);
      expect(out, contains('#cetz.canvas(length: 1cm, {'));
      expect(out, contains('import cetz.draw: *'));
      expect(out, contains('#import "packages/cetz/0.5.2/src/lib.typ" as cetz'));
      expect(out, contains('rgb("#1b1b1b")'));
    });

    test('dark theme recolours page text', () {
      expect(wrapCetz('circle((0,0))', dark: true), contains('rgb("#e8eaed")'));
    });

    test('a full snippet is used as-is, import still bound', () {
      final out = wrapCetz('#cetz.canvas(length: 2cm, { circle((0,0)) })', dark: true);
      expect(out.contains('#cetz.canvas(length: 1cm'), isFalse);
      expect(out, contains('#import "packages/cetz/0.5.2/src/lib.typ" as cetz'));
    });

    test('preview imports are localized to the bundled paths', () {
      final out = wrapCetz('#import "@preview/cetz-plot:0.1.4": *\nplot.plot(data: ([],))', dark: false);
      expect(out.contains('@preview'), isFalse);
      expect(out, contains('packages/cetz-plot/0.1.4/src/lib.typ'));
    });
  });
}
