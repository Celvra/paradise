import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/human/human_models.dart';
import 'package:paradise/data/human/scheduler.dart';
import 'package:paradise/data/models.dart';

// deterministic dice for the urgent check tests
class _Dice extends HumanRandom {
  _Dice(this.p) : super(Random(0));
  final double p;
  @override
  bool chance(double p) => this.p < p;
}

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

  // quiet hours and urgent check-ins. the window is a wall clock one, so the
  // tests pin `now` to fixed moments instead of reading the clock
  final night = DateTime(2026, 1, 1, 23, 30).millisecondsSinceEpoch;
  final midday = DateTime(2026, 1, 1, 12, 0).millisecondsSinceEpoch;

  Persona sleepy({bool urgent = false, bool urgentCap = true, int urgentMax = 1}) => Persona(
        name: 'x',
        prompt: 'p',
        color: 0,
        clingy: true,
        clingySilentMin: 90,
        clingyQuietOn: true,
        clingyQuietStart: 22 * 60,
        clingyQuietEnd: 8 * 60,
        clingyUrgent: urgent,
        clingyUrgentCap: urgentCap,
        clingyUrgentMax: urgentMax,
      );

  test('quiet hours suppress the ordinary check-in', () {
    final sched = Scheduler();
    final s = state(lastUser: night - 3 * 86400000);
    expect(tick(sched, s, sleepy(), night), isEmpty);
    expect(sched.tasks, isEmpty);
  });

  test('an urgent check may pass quiet hours when the dice agree', () {
    final sched = Scheduler();
    final s = state(lastUser: night - 3 * 86400000);
    final out = sched.autoTasks(chatId: 'c1', s: s, cfg: quietCfg(), now: night, persona: sleepy(urgent: true), rng: _Dice(0.0));
    expect(out, hasLength(1));
    expect(out.single.urgent, isTrue);
    expect(out.single.tag, 'clingy:c1');
    expect(s.clingyUrgentCount, 1);
    expect(s.clingyUrgentStamp, night);
  });

  test('the dice saying no keeps the persona asleep', () {
    final sched = Scheduler();
    final s = state(lastUser: night - 3 * 86400000);
    expect(sched.autoTasks(chatId: 'c1', s: s, cfg: quietCfg(), now: night, persona: sleepy(urgent: true), rng: _Dice(0.99)), isEmpty);
  });

  test('the urgent cap is per quiet stretch', () {
    final sched = Scheduler();
    final s = state(lastUser: night - 3 * 86400000);
    // first urgent of the stretch goes out, budget of 1 is then spent
    sched.autoTasks(chatId: 'c1', s: s, cfg: quietCfg(), now: night, persona: sleepy(urgent: true), rng: _Dice(0.0));
    sched.tasks.single.status = TaskStatus.done;
    expect(sched.autoTasks(chatId: 'c1', s: s, cfg: quietCfg(), now: night + 60000, persona: sleepy(urgent: true), rng: _Dice(0.0)), isEmpty);
    // an uncapped persona keeps the right to speak up
    final sched2 = Scheduler();
    final s2 = state(lastUser: night - 3 * 86400000);
    sched2.autoTasks(chatId: 'c1', s: s2, cfg: quietCfg(), now: night, persona: sleepy(urgent: true, urgentCap: false), rng: _Dice(0.0));
    sched2.tasks.single.status = TaskStatus.done;
    expect(sched2.autoTasks(chatId: 'c1', s: s2, cfg: quietCfg(), now: night + 60000, persona: sleepy(urgent: true, urgentCap: false), rng: _Dice(0.0)), hasLength(1));
  });

  test('outside the window the ordinary check-in fires and the stale quota clears', () {
    final sched = Scheduler();
    final s = state(lastUser: midday - 3 * 86400000)
      ..clingyUrgentStamp = midday - 20 * 3600000
      ..clingyUrgentCount = 1;
    final out = tick(sched, s, sleepy(urgent: true), midday);
    expect(out, hasLength(1));
    expect(out.single.urgent, isFalse, reason: 'a daytime check-in is an ordinary one');
    expect(s.clingyUrgentCount, 0, reason: 'a stretch older than 12h is over, its quota resets');
  });

  test('a fresh stretch keeps an in-window quota across short night hops', () {
    final sched = Scheduler();
    final s = state(lastUser: night - 3 * 86400000);
    sched.autoTasks(chatId: 'c1', s: s, cfg: quietCfg(), now: night, persona: sleepy(urgent: true), rng: _Dice(0.0));
    sched.tasks.single.status = TaskStatus.done;
    // two hours later, still the same night, the cap of 1 still holds
    expect(sched.autoTasks(chatId: 'c1', s: s, cfg: quietCfg(), now: night + 2 * 3600000, persona: sleepy(urgent: true), rng: _Dice(0.0)), isEmpty);
  });

  test('a clingy urgent check is not deferred by the global quiet hours', () {
    final sched = Scheduler();
    final cfg = HumanSettings()
      ..greetMorning = false
      ..greetEvening = false
      ..icebreakDays = 1 << 30
      ..quietStart = 22 * 60
      ..quietEnd = 8 * 60
      ..allowUrgent = false;
    final s = state(lastUser: night - 3 * 86400000);
    final out = sched.autoTasks(chatId: 'c1', s: s, cfg: cfg, now: night, persona: sleepy(urgent: true), rng: _Dice(0.0));
    expect(out, hasLength(1));
    final g = sched.gate(out.single, s, cfg, night, HumanRandom(Random(1)));
    expect(g.verdict, Verdict.fire, reason: 'the persona level urgent opt in already passed its own quota and dice');
    // a non clingy urgent reminder still respects the global switch
    final reminder = sched.schedule(chatId: 'c1', delayMs: 0, prompt: 'r', type: ProactiveType.reminder, urgent: true, now: night);
    expect(sched.gate(reminder, s, cfg, night, HumanRandom(Random(1))).verdict, Verdict.defer);
  });

  test('quiet hour fields stay quiet on old cards and round trip', () {
    final old = Persona.fromJson({'name': 'a', 'prompt': 'b', 'color': 1});
    expect(old.clingyQuietOn, isFalse);
    expect(old.clingyQuietStart, 22 * 60);
    expect(old.clingyQuietEnd, 8 * 60);
    expect(old.clingyUrgent, isFalse);
    expect(old.clingyUrgentCap, isTrue);
    expect(old.clingyUrgentMax, 1);
    final back = Persona.fromJson(sleepy(urgent: true).toJson());
    expect(back.clingyQuietOn, isTrue);
    expect(back.clingyQuietStart, 22 * 60);
    expect(back.clingyUrgent, isTrue);
    expect(back.clingyUrgentCap, isTrue);
    expect(back.clingyUrgentMax, 1);
  });
}
