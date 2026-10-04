import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/human/human_models.dart';
import 'package:paradise/data/human/scheduler.dart';

// the post reply dice is what keeps the assistant from going cold between
// turns, the guard rails around it are the point of these tests
void main() {
  final now = DateTime.now().millisecondsSinceEpoch;

  ScheduledTask? roll(HumanState s, HumanSettings cfg, {bool annoyed = false, required int seed}) {
    final sched = Scheduler();
    return sched.rollProactive(chatId: 'c1', s: s, cfg: cfg, now: now, rng: HumanRandom(Random(seed)), userAnnoyed: annoyed);
  }

  HumanState chat({Stage stage = Stage.close, int consecutive = 0}) => HumanState()
    ..stage = stage
    ..energy = 90
    ..affection = 80
    ..lastUserAt = now
    ..lastAiAt = now
    ..consecutiveProactive = consecutive;

  test('a close high energy chat rolls often', () {
    final cfg = HumanSettings();
    var queued = 0;
    for (var i = 0; i < 50; i++) {
      if (roll(chat(), cfg, seed: i) != null) queued++;
    }
    expect(queued, greaterThan(5), reason: 'a close chat should feel alive, queued $queued/50');
  });

  test('a stranger never writes first', () {
    final cfg = HumanSettings();
    for (var i = 0; i < 50; i++) {
      expect(roll(chat(stage: Stage.stranger), cfg, seed: i), isNull);
    }
  });

  test('an annoyed user is never bothered again', () {
    final cfg = HumanSettings();
    for (var i = 0; i < 30; i++) {
      expect(roll(chat(), cfg, annoyed: true, seed: i), isNull);
    }
  });

  test('the max in a row cap holds without a user turn', () {
    final cfg = HumanSettings();
    for (var i = 0; i < 30; i++) {
      expect(roll(chat(consecutive: 3), cfg, seed: i), isNull);
    }
  });

  test('a queued task waits minutes not days and stays silent until then', () {
    final cfg = HumanSettings();
    final seen = <ScheduledTask>[];
    for (var i = 0; i < 100; i++) {
      final t = roll(chat(), cfg, seed: i);
      if (t != null) seen.add(t);
    }
    expect(seen, isNotEmpty);
    for (final t in seen) {
      final wait = t.fireAt - now;
      expect(wait, inInclusiveRange(3 * 60000, 113 * 60000), reason: '${t.id} waits ${wait ~/ 60000}min');
      expect(t.condition, 'user_silent', reason: 'a real user turn must cancel the plan');
    }
  });
}
