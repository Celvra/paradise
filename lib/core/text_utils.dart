import 'package:flutter/widgets.dart';

// matched text goes accent and medium like the search cells
List<InlineSpan> hlSpans(String text, String q, TextStyle base, Color accent, {Color? bg}) {
  final s = q.trim().toLowerCase();
  if (s.isEmpty) return [TextSpan(text: text, style: base)];
  final low = text.toLowerCase();
  final out = <InlineSpan>[];
  var at = 0;
  while (true) {
    final i = low.indexOf(s, at);
    if (i < 0) break;
    if (i > at) out.add(TextSpan(text: text.substring(at, i), style: base));
    out.add(TextSpan(text: text.substring(i, i + s.length), style: bg != null ? base.copyWith(backgroundColor: bg) : base.copyWith(color: accent, fontWeight: FontWeight.w500)));
    at = i + s.length;
  }
  if (at < text.length) out.add(TextSpan(text: text.substring(at), style: base));
  return out;
}

// crop around the first hit so it stays visible on one line
String snippet(String text, String q) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final s = q.trim().toLowerCase();
  if (s.isEmpty) return t;
  final i = t.toLowerCase().indexOf(s);
  if (i > 24) return '…${t.substring(i - 20)}';
  return t;
}
