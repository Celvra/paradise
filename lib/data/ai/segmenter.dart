import 'dart:math';

// character mode splits one generation into several short messages
// newline and br tags are hard boundaries, length is the safety net
final _break = RegExp(r'\r?\n|<\s*br\s*/?\s*>', caseSensitive: false);
final _sentence = RegExp(r'[。！？!?…]');
const _hardCap = 120;
const _minLen = 2;
const _maxLen = 400;

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
_Break? _findBreak(String buffer) {
  final m = _break.firstMatch(buffer);
  if (m != null) return _Break(m.start, m.group(0)!.length);
  if (buffer.length < _hardCap) return null;
  // no boundary yet so cut at the nearest sentence end inside the window
  var last = -1;
  for (final s in _sentence.allMatches(buffer)) {
    if (s.start > _hardCap) break;
    last = s.start;
  }
  if (last > 0) return _Break(last, 1);
  return _Break(_hardCap, 0);
}

class Segmenter {
  Segmenter({bool strip = true}) : _strip = strip;
  final bool _strip;
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
    if (text.length < _minLen) {
      _carry += text;
      return null;
    }
    if (_carry.isEmpty) return text;
    final merged = _carry + text;
    _carry = '';
    return merged;
  }

  // the break tag itself never lands inside a segment
  String? _take(int cut, int consumed) {
    final raw = _buffer.substring(0, cut);
    _buffer = _buffer.substring(cut + consumed);
    if (raw.length > _maxLen) {
      _buffer = raw.substring(_maxLen) + _buffer;
      return _finish(_clean(raw.substring(0, _maxLen)));
    }
    return _finish(_clean(raw));
  }

  List<String> push(String delta) {
    _buffer += delta;
    final out = <String>[];
    for (;;) {
      final hit = _findBreak(_buffer);
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
int humanDelay(String text, {Random? random}) {
  final base = min(1500, 250 + text.length * 22);
  final r = random ?? Random();
  final jittered = base * (0.75 + r.nextDouble() * 0.5);
  return min(1500, max(180, jittered.round()));
}