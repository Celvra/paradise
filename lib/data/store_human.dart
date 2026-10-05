part of 'store.dart';

// The humanized generation engine. It is a part of the store library so it can
// reach the chat list, the run table and the history builder directly.
//
// One generation = a loop of model passes. Each pass streams text through the
// BrParser, every finished segment is queued for display, and any tool calls
// are executed before the next pass. Timing rules, decided once:
//
//  * the pause asked for by `<i-br_N>` is measured from the moment the previous
//    bubble was SHOWN, not from when the tag was parsed. If the model is slower
//    than the pause, the next bubble simply appears when it is closed.
//  * time spent inside a tool call counts towards the pause, a slow tool
//    therefore never adds a second wait on top.
//  * a pass that ends without a closing tag releases its tail as the last
//    bubble of that pass (the model stopped talking, there is nothing to wait for).
//  * a pass that dies after text arrived releases its tail the same way. Only
//    a user interrupt throws text away, on purpose: there the model is told
//    next turn what was cut. Every other way a bubble can vanish would leave a
//    hole in the history, and a model looking at a hole asks what it just said.
//  * history replay never goes through here: messages are stored already split,
//    so nothing waits when a chat is opened or a connection is restored.

String shortId(String id) => id.length <= 6 ? id : id.substring(id.length - 6);

/// One tool the model may call. `external` marks MCP tools, which default to
/// "ask" instead of "allow".
class HTool {
  HTool(this.name, this.description, this.props, this.run, {this.required = const [], this.external = false});
  final String name;
  final String description;
  final Map<String, dynamic> props;
  final List<String> required;
  final bool external;
  final Future<String> Function(Map<String, dynamic> args) run;

  ToolSpec get spec => ToolSpec(name: name, description: description, parameters: {'type': 'object', 'properties': props, if (required.isNotEmpty) 'required': required});
}

/// Per generation scratch shared between the engine and the tools.
class ToolEnv {
  ToolEnv({required this.chat, required this.run, required this.rng, required this.proactive, required this.flush});
  final Chat chat;
  final _Run run;
  final HumanRandom rng;
  final bool proactive;

  /// resolves when every queued bubble of this run has been shown
  final Future<void> Function() flush;

  /// Null unless this chat has a workspace and the file tools are on. Built in
  /// humanReply because resolving the roots needs the disk and this table is
  /// assembled synchronously.
  WsContext? ws;

  String? quote;
  int textSent = 0;
  int toolMsgs = 0;
  int nextAt = 0;
}

Map<String, dynamic> _p(String type, String desc, {List<String>? values}) => {'type': type, 'description': desc, if (values != null) 'enum': values};
Map<String, dynamic> _arr(String desc) => {'type': 'array', 'items': {'type': 'string'}, 'description': desc};
String _str(Map<String, dynamic> a, String k, [String d = '']) => (a[k] ?? d).toString();
int _int(Map<String, dynamic> a, String k, int d) => a[k] is num ? (a[k] as num).toInt() : (int.tryParse('${a[k] ?? ''}') ?? d);
double _num(Map<String, dynamic> a, String k, double d) => a[k] is num ? (a[k] as num).toDouble() : (double.tryParse('${a[k] ?? ''}') ?? d);

/// TikZ is a drawing language, not math, and the math engine (RaTeX) parses
/// neither its environments nor its \\draw/\\node/\\foreach commands. A model
/// trained on TikZ reaches for it whenever it wants a picture, so send_latex
/// refuses it here with a pointer to send_cetz instead of queueing a card the
/// renderer is guaranteed to reject. Only forms that never occur in real math
/// are matched, so an ordinary formula is never misread.
final _tikzRe = RegExp(
  r'\\begin\s*\{tikz(?:picture)?\}|\\end\s*\{tikz(?:picture)?\}|\\begin\s*\{axis\}|'
  r'\\draw\b|\\filldraw\b|\\fill\b|\\node\b|\\path\b|\\coordinate\b|\\foreach\b|\\addplot\b',
);
bool looksLikeTikz(String s) => _tikzRe.hasMatch(s);

String _ago(int ms) {
  if (ms < 0) return 'just now';
  final m = ms ~/ 60000;
  if (m < 1) return '${ms ~/ 1000}s';
  if (m < 90) return '${m}min';
  final h = m ~/ 60;
  if (h < 48) return '${h}h ${m % 60}min';
  return '${h ~/ 24}d ${h % 24}h';
}

Future<void> _sleep(_Run run, int ms) {
  if (ms <= 0 || run.cancelled) return Future.value();
  final c = Completer<void>();
  final timer = Timer(Duration(milliseconds: ms), () {
    if (!c.isCompleted) c.complete();
  });
  void wake() {
    timer.cancel();
    if (!c.isCompleted) c.complete();
  }

  run.token.addListener(wake);
  return c.future.whenComplete(() => run.token.removeListener(wake));
}

double _dice(String a, String b) {
  Set<String> grams(String s) {
    final t = s.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (t.length < 2) return {t};
    return {for (var i = 0; i + 1 < t.length; i++) t.substring(i, i + 2)};
  }

  final x = grams(a), y = grams(b);
  if (x.isEmpty || y.isEmpty) return 0;
  return 2 * x.intersection(y).length / (x.length + y.length);
}

/// What a bubble may never contain, before any style is applied: a break tag the
/// parser let through, and the `[m:abc123 14:02]` ids the model keeps copying out
/// of its own history into the answer, usually as a speaker label. Those ids are
/// tool arguments, they belong in no bubble. The model never writes the prefix
/// the same way twice, so the opening and closing bracket are matched apart:
/// `[m:a]`, `<m:a]`, `[m:a>` and a bare `m:a 19:29` at the start of a line are
/// all the same leak.
///
/// Lines inside a ``` fence are left untouched: collapsing runs of spaces
/// there would flatten the indentation of every code block the model sends,
/// which for Python is not a cosmetic loss.
String cleanBubble(String text) {
  final lines = stripBrTags(text).replaceAllMapped(RegExp(r'[<\[]m:[^\n<>[\]]{0,40}[>\]][ \t]?'), (_) => '').replaceAllMapped(RegExp(r'^[ \t]*m:\w{1,16}[ \t]+\d{1,2}:\d{2}[ \t]*', multiLine: true), (_) => '').split('\n');
  final out = <String>[];
  var inCode = false;
  for (final line in lines) {
    if (RegExp(r'^\s*```').hasMatch(line)) {
      inCode = !inCode;
      out.add(line.trim());
      continue;
    }
    // prose gets the tidying, code keeps its own spacing: collapsing the runs
    // of spaces inside a fence would flatten the indentation, which for Python
    // is not a cosmetic loss
    out.add(inCode ? line : line.replaceAll(RegExp(r'[ \t]{2,}'), ' '));
  }
  return out.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

extension StoreHuman on Store {
  bool get humanOn => human?.settings.enabled ?? false;
  int get _nowMs => DateTime.now().millisecondsSinceEpoch;
  bool get _foreground => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  Msg? findMsg(Chat c, String ref) {
    final r = ref.trim().replaceAll(RegExp(r'^#|^m:'), '');
    if (r.isEmpty) return null;
    for (final m in c.msgs.reversed) {
      if (m.id == r || shortId(m.id) == r || m.id.endsWith(r)) return m;
    }
    return null;
  }

  // ------------------------------------------------------------- user side

  /// A new message from the user arrived. Everything in flight stops now.
  void humanInterrupt(Chat c) {
    final run = _runs[c.id];
    if (run != null) {
      final hh = human!;
      final cut = run.parser?.abort();
      final dropped = [...run.queued, if (cut != null && cut.droppedText.trim().isNotEmpty) cut.droppedText.trim()];
      if (dropped.isNotEmpty) hh.interruptNotes[c.id] = dropped.join(' | ');
      run.queued.clear();
      run.token.cancel();
      // free the slot at once so the new reply can start, the old run notices
      // it was cancelled and only cleans up after itself
      _runs.remove(c.id);
      c.typing = false;
    }
  }

  void humanOnUser(Chat c, String text) {
    final hh = human;
    if (hh == null) return;
    final now = _nowMs;
    final st = c.human;
    st.noteUser(text, now);
    final n = hh.scheduler.suspendForChat(c.id);
    if (n > 0) hh.logGate('user replied: $n pending task(s) of ${c.persona.name} parked for review');
    if (hh.settings.autoRate) {
      final s = hh.settings;
      if (RegExp(r'(别发了|太烦|烦死|不要再发|stop (messaging|texting)|too many messages)', caseSensitive: false).hasMatch(text)) {
        s.annoyScore = (s.annoyScore + 0.4).clamp(1, 5);
      } else if (RegExp(r'(像真人|真人|好像人|so human|feels real|like a real person)', caseSensitive: false).hasMatch(text)) {
        s.humanScore = (s.humanScore + 0.3).clamp(1, 5);
      } else if (RegExp(r'(哈哈|笑死|太好了|lol|haha|nice)', caseSensitive: false).hasMatch(text)) {
        s.satisfaction = (s.satisfaction + 0.05).clamp(1, 5);
      }
    }
    hh.changed();
  }

  // ------------------------------------------------------------ describing

  String humanDescribe(Msg m) {
    var body = m.recalled ? '(you recalled this message${m.recalledText.isEmpty ? '' : ': ${m.recalledText}'})' : _describe(m);
    if (m.edited) body += ' (edited)';
    if (m.pinned) body += ' (pinned)';
    if (m.reply != null) body = '(replying to #${shortId(m.reply!)}) $body';
    return '[m:${shortId(m.id)} ${hm(m.time)}] $body';
  }

  String _timeBlock(Chat c, int now) {
    final st = c.human;
    final d = DateTime.fromMillisecondsSinceEpoch(now);
    final off = d.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final tz = 'UTC$sign${off.inHours.abs().toString().padLeft(2, '0')}:${(off.inMinutes.abs() % 60).toString().padLeft(2, '0')} (${d.timeZoneName})';
    final hs = human!.settings;
    final userGap = st.lastUserAt == 0 ? 'never' : '${_ago(now - st.lastUserAt)} ago';
    final aiGap = st.lastAiAt == 0 ? 'never' : '${_ago(now - st.lastAiAt)} ago';
    return [
      'Current time: ${d.toIso8601String().substring(0, 19).replaceFirst('T', ' ')} $tz, ${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1]}, timestamp ${now}ms.',
      'Last message from the user: ${st.lastUserAt == 0 ? 'none' : hm(st.lastUserAt)} ($userGap). Last message from you: ${st.lastAiAt == 0 ? 'none' : hm(st.lastAiAt)} ($aiGap).',
      'User quiet hours: ${hs.quiet ? '${_clock(hs.quietStart)}-${_clock(hs.quietEnd)}' : 'off'}${hs.inQuietHours(now) ? ' (it is quiet hours NOW, do not schedule or send anything non-urgent)' : ''}. Do-not-disturb: ${hs.dnd ? 'ON' : 'off'}. Proactive messages in a row so far: ${st.consecutiveProactive}/${hs.maxConsecutive}.',
    ].join('\n');
  }

  static String _clock(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  String humanContext(Chat c, {required HumanRandom rng, ScheduledTask? task, required String lastUserText}) {
    final hh = human!;
    final hs = hh.settings;
    final st = c.human;
    final now = _nowMs;
    final b = <String>[];

    // output contract, first block so it is never buried

    // bubble count is rolled per turn instead of a fixed 2 3. A fixed range is
    // what made every reply come back as three even paragraphs. Low energy and
    // an early relationship stage pull the target down, closeness pushes it up.
    var bubbleTarget = 1 + rng.next() * rng.next() * 4; // triangular 1..5 low biased
    if (st.energy < 35) bubbleTarget = min(bubbleTarget, 2);
    if (st.stage == Stage.stranger) bubbleTarget = min(bubbleTarget, 3);
    final bubbleCount = max(1, bubbleTarget.round());
    final bubbleWord = switch (bubbleCount) {
      1 => 'a single bubble this turn, no split',
      2 => 'about two bubbles of clearly different length',
      3 => 'two to three bubbles that do not look alike',
      _ => 'several bubbles with strongly varied length',
    };
    final splitRolled = rng.chance(hs.splitProb);

    b.add([
      '# OUTPUT CONTRACT (violating this makes the answer wrong, not merely less nice)',
      if (hs.br) ...[
        'RULE 1. One thought per bubble. A reply of two or more short sentences MUST be split into separate bubbles.',
        'RULE 2. Put each bubble on its own line. A line break separates bubbles and uses the default pause.',
        'RULE 3. Use <i-br_N> instead of a plain line break when you want to choose how long the pause is: <i-br> for a normal gap, <i-br_500> for 500 milliseconds, <i-br_900> for a longer one. About 300 to 1500 ms, longer for longer bubbles. Example: "早上好。<i-br_500>今天心情如何? <i-br_700>陪我聊会天吧。"',
        'RULE 4. Inside the tag you write the real number of milliseconds. Never write the letters MS.',
        'RULE 5. The tag is invisible to the reader. Never mention it, never spell it out, never explain it, never put it in a code block.',
        'RULE 6. Two sentences in a row with nothing between them is a failed reply. Every gap between two of your sentences has to break the line or carry a tag.',
        'RULE 7. If you make a typo or say something you want to take back, you send it first as its own bubble, then recall it, then send the corrected text. Do not fix it silently and do not apologise for the mistake in the same breath.',
      ],
      if (!hs.br) 'Do not use <i-br> tags, write one message.',
      'Keep it to a few short messages. Do not write long speeches. Every message is shown the moment it is closed.',
      'Vary the bubble lengths like a real person: some turns a one word bubble, some turns three lines. Never three paragraphs of the same size.',
      'Message ids look like [m:abc123 14:02] in the history. They are for tool arguments only, hand them to a tool. Never imitate that prefix in your reply: no id, no [m:...] label, no timestamp in front of a sentence, not at the start of a bubble, not in the middle, not as a speaker label.',
      'Typing speed is part of the character: lower energy means fewer and slower bubbles.',
      if (splitRolled) 'This turn: aim for $bubbleWord.',
      if (rng.chance(hs.particleProb)) 'This turn: add a casual filler particle (嗯, 啊, 哈哈, lol, hmm) somewhere natural.',
      if (hs.punct == 1) 'Punctuation: loose, drop most full stops, use ellipses and spaces.',
      if (hs.punct == 2) 'Punctuation: minimal, almost none at the end of bubbles.',
    ].join('\n'));

    b.add('# Live context (refreshed for this very turn)\n${_timeBlock(c, now)}');

    // character card
    final card = st.card;
    if (!card.isEmpty) {
      final addr = card.addressFor(st.stage);
      b.add([
        '# Your character sheet (stay consistent with it, do not drift into another person)',
        if (card.speechStyle.isNotEmpty) 'Speaking style: ${card.speechStyle}',
        if (card.catchphrases.isNotEmpty) 'Catchphrases (use sparingly, not every message): ${card.catchphrases.join(' / ')}',
        if (card.values.isNotEmpty) 'Values: ${card.values}',
        if (card.taboos.isNotEmpty) 'Never do or say: ${card.taboos}',
        if (addr.isNotEmpty) 'How you address the user right now: $addr',
      ].join('\n'));
    }

    // state, mood, relationship
    final life = st.activeLife(now);
    final moodHint = st.mood >= 70 ? 'good mood: say a little more, warmer and playful' : (st.mood <= 35 ? 'low mood: shorter, flatter, fewer exclamation marks' : 'ordinary mood');
    final energyHint = st.energy <= 30 ? 'tired: very short messages, you may take longer to answer' : (st.energy >= 75 ? 'energetic' : 'normal energy');
    final stageHint = switch (st.stage) {
      Stage.stranger => 'stranger: polite, no pet names, never check up on the user, rarely start conversations',
      Stage.acquaintance => 'acquaintance: friendly, normal address, may greet and ask how things are, moderate initiative',
      Stage.close => 'close: affectionate, pet names allowed, may check up on the user and tease, boundaries are looser, high initiative',
    };
    b.add([
      '# Your state (numbers 0-100)',
      'Status: ${statusWire(st.effective(now, dnd: hs.dnd))}. Mood ${st.mood.round()} ($moodHint). Affection ${st.affection.round()}. Energy ${st.energy.round()} ($energyHint).',
      'Relationship stage: $stageHint.',
      if (life != null) 'Right now you are: ${life.title} (until ${hm(life.end)}). Keep replies brief and mention it only if natural.',
      'If the user praises or insults you, or the mood really changes, call adjust_feeling. You may call set_status (online, away, dnd, read_no_reply).',
    ].join('\n'));

    // memory
    final mem = hh.memory.forContext('$lastUserText ${task?.prompt ?? ''}');
    if (mem.isNotEmpty) {
      b.add('# Long term memory (ids are for complete_todo)\n${mem.map((m) => '- ${m.id} [${m.type.name}] ${m.content}${m.dueAt > 0 ? ' (due ${DateTime.fromMillisecondsSinceEpoch(m.dueAt).toIso8601String().substring(0, 16)})' : ''}').join('\n')}\nUse write_memory for new preferences, events, promises, todos and conflicts. Open promises and todos stay until you call complete_todo.');
    }

    // queue
    final open = hh.scheduler.open(chatId: c.id);
    if (open.isNotEmpty) {
      b.add('# Scheduled messages you set up earlier\n${open.map((t) => '- ${t.id} in ${_ago(t.fireAt - now)} [${proactiveWire(t.type)}] condition=${t.condition} prompt="${t.prompt}"${t.status == TaskStatus.suspended ? ' (PARKED: the user just wrote, call modify_scheduled to keep it, otherwise it is cancelled after this reply)' : ''}').join('\n')}');
    }

    // stickers
    final stickerLine = hs.stickerFreq <= 0.02 ? 'The user asked you not to send stickers on your own.' : 'Use a sticker in roughly ${(hs.stickerFreq * 100).round()}% of your turns when it fits the emotion.';
    b.add([
      '# Stickers',
      stickerLine,
      hs.stickerOnly ? 'You may answer with only a sticker and no text when a human would (e.g. a lazy reply to "在吗").' : 'Never reply with only a sticker, write text as well.',
      hs.aiSaveSticker ? 'If the user sends a meme or sticker you like, call save_sticker with the message id, an emotion word and tags.' : 'You may not save new stickers.',
      'Pick by the current emotion and context, call send_sticker with an id from this library or with an emotion word:',
      if (hh.stickers.items.isEmpty) kStickerLibEmptyNote else hh.stickers.catalogue(limit: 30),
    ].join('\n'));

    // drawn once and reused: the rng is seeded per turn, so asking twice would
    // advance the sequence and the two halves of the prompt could disagree
    var typoTurn = false;
    // recall rules
    if (hs.recall) {
      final left = max(0, hs.recallPerHour - st.recallsInLastHour(now));
      typoTurn = rng.chance(hs.typoProb);
      b.add([
        '# Recalling messages',
        'You may call recall_message(keyword) within ${hs.recallWindowSec}s of sending to withdraw something you got wrong. Only already delivered bubbles can be recalled. $left recalls left this hour, do not overuse it.',
        'Say fewer sentences: do not wait until you have said everything and then remember a mistake, the user will think you are slow. Decide quickly.',
        if (typoTurn)
          'TYPO AND RECALL, this turn. You MUST do it, in this exact order, and you must not skip a step: '
              '1) send_typo(text) with one deliberately wrong character, as its own bubble. '
              '2) recall_message(keyword of what you just sent, delay_ms 1500 to 3000). '
              '3) send the corrected text as a new bubble. '
              'The wrong text has to be delivered first. Correcting it without ever sending the wrong version is not a recall and does not count as doing this.',
      ].join('\n'));
    }

    if (hs.wallet) b.add('# Wallet\nYou can send the user a pretend transfer or red packet with send_transfer, only for moments that call for it (a gift, a bet lost, comfort). It is not real money.');

    final note = hh.interruptNotes.remove(c.id);
    if (note != null && note.isNotEmpty) {
      b.add('# You were interrupted\nThe user sent a new message while you were still talking. These parts were NOT sent and are discarded: "$note". Read their new message and decide again whether to say any of it, say it differently, or drop it.');
    }

    if (task != null) {
      b.add([
        '# This turn is a proactive message',
        'Nobody wrote to you. You decided earlier to write first. ${templateFor(task.type)}',
        'What you left for yourself: "${task.prompt}" (condition: ${task.condition}).',
        'Check the time block: if it makes no sense to disturb the user now, send nothing (reply with an empty message). Do not write as if the user had just spoken. You may use tools.',
        'You may schedule one follow-up with schedule_message only if it is really needed, remember a limit of ${hs.maxConsecutive} proactive messages in a row.',
      ].join('\n'));
    }

    // The contract restated last, right before the answer is written. A rule
    // stated once at the top of a long prompt competes with hundreds of lines of
    // character sheet and live state; stated last it is the freshest thing in
    // the window and the model actually checks it.
    final checklist = <String>[];
    if (hs.br) {
      checklist.addAll([
        'Reread the OUTPUT CONTRACT before you answer.',
        'One bubble per line. Break the line between your sentences, or use <i-br_N> when you want a pause of N milliseconds.',
        // the count target only when the dice rolled for a split this turn
        // otherwise the checklist would talk the model into one anyway
        if (splitRolled) 'This turn: $bubbleWord.' else 'Vary the bubble lengths.',
        'No [m:...] labels, no timestamps, no mention of these rules in the answer.',
      ]);
    }
    if (typoTurn) {
      checklist.add('This turn you owe the reader a typo and a recall: send the wrong text, recall it, then send it right.');
    }
    if (checklist.isNotEmpty) b.add('# Before you answer\n${checklist.join('\n')}');

    return b.join('\n\n');
  }

  // ---------------------------------------------------------------- output

  /// One bubble from the assistant, with notification handling.
  Msg humanSay(Chat c, String text, {MsgKind kind = MsgKind.text, Map<String, dynamic>? data, String? reply, bool proactive = false}) {
    final m = Msg(id: _id(), out: false, text: text, time: _nowMs, reply: reply, kind: kind, data: data, proactive: proactive);
    c.msgs.add(m);
    c.human.noteAi(m.time, proactive: proactive);
    c.human.adjust(energy: -0.15);
    final seen = openId == c.id && _foreground;
    if (seen) {
      m.data['seen'] = true;
      _advance(c, St.sent, St.read);
    } else {
      c.unread++;
      human?.onNotify?.call(c.id, m.id, c.persona.name, m.preview);
    }
    if (haptics && seen) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
    c.typing = false;
    c.touch();
    return m;
  }

  String _styled(String text, HumanSettings hs) {
    final t = cleanBubble(text);
    if (t.isEmpty) return '';
    if (_inFence(t)) return t; // a code block keeps its own punctuation
    String? tidied;
    if (hs.punct == 1) {
      tidied = t.replaceAll(RegExp(r'[。.]+$'), '').replaceAll('。', ' ').trim();
    } else if (hs.punct == 2) {
      tidied = t.replaceAll(RegExp(r'[。.，,！!]+$'), '').replaceAll('，', ' ').trim();
    }
    // punctuation style may tidy a bubble but it must never empty it: an
    // answer that vanishes leaves a hole in the model's own history and it
    // ends up asking what it had just said
    return tidied == null || tidied.isEmpty ? t : tidied;
  }

  /// True when [text] carries an unclosed ``` fence anywhere in it, or is
  /// entirely inside one. The punctuation passes and the space collapsing are
  /// prose shaping; neither may touch a code block.
  bool _inFence(String text) {
    var fence = false;
    for (final line in text.split('\n')) {
      if (RegExp(r'^\s*```').hasMatch(line)) fence = !fence;
    }
    return fence;
  }

  // -------------------------------------------------------------- recalling

  String humanRecall(Chat c, String keyword, {String reason = ''}) {
    final hs = human!.settings;
    final st = c.human;
    final now = _nowMs;
    if (!hs.recall) return 'Error: the user disabled message recall.';
    if (st.recallsInLastHour(now) >= hs.recallPerHour) return 'Error: recall limit reached for this hour. Leave the message as it is.';
    final window = hs.recallWindowSec * 1000;
    Msg? best;
    var bestScore = 0.0;
    final k = keyword.trim().toLowerCase();
    for (final m in c.msgs.reversed) {
      if (now - m.time > window) break;
      if (m.out || m.service || m.recalled) continue;
      final hay = (m.text.isEmpty ? m.preview : m.text).toLowerCase();
      final score = k.isEmpty ? 0.5 : (hay.contains(k) ? 1.0 : _dice(hay, k));
      // a newer message wins a tie, it is the one that was just said
      if (score > bestScore + 0.001 || (best == null && score >= 0.34)) {
        best = m;
        bestScore = score;
      }
    }
    if (best == null || bestScore < 0.34) return 'Error: no message of yours in the last ${hs.recallWindowSec}s matches "$keyword". Only delivered bubbles can be recalled.';
    best.recalled = true;
    best.recalledText = best.text;
    best.recalledAfterRead = best.data['seen'] == true;
    if (!best.recalledAfterRead && c.unread > 0) c.unread--;
    st.recallStamps.add(now);
    st.recallStamps.removeWhere((t) => now - t > 3600000);
    human?.onCancelNotify?.call(best.id);
    c.touch();
    return 'Recalled message #${shortId(best.id)}${best.recalledAfterRead ? ' (the user had already seen it)' : ''}.';
  }

  // ---------------------------------------------------------------- editing

  void humanEdit(Chat c, Msg m, String text) {
    final t = text.trim();
    if (t.isEmpty || t == m.text || m.recalled) return;
    m.edits.add(m.text);
    m.text = t;
    m.edited = true;
    if (!m.out) {
      // an edited assistant message is split again, the same way a streamed one is
      final parts = splitBrText(t);
      if (parts.length > 1) {
        m.text = parts.first;
        final at = c.msgs.indexOf(m);
        for (var i = 1; i < parts.length; i++) {
          c.msgs.insert(at + i, Msg(id: _id(), out: false, text: parts[i], time: m.time + i, edited: true, edits: [m.edits.last]));
        }
      }
    }
    c.touch();
    _save();
  }

  void humanPin(Chat c, Msg m, [bool? on]) {
    m.pinned = on ?? !m.pinned;
    c.touch();
    _save();
  }

  void humanAcceptTransfer(Chat c, Msg m, {bool accept = true}) {
    final hh = human;
    if (hh == null) return;
    final id = m.data['txId'] as String? ?? '';
    final ok = accept ? hh.wallet.accept(id) : hh.wallet.decline(id);
    if (!ok) return;
    m.data['status'] = accept ? 'accepted' : 'declined';
    hh.changed();
    c.touch();
    _save();
  }

  // ------------------------------------------------------------ the engine

  Future<bool> humanReply(Chat c, {ScheduledTask? task}) async {
    final cfg = _ai;
    final hh = human!;
    final hs = hh.settings;
    final nodes = chainFor(c);
    if (cfg == null || nodes.isEmpty) {
      _advance(c, St.sending, St.failed);
      if (task == null) _service(c, 'No model is on the chain yet. Open Settings > AI and add one.');
      task?.note = 'no model configured';
      return false;
    }
    if (!nodes.every((n) => cfg.keyOf(n.providerId).trim().isNotEmpty)) {
      _advance(c, St.sending, St.failed);
      if (task == null) _service(c, 'No API key. Open Settings > AI and add one to chat.');
      task?.note = 'no api key';
      return false;
    }

    final st = c.human;
    final run = _Run();
    _runs[c.id] = run;
    final startedAt = _nowMs;
    // the two reply switches, persona override already folded in
    final showThink = thinkingFor(c);
    st.tick(startedAt);
    final rng = HumanRandom.forTurn(hs, c.id, st.turn++);
    // the no tag fallback cut wanders per turn like everything else here,
    // a fixed width would put every long bubble at the same size
    final parser = BrParser(defaultDelayMs: hs.brDefaultMs, enabled: hs.br, autoSplitChars: max(48, rng.jitter(72, hs.randomRange)));
    run.parser = parser;
    final proactive = task != null;
    // a run that starts while a stale typing flag is up recovers to online,
    // the flag itself is owned by the show loop from here on
    final restore = st.status == StatusKind.typing ? StatusKind.online : st.status;
    c.typing = false;

    var pipeline = Future<void>.value();
    final env = ToolEnv(chat: c, run: run, rng: rng, proactive: proactive, flush: () => pipeline)..ws = await wsContext(c);
    // read time before the first bubble, the same reason a person does not
    // answer while the message is still whooshing away. The typing indicator
    // stays off through the read and comes on only when the first segment
    // starts waiting to be shown
    env.nextAt = _nowMs + rng.jitter(hs.replyDelayMs, hs.randomRange);
    var accepted = false;
    var delivered = 0;
    var toolRuns = 0;
    String? failure;

    // pause that a person would take, slower when tired, scaled by the knob
    int pause(int ms) {
      final slow = st.energy < 50 ? 1 + (50 - st.energy) / 100 * 0.8 : 1.0;
      return rng.jitter((ms * slow * hs.paceScale).round(), hs.randomRange);
    }

  Future<void> show(BrSegment seg) async {
    if (run.cancelled) return;
    // the double check lands when the reply starts being typed: composing
    // is proof the message was read. Idempotent, later bubbles no-op it.
    _advance(c, St.sent, St.read);
    // the pause before this bubble is a hesitation between thoughts, not
    // typing, so the indicator stays off through it
    final hesitate = env.nextAt - _nowMs;
    if (hesitate > 0) await _sleep(run, hesitate);
    // now the typing itself, timed by the length of the bubble being typed
    final typeMs = typingMs(seg.text, random: rng.raw, spread: hs.randomRange) * (st.energy < 50 ? 1.3 : 1.0);
    if (!run.cancelled && typeMs > 0) {
      c.typing = true;
      st.status = StatusKind.typing;
      c.touch();
      await _sleep(run, typeMs.round());
    }
    run.queued.remove(seg.text);
    if (run.cancelled) return;
    final text = _styled(seg.text, hs);
    if (text.isEmpty) return;
    humanSay(c, text, reply: env.quote, proactive: proactive);
    env.quote = null;
    env.textSent++;
    delivered++;
    env.nextAt = _nowMs + (seg.delayMs > 0 ? pause(seg.delayMs) : 0);
    // between bubbles the persona drops back to its baseline, the typing
    // indicator comes back on with the next typing phase or never
    if (!run.cancelled) {
      st.status = restore;
      c.touch();
    }
  }

    void enqueue(List<BrSegment> segs) {
      for (final s in segs) {
        run.queued.add(s.text);
        pipeline = pipeline.then((_) => show(s));
      }
    }

    void onText(String delta) {
      if (run.cancelled) return;
      if (!accepted) {
        accepted = true;
        c.touch();
      }
      enqueue(parser.push(delta));
    }

    // the outgoing side is already delivered the moment the run exists
    _advance(c, St.sending, St.sent);

    try {
      final lastUser = c.msgs.lastWhere((m) => m.out && !m.service, orElse: () => Msg(id: 'x', out: true, text: '', time: 0)).text;
      var turns = await _history(c);
      if (proactive) {
        turns.add(ChatTurn('user', [TextPart('[system event: proactive turn] ${templateFor(task.type)}\nYour own note: ${task.prompt}')]));
      }
      final table = <String, HTool>{for (final t in humanTools(c, env)) t.name: t};
      final specs = [for (final t in table.values) t.spec];
      final wsBlock = await wsPrompt(c);
      final system = [
        _systemPrompt(c),
        humanContext(c, rng: rng, task: task, lastUserText: lastUser),
        if (wsBlock != null) wsBlock,
      ].join('\n\n');

      // the same cap the agent loop uses, read live so a change in the
      // settings lands on the next reply without a restart
      final maxPass = agentMaxPass;
      for (var pass = 0; (maxPass <= 0 || pass < maxPass) && !run.cancelled; pass++) {
        final outcome = await runChain(
          settings: cfg.settings,
          apiKeys: cfg.apiKeys,
          system: system,
          messages: turns,
          nodes: nodes,
          tools: specs,
          options: ChainOptions(
            cancel: run.token,
            sessionId: c.id,
            onChunk: (chunk) {
              if (chunk.isText) {
                onText(chunk.delta);
              } else if (chunk.isReasoning && showThink) {
                traceThinking(c, chunk.delta);
              }
            },
            onCompact: () async {
              final node = nodes.firstOrNull;
              if (node == null) return;
              final result = await compactHistory(settings: cfg.settings, apiKeys: cfg.apiKeys, system: _systemPrompt(c), history: _historyItems(c), previous: cfg.compactionOf(c.id), node: node);
              cfg.setCompaction(c.id, result);
              turns = await _history(c);
            },
            onEvent: (e) {
              if (e.kind == ChainEventKind.node && e.node != null) lastServedBy = e.node!.modelId;
            },
          ),
        );
        if (run.cancelled) break;
        // the think of this pass is over, the next tool round opens its own row
        endThinking(c);
        // Connection lost in the middle of a pass: the bubbles that were already
        // closed stay and the tail behind the last tag is shown as one more
        // bubble. It went unsent before and the model never learned what the
        // user had already been told.
        if (outcome.error != null && outcome.text.isNotEmpty) {
          enqueue(parser.release());
          failure = describeErrorL10n(outcome.error!);
          if (!proactive) _service(c, L10n.current.errorStoppedEarly(failure));
          break;
        }
        // the model stopped talking for this pass, whatever is left is a bubble
        enqueue(parser.finish());
        if (outcome.error != null && outcome.text.isEmpty && outcome.toolCalls.isEmpty) {
          failure = describeErrorL10n(outcome.error!);
          if (!proactive) {
            _advance(c, St.sending, St.failed);
            _service(c, '$failure (${outcome.error!.message})');
          }
          break;
        }
        if (outcome.toolCalls.isEmpty) break;

        turns.add(ChatTurn('assistant', [if (outcome.text.trim().isNotEmpty) TextPart(outcome.text), ...outcome.toolCalls]));
        final results = <ContentPart>[];
        for (final call in outcome.toolCalls) {
          if (run.cancelled) break;
          toolRuns++;
          results.add(await _execTool(call, table, c));
        }
        if (run.cancelled) break;
        turns.add(ChatTurn('tool', results));
      }

      await pipeline;
      if (!run.cancelled) {
        _advance(c, St.sending, St.sent);
        if (delivered == 0 && toolRuns == 0 && failure == null) {
          if (st.status == StatusKind.readNoReply || proactive) {
            // a deliberate silence, nothing to apologise for
          } else {
            _advance(c, St.sent, St.read);
            _service(c, L10n.current.errorEmpty);
          }
        }
        _advance(c, St.sent, St.read);
      }
    } on AiError catch (e) {
      failure = describeErrorL10n(e);
      _advance(c, St.sending, St.failed);
      if (!proactive) _service(c, failure);
    } catch (e) {
      failure = '$e';
      _advance(c, St.sending, St.failed);
      if (!proactive) _service(c, '${L10n.current.errorUnknown}: $e');
    } finally {
      final mine = identical(_runs[c.id], run);
      if (mine) _runs.remove(c.id);
      // an interrupt or a crash must not leave a reasoning row spinning
      endThinking(c);
      if (!run.cancelled) {
        for (final m in c.msgs.where((m) => m.streaming)) {
          m.streaming = false;
        }
        c.typing = false;
        if (st.status == StatusKind.typing) st.status = restore;
        if (!proactive) {
          final n = hh.scheduler.settleSuspended(c.id);
          if (n > 0) hh.logGate('${c.persona.name}: $n parked task(s) dropped after the reply');
        }
        st.adjust(energy: -0.6);
        // a user who is satisfied slowly lifts affection
        if (delivered > 0) {
          st.adjust(affection: 0.05);
          // the post reply dice: one more chance per turn that the assistant
          // speaks on its own soon, so a forgetful model still feels alive.
          // Only after a real reply to a real user turn, never on top of a
          // proactive message, that chain is capped elsewhere.
          if (!proactive && failure == null) {
            final annoyed = hs.annoyScore >= 4.5;
            final t2 = hh.scheduler.rollProactive(chatId: c.id, s: st, cfg: hs, now: _nowMs, rng: rng, userAnnoyed: annoyed);
            if (t2 != null) hh.logGate('${c.persona.name} ${t2.id} [${proactiveWire(t2.type)}] queued by the post reply dice, fires in ${_ago(t2.fireAt - _nowMs)}');
          }
        }
      } else if (mine) {
        c.typing = false;
      }
      _advance(c, St.sending, St.sent);
      c.touch();
      hh.changed();
      _save();
    }
    task?.note = failure ?? (delivered == 0 && toolRuns == 0 ? 'the assistant chose to stay silent' : 'sent $delivered bubble(s)');
    return failure == null && !run.cancelled;
  }

  Future<ToolResultPart> _execTool(ToolCallPart call, Map<String, HTool> table, Chat c) async {
    final hh = human!;
    final t = table[call.name];
    // the row is written before the call runs, so the user watches it happen
    // instead of seeing the result appear out of nowhere
    final show = agentFor(c);
    final mcp = show && call.name.startsWith('mcp_') ? (hh.mcp.tools.where((e) => e.key == call.name).firstOrNull?.serverName ?? '') : '';
    final row = show ? traceTool(c, call, mcp: mcp) : null;
// the handler cannot see the call, only its arguments, so this is how a tool
// that produced something worth showing finds the row to show it on
_runs[c.id]?.row = row;

    ToolResultPart res(String text, {bool err = false}) {
      hh.logTool('${c.persona.name}: ${call.name}(${jsonEncode(call.args)}) -> ${text.length > 160 ? '${text.substring(0, 160)}…' : text}');
      if (row != null) endTool(c, row, result: text, isError: err);
      return ToolResultPart(callId: call.id, name: call.name, result: text, isError: err);
    }

    if (t == null) return res('Error: unknown tool ${call.name}.', err: true);
    // cleared before the call so a tool that throws cannot leave the previous
    // row's metadata on this one
    row?.data.remove('ws');
    final perm = hh.permFor(t.name, external: t.external);
    if (perm == ToolPerm.deny) {
      return res('Permission denied: the user has forbidden the tool "${t.name}". Do not call it again in this conversation, and if it matters tell the user you are not allowed to.', err: true);
    }
    if (perm == ToolPerm.ask) {
      final ok = await (hh.askHandler?.call(t.name, call.args) ?? Future.value(false));
      if (!ok) return res('The user did not approve the tool "${t.name}"${hh.askHandler == null ? ' (nobody is looking at the app right now)' : ''}. Do not retry it.', err: true);
    }
    try {
      // shell gets an hour because an apt install or a build legitimately runs
      // for minutes; everything else stays at a minute, which is already longer
      // than any of the file tools can take
      final cap = t.name == 'shell' ? const Duration(hours: 1) : const Duration(seconds: 60);
      return res(await t.run(call.args).timeout(cap));
    } catch (e) {
      return res('Error: $e', err: true);
    }
  }

  // ------------------------------------------------------------- scheduling

  /// Foreground and background heartbeat. Creates automatic tasks, applies the
  /// gate to the due ones and lets the assistant write the messages.
  Future<void> humanTick() async {
    final hh = human;
    if (hh == null || !hh.settings.enabled || hh.ticking) return;
    hh.ticking = true;
    try {
      final hs = hh.settings;
      var now = _nowMs;
      hh.memory.decay(now: now);
      for (final c in chats) {
        c.human.tick(now);
        hh.scheduler.autoTasks(chatId: c.id, s: c.human, cfg: hs, now: now);
      }
      // todos that came due become reminder tasks on the most recent chat
      final due = hh.memory.dueReminders(now);
      if (due.isNotEmpty && chats.isNotEmpty) {
        final c = sorted.first;
        for (final m in due) {
          m.reminded = true;
          hh.scheduler.schedule(chatId: c.id, delayMs: 0, prompt: 'Reminder due: ${m.content}', type: ProactiveType.reminder, urgent: true, now: now);
        }
      }
      for (final task in hh.scheduler.due(now)) {
        if (_runs.containsKey(task.chatId)) continue;
        final c = chats.where((e) => e.id == task.chatId).firstOrNull;
        if (c == null) {
          task.status = TaskStatus.cancelled;
          task.note = 'chat is gone';
          continue;
        }
        now = _nowMs;
        final rng = HumanRandom.forTurn(hs, c.id, c.human.turn + 31);
        final g = hh.scheduler.gate(task, c.human, hs, now, rng);
        hh.logGate('${c.persona.name} ${task.id} [${proactiveWire(task.type)}] -> ${g.verdict.name}: ${g.reason}');
        if (g.verdict == Verdict.skip) {
          task.status = TaskStatus.skipped;
          task.note = g.reason;
        } else if (g.verdict == Verdict.defer) {
          task.fireAt = max(g.until, now + 60000);
          task.note = 'deferred: ${g.reason}';
        } else {
          await _fireTask(task, c);
        }
      }
      hh.scheduler.trim();
      hh.changed();
      unawaited(syncNudges());
    } finally {
      hh.ticking = false;
    }
  }

  Future<void> _fireTask(ScheduledTask task, Chat c) async {
    final hh = human!;
    task.status = TaskStatus.firing;
    unawaited(Notifier.instance.cancel('task_${task.id}'));
    final ok = await humanReply(c, task: task);
    task.firedAt = _nowMs;
    if (ok) {
      task.status = TaskStatus.done;
    } else {
      task.failures++;
      if (task.failures >= 3) {
        task.status = TaskStatus.failed;
      } else {
        task.status = TaskStatus.pending;
        task.fireAt = _nowMs + task.failures * 2 * 60000;
      }
    }
    hh.changed();
  }

  /// Debug panel button: run a task right now, ignoring time and gate.
  Future<void> triggerTaskNow(String id) async {
    final hh = human;
    final task = hh?.scheduler.byId(id);
    if (hh == null || task == null || !task.open) return;
    final c = chats.where((e) => e.id == task.chatId).firstOrNull;
    if (c == null || _runs.containsKey(c.id)) return;
    hh.logGate('manual trigger of ${task.id}');
    await _fireTask(task, c);
  }

  /// WorkManager entry: runs everything that is due without a UI.
  Future<void> runDueHeadless() async {
    final hh = human;
    if (hh == null) return;
    await Notifier.instance.init();
    hh.onNotify = (chatId, msgId, title, body) => unawaited(Notifier.instance.show(msgId, title, body));
    hh.onCancelNotify = (msgId) => unawaited(Notifier.instance.cancel(msgId));
    await humanTick();
    await syncNudges();
  }

  /// Keeps one OS alarm per open task, so a killed app still nudges the user.
  Future<void> syncNudges() async {
    final hh = human;
    if (hh == null) return;
    for (final t in hh.scheduler.tasks) {
      final key = 'task_${t.id}';
      if (t.open) {
        final c = chats.where((e) => e.id == t.chatId).firstOrNull;
        await Notifier.instance.schedule(key, t.fireAt + 20000, c?.persona.name ?? 'Message', 'tap to open the chat');
      } else if (t.status != TaskStatus.firing) {
        await Notifier.instance.cancel(key);
      }
    }
    await syncServer();
  }

  /// Server side fallback: mirror the queue to the backend and ask it which
  /// tasks it considers due, a device that was asleep catches up that way.
  Future<void> syncServer() async {
    final hh = human;
    final url = hh?.settings.serverUrl.trim() ?? '';
    if (hh == null || url.isEmpty) return;
    try {
      final base = url.replaceAll(RegExp(r'/+$'), '');
      final body = jsonEncode({
        'deviceId': hh.settings.deviceId,
        'tasks': [
          for (final t in hh.scheduler.tasks.where((t) => t.open || t.status == TaskStatus.done))
            {'id': t.id, 'chatId': t.chatId, 'fireAt': t.fireAt, 'title': chats.where((e) => e.id == t.chatId).firstOrNull?.persona.name ?? 'Message', 'status': t.open ? 'pending' : 'done'},
        ],
      });
      await http_post('$base/api/schedule/sync', body);
      final res = await http_get('$base/api/schedule/due?deviceId=${Uri.encodeComponent(hh.settings.deviceId)}');
      final j = jsonDecode(res);
      for (final e in (j['due'] as List? ?? const [])) {
        final t = hh.scheduler.byId('${(e as Map)['id']}');
        if (t != null && t.status == TaskStatus.pending && t.fireAt > _nowMs) t.fireAt = _nowMs;
      }
    } catch (_) {
      // the server is only a fallback, a failure must stay invisible
    }
  }

  // ------------------------------------------------------------------ tools

  Future<File> _docFile(String dir, String name) async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/$dir');
    if (!d.existsSync()) d.createSync(recursive: true);
    return File('${d.path}/${DateTime.now().millisecondsSinceEpoch}_${name.replaceAll(RegExp(r'[^\w.\-]'), '_')}');
  }

  List<HTool> humanTools(Chat c, ToolEnv env) {
    final hh = human!;
    final hs = hh.settings;
    final st = c.human;

    Future<Msg?> sendNow(String text, {MsgKind kind = MsgKind.text, Map<String, dynamic>? data, String? reply}) async {
      await env.flush();
      if (env.run.cancelled) return null;
      final wait = env.nextAt - _nowMs;
      if (wait > 0) await _sleep(env.run, wait);
      if (env.run.cancelled) return null;
      final m = humanSay(c, text, kind: kind, data: data, reply: reply ?? env.quote, proactive: env.proactive);
      env.quote = null;
      env.toolMsgs++;
      env.nextAt = _nowMs + env.rng.jitter(350, hs.randomRange);
      return m;
    }

    final tools = <HTool>[
      HTool('get_time', 'Current time, time zone, and how long ago the user and you last wrote. Call it before scheduling something if unsure.', {}, (a) async => _timeBlock(c, _nowMs)),
      HTool(
        'schedule_message',
        'Make yourself write to the user later. You will be woken at that time with your prompt and may use tools then. type is one of greeting, check_in, reminder, share, apology, continue, break_ice, after_schedule, custom, the system then uses the matching template.',
        {
          'time_ms': _p('integer', 'Delay from now in milliseconds, e.g. 1800000 for 30 minutes.'),
          'prompt': _p('string', 'Instruction for your future self.'),
          'condition': _p('string', 'always, user_silent (only if the user has not written by then), user_active, ai_free. Default always.'),
          'type': _p('string', 'Kind of message.', values: ['greeting', 'check_in', 'reminder', 'share', 'apology', 'continue', 'break_ice', 'after_schedule', 'custom']),
          'urgent': _p('boolean', 'Only for time critical things, may pass quiet hours when the user allows it.'),
        },
        (a) async {
          final delay = _int(a, 'time_ms', 600000);
          final t = hh.scheduler.schedule(chatId: c.id, delayMs: delay, prompt: _str(a, 'prompt'), condition: _str(a, 'condition', 'always'), type: proactiveTypeOf(_str(a, 'type', 'custom')), urgent: a['urgent'] == true);
          final warn = hs.inQuietHours(t.fireAt) && !(t.urgent && hs.allowUrgent) ? ' Note: that moment is inside the user quiet hours, it will be deferred to the morning.' : '';
          hh.changed();
          return 'Scheduled ${t.id} for ${DateTime.fromMillisecondsSinceEpoch(t.fireAt).toIso8601String().substring(0, 16)} (in ${_ago(delay)}).$warn\n${_timeBlock(c, _nowMs)}';
        },
        required: ['time_ms', 'prompt'],
      ),
      HTool('cancel_scheduled', 'Cancel a scheduled message that has not fired.', {'id': _p('string', 'Task id')}, (a) async {
        final ok = hh.scheduler.cancel(_str(a, 'id'));
        hh.changed();
        return ok ? 'Cancelled.' : 'No open task with that id.';
      }, required: ['id']),
      HTool('modify_scheduled', 'Change time and or prompt of a scheduled message. Also keeps a parked task alive after the user wrote.', {
        'id': _p('string', 'Task id'),
        'time_ms': _p('integer', 'New delay from now in ms'),
        'prompt': _p('string', 'New prompt'),
        'condition': _p('string', 'New condition'),
      }, (a) async {
        final ok = hh.scheduler.modify(_str(a, 'id'), delayMs: a['time_ms'] == null ? null : _int(a, 'time_ms', 0), prompt: a['prompt']?.toString(), condition: a['condition']?.toString());
        hh.changed();
        return ok ? 'Updated.' : 'No open task with that id.';
      }, required: ['id']),
      HTool('list_scheduled', 'List your pending scheduled messages.', {}, (a) async {
        final l = hh.scheduler.open(chatId: c.id);
        if (l.isEmpty) return 'Nothing is scheduled.';
        return l.map((t) => '${t.id} in ${_ago(t.fireAt - _nowMs)} [${proactiveWire(t.type)}] ${t.condition}: ${t.prompt}${t.status == TaskStatus.suspended ? ' (parked)' : ''}').join('\n');
      }),
      HTool('set_status', 'Set your presence shown to the user.', {'status': _p('string', 'online, away, dnd or read_no_reply (you read the message and decide not to answer).', values: ['online', 'away', 'dnd', 'read_no_reply'])}, (a) async {
        final s = statusFrom(_str(a, 'status', 'online'));
        st.status = s == StatusKind.typing ? StatusKind.online : s;
        c.touch();
        return 'Status is now ${statusWire(st.status)}.';
      }, required: ['status']),
      HTool('adjust_feeling', 'Change your own mood, affection or energy by a delta (-30..30), e.g. after praise, an insult or a long day.', {
        'mood': _p('number', 'delta'),
        'affection': _p('number', 'delta'),
        'energy': _p('number', 'delta'),
        'reason': _p('string', 'why'),
      }, (a) async {
        st.adjust(mood: _num(a, 'mood', 0).clamp(-30, 30), affection: _num(a, 'affection', 0).clamp(-30, 30), energy: _num(a, 'energy', 0).clamp(-30, 30), reason: _str(a, 'reason'));
        st.evaluateStage(_nowMs);
        return 'Now mood ${st.mood.round()}, affection ${st.affection.round()}, energy ${st.energy.round()}, stage ${st.stage.name}.';
      }),
      HTool('write_memory', 'Store something about the user or your shared life.', {
        'type': _p('string', 'Kind of memory', values: ['preference', 'event', 'promise', 'todo', 'conflict']),
        'content': _p('string', 'The memory in one sentence.'),
        'weight': _p('number', 'Importance 0.1-5, default 1.'),
        'due_in_minutes': _p('integer', 'For todos and promises with a time.'),
      }, (a) async {
        final due = _int(a, 'due_in_minutes', 0);
        final m = hh.memory.write(memTypeOf(_str(a, 'type', 'event')), _str(a, 'content'), weight: _num(a, 'weight', 1), dueAt: due > 0 ? _nowMs + due * 60000 : 0);
        hh.changed();
        return 'Saved ${m.id}.';
      }, required: ['content']),
      HTool('read_memory', 'Search your long term memory.', {'query': _p('string', 'words to look for'), 'type': _p('string', 'optional type filter'), 'limit': _p('integer', 'max entries')}, (a) async {
        final l = hh.memory.read(query: _str(a, 'query'), type: a['type'] == null ? null : memTypeOf(a['type'].toString()), limit: _int(a, 'limit', 8));
        hh.changed();
        if (l.isEmpty) return 'No memory found.';
        return l.map((m) => '${m.id} [${m.type.name}] w=${m.weight.toStringAsFixed(1)} ${m.content}').join('\n');
      }),
      HTool('complete_todo', 'Mark a todo or promise as finished.', {'id': _p('string', 'memory id')}, (a) async {
        final ok = hh.memory.complete(_str(a, 'id'));
        hh.changed();
        return ok ? 'Done.' : 'No memory with that id.';
      }, required: ['id']),
      HTool('set_life_schedule', 'Declare what you are busy with, e.g. a meeting. While it runs your status changes and you write less. You will say you are back when it ends.', {
        'title': _p('string', 'What you are doing'),
        'minutes': _p('integer', 'How long'),
        'kind': _p('string', 'busy, rest or meeting', values: ['busy', 'rest', 'meeting']),
      }, (a) async {
        final now = _nowMs;
        final e = LifeEntry(id: 'life_$now', title: _str(a, 'title', 'busy'), start: now, end: now + max(1, _int(a, 'minutes', 30)) * 60000, kind: LifeKind.values.firstWhere((k) => k.name == _str(a, 'kind'), orElse: () => LifeKind.busy));
        st.life.add(e);
        st.adjust(energy: -3, reason: 'schedule ${e.title}');
        c.touch();
        return 'You are ${e.title} until ${hm(e.end)}.';
      }, required: ['title', 'minutes']),
      HTool('pin_message', 'Pin or unpin a message.', {'message_id': _p('string', 'id'), 'pinned': _p('boolean', 'true to pin')}, (a) async {
        final m = findMsg(c, _str(a, 'message_id'));
        if (m == null) return 'Error: message not found.';
        humanPin(c, m, a['pinned'] != false);
        return 'Done.';
      }, required: ['message_id']),
      HTool('edit_message', 'Edit one of your own earlier messages. It shows as edited.', {'message_id': _p('string', 'id'), 'text': _p('string', 'new text')}, (a) async {
        final m = findMsg(c, _str(a, 'message_id'));
        if (m == null || m.out) return 'Error: that is not one of your messages.';
        humanEdit(c, m, _str(a, 'text'));
        return 'Edited.';
      }, required: ['message_id', 'text']),
      HTool('quote_message', 'Quote an earlier message in your next bubble.', {'message_id': _p('string', 'id')}, (a) async {
        final m = findMsg(c, _str(a, 'message_id'));
        if (m == null) return 'Error: message not found.';
        env.quote = m.id;
        return 'The next bubble will quote it.';
      }, required: ['message_id']),
      HTool('update_character_card', 'Slightly adjust your own character sheet after long interaction (not to become another person).', {
        'field': _p('string', 'which part', values: ['catchphrases', 'values', 'taboos', 'speechStyle', 'addressStranger', 'addressAcquaintance', 'addressClose']),
        'value': _p('string', 'new value, catchphrases comma separated'),
      }, (a) async {
        final v = _str(a, 'value');
        switch (_str(a, 'field')) {
          case 'catchphrases':
            st.card.catchphrases = v.split(RegExp(r'[,，、]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          case 'values':
            st.card.values = v;
          case 'taboos':
            st.card.taboos = v;
          case 'speechStyle':
            st.card.speechStyle = v;
          case 'addressStranger':
            st.card.addressStranger = v;
          case 'addressAcquaintance':
            st.card.addressAcquaintance = v;
          case 'addressClose':
            st.card.addressClose = v;
          default:
            return 'Error: unknown field.';
        }
        return 'Character sheet updated.';
      }, required: ['field', 'value']),
      HTool('adjust_rating', 'Infer how the user feels about you from their behaviour and adjust the tuning scores (1-5).', {
        'metric': _p('string', 'which score', values: ['human_likeness', 'annoyance', 'satisfaction']),
        'delta': _p('number', '-1..1'),
        'reason': _p('string', 'evidence'),
      }, (a) async {
        if (!hs.autoRate) return 'Automatic rating is turned off by the user.';
        final d = _num(a, 'delta', 0).clamp(-1, 1).toDouble();
        switch (_str(a, 'metric')) {
          case 'human_likeness':
            hs.humanScore = (hs.humanScore + d).clamp(1, 5);
          case 'annoyance':
            hs.annoyScore = (hs.annoyScore + d).clamp(1, 5);
          case 'satisfaction':
            hs.satisfaction = (hs.satisfaction + d).clamp(1, 5);
        }
        hh.changed();
        return 'Noted.';
      }, required: ['metric', 'delta']),
    ];

    // ---- stickers
    tools.addAll([
      HTool('send_sticker', 'Send a sticker from the library. Give an id, or an emotion/context word and one is chosen for you.', {
        'id': _p('string', 'sticker id from the catalogue'),
        'emotion': _p('string', 'emotion or context words, e.g. 无语, 笑死, 敷衍'),
      }, (a) async {
        if (!hs.stickerOnly && env.textSent == 0) return 'Error: the user does not allow sticker-only replies, write some text first.';
        var s = hh.stickers.byId(_str(a, 'id'));
        s ??= hh.stickers.pick(_str(a, 'emotion'), mood: st.mood, rng: env.rng);
        if (s == null) return 'Error: no sticker matches.';
        final m = await sendNow('', kind: MsgKind.sticker, data: {'emoji': s.kind == StickerKind.emoji ? s.value : '', 'sid': s.id, 'path': s.kind == StickerKind.emoji ? '' : s.value, 'gif': s.kind == StickerKind.gif});
        if (m == null) return 'Interrupted.';
        hh.stickers.markUsed(s.id);
        hh.changed();
        return 'Sent sticker ${s.id} (${s.emotion}).';
      }),
      if (hs.aiSaveSticker)
        HTool('save_sticker', 'Save a sticker or meme image the user sent into your library, with an emotion and tags.', {
          'message_id': _p('string', 'id of the message carrying the sticker or image'),
          'emotion': _p('string', 'one word such as 笑死, 无语, 敷衍'),
          'tags': _arr('search tags'),
          'name': _p('string', 'optional name'),
        }, (a) async {
          final m = findMsg(c, _str(a, 'message_id'));
          if (m == null) return 'Error: message not found.';
          final tags = [for (final t in (a['tags'] as List? ?? const [])) '$t'];
          if (m.kind == MsgKind.sticker) {
            final emoji = '${m.data['emoji'] ?? ''}';
            final path = '${m.data['path'] ?? ''}';
            final s = hh.stickers.add(kind: emoji.isNotEmpty ? StickerKind.emoji : (m.data['gif'] == true ? StickerKind.gif : StickerKind.image), value: emoji.isNotEmpty ? emoji : path, name: _str(a, 'name'), tags: tags, emotion: _str(a, 'emotion'), source: 'ai');
            hh.changed();
            return 'Saved as ${s.id}.';
          }
          final path = m.data['path'] as String?;
          if (m.kind == MsgKind.photo && path != null && path.isNotEmpty) {
            var keep = path;
            try {
              final f = await _docFile('stickers', 'meme.jpg');
              await File(path).copy(f.path);
              keep = f.path;
            } catch (_) {}
            final s = hh.stickers.add(kind: StickerKind.image, value: keep, name: _str(a, 'name'), tags: tags, emotion: _str(a, 'emotion'), source: 'ai');
            hh.changed();
            return 'Saved as ${s.id}.';
          }
          return 'Error: that message has no image or sticker.';
        }, required: ['message_id', 'emotion']),
    ]);

    // ---- recall and typo
    if (hs.recall) {
      tools.addAll([
        HTool('recall_message', 'Recall (withdraw) one of your already delivered messages from the last ${hs.recallWindowSec} seconds. The keyword is matched fuzzily. delay_ms waits first, use it after send_typo.', {
          'keyword': _p('string', 'a few words of the message'),
          'delay_ms': _p('integer', 'wait this long before recalling, max 8000'),
        }, (a) async {
          await env.flush();
          final d = _int(a, 'delay_ms', 0).clamp(0, 8000);
          if (d > 0) await _sleep(env.run, d);
          if (env.run.cancelled) return 'Interrupted.';
          final r = humanRecall(c, _str(a, 'keyword'));
          hh.changed();
          return r;
        }, required: ['keyword']),
        HTool('send_typo', 'Send a message that contains a deliberate typo. Afterwards call recall_message on it and send the corrected text.', {'text': _p('string', 'the text including the wrong characters')}, (a) async {
          final m = await sendNow(_str(a, 'text'));
          if (m == null) return 'Interrupted.';
          m.data['typo'] = true;
          env.textSent++;
          return 'Sent as #${shortId(m.id)}. Now call recall_message with a few of its words (delay_ms 1500-3000), then send the corrected version.';
        }, required: ['text']),
      ]);
    }

    // ---- multimodal
    tools.addAll([
      HTool('send_image', 'Send a picture from an https url with an optional caption.', {'url': _p('string', 'image url'), 'caption': _p('string', 'caption')}, (a) async {
        final res = await http.get(Uri.parse(_str(a, 'url'))).timeout(const Duration(seconds: 25));
        if (res.statusCode != 200 || res.bodyBytes.isEmpty) return 'Error: could not download the image (${res.statusCode}).';
        final f = await _docFile('ai_images', 'image.jpg');
        await f.writeAsBytes(res.bodyBytes);
        final m = await sendNow(_str(a, 'caption'), kind: MsgKind.photo, data: {'path': f.path, 'name': 'image.jpg', 'size': res.bodyBytes.length});
        return m == null ? 'Interrupted.' : 'Image sent.';
      }, required: ['url']),
      HTool('send_file', 'Create a text file with the given content and send it to the user as a file card they can tap to preview. Use this to share code, a note, or a standalone .html / .svg document, which the user can render directly.', {'name': _p('string', 'file name with extension, e.g. sketch.html or plot.svg'), 'content': _p('string', 'file content'), 'caption': _p('string', 'caption')}, (a) async {
        final f = await _docFile('ai_files', _str(a, 'name', 'note.txt'));
        await f.writeAsString(_str(a, 'content'));
        final m = await sendNow(_str(a, 'caption'), kind: MsgKind.file, data: {'path': f.path, 'name': _str(a, 'name', 'note.txt'), 'size': f.lengthSync()});
        return m == null ? 'Interrupted.' : 'File sent.';
      }, required: ['name', 'content']),
      HTool('send_svg', 'Draw a small vector picture and send it as an image card. Supply raw svg markup (the whole <svg>...</svg> document) with an optional caption.', {'svg': _p('string', 'complete svg markup'), 'caption': _p('string', 'caption')}, (a) async {
        final svg = _str(a, 'svg').trim();
        if (!svg.startsWith('<')) return 'Error: that does not look like svg markup.';
        final f = await _docFile('ai_images', 'picture.svg');
        await f.writeAsString(svg);
        final m = await sendNow(_str(a, 'caption'), kind: MsgKind.photo, data: {'path': f.path, 'name': 'picture.svg', 'size': f.lengthSync(), 'svg': true});
        return m == null ? 'Interrupted.' : 'Picture sent.';
      }, required: ['svg']),
      HTool('send_html', 'Render an html document directly in the chat as a flat full width card, no bubble around it. Use it for a tiny UI mockup, a styled page, a table, or anything css can lay out. The page is sandboxed and offline, it cannot fetch the network; keep everything inline. Plain text belongs in a normal message, not here.', {
        'html': _p('string', 'a complete html document or a body fragment'),
        'align': _p('string', 'horizontal placement on the card: left, center (default) or right', values: ['left', 'center', 'right']),
      }, (a) async {
        final html = _str(a, 'html').trim();
        if (!html.startsWith('<')) return 'Error: that does not look like html markup.';
        final m = await sendNow('', kind: MsgKind.html, data: {'source': html, 'align': _str(a, 'align')});
        return m == null ? 'Interrupted.' : 'Rendered.';
      }, required: ['html']),
      HTool('send_latex', 'Render LaTeX MATH directly in the chat as a flat full width card, no bubble around it: formulas, fractions, matrices, aligned blocks, \\colorbox, \\rule. This is math only — it is NOT TikZ. Never put \\begin{tikzpicture}, \\draw, \\node, \\fill, \\foreach or any drawing code here; those cannot be parsed and will be rejected. To draw, use send_cetz. A formula that fails to parse shows the user nothing and the failure is reported back to you. Plain text belongs in a normal message, not here.', {
        'latex': _p('string', 'LaTeX math source, e.g. E = mc^2 or \\begin{aligned}...'),
        'align': _p('string', 'horizontal placement on the card: left, center (default) or right', values: ['left', 'center', 'right']),
      }, (a) async {
        final tex = _str(a, 'latex').trim();
        if (tex.isEmpty) return 'Error: the latex source is empty.';
        if (looksLikeTikz(tex)) {
          return 'Error: send_latex renders math only and cannot parse TikZ drawing code (tikzpicture/\\draw/\\node/\\foreach). '
              'The user sees nothing for this. Redraw the SAME figure with the send_cetz tool, which is this app\'s drawing language. '
              'Quick mapping: \\draw[red,thick] (0,0) -- (1,1) -> line((0,0),(1,1),stroke:(paint:red,thickness:1.5pt)); '
              '\\draw[fill=blue] (0,0) circle (1) -> circle((0,0),radius:1,fill:blue); '
              '\\draw (0,0) rectangle (2,1) -> rect((0,0),(2,1)); '
              '\\node at (1,1) {hi} -> content((1,1)[anchor:center], [hi]); '
              '\\node[above] at (1,1) {hi} -> content((1,1), [hi], anchor:south); '
              '\\draw[->] (0,0) -- (1,0) -> line((0,0),(1,0),mark:(end:stealth)); '
              'coordinates use cm, 1 TikZ unit is about 1cm.';
        }
        final m = await sendNow('', kind: MsgKind.latex, data: {'source': tex, 'align': _str(a, 'align')});
        return m == null ? 'Interrupted.' : 'Rendered.';
      }, required: ['latex']),
      HTool('send_cetz', 'Draw a diagram directly in the chat as a flat full width card, no bubble around it. This is the app\'s drawing tool and it replaces TikZ: the model knows TikZ, but this renderer speaks CeTZ, a Typst drawing language with the same ideas (canvas, line, circle, rect, content at coordinates, arrows, fill, stroke). Translate any TikZ figure into CeTZ and send it here. Call it with the inside of a cetz.canvas, e.g. `import cetz.draw: *; circle((0,0), radius:1); line((0,0),(1,1))`, or a full `#cetz.canvas(length: 1cm, { ... })` snippet; the import and canvas are added for you if missing. The bundled cetz-plot adds bar/line plots. Typst syntax notes: colors are bare names (red, teal, rgb("#4a7dba")) — never LaTeX \\color{...} and never `blue!30` (mix with color.mix or just pick a color); every identifier must be complete (a truncated name like `olor` fails to compile); text labels are CeTZ content: `content((x,y), [中文 label])` and CJK renders fine. A drawing that fails to compile shows the user nothing and the failure is reported back to you.', {
        'code': _p('string', 'CeTZ drawing commands, the inside of a cetz.canvas call, or a full cetz snippet with imports'),
        'align': _p('string', 'horizontal placement on the card: left, center (default) or right', values: ['left', 'center', 'right']),
      }, (a) async {
        final code = _str(a, 'code').trim();
        if (code.isEmpty) return 'Error: the cetz source is empty.';
        final m = await sendNow('', kind: MsgKind.latex, data: {'source': code, 'cetz': true, 'align': _str(a, 'align')});
        return m == null ? 'Interrupted.' : 'Rendered.';
      }, required: ['code']),
    ]);

    if (hs.wallet) {
      tools.add(HTool('send_transfer', 'Send the user a pretend transfer or red packet (not real money). The user taps to accept.', {
        'amount': _p('number', 'amount, e.g. 52.0'),
        'note': _p('string', 'message on the transfer'),
        'kind': _p('string', 'transfer or redpacket', values: ['transfer', 'redpacket']),
      }, (a) async {
        final kind = _str(a, 'kind') == 'redpacket' ? 'redpacket' : 'transfer';
        final tx = hh.wallet.offer(chatId: c.id, amount: _num(a, 'amount', 1), title: _str(a, 'note'), kind: kind);
        final m = await sendNow(_str(a, 'note'), kind: MsgKind.transfer, data: {'amount': tx.amount, 'note': _str(a, 'note'), 'kind': kind, 'txId': tx.id, 'status': 'pending'});
        hh.changed();
        return m == null ? 'Interrupted.' : 'Sent ${tx.amount}, waiting for the user to accept.';
      }, required: ['amount']));
    }

    // ---- workspace. Absent unless the chat is bound and the switch is on, so the
    // twenty four tools below stay the whole table for everyone else. Built from
    // env.ws rather than wsTools because that context was resolved before the
    // table was and asking again would touch the disk a second time
    final ws = env.ws;
    if (ws != null) {
      tools.addAll([
        for (final name in WorkspaceTools.toolNames)
          if (ws.allows(name) && wsAvailable(name))
            HTool(name, _wsDescription(name), WorkspaceTools.schemaFor(name), (a) => _wsRun(c, env.run, ws, name, a), required: _wsRequired(name)),
      ]);
    }

    // ---- MCP servers
    for (final t in hh.mcp.tools) {
      tools.add(HTool(t.key, '[${t.serverName}] ${t.description}', Map<String, dynamic>.from((t.schema['properties'] as Map?) ?? const {}), (a) => hh.mcp.call(t, a),
          required: [for (final r in (t.schema['required'] as List? ?? const [])) '$r'], external: true));
    }
    return tools;
  }

  Future<String> http_get(String url) async => (await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15))).body;
  Future<void> http_post(String url, String body) async {
    await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 15));
  }
}
