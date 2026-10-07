/// Minimal oii value codec for backup documents.
///
/// The app vendors `oii_bridge` (a script engine bridge) but backup files must
/// not depend on a native library: they are written on every auto backup tick
/// and must also decode in tests and on machines without cargo. So the backup
/// layer speaks a small, fixed subset of oii with its own encoder and decoder:
///
/// * scalars: `null`, `true`/`false`, ints, doubles (`#inf`, `#-inf`, `#nan`
///   mirroring the rust formatter), quoted strings.
/// * every string rides as a raw string (`#"..."#`, growing hashes when the
///   content holds `"#`): plain `"..."` strings interpolate `{var}` in oii,
///   which would eat chat text, while raw strings never interpolate.
/// * arrays: `[a, b]` (empty is `[]`).
/// * maps: `(map)[["k", v], ...]` (empty is `(map)[]`). oii has no map literal
///   (the rust formatter renders runtime maps as pair arrays), so the `map`
///   type tag is what tells a pair array apart from a genuine array of pairs
///   on the way back. Unknown `(type)` wrappers are unwrapped, mirroring
///   `oii::value_json`; `/-disabled` values are unwrapped the same way.
/// * one `.oii` file holds one top level node: `<name> [\n  key: value,\n]`
///   with identifier keys. Duplicate map keys are last-wins, like oii.
///
/// The constructs above were verified against oii 1.1.1 (`parse_with` accepts
/// them, `format_doc` re-emits them), so a backup file is also readable by
/// real oii tooling. Non-finite doubles are the one known divergence: rust's
/// `to_json` folds them to null, this decoder restores them.
library;

/// Encodes a JSON-like value (null, bool, int, double, String, List, Map with
/// String keys) as oii text. Anything else throws [ArgumentError].
String oiiEncodeValue(Object? v) {
  final out = StringBuffer();
  _writeValue(out, v);
  return out.toString();
}

void _writeValue(StringBuffer out, Object? v) {
  if (v == null) {
    out.write('null');
  } else if (v is bool) {
    out.write(v ? 'true' : 'false');
  } else if (v is int) {
    out.write(v.toString());
  } else if (v is double) {
    if (v.isNaN) {
      out.write('#nan');
    } else if (v.isInfinite) {
      out.write(v.isNegative ? '#-inf' : '#inf');
    } else {
      out.write(v.toString());
    }
  } else if (v is String) {
    _writeRawString(out, v);
  } else if (v is List) {
    out.write('[');
    for (var i = 0; i < v.length; i++) {
      if (i > 0) out.write(', ');
      _writeValue(out, v[i]);
    }
    out.write(']');
  } else if (v is Map) {
    out.write('(map)[');
    var first = true;
    for (final e in v.entries) {
      if (e.key is! String) {
        throw ArgumentError('oii map keys must be strings, got ${e.key.runtimeType}');
      }
      if (!first) out.write(', ');
      first = false;
      out.write('[');
      _writeRawString(out, e.key as String);
      out.write(', ');
      _writeValue(out, e.value);
      out.write(']');
    }
    out.write(']');
  } else {
    throw ArgumentError('oii cannot encode ${v.runtimeType}');
  }
}

void _writeRawString(StringBuffer out, String s) {
  var n = 1;
  while (s.contains('"${'#' * n}')) {
    n++;
  }
  final h = '#' * n;
  out.write('$h"$s"$h');
}

/// Encodes one backup file: a single node whose attributes are [fields].
/// [node] and every key must be identifiers (`[A-Za-z_][A-Za-z0-9_]*`).
String oiiEncodeDoc(String node, Map<String, Object?> fields) {
  _checkIdent(node, 'node');
  final out = StringBuffer()..writeln('$node [');
  for (final e in fields.entries) {
    _checkIdent(e.key, 'key');
    out.write('  ${e.key}: ');
    _writeValue(out, e.value);
    out.writeln(',');
  }
  out.writeln(']');
  return out.toString();
}

void _checkIdent(String s, String what) {
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(s)) {
    throw ArgumentError('oii $what must be an identifier, got "$s"');
  }
}

/// Decodes one value produced by [oiiEncodeValue]. Throws [FormatException]
/// on anything else; in particular bare words are refused, so a truncated or
/// hand edited file fails loudly instead of decoding into a wrong string.
Object? oiiDecodeValue(String src) {
  final p = _Parser(src);
  final v = p.value();
  p.end();
  return v;
}

/// Decodes one file produced by [oiiEncodeDoc].
({String name, Map<String, Object?> fields}) oiiDecodeDoc(String src) {
  final p = _Parser(src);
  final name = p.ident();
  p.expect('[');
  final fields = <String, Object?>{};
  while (!p.eof) {
    p.gap();
    if (p.eof) break;
    if (p.peek() == ']') {
      p.next();
      break;
    }
    final key = p.ident();
    p.gap();
    p.expect(':');
    fields[key] = p.value();
  }
  p.end();
  return (name: name, fields: fields);
}

class _Parser {
  _Parser(this.s);
  final String s;
  int i = 0;

  bool get eof => i >= s.length;
  String peek() => s[i];

  String next() => s[i++];

  /// Whitespace, newlines and value separators. `#` outside a string is not
  /// special except inside raw strings, which are consumed whole.
  void gap() {
    while (!eof) {
      final c = s[i];
      if (c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == ',') {
        i++;
      } else {
        break;
      }
    }
  }

  void end() {
    gap();
    if (!eof) throw FormatException('unexpected trailing text at offset $i');
  }

  void expect(String c) {
    gap();
    if (eof || s[i] != c) throw FormatException('expected "$c" at offset $i');
    i++;
  }

  String ident() {
    gap();
    final start = i;
    while (!eof && (_isWord(s[i]))) {
      i++;
    }
    if (start == i) throw FormatException('expected identifier at offset $i');
    return s.substring(start, i);
  }

  Object? value() {
    gap();
    if (eof) throw const FormatException('unexpected end, expected a value');
    final c = s[i];
    if (c == '#') return _hash();
    if (c == '"') return _quoted();
    if (c == '[') return _list();
    if (c == '(') return _typed();
    if (c == '/' && i + 1 < s.length && s[i + 1] == '-') {
      i += 2; // /-disabled: unwrap, like the rust reader
      return value();
    }
    if (c == '-' || _isDigit(c)) return _number();
    if (_isWord(c)) return _literal();
    throw FormatException('unexpected "$c" at offset $i');
  }

  Object? _hash() {
    // raw string #"..."#, ##"..."##, ... or #inf #-inf #nan
    var n = 0;
    while (!eof && s[i] == '#') {
      n++;
      i++;
    }
    if (!eof && s[i] == '"') {
      final close = '"${'#' * n}';
      final start = i + 1;
      final at = s.indexOf(close, start);
      if (at < 0) throw const FormatException('unterminated raw string');
      i = at + close.length;
      return s.substring(start, at);
    }
    final rest = s.substring(i);
    if (rest.startsWith('inf')) {
      i += 3;
      return double.infinity;
    }
    if (rest.startsWith('-inf')) {
      i += 4;
      return double.negativeInfinity;
    }
    if (rest.startsWith('nan')) {
      i += 3;
      return double.nan;
    }
    throw FormatException('unexpected "#" at offset ${i - n}');
  }

  String _quoted() {
    // plain "..." strings are never emitted by the encoder but stay readable
    // so a hand fixed file still loads; escapes mirror the rust lexer.
    i++; // "
    final out = StringBuffer();
    while (true) {
      if (eof) throw const FormatException('unterminated string');
      final c = next();
      if (c == '"') break;
      if (c != '\\') {
        out.write(c);
        continue;
      }
      if (eof) throw const FormatException('unterminated escape');
      final e = next();
      switch (e) {
        case 'n':
          out.write('\n');
        case 'r':
          out.write('\r');
        case 't':
          out.write('\t');
        case '0':
          out.writeCharCode(0);
        case '\\':
          out.write('\\');
        case '"':
          out.write('"');
        case 'x':
          if (i + 2 > s.length) throw const FormatException('bad \\x escape');
          out.writeCharCode(int.parse(s.substring(i, i + 2), radix: 16));
          i += 2;
        case 'u':
          if (eof || s[i] != '{') throw const FormatException('bad \\u escape');
          final end = s.indexOf('}', i);
          if (end < 0) throw const FormatException('bad \\u escape');
          out.writeCharCode(int.parse(s.substring(i + 1, end), radix: 16));
          i = end + 1;
        default:
          throw FormatException('unknown escape "\\$e"');
      }
    }
    return out.toString();
  }

  List<Object?> _list() {
    i++; // [
    final out = <Object?>[];
    while (true) {
      gap();
      if (eof) throw const FormatException('unterminated list');
      if (s[i] == ']') {
        i++;
        return out;
      }
      out.add(value());
    }
  }

  Object? _typed() {
    i++; // (
    final start = i;
    while (!eof && s[i] != ')') {
      i++;
    }
    if (eof) throw const FormatException('unterminated type tag');
    final ty = s.substring(start, i);
    i++; // )
    final inner = value();
    if (ty == 'map') {
      if (inner is! List) throw const FormatException('(map) needs a pair list');
      final m = <String, Object?>{};
      for (final e in inner) {
        if (e is! List || e.length != 2 || e[0] is! String) {
          throw const FormatException('(map) needs [["k", v], ...] pairs');
        }
        m[e[0] as String] = e[1];
      }
      return m;
    }
    return inner; // unknown tags unwrap, like the rust reader
  }

  Object? _number() {
    final start = i;
    if (!eof && s[i] == '-') i++;
    while (!eof && (_isDigit(s[i]))) {
      i++;
    }
    var isFloat = false;
    if (!eof && s[i] == '.') {
      isFloat = true;
      i++;
      while (!eof && _isDigit(s[i])) {
        i++;
      }
    }
    if (!eof && (s[i] == 'e' || s[i] == 'E')) {
      isFloat = true;
      i++;
      if (!eof && (s[i] == '+' || s[i] == '-')) i++;
      while (!eof && _isDigit(s[i])) {
        i++;
      }
    }
    final text = s.substring(start, i);
    try {
      return isFloat ? double.parse(text) : int.parse(text);
    } catch (_) {
      throw FormatException('bad number "$text"');
    }
  }

  Object? _literal() {
    final start = i;
    while (!eof && _isWord(s[i])) {
      i++;
    }
    return switch (s.substring(start, i)) {
      'null' => null,
      'true' => true,
      'false' => false,
      final w => throw FormatException('bare word "$w" is not a value'),
    };
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  static bool _isWord(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || (u >= 48 && u <= 57) || u == 95;
  }
}
