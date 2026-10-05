import 'package:characters/characters.dart';

/// One installed skill: a directory holding a `SKILL.md` with frontmatter.
///
/// The directory name is the stable id. [name] and [description] come from
/// the frontmatter and are what the model sees in the listing.
class Skill {
  const Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.dir,
    required this.mdPath,
    required this.enabled,
    required this.useCount,
    required this.source,
    required this.installedAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String dir;
  final String mdPath;
  final bool enabled;
  final int useCount;
  final SkillSource source;
  final DateTime installedAt;
  final DateTime updatedAt;

  Skill copyWith({
    String? name,
    String? description,
    bool? enabled,
    int? useCount,
    SkillSource? source,
    DateTime? updatedAt,
  }) =>
      Skill(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        dir: dir,
        mdPath: mdPath,
        enabled: enabled ?? this.enabled,
        useCount: useCount ?? this.useCount,
        source: source ?? this.source,
        installedAt: installedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> recordJson() => {
        'id': id,
        'enabled': enabled,
        'useCount': useCount,
        'source': source.name,
        'installedAt': installedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static SkillSource sourceOf(String? raw) => switch (raw) {
        'file' => SkillSource.file,
        'url' => SkillSource.url,
        _ => SkillSource.paste,
      };
}

enum SkillSource { paste, file, url }

/// Frontmatter of a `SKILL.md` body: `name` and `description` plus the rest.
class SkillDoc {
  const SkillDoc({required this.name, required this.description, required this.body});

  final String name;
  final String description;
  final String body;

  /// Problems that block an import. Empty means the document is usable.
  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) errors.add('missing name');
    if (description.trim().isEmpty) errors.add('missing description');
    return errors;
  }

  /// Parses markdown that may start with a `---` block.
  ///
  /// Tolerates a leading BOM and CRLF. Only the `name` and `description`
  /// keys are read; everything else is ignored. When there is no block,
  /// [name] falls back to the first `# Heading`.
  static SkillDoc parse(String markdown) {
    var text = markdown;
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    String? block;
    var body = text;
    final lines = text.split('\n');
    if (lines.isNotEmpty && _fence(lines.first)) {
      for (var i = 1; i < lines.length; i++) {
        if (_fence(lines[i])) {
          block = lines.sublist(1, i).join('\n');
          body = lines.sublist(i + 1).join('\n');
          break;
        }
      }
    }

    var name = '';
    var description = '';
    if (block != null) {
      final parsed = _readBlock(block);
      name = parsed['name'] ?? '';
      description = parsed['description'] ?? '';
    }
    if (name.trim().isEmpty) name = _firstHeading(body) ?? '';
    return SkillDoc(name: name.trim(), description: description.trim(), body: body);
  }

  /// Reads `key: value` lines, including a `|`/`>` folded value that spans
  /// the indented lines below it. Anything fancier is out of scope on
  /// purpose: a skill header is two short strings, not a config file.
  static Map<String, String> _readBlock(String block) {
    final out = <String, String>{};
    final lines = block.split('\n');
    var i = 0;
    while (i < lines.length) {
      final raw = lines[i];
      if (raw.trim().isEmpty || raw.trimLeft().startsWith('#')) {
        i++;
        continue;
      }
      final m = RegExp(r'^([A-Za-z0-9_-]+)\s*:\s*(.*)$').firstMatch(raw);
      if (m == null) {
        i++;
        continue;
      }
      final key = m.group(1)!;
      if (key != 'name' && key != 'description') {
        i++;
        continue;
      }
      var rest = (m.group(2) ?? '').trim();
      // strip an end of line comment outside quotes
      if (!rest.startsWith('"') && !rest.startsWith("'")) {
        final hash = rest.indexOf(' #');
        if (hash >= 0) rest = rest.substring(0, hash).trimRight();
      }
      if (rest == '|' || rest == '|-' || rest == '|+' || rest == '>' || rest == '>-' || rest == '>+') {
        final fold = rest.startsWith('>');
        final buf = <String>[];
        i++;
        while (i < lines.length && (lines[i].startsWith(' ') || lines[i].startsWith('\t') || lines[i].trim().isEmpty)) {
          buf.add(lines[i].trim());
          i++;
        }
        while (buf.isNotEmpty && buf.last.isEmpty) {
          buf.removeLast();
        }
        out[key] = fold ? buf.join(' ') : buf.join('\n');
        continue;
      }
      out[key] = _unquote(rest);
      i++;
    }
    return out;
  }

  static String _unquote(String raw) {
    var text = raw.trim();
    if (text.length >= 2 && ((text.startsWith('"') && text.endsWith('"')) || (text.startsWith("'") && text.endsWith("'")))) {
      final quote = text[0];
      text = text.substring(1, text.length - 1);
      if (quote == "'") return text.replaceAll("''", "'");
      return text.replaceAll(r'\n', '\n').replaceAll(r'\t', '\t').replaceAll(r'\"', '"').replaceAll('\\\\', '\\');
    }
    final number = num.tryParse(text);
    if (number != null) return '$number';
    if (text == 'true' || text == 'false' || text == 'null' || text == '~') return '';
    return text;
  }
}

bool _fence(String line) => RegExp(r'^---\s*$').hasMatch(line);

String? _firstHeading(String text) {
  for (final line in text.split('\n')) {
    final m = RegExp(r'^#{1,6}\s+(.+?)\s*$').firstMatch(line);
    if (m != null) return m.group(1);
  }
  return null;
}

/// Lowercase `[a-z0-9-]` slug, at most 64 characters.
String skillSlug(String name) {
  var slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  slug = slug.replaceAll(RegExp(r'-{2,}'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length > 64) slug = slug.substring(0, 64).replaceAll(RegExp(r'-+$'), '');
  return slug.isEmpty ? 'skill' : slug;
}

/// Clips to [max] grapheme clusters so an emoji is never cut in half.
String clipDescription(String text, [int max = 200]) {
  final chars = text.characters;
  if (chars.length <= max) return text;
  return chars.take(max).toString();
}
