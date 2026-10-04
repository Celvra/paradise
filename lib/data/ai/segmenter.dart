import 'dart:math';

// character mode splits one generation into several short messages
// newline and br tags are hard boundaries, length is the safety net
// where the safety net cuts and whether a short bubble merges into the
// next one are rolled per reply, so two replies rarely come out the
// same shape even from the same model
final _break = RegExp(r'\r?\n|<\s*br\s*/?\s*>', caseSensitive: false);
final _sentence = RegExp(r'[。！？!?…]');
final _clause = RegExp(r'[，、,;；：:]');

// a bubble shorter than this may be held back to ride with the next one
const _mergeMax = 40;

String stripMarkdown(String text) => text
    .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
    .replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1) ?? '')
    .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
    .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1) ?? '')
    .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
    .replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '')
    .replaceAll(RegExp(r'^\s{0,3}([-*+]|\d+\.)\s+', multiLine: true), '')
    .replaceAllMapped(RegExp(r'(\*\*|__)(.*?)\1'), (m) => m.group(2) ?? '')
    .replaceAllMapped(RegExp(r'(\*|_)(.*?)\1'), (m) => m.group(2) ?? '')
    .replaceAllMapped(RegExp(r'~~(.*?)~~'), (m) => m.group(1) ?? '')
    .replaceAll('|', ' ')
    .replaceAll(RegExp(r'\n{2,}'), '\n')
    .trim();

class _Break {
  const _Break(this.cut, this.consumed);
  final int cut;
  final int consumed;
}

// returns the index to cut at and how many trailing chars the tag consumed
// the cap and the boundary preference are rolled per segmenter so replies
// differ in shape
_Break? _findBreak(String buffer, _Shape shape) {
  final m = _break.firstMatch(buffer);
  if (m != null) return _Break(m.start, m.group(0)!.length);
  if (buffer.length < shape.cap) return null;
  // no boundary yet so cut at the nearest sentence or clause end inside the
  // window, a clause cut makes a mid thought bubble which is exactly the
  // human rhythm the fixed sentence cut never had
  var last = -1;
  for (final s in _sentence.allMatches(buffer)) {
    if (s.start > shape.cap) break;
    last = s.start;
  }
  if (last < 0 && shape.clause) {
    for (final s in _clause.allMatches(buffer)) {
      if (s.start > shape.cap) break;
      last = s.start;
    }
  }
  if (last > 0) return _Break(last, 1);
  return _Break(shape.cap, 0);
}

// per reply dice, built once by the segmenter
class _Shape {
  _Shape(Random r)
      : cap = _hardCapMin + r.nextInt(_hardCapMax - _hardCapMin),
        clause = r.nextBool(),
        merge = r.nextDouble() < _mergeProb;

  // the safety net cap varies so long runs of text do not always land at the
  // same width
  final int cap;
  // whether the safety net may also cut at a comma
  final bool clause;
  // whether short bubbles are merged into the following one
  final bool merge;
}

const _hardCapMin = 90;
const _hardCapMax = 160;
const _mergeProb = 0.35;

class Segmenter {
  Segmenter({bool strip = true, Random? random}) : _strip = strip, _shape = _Shape(random ?? Random());
  final bool _strip;
  final _Shape _shape;
  var _buffer = '';
  // fragments shorter than the minimum are never dropped
  // they ride along with the next segment instead
  var _carry = '';

  String _clean(String raw) {
    final trimmed = raw.trim();
    return _strip ? stripMarkdown(trimmed) : trimmed;
  }

  String? _finish(String text) {
    if (text.isEmpty) return null;
    // a held fragment always fuses into the very next segment, the merge is
    // one bubble wide never a chain, otherwise the whole reply piles up in
    // the carry and the reader sees nothing until the stream ends
    if (_carry.isNotEmpty) {
      final merged = _carry + text;
      _carry = '';
      return merged;
    }
    // a short bubble may be held back to ride with the next one, only
    // sometimes and only when it is a fragment not a sentence of its own
    if (_shape.merge && text.length <= _mergeMax) {
      _carry = text;
      return null;
    }
    return text;
  }

  // the break tag itself never lands inside a segment
  String? _take(int cut, int consumed) {
    final raw = _buffer.substring(0, cut);
    _buffer = _buffer.substring(cut + consumed);
    if (raw.length > _shape.cap) {
      _buffer = raw.substring(_shape.cap) + _buffer;
      return _finish(_clean(raw.substring(0, _shape.cap)));
    }
    return _finish(_clean(raw));
  }

  List<String> push(String delta) {
    _buffer += delta;
    final out = <String>[];
    for (;;) {
      final hit = _findBreak(_buffer, _shape);
      if (hit == null) break;
      final text = _take(hit.cut, hit.consumed);
      if (text != null) out.add(text);
    }
    return out;
  }

  List<String> flush() {
    final out = <String>[];
    if (_buffer.isNotEmpty) {
      final text = _take(_buffer.length, 0);
      if (text != null) out.add(text);
    }
    // a trailing fragment still has to reach the transcript
    if (_carry.isNotEmpty) {
      out.add(_carry);
      _carry = '';
    }
    return out;
  }
}

// jitter stays inside the cap so long messages never stall for too long
// scale is the user pacing knob floor and cap grow with it
// spread is the half span of the dice around the base, 0 is a metronome
int humanDelay(String text, {Random? random, double scale = 1, double spread = 0.25}) {
  final s = scale < 0.1 ? 0.1 : scale;
  final base = min(1500, 250 + text.length * 22);
  final r = random ?? Random();
  final jittered = base * (1 - spread + r.nextDouble() * spread * 2) * s;
  return min((1500 * s).round(), max((180 * s).round(), jittered.round()));
}

// base times a dice factor drawn from 1 - jitter to 1 + jitter
// base zero stays zero, a nonzero base never collapses to nothing
int jitterMs(int base, Random r, [double jitter = 0.35]) {
  if (base <= 0) return 0;
  final f = 1 - jitter + r.nextDouble() * jitter * 2;
  return max(1, (base * f).round());
}

// a cjk char is one keystroke worth, a latin letter about half, so an english
// bubble does not read as ten times the typing of a chinese one
bool _wide(int r) => (r >= 0x3000 && r <= 0x9FFF) || (r >= 0xF900 && r <= 0xFAFF) || (r >= 0xFF00 && r <= 0xFFEF);

// typing a bubble out costs time proportional to its length at a phone
// keyboard pace, the cap keeps one enormous bubble from stalling the whole
// timeline and the floor keeps a two char bubble from flashing by
int typingMs(String text, {Random? random, double spread = 0.2}) {
  var w = 0.0;
  for (final r in text.runes) {
    w += _wide(r) ? 1 : 0.5;
  }
  if (w <= 0) return 0;
  final r = random ?? Random();
  final f = 1 - spread + r.nextDouble() * spread * 2;
  return min(12000, max(500, (w / 8 * f * 1000).round()));
}