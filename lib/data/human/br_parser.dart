// Streaming parser for the <i-br> / <i-br_MS> break tag.
//
// The model writes `早上好。<i-br_500>今天心情如何? <i-br_700>陪我聊会天吧。`
// and this parser cuts the stream into messages while the tokens are still
// arriving. Rules, in the order they matter:
//
//  * '<' opens tag mode, '>' closes it. A closed `<i-br>` or `<i-br_123>` cuts
//    the text collected so far into a segment. Anything else between '<' and
//    '>' is ordinary text and is given back verbatim.
//  * the tag is read generously. Models copy the placeholder out of the prompt
//    and write `<i-br_MS>`, `<i-br 800>`, `<i-br800>` or `<i-br/>`, and a tag
//    that is not understood must still cut the answer instead of leaking into
//    the bubble as text, which is what used to swallow the rest of a turn.
//  * A tag that stops being a possible `<i-br...` prefix is released as text at
//    once, so "a < b" is never held back.
//  * A line break is a break, and an empty line always is. Models separate
//    messages with a plain newline far more often than they write the tag, so
//    refusing to split on one left whole replies inside a single bubble. A
//    newline that arrives before enough text has piled up to stand as a bubble
//    is kept as text instead, otherwise short lines would each become their own
//    bubble.
//  * A model that writes no tag and no blank line at all used to land as one
//    giant bubble. [autoSplitChars] is the fallback: once that much text has
//    piled up with no break in it, the bubble is cut at the nearest sentence or
//    clause boundary and the default pause is used. It is the one rule that
//    fires without the model cooperating, so it only runs when splitting is on
//    and never inside code.
//  * Inside ``` fences and `inline code` the tag is just text, a question about
//    the tag itself must not cut the answer in half.
//  * [abort] throws away everything that was not cut yet, including a half
//    written tag such as `<i-br_5`. Nothing of it ever reaches the user.
//  * [release] is the other half of that: when a pass dies after the model has
//    already written something, the tail is handed over as one last bubble
//    instead of being dropped. A half sentence beats silence.
//  * [finish] ends a normal turn. The tail is a last segment, a dangling
//    half tag is dropped because it was never a message.
//
// Timing is not decided here. A segment carries the delay the model asked for
// and the sender decides how long to really wait (see HumanEngine).

class BrSegment {
  const BrSegment(this.text, this.delayMs, {this.explicit = false});

  /// The finished message text, trimmed.
  final String text;

  /// Pause requested after this segment, before the next one may be shown.
  /// Zero for the last segment of a turn.
  final int delayMs;

  /// True when the model wrote a number itself, false for a bare `<i-br>`.
  final bool explicit;

  @override
  String toString() => 'BrSegment("$text", ${delayMs}ms)';
}

class BrAbort {
  const BrAbort({required this.droppedText, required this.droppedTag});

  /// Text that had been written but never closed by a tag.
  final String droppedText;

  /// The half tag that was cut off, empty when there was none.
  final String droppedTag;
}

// what may still grow into a tag: the name, then separators, then digits or
// the MS placeholder the prompt shows, or a self closing slash
final _tagPrefix = RegExp(r'^<(?:i(?:-(?:b(?:r(?:[0-9_\s/ms-]{0,24})?)?)?)?)?$', caseSensitive: false);
final _tagFull = RegExp(r'^<i-br(?:[_\s-]*ms)?(?:[_\s-]*(\d{1,9}))?\s*/?>$', caseSensitive: false);

class BrParser {
  BrParser({this.defaultDelayMs = 600, this.maxDelayMs = 8000, this.enabled = true, this.autoSplitChars = 72});

  /// Delay used for a bare `<i-br>`, and for a break this parser made up.
  final int defaultDelayMs;
  final int maxDelayMs;

  /// When false the tags are not interpreted, the whole turn is one segment and
  /// any tag that slipped through is stripped. The length fallback is off too:
  /// turning splitting off has to mean one bubble, not "one bubble most of the
  /// time".
  final bool enabled;

  /// How much text may pile up in one bubble before the parser cuts it itself.
  /// Zero turns the fallback off.
  final int autoSplitChars;

  final StringBuffer _text = StringBuffer();
  String _tag = '';
  var _ticks = 0;
  var _fence = false;
  var _inline = false;
  var _aborted = false;
  var _carryDelay = 0;
  var _carryExplicit = false;

  /// newlines seen with nothing but blanks between them. The second one closes
  /// the empty line and that pair is a break.
  var _nlRun = 0;

  bool get aborted => _aborted;

  /// True while the stream is inside a fenced or inline code span.
  bool get inCode => _fence || _inline;

  /// Text collected for the segment that has not been cut yet.
  String get pending => _text.toString();

  /// A tag that is still being written.
  String get openTag => _tag;

  // ------------------------------------------------------------- code state

  void _resolveTicks() {
    if (_ticks == 0) return;
    if (_ticks >= 3) {
      _fence = !_fence;
      _inline = false;
    } else if (_ticks == 1 && !_fence) {
      _inline = !_inline;
    }
    _ticks = 0;
  }

  // ------------------------------------------------------------------- feed

  List<BrSegment> push(String delta) {
    if (_aborted || delta.isEmpty) return const [];
    final out = <BrSegment>[];
    for (final unit in delta.runes) {
      _char(String.fromCharCode(unit), out);
    }
    _autoSplit(out);
    return out;
  }

  // ------------------------------------------------- the no-tag fallback

  // Sentences first, then clauses, then plain whitespace. Ordered so a cut lands
  // on a real pause instead of mid-clause.
  static final _stopSentence = RegExp(r'[。！？!?…]+|[.!?](?=\s|$)');
  static final _stopClause = RegExp(r'[，、,;；：:]+');
  static final _stopSpace = RegExp(r'\s');

  /// Index to cut a made up break at, or 0 when there is nothing to cut.
  ///
  /// Only boundaries at or past [autoSplitChars] count, so a bubble never ends
  /// up shorter than the threshold. Past that point the FIRST boundary wins,
  /// which keeps the bubbles a consistent size instead of letting one of them
  /// swallow the whole answer.
  int _softCut() {
    final s = _text.toString();
    final from = autoSplitChars;
    if (s.length < from) return 0;
    for (final re in [_stopSentence, _stopClause, _stopSpace]) {
      for (final m in re.allMatches(s)) {
        if (m.end > from) return m.end;
      }
    }
    // No punctuation and no space at all, one enormous run of characters. Cut it
    // at the threshold rather than let it grow forever.
    return s.length >= from * 2 ? from : 0;
  }

  /// Cuts bubbles the model did not ask for. See [autoSplitChars].
  void _autoSplit(List<BrSegment> out) {
    // a half written tag could still turn into a real break, and code must
    // never be split
    if (!enabled || autoSplitChars <= 0 || _tag.isNotEmpty || inCode) return;
    while (true) {
      final cut = _softCut();
      if (cut <= 0) return;
      _cutAt(cut, defaultDelayMs, out);
    }
  }

  /// [cut] cuts the buffer but keeps the tail for the next segment, which is
  /// what _cut cannot do: it assumes the whole buffer belongs to one bubble.
  void _cutAt(int cut, int ms, List<BrSegment> out) {
    final full = _text.toString();
    if (cut <= 0 || cut >= full.length) return;
    final text = _trimSegment(full.substring(0, cut));
    _text
      ..clear()
      ..write(full.substring(cut));
    if (text.isEmpty) return;
    out.add(BrSegment(text, ms.clamp(0, maxDelayMs)));
  }

  void _char(String c, List<BrSegment> out) {
    if (_tag.isNotEmpty) {
      final next = _tag + c;
      if (c == '>') {
        final m = _tagFull.firstMatch(next);
        _tag = '';
        if (m != null) {
          final raw = m.group(1);
          _cut(raw == null ? defaultDelayMs : int.parse(raw), raw != null, out);
        } else {
          _text.write(next);
        }
        return;
      }
      if (_tagPrefix.hasMatch(next)) {
        _tag = next;
        return;
      }
      // not a break tag after all, hand the held characters back as text
      _text.write(_tag);
      _tag = '';
      // fall through so this character is looked at again from scratch
    }

    if (c == '`') {
      _ticks++;
      _text.write(c);
      return;
    }
    _resolveTicks();
    if (c == '\n' && !_fence) _inline = false;

    // A line break is a break, and an empty line always is. Models separate
    // messages with a plain newline far more often than they write the tag, and
    // refusing to split on a newline left whole replies inside one bubble with
    // three lines in it.
    //
    // The one exception is a newline arriving while too little text has piled
    // up to stand as a bubble of its own. Cutting there would carve off a
    // fragment like "喵" on its own, so the newline is kept as text and the
    // lines stay together. Keeping it matters: dropping it would join two lines
    // the reader can plainly see were two.
    if (enabled && !inCode && c == '\n') {
      if (_nlRun > 0) {
        // an empty line, or blanks between two of them. This is the form a
        // model reaches for when it forgets the tag entirely, so it cuts
        // whatever is there, however short.
        _nlRun = 0;
        _cut(defaultDelayMs, false, out);
        return;
      }
      _nlRun = 1;
      if (_trimSegment(_text.toString()).length >= _minBreak) {
        _cut(defaultDelayMs, false, out);
        return;
      }
      _text.write(c);
      return;
    }
    // spaces, tabs and carriage returns between two newlines are still that one
    // empty line, anything else ends the run
    if (c != ' ' && c != '\t' && c != '\r') _nlRun = 0;

    if (c == '<' && enabled && !inCode) {
      _tag = '<';
      return;
    }
    _text.write(c);
  }

  void _cut(int ms, bool explicit, List<BrSegment> out) {
    final text = _trimSegment(_text.toString());
    _text.clear();
    final delay = ms.clamp(0, maxDelayMs);
    if (text.isEmpty) {
      // two tags in a row, or a tag at the very start: the pauses add up and
      // belong to the next bubble, they are carried over instead of dropped
      _carryDelay = (_carryDelay + delay).clamp(0, maxDelayMs);
      _carryExplicit = _carryExplicit || explicit;
      return;
    }
    // a pause the model asked for before this text still counts when it did not
    // ask for one after it, so a leading tag is not a pause into nowhere
    final carry = _carryDelay;
    final carriedExplicit = _carryExplicit;
    _carryDelay = 0;
    _carryExplicit = false;
    out.add(BrSegment(text, delay > 0 ? delay : carry, explicit: explicit || carriedExplicit));
  }

  /// Normal end of a turn. Returns the last segment, if any.
  List<BrSegment> finish() {
    if (_aborted) return const [];
    _resolveTicks();
    // a half tag at the end of a finished turn is garbage, never a message
    _tag = '';
    final text = _trimSegment(_text.toString());
    _text.clear();
    if (text.isEmpty) return const [];
    final carry = _carryDelay;
    final carriedExplicit = _carryExplicit;
    _carryDelay = 0;
    _carryExplicit = false;
    return [BrSegment(text, carry, explicit: carriedExplicit)];
  }

  /// The pass failed after the model had already written something. Everything
  /// past the last tag is handed back as one last bubble and the parser stops,
  /// so the tail of an answer is never swallowed by a broken connection.
  List<BrSegment> release() {
    if (_aborted) return const [];
    _resolveTicks();
    _tag = '';
    _aborted = true;
    final text = _trimSegment(_text.toString());
    _text.clear();
    final carry = _carryDelay;
    _carryDelay = 0;
    _carryExplicit = false;
    return text.isEmpty ? const [] : [BrSegment(text, carry)];
  }

  /// Call when the user interrupts. Everything not cut yet is discarded and the
  /// parser stops producing output.
  BrAbort abort() {
    final report = BrAbort(droppedText: _text.toString(), droppedTag: _tag);
    _aborted = true;
    _text.clear();
    _tag = '';
    _ticks = 0;
    return report;
  }
}

/// Shortest text a line break may cut after. Below this the line merges into
/// the next one, so a stray newline cannot produce a two character bubble.
const _minBreak = 6;

String _trimSegment(String s) => s.replaceAll(RegExp(r'^\s+|\s+$'), '');
/// Splits finished text without any timing, used when a message is edited or a
/// history is replayed. The delays come back as zero so nothing waits.
List<String> splitBrText(String text) {
  final p = BrParser();
  final parts = [...p.push(text), ...p.finish()];
  return [for (final s in parts) s.text];
}

/// Anything that still looks like a break tag, however the model spelled it:
/// `<i-br>`, `<i-br_500>`, `<i-br_MS>`, `<i-br800>`, `<i-br/>`. Nothing of it
/// may reach a bubble or the history. `<i-bracket>` is left alone, an angle
/// bracket with something else behind it is ordinary text.
final _tagJunk = RegExp(r'<i-br(?:[_\s-]*ms)?(?:[_\s-]*\d{1,9})?\s*/?>|<i-br[_\s/-]*\d{1,12}\s*/?>', caseSensitive: false);

/// Removes the tags and keeps the text in one piece, for the plain (tags off)
/// path, for a bubble that is about to be shown and for notification previews.
String stripBrTags(String text) => text.replaceAll(_tagJunk, '');
