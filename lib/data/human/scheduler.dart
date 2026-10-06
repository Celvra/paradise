import 'dart:math';

import '../models.dart';
import 'human_models.dart';

// The queue behind schedule_message. The assistant decides when it wants to
// speak and why; this file only holds the queue and decides whether a due task
// may really fire right now. The words always come from the model.

enum ProactiveType { greeting, checkin, reminder, share, apology, followup, icebreak, afterSchedule, custom }

ProactiveType proactiveTypeOf(String? raw) {
  switch (raw) {
    case 'check_in':
    case 'checkin':
      return ProactiveType.checkin;
    case 'after_schedule':
    case 'afterSchedule':
      return ProactiveType.afterSchedule;
    case 'continue':
    case 'followup':
      return ProactiveType.followup;
    case 'break_ice':
    case 'icebreak':
      return ProactiveType.icebreak;
  }
  return ProactiveType.values.firstWhere((e) => e.name == raw, orElse: () => ProactiveType.custom);
}

String proactiveWire(ProactiveType t) => switch (t) {
      ProactiveType.checkin => 'check_in',
      ProactiveType.afterSchedule => 'after_schedule',
      ProactiveType.followup => 'continue',
      ProactiveType.icebreak => 'break_ice',
      _ => t.name,
    };

/// The template that tells the model what kind of message this is. It never
/// contains the message itself.
String templateFor(ProactiveType t) => switch (t) {
      ProactiveType.greeting => 'Type greeting. It is a fixed greeting time (morning or evening). Say hello the way you normally would, mention something real from the context if you have it, keep it light.',
      ProactiveType.checkin => 'Type check-in. The user has not replied for a while. Ask where they went or how they are, in your own tone. Do not nag if you already asked recently.',
      ProactiveType.reminder => 'Type reminder. A todo or promise you wrote down has come due. Remind the user naturally, and call complete_todo when it is settled.',
      ProactiveType.share => 'Type share. You thought of something worth sharing. Share it briefly and ask what they think, do not lecture.',
      ProactiveType.apology => 'Type apology. You said something wrong or hurtful last time. Apologise sincerely, keep it short, no grovelling.',
      ProactiveType.followup => 'Type follow-up. The last topic was left unfinished. Pick it up where it stopped, without recapping everything.',
      ProactiveType.icebreak => 'Type ice-breaker. It has been a long time since you two talked. Open a conversation gently, do not act as if no time has passed.',
      ProactiveType.afterSchedule => 'Type after-schedule. You just finished what you were busy with. Say so in one short line and return to the chat.',
      ProactiveType.custom => 'Type custom. Follow the instruction you left for yourself.',
    };

enum TaskStatus { pending, suspended, firing, done, skipped, cancelled, failed }

class ScheduledTask {
  ScheduledTask({
    required this.id,
    required this.chatId,
    required this.fireAt,
    required this.prompt,
    required this.createdAt,
    this.condition = 'always',
    this.type = ProactiveType.custom,
    this.status = TaskStatus.pending,
    this.failures = 0,
    this.urgent = false,
    this.note = '',
    this.firedAt = 0,
    this.tag = '',
  });

  final String id;
  final String chatId;
  int fireAt;
  String prompt;
  final int createdAt;
  String condition;
  ProactiveType type;
  TaskStatus status;
  int failures;
  bool urgent;

  /// why it was skipped, deferred or failed
  String note;
  int firedAt;

  /// Deduplication bucket, empty for tasks that never need one. The clingy
  /// check-in writes 'clingy:<chatId>' here so at most one is ever open.
  String tag;

  bool get open => status == TaskStatus.pending || status == TaskStatus.suspended;

  Map<String, dynamic> toJson() => {
        'id': id,
        'chatId': chatId,
        'fireAt': fireAt,
        'prompt': prompt,
        'createdAt': createdAt,
        'condition': condition,
        'type': proactiveWire(type),
        'status': status.name,
        'failures': failures,
        'urgent': urgent,
        'note': note,
        'firedAt': firedAt,
        if (tag.isNotEmpty) 'tag': tag,
      };

  factory ScheduledTask.fromJson(Map<String, dynamic> j) => ScheduledTask(
        id: j['id'] as String,
        chatId: j['chatId'] as String,
        fireAt: (j['fireAt'] as num).toInt(),
        prompt: j['prompt'] as String? ?? '',
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        condition: j['condition'] as String? ?? 'always',
        type: proactiveTypeOf(j['type'] as String?),
        status: TaskStatus.values.firstWhere((e) => e.name == j['status'], orElse: () => TaskStatus.pending),
        failures: (j['failures'] as num?)?.toInt() ?? 0,
        urgent: j['urgent'] as bool? ?? false,
        note: j['note'] as String? ?? '',
        firedAt: (j['firedAt'] as num?)?.toInt() ?? 0,
        tag: j['tag'] as String? ?? '',
      );
}

enum Verdict { fire, defer, skip }

class Gate {
  const Gate(this.verdict, this.reason, {this.until = 0});
  final Verdict verdict;
  final String reason;

  /// new fire time when the verdict is defer
  final int until;
}

/// Types whose delivery is optional and therefore subject to the dice.
const _optional = {ProactiveType.greeting, ProactiveType.share, ProactiveType.icebreak, ProactiveType.followup, ProactiveType.checkin};

class Scheduler {
  final List<ScheduledTask> tasks = [];
  var _seq = 0;

  String _id() => 't${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_seq++}';

  ScheduledTask schedule({
    required String chatId,
    required int delayMs,
    required String prompt,
    String condition = 'always',
    ProactiveType type = ProactiveType.custom,
    bool urgent = false,
    int? now,
  }) {
    final t = now ?? DateTime.now().millisecondsSinceEpoch;
    final task = ScheduledTask(id: _id(), chatId: chatId, fireAt: t + max(0, delayMs), prompt: prompt.trim(), createdAt: t, condition: condition.trim().isEmpty ? 'always' : condition.trim(), type: type, urgent: urgent);
    tasks.add(task);
    return task;
  }

  ScheduledTask? byId(String id) => tasks.where((t) => t.id == id).firstOrNull;

  List<ScheduledTask> open({String? chatId}) => [for (final t in tasks) if (t.open && (chatId == null || t.chatId == chatId)) t]..sort((a, b) => a.fireAt.compareTo(b.fireAt));

  bool cancel(String id, {String reason = 'cancelled by the assistant'}) {
    final t = byId(id);
    if (t == null || !t.open) return false;
    t.status = TaskStatus.cancelled;
    t.note = reason;
    return true;
  }

  /// Changes time and/or prompt of a task that has not fired. A suspended task
  /// comes back to life, that is how the assistant says "still wanted".
  bool modify(String id, {int? delayMs, String? prompt, String? condition, int? now}) {
    final t = byId(id);
    if (t == null || !t.open) return false;
    final base = now ?? DateTime.now().millisecondsSinceEpoch;
    if (delayMs != null) t.fireAt = base + max(0, delayMs);
    if (prompt != null && prompt.trim().isNotEmpty) t.prompt = prompt.trim();
    if (condition != null && condition.trim().isNotEmpty) t.condition = condition.trim();
    t.status = TaskStatus.pending;
    t.note = 'modified';
    return true;
  }

  /// The user wrote something. Pending tasks of the chat are parked until the
  /// assistant has looked at them in the reply it is about to write.
  int suspendForChat(String chatId) {
    var n = 0;
    for (final t in tasks) {
      if (t.chatId == chatId && t.status == TaskStatus.pending) {
        t.status = TaskStatus.suspended;
        n++;
      }
    }
    return n;
  }

  /// After the reply: whatever is still suspended was not renewed, drop it.
  int settleSuspended(String chatId) {
    var n = 0;
    for (final t in tasks) {
      if (t.chatId == chatId && t.status == TaskStatus.suspended) {
        t.status = TaskStatus.cancelled;
        t.note = 'user replied, not renewed';
        n++;
      }
    }
    return n;
  }

  List<ScheduledTask> due(int now) => [for (final t in tasks) if (t.status == TaskStatus.pending && t.fireAt <= now) t];

  /// Does the free text condition still hold?
  bool conditionHolds(ScheduledTask t, HumanState s, int now) {
    final c = t.condition.toLowerCase();
    if (c.isEmpty || c == 'always') return true;
    for (final part in c.split(RegExp(r'[,&+]|\band\b'))) {
      final k = part.trim();
      switch (k) {
        case 'user_silent':
        case 'silent':
          if (s.lastUserAt > t.createdAt) return false;
        case 'user_active':
          if (now - s.lastUserAt > 10 * 60 * 1000) return false;
        case 'ai_free':
          final e = s.effective(now);
          if (e == StatusKind.away || e == StatusKind.dnd) return false;
        default:
          break; // unknown words are context for the model, not a hard rule
      }
    }
    return true;
  }

  /// Decides what happens to a due task. Order: hard blocks first, then quiet
  /// hours and busy time (deferred, not lost), then the dice. [maxConsecutive]
  /// overrides the settings chain cap, a persona can tighten it for itself.
  Gate gate(ScheduledTask t, HumanState s, HumanSettings cfg, int now, HumanRandom rng, {int? maxConsecutive}) {
    if (!cfg.proactive) return const Gate(Verdict.skip, 'proactive messages are switched off');
    if (!conditionHolds(t, s, now)) return const Gate(Verdict.skip, 'condition no longer holds');
    final cap = maxConsecutive ?? cfg.maxConsecutive;
    if (s.consecutiveProactive >= cap && !t.urgent) {
      return Gate(Verdict.skip, 'reached $cap proactive messages in a row, waiting for the user');
    }
    if (cfg.dnd) return const Gate(Verdict.skip, 'do not disturb is on');
    if (cfg.inQuietHours(now)) {
      if (!(t.urgent && cfg.allowUrgent)) return Gate(Verdict.defer, 'quiet hours', until: _quietEnd(now, cfg));
    }
    // a clingy check-in is a switch the user set on purpose: it fires when the
    // silence is long enough, not when the mood dice feel like it, and a young
    // chat is exactly where a clingy persona is supposed to nag
    final isClingy = t.tag.startsWith('clingy:');
    if (t.type == ProactiveType.checkin && s.stage == Stage.stranger && !isClingy) {
      return const Gate(Verdict.skip, 'no check-ins at the stranger stage');
    }
    final life = s.activeLife(now);
    if (life != null) {
      if (t.type != ProactiveType.afterSchedule) return Gate(Verdict.defer, 'busy: ${life.title}', until: life.end + 30000);
    }
    final eff = s.effective(now);
    if (eff == StatusKind.dnd) return Gate(Verdict.defer, 'status is dnd', until: now + 30 * 60000);
    if (_optional.contains(t.type) && !isClingy) {
      var will = s.proactiveWill(cfg, now);
      // away keeps the frequency at the minimum, already folded into will
      will = (will * 1.6).clamp(0, 1);
      if (!rng.chance(will)) return Gate(Verdict.skip, 'not in the mood (will ${will.toStringAsFixed(2)})');
    }
    return const Gate(Verdict.fire, 'ok');
  }

  int _quietEnd(int now, HumanSettings cfg) {
    final d = DateTime.fromMillisecondsSinceEpoch(now);
    var end = DateTime(d.year, d.month, d.day, cfg.quietEnd ~/ 60, cfg.quietEnd % 60);
    if (!end.isAfter(d)) end = end.add(const Duration(days: 1));
    // a little random spread so it does not fire on the dot of the minute
    return end.millisecondsSinceEpoch + Random().nextInt(5 * 60000);
  }

  /// Queues the system generated triggers: greetings, ice-breakers and the
  /// "done" message after a life entry. These only create tasks, the model
  /// writes what is said. With [persona] the clingy switch joins the list: a
  /// persona that misses the user queues one check-in after the configured
  /// silence, at most one at a time.
  List<ScheduledTask> autoTasks({required String chatId, required HumanState s, required HumanSettings cfg, required int now, Persona? persona}) {
    final out = <ScheduledTask>[];
    final d = DateTime.fromMillisecondsSinceEpoch(now);
    final day = '${d.year}-${d.month}-${d.day}';
    final minute = d.hour * 60 + d.minute;
    ScheduledTask add(String key, ProactiveType type, String prompt, {bool urgent = false}) {
      s.autoKeys.add(key);
      final t = schedule(chatId: chatId, delayMs: 0, prompt: prompt, type: type, urgent: urgent, now: now);
      out.add(t);
      return t;
    }

    if (cfg.greetMorning && !s.autoKeys.contains('$day:morning') && minute >= cfg.morningAt && minute < cfg.morningAt + 180 && s.stage != Stage.stranger) {
      add('$day:morning', ProactiveType.greeting, 'Good morning greeting.');
    }
    if (cfg.greetEvening && !s.autoKeys.contains('$day:evening') && minute >= cfg.eveningAt && minute < cfg.eveningAt + 180 && s.stage != Stage.stranger) {
      add('$day:evening', ProactiveType.greeting, 'Good evening greeting.');
    }
    if (s.lastUserAt > 0 && s.stage != Stage.stranger && now - s.lastUserAt > cfg.icebreakDays * 86400000 && !s.autoKeys.contains('ice:${s.lastUserAt}')) {
      add('ice:${s.lastUserAt}', ProactiveType.icebreak, 'It has been ${(now - s.lastUserAt) ~/ 86400000} days since the last chat.');
    }
    for (final e in s.life) {
      if (!e.announced && e.end <= now && e.end > now - 6 * 3600000) {
        e.announced = true;
        schedule(chatId: chatId, delayMs: 0, prompt: 'You were busy with "${e.title}" and it is over now.', type: ProactiveType.afterSchedule, now: now);
      }
    }
    // no stage gate here: clingy is a switch the user set on purpose, and a
    // young chat stuck at the stranger stage is exactly where a clingy
    // persona is supposed to reach out; the gate already exempts the tag
    if (persona != null && persona.clingy && s.lastUserAt > 0) {
      final intervalMs = persona.clingySilentMin * 60000;
      // silence counts from the newest message on either side, so a check-in
      // that just went out restarts the wait instead of chaining into more
      final silentFor = now - max(s.lastUserAt, s.lastAiAt);
      final underCap = !persona.clingyCap || s.consecutiveProactive < persona.clingyMax;
      final tag = 'clingy:$chatId';
      if (intervalMs > 0 && silentFor >= intervalMs && underCap && !tasks.any((t) => t.open && t.tag == tag)) {
        final t = schedule(chatId: chatId, delayMs: 0, prompt: 'The user has been quiet for a while. Check in on them, in your own tone, do not nag.', condition: 'user_silent', type: ProactiveType.checkin, now: now);
        t.tag = tag;
        out.add(t);
      }
    }
    s.autoKeys.removeWhere((k) => !k.startsWith(day) && !k.startsWith('ice:'));
    return out;
  }

  /// Old finished tasks are kept for the debug panel but not forever.
  void trim() {
    final done = tasks.where((t) => !t.open).toList();
    if (done.length > 60) {
      done.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final t in done.take(done.length - 60)) {
        tasks.remove(t);
      }
    }
  }

  /// The post reply dice: every finished answer rolls once more for whether
  /// the assistant wants to speak again on its own soon. Without this the
  /// proactive side only lived on the model remembering to call
  /// schedule_message, which it forgets, and that read as coldness.
  ///
  /// The wait is minutes to a couple of hours, skewed short, and the type is
  /// picked from how the conversation actually went. A task the user asked
  /// to be left alone is never queued; the gate still vets the task at fire
  /// time, so mood and quiet hours are honoured twice.
  ScheduledTask? rollProactive({required String chatId, required HumanState s, required HumanSettings cfg, required int now, required HumanRandom rng, required bool userAnnoyed, int? maxConsecutive}) {
    if (!cfg.proactive) return null;
    if (userAnnoyed) return null;
    if (s.consecutiveProactive >= (maxConsecutive ?? cfg.maxConsecutive)) return null;
    if (s.stage == Stage.stranger) return null;
    final will = s.proactiveWill(cfg, now);
    if (!rng.chance(will * 0.45)) return null;
    final type = s.silence(now) > 3 * 3600000 ? ProactiveType.checkin : (rng.chance(0.5) ? ProactiveType.share : ProactiveType.followup);
    final wait = _postReplyWait(rng);
    final t = schedule(
      chatId: chatId,
      delayMs: wait,
      prompt: switch (type) {
        ProactiveType.checkin => 'You were left with the last word a while ago. See how the user is doing, in your own tone.',
        ProactiveType.share => 'Something from this chat or your day is worth sharing. Bring it up briefly.',
        _ => 'Pick up the thread you two left hanging, without recapping.',
      },
      condition: 'user_silent',
      type: type,
      now: now,
    );
    return t;
  }

  /// minutes to about two hours, weighted toward the short end
  int _postReplyWait(HumanRandom rng) {
    final r = rng.next() * rng.next(); // triangular toward zero
    return (3 * 60000 + r * 110 * 60000).round();
  }

  List<Map<String, dynamic>> toJson() => [for (final t in tasks) t.toJson()];
  void loadJson(List<dynamic> raw) {
    tasks
      ..clear()
      ..addAll([for (final e in raw) ScheduledTask.fromJson(Map<String, dynamic>.from(e as Map))]);
    // a task caught in the middle of firing when the app died is retried
    for (final t in tasks) {
      if (t.status == TaskStatus.firing) t.status = TaskStatus.pending;
    }
  }
}
