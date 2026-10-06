import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/human/human_models.dart';
import 'package:paradise/data/human/scheduler.dart';
import 'package:paradise/data/models.dart';

// the clingy switch: a persona that speaks up on its own after the user
// stays quiet. silence is measured from the newest message of either side,
// at most one check-in waits at a time and an optional cap counts
// consecutive proactive messages that any user message refreshes.
void main() {
  final t0 = DateTime.now().millisecondsSinceEpoch;

  Persona clingy({int silentMin = 90, bool cap = false, int max = 3}) => Persona(
        name: 'x',
        prompt: 'p',
        color: 0,
        clingy: true,
        clingySilentMin: silentMin,
        clingyCap: cap,
        clingyMax: max,
      );

  HumanState state({int lastUser = 0, int lastAi = 0, int consecutive = 0, Stage stage = Stage.close}) => HumanState()
    ..stage = stage
    ..energy = 90
    ..affection = 80
    ..lastUserAt = lastUser
    ..lastAiAt = lastAi
    ..consecutiveProactive = consecutive;

  // greetMorning/greetEvening/icebreakDays default to on and autoTasks keys
  // those windows off the wall clock and the last user message, so a cfg with
  // defaults leaks a greeting or ice-break task whenever the suite runs in
  // the greeting window or minutes past the ice-break horizon. the tests
  // below only care about the clingy switch, turn the others off
  HumanSettings quietCfg() => HumanSettings()
    ..greetMorning = false
    ..greetEvening = false
    ..icebreakDays = 1 << 30;

  List<ScheduledTask> tick(Scheduler sched, HumanState s, Persona p, int now) =>
      sched.autoTasks(chatId: 'c1', s: s, cfg: quietCfg(), now: now, persona: p);

  test('off by default, nothing is queued', () {
    final sched = Scheduler();
    final quiet = Persona(name: 'x', prompt: 'p', color: 0);
    final out = tick(sched, state(lastUser: t0 - 3 * 86400000, lastAi: t0 - 3 * 86400000), quiet, t0);
    expect(out, isEmpty);
    expect(sched.tasks, isEmpty);
  });

  test('a check-in waits for the full silence', () {
    final sched = Scheduler();
    final p = clingy(silentMin: 90);
    // 89 minutes of silence: too soon
    expect(tick(sched, state(lastUser: t0 - 89 * 60000), p, t0), isEmpty);
    // 91 minutes: due, exactly one
    final out = tick(sched, state(lastUser: t0 - 91 * 60000), p, t0);
    expect(out, hasLength(1));
    expect(out.single.type, ProactiveType.checkin);
    expect(out.single.condition, 'user_silent');
    expect(out.single.tag, 'clingy:c1');
  });

  test('the silence restarts at the assistants own last word', () {
    final sched = Scheduler();
    final p = clingy(silentMin: 90);
    // user silent 2 hours but the assistant replied 10 minutes ago
    final s = state(lastUser: t0 - 120 * 60000, lastAi: t0 - 10 * 60000);
    expect(tick(sched, s, p, t0), isEmpty);
  });

  test('fires even at the stranger stage, never before the first user word', () {
    final sched = Scheduler();
    final p = clingy();
    // a young chat still at the stranger stage still gets a check-in: the
    // user switched clingy on on purpose and the gate exempts the tag
    expect(
      tick(sched, state(lastUser: t0 - 3 * 86400000, stage: Stage.stranger), p, t0),
      hasLength(1),
    );
    final sched2 = Scheduler();
    expect(tick(sched2, state(), p, t0), isEmpty, reason: 'no user message yet, nothing to miss');
  });

  test('at most one open check-in per chat', () {
    final sched = Scheduler();
    final p = clingy();
    final s = state(lastUser: t0 - 3 * 86400000);
    expect(tick(sched, s, p, t0), hasLength(1));
    expect(tick(sched, s, p, t0), isEmpty, reason: 'one is already waiting');
    // a fired one frees the slot again
    sched.tasks.single.status = TaskStatus.done;
    expect(tick(sched, s, p, t0), hasLength(1));
  });

  test('the cap counts consecutive proactive messages', () {
    final sched = Scheduler();
    final p = clingy(cap: true, max: 2);
    expect(tick(sched, state(lastUser: t0 - 3 * 86400000, consecutive: 2), p, t0), isEmpty);
    expect(tick(sched, state(lastUser: t0 - 3 * 86400000, consecutive: 1), p, t0), hasLength(1));
  });

  test('a user message refreshes the count and the silence', () {
    final s = state(lastUser: t0 - 3 * 86400000, consecutive: 5);
    s.noteUser('hi', t0);
    expect(s.consecutiveProactive, 0);
    expect(s.silence(t0), 0);
  });

  test('gate and the post reply dice honour the persona cap override', () {
    final sched = Scheduler();
    final cfg = HumanSettings()
      // quiet hours are a wall clock window, off so the test runs at any hour
      ..quietStart = 0
      ..quietEnd = 0;
    final s = state(consecutive: 2);
    final task = sched.schedule(chatId: 'c1', delayMs: 0, prompt: 'r', type: ProactiveType.reminder, now: t0);
    // reminder is not optional, no dice: only the cap can stop it
    expect(sched.gate(task, s, cfg, t0, HumanRandom(Random(1))).verdict, Verdict.fire);
    expect(sched.gate(task, s, cfg, t0, HumanRandom(Random(1)), maxConsecutive: 2).verdict, Verdict.skip);
    expect(sched.gate(task, s, cfg, t0, HumanRandom(Random(1)), maxConsecutive: 5).verdict, Verdict.fire);
    // the dice path: two in a row already, cap of 2 says no more
    var rolled = 0;
    for (var i = 0; i < 40; i++) {
      final t = sched.rollProactive(chatId: 'c1', s: state(consecutive: 2), cfg: cfg, now: t0, rng: HumanRandom(Random(i)), userAnnoyed: false, maxConsecutive: 2);
      if (t != null) rolled++;
    }
    expect(rolled, 0);
  });

  test('persona json keeps old cards quiet and round trips the new fields', () {
    final old = Persona.fromJson({'name': 'a', 'prompt': 'b', 'color': 1});
    expect(old.clingy, isFalse);
    expect(old.clingySilentMin, 90);
    expect(old.clingyCap, isFalse);
    expect(old.clingyMax, 3);
    final p = clingy(silentMin: 30, cap: true, max: 5);
    final back = Persona.fromJson(p.toJson());
    expect(back.clingy, isTrue);
    expect(back.clingySilentMin, 30);
    expect(back.clingyCap, isTrue);
    expect(back.clingyMax, 5);
  });

  test('an answered check-in does not immediately queue the next one', () {
    final sched = Scheduler();
    final p = clingy(silentMin: 90);
    final s = state(lastUser: t0 - 3 * 86400000);
    final out = tick(sched, s, p, t0);
    expect(out, hasLength(1));
    // the assistant just sent it
    s.noteAi(t0, proactive: true);
    sched.tasks.single.status = TaskStatus.done;
    expect(tick(sched, s, p, t0), isEmpty, reason: 'the full interval starts over after its own word');
    expect(tick(sched, s, p, t0 + 91 * 60000), hasLength(1));
  });
}
