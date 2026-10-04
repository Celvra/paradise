import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/segmenter.dart';

// the pacing knobs decide how long the reader waits, a regression here is
// felt on every message so the boundaries are pinned down
// the segmenter dice decide the shape of a reply, both fixed shapes and
// vanished text are failures worth catching
void main() {
  group('humanDelay scale', () {
    test('scale one keeps the old behaviour and cap', () {
      final r = Random(7);
      for (var i = 0; i < 200; i++) {
        final d = humanDelay('a' * 200, random: r);
        expect(d, inInclusiveRange(180, 1500));
      }
    });

    test('scale multiplies the pause and the cap', () {
      // two independent generators on the same seed replay the same jitter
      // sequence so only the multiplier differs between the sums
      final r1 = Random(7);
      final r2 = Random(7);
      var plain = 0;
      var scaled = 0;
      for (var i = 0; i < 200; i++) {
        plain += humanDelay('hello world', random: r1);
        scaled += humanDelay('hello world', random: r2, scale: 2);
      }
      expect(scaled, closeTo(plain * 2, plain * 0.01));
    });

    test('scale zero clamps to a proportional floor not to the old one', () {
      final r = Random(7);
      for (var i = 0; i < 50; i++) {
        expect(humanDelay('hello', random: r, scale: 0), inInclusiveRange(18, 150));
      }
    });

    test('jitterMs keeps a nonzero base nonzero and zero at zero', () {
      final r = Random(7);
      for (var i = 0; i < 100; i++) {
        expect(jitterMs(1000, r), inInclusiveRange(650, 1350));
      }
      expect(jitterMs(0, r), 0);
      // the jitter knob shrinks and widens the span around the base
      for (var i = 0; i < 100; i++) {
        expect(jitterMs(1000, r, 0), 1000);
        expect(jitterMs(1000, r, 0.6), inInclusiveRange(400, 1600));
      }
    });

    test('typingMs scales with cjk full width and latin half width', () {
      final r = Random(7);
      // eight cjk chars is one second of keyboard work at the base pace
      expect(typingMs('一二三四五六七八', random: r, spread: 0), 1000);
      // a latin letter counts half, so sixteen of them cost the same
      expect(typingMs('abcdefghijklmnop', random: r, spread: 0), 1000);
      // the floor keeps a two char bubble from flashing by
      expect(typingMs('好', random: r, spread: 0), 500);
      // the cap keeps an enormous bubble from stalling the timeline
      expect(typingMs('字' * 500, random: r, spread: 0), 12000);
      expect(typingMs('', random: r), 0);
    });
  });

  group('segmenter shape dice', () {
    // one long run with no newlines forces the safety net to cut, the widths
    // must drift between segmenters instead of always landing the same
    test('the safety net cap drifts between replies', () {
      final run = '这是一段没有换行的长文本' * 30;
      final widths = <int>[];
      for (var i = 0; i < 30; i++) {
        final seg = Segmenter(strip: false, random: Random(i));
        final out = seg.push(run);
        if (out.isNotEmpty) widths.add(out.first.length);
      }
      expect(widths.toSet().length, greaterThan(1));
      for (final w in widths) {
        expect(w, inInclusiveRange(80, 170));
      }
    });

    test('two segmenters on the same seed produce the same shape', () {
      final run = '这是一段没有换行的长文本' * 30;
      final a = Segmenter(strip: false, random: Random(42)).push(run);
      final b = Segmenter(strip: false, random: Random(42)).push(run);
      expect(a, b);
    });

    test('merge dice occasionally fuse a short segment into the next', () {
      final merged = <int>[];
      final unmerged = <int>[];
      for (var i = 0; i < 40; i++) {
        final seg = Segmenter(strip: false, random: Random(100 + i));
        final out = seg.push('好。\n是的没错这一条足够长可以独立成为一条消息。\n');
        seg.flush();
        // the seeded dice either hold the short first line back or let it
        // through, both shapes must appear across the run
        (out.length == 1 ? merged : unmerged).add(out.length);
      }
      expect(merged, isNotEmpty);
      expect(unmerged, isNotEmpty);
    });
  });
}
