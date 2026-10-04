import 'package:flutter/widgets.dart';
import 'package:highlight/highlight.dart' show highlight, Node;

/// How a file is previewed, chosen from the extension and then from the first
/// few KiB of the content.
///
/// Sniffing matters more than it looks: a model writes files with no extension
/// often enough that routing everything unknown to the binary card would hide
/// half of what it produced.
enum PreviewKind { image, markdown, html, csv, code, binary }

PreviewKind previewKindFor(String path, {bool sniffedText = true}) {
  final e = _ext(path);
  if (_image.contains(e)) return PreviewKind.image;
  if (_markdown.contains(e)) return PreviewKind.markdown;
  if (_html.contains(e)) return PreviewKind.html;
  if (_csv.contains(e)) return PreviewKind.csv;
  if (_code.contains(e)) return PreviewKind.code;
  return sniffedText ? PreviewKind.code : PreviewKind.binary;
}

String _ext(String path) {
  final slash = path.lastIndexOf('/');
  final dot = path.lastIndexOf('.');
  return dot > slash && dot > 0 ? path.substring(dot).toLowerCase() : '';
}

const _image = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'};
const _markdown = {'.md', '.markdown'};
const _html = {'.html', '.htm', '.svg'};
const _csv = {'.csv', '.tsv'};

/// What the icon column draws. Kept beside the routing tables so a file that is
/// previewed as code is never given a picture glyph.
const _code = {
  '.txt', '.log', '.json', '.yaml', '.yml', '.toml', '.ini', '.cfg', '.conf', '.env', '.properties', //
  '.dart', '.js', '.mjs', '.cjs', '.ts', '.tsx', '.jsx', '.py', '.java', '.kt', '.kts', '.c', '.h', '.cc', '.cpp', '.hpp', '.cs', '.go', '.rs', '.rb', '.php', '.swift', '.m', '.mm', '.sh', '.bash', '.zsh', '.fish', '.ps1', '.sql', '.graphql', '.r', '.lua', '.pl', '.scala', '.clj', '.ex', '.exs', '.erl', '.hs', '.jl', '.vim', '.gradle', '.cmake', '.mk', '.dockerfile', '.gitignore', '.editorconfig', '.diff', '.patch',
};

/// dotfiles the model writes a lot, routed by name rather than by extension
const _dotNames = {'.bashrc', '.zshrc', '.profile', '.bash_profile', '.zprofile', '.env', '.gitignore', '.editorconfig', '.dockerignore', '.npmrc', '.gitconfig'};

String _name(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 ? path : path.substring(slash + 1);
}

/// The highlighter language for a path, or null for plain text.
///
/// Null means "do not try to highlight", which is the right answer for a file
/// with no recognisable grammar. Guessing from the first line instead produces
/// plausible looking nonsense.
String? previewLanguage(String path) {
  final dot = _dotNames.contains(_name(path).toLowerCase());
  if (dot) return 'shell';
  final e = _ext(path);
  if (e.isEmpty) return null;
  if (_markdown.contains(e)) return 'markdown';
  if (_html.contains(e)) return 'xml';
  if (_csv.contains(e)) return 'plaintext';
  if (e == '.ts' || e == '.tsx') return 'typescript';
  if (e == '.js' || e == '.mjs' || e == '.cjs') return 'javascript';
  if (e == '.py') return 'python';
  if (e == '.rb') return 'ruby';
  if (e == '.rs') return 'rust';
  if (e == '.go') return 'go';
  if (e == '.java') return 'java';
  if (e == '.kt' || e == '.kts') return 'kotlin';
  if (e == '.c' || e == '.h') return 'c';
  if (e == '.cc' || e == '.cpp' || e == '.hpp') return 'cpp';
  if (e == '.cs') return 'csharp';
  if (e == '.sh' || e == '.bash' || e == '.zsh') return 'bash';
  if (e == '.ps1') return 'powershell';
  if (e == '.sql') return 'sql';
  if (e == '.json') return 'json';
  if (e == '.yaml' || e == '.yml') return 'yaml';
  if (e == '.toml' || e == '.ini' || e == '.cfg') return 'ini';
  if (e == '.dart') return 'dart';
  if (e == '.php') return 'php';
  if (e == '.swift') return 'swift';
  if (e == '.lua') return 'lua';
  if (e == '.pl') return 'perl';
  if (e == '.r') return 'r';
  if (e == '.scala') return 'scala';
  if (e == '.jsx') return 'javascript';
  if (e == '.graphql') return 'graphql';
  if (e == '.dockerfile') return 'dockerfile';
  return null;
}

/// A word for the header, so the user sees which grammar was guessed.
String previewLanguageLabel(String path) {
  final l = previewLanguage(path);
  if (l == null) return 'text';
  return l;
}

/// Turns a highlighted tree into spans over [base].
///
/// Any exception is swallowed and the whole thing falls back to one plain span:
/// a syntax highlighter is decoration, and a malformed file must still open.
List<TextSpan> previewSpans(String source, String? language, Map<String, TextStyle> theme, TextStyle base) {
  if (language == null || language.isEmpty || language == 'plaintext' || source.isEmpty) {
    return [TextSpan(text: source, style: base)];
  }
  try {
    final nodes = highlight.parse(source, language: language).nodes;
    if (nodes == null || nodes.isEmpty) return [TextSpan(text: source, style: base)];
    return _convert(nodes, theme, base);
  } catch (_) {
    return [TextSpan(text: source, style: base)];
  }
}

List<TextSpan> _convert(List<Node> nodes, Map<String, TextStyle> theme, TextStyle base) {
  final out = <TextSpan>[];
  for (final n in nodes) {
    final merged = _merge(n, theme, base);
    if (n.value == null) {
      out.addAll(_convert(n.children ?? const [], theme, base));
    } else {
      out.add(TextSpan(text: n.value, style: merged));
    }
  }
  return out;
}

/// The theme entry wins over [base] for anything it sets, so a file that has no
/// theme for a class keeps the base font size rather than getting a default.
TextStyle _merge(Node n, Map<String, TextStyle> theme, TextStyle base) {
  final entry = n.className == null ? null : theme[n.className!];
  if (entry == null) return base;
  return base.merge(entry);
}

/// Line numbers as one paragraph, one label per rendered line.
///
/// Unwrapped that is one label per source line. When wrapping, a source line
/// can occupy several rendered lines, so its number is followed by as many
/// blank lines as the code beside it takes. Laying the code out here with the
/// styled spans and at the width it will really be rendered at is the only way
/// to get the two columns onto the same rows.
String gutterLabels({
  required TextSpan span,
  required List<String> lines,
  required StrutStyle strutStyle,
  required TextScaler textScaler,
  required double? wrapWidth,
}) {
  final plain = () => <String>[for (var i = 1; i <= lines.length; i++) '$i'].join('\n');
  if (wrapWidth == null) return plain();

  final painter = TextPainter(text: span, strutStyle: strutStyle, textDirection: TextDirection.ltr, textScaler: textScaler)..layout(maxWidth: wrapWidth);
  final metrics = painter.computeLineMetrics();
  // with a forced strut every rendered line is the strut's height, so a caret
  // offset divided by it is the row that offset sits on
  final lineHeight = metrics.isEmpty ? 0.0 : metrics.first.height;
  if (lineHeight <= 0) {
    painter.dispose();
    return plain();
  }
  final buffer = StringBuffer();
  var offset = 0;
  var previousRow = 0;
  for (var i = 0; i < lines.length; i++) {
    final caret = painter.getOffsetForCaret(TextPosition(offset: offset), Rect.zero);
    final row = (caret.dy / lineHeight).round();
    if (i > 0) buffer.write('\n' * (row - previousRow < 1 ? 1 : row - previousRow));
    buffer.write('${i + 1}');
    previousRow = row;
    offset += lines[i].length + 1; // + the line break
  }
  painter.dispose();
  return buffer.toString();
}