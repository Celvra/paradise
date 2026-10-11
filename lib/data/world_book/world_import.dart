import 'dart:convert';

import 'world_book.dart';
import 'world_store.dart';

// SillyTavern world info (lorebook) JSON, both directions.
//
// The format is a map of entries keyed by index, each with `key`,
// `keysecondary`, `position`, `selectiveLogic`, `probability` in percent and
// friends. Paradise's own format is a list of books, so a document is told
// apart by its shape: `entries` as a map is SillyTavern, `entries` as a list
// (or a `books` wrapper) is ours.

/// SillyTavern selectiveLogic: AND ANY, NOT ANY, NOT ALL, AND ALL.
const _stSelectiveLogic = ['anySecondary', 'notAnySecondary', 'notAllSecondary', 'allSecondary'];

class WorldIo {
  const WorldIo._();

  /// One book as a SillyTavern world info document.
  static Map<String, dynamic> toTavern(WorldBook book) {
    final entries = <String, dynamic>{};
    for (var i = 0; i < book.entries.length; i++) {
      final e = book.entries[i];
      entries['$i'] = {
        'uid': i,
        'key': e.keys,
        'keysecondary': e.secondaryKeys,
        'comment': e.comment,
        'content': e.content,
        'constant': e.constant,
        'vectorized': false,
        'selective': e.secondaryKeys.isNotEmpty,
        'selectiveLogic': _stIndex(_stSelectiveLogic, e.logic.name),
        'addMemo': true,
        'order': e.priority,
        'position': _toStPosition(e),
        'depth': e.depth,
        'disable': !e.enabled,
        'excludeRecursion': false,
        'probability': (e.probability * 100).round(),
        'useProbability': e.probability < 1,
        'caseSensitive': e.caseSensitive,
        'matchWholeWords': e.matchWholeWords,
        'useRegex': e.useRegex,
        'group': e.inclusionGroup,
        'groupWeight': e.groupWeight,
        'scanDepth': e.scanDepth,
        'role': switch (e.role) { EntryRole.system => 0, EntryRole.user => 1, EntryRole.assistant => 2 },
        // Paradise extensions, ignored by SillyTavern and kept so a
        // round-trip does not lose the depth this project adds
        'lib3': {
          'kind': book.kind.name,
          'aiEditable': e.aiEditable,
          'logic': e.logic.name,
          'position': e.position.name,
          'role': e.role.name,
        },
      };
    }
    return {
      'entries': entries,
      // the book itself, so a re-import keeps the name, kind and description
      'lib3': {'book': book.toJson()},
    };
  }

  /// Every book as one JSON array of SillyTavern documents.
  static String exportAll(List<WorldBook> books) {
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert([for (final b in books) toTavern(b)]);
  }

  /// Parses any accepted shape into books. Throws [FormatException] with a
  /// message the UI can show verbatim.
  static List<WorldBook> parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) throw const FormatException('Nothing to import.');
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const FormatException('Not valid JSON.');
    }
    final out = <WorldBook>[];
    if (decoded is List) {
      for (final e in decoded) {
        if (e is Map) out.addAll(_parseDoc(Map<String, dynamic>.from(e)));
      }
    } else if (decoded is Map) {
      out.addAll(_parseDoc(Map<String, dynamic>.from(decoded)));
    } else {
      throw const FormatException('Expected an object or a list.');
    }
    if (out.isEmpty || out.every((b) => b.entries.isEmpty)) {
      throw const FormatException('No world info entries found.');
    }
    return out;
  }

  static List<WorldBook> _parseDoc(Map<String, dynamic> doc) {
    // ours: a book, or the {"books": [...]} wrapper
    final booksRaw = doc['books'];
    if (booksRaw is List) {
      return [for (final e in booksRaw) WorldBook.fromJson(Map<String, dynamic>.from(e as Map))];
    }
    if (doc['name'] is String && doc['entries'] is List) {
      return [WorldBook.fromJson(doc)];
    }

    // SillyTavern: {entries: {index: {...}}}
    final entries = doc['entries'];
    if (entries is! Map) return const [];
    final name = (doc['lib3'] is Map ? (doc['lib3'] as Map)['book'] : null);
    final own = name is Map ? WorldBook.fromJson(Map<String, dynamic>.from(name)) : null;
    final book = own ??
        WorldBook(
          id: '',
          name: 'Imported world',
          description: 'Imported from SillyTavern world info.',
        );
    final parsed = <WorldEntry>[];
    for (final e in entries.values) {
      if (e is! Map) continue;
      final j = Map<String, dynamic>.from(e);
      try {
        parsed.add(_entry(j));
      } catch (_) {
        // one malformed entry must not sink a whole import
      }
    }
    return [book.copy(entries: parsed)];
  }

  static WorldEntry _entry(Map<String, dynamic> j) {
    final ext = (j['lib3'] is Map ? Map<String, dynamic>.from(j['lib3'] as Map) : const <String, dynamic>{});
    final probability = j['probability'];
    final useProbability = j['useProbability'] == true;
    final pct = (probability is num ? probability.toDouble() : 100) / 100;
    return WorldEntry(
      id: '',
      comment: '${j['comment'] ?? ''}',
      content: '${j['content'] ?? ''}',
      enabled: j['disable'] != true,
      keys: _keys(j['key']),
      secondaryKeys: _keys(j['keysecondary']),
      logic: KeyLogic.of(ext['logic'] as String? ?? _logicOf(j['selectiveLogic'])),
      probability: useProbability ? pct.clamp(0.0, 1.0) : 1,
      caseSensitive: j['caseSensitive'] == true,
      matchWholeWords: j['matchWholeWords'] == true,
      useRegex: j['useRegex'] == true,
      constant: j['constant'] == true,
      scanDepth: (j['scanDepth'] as num?)?.toInt() ?? 0,
      position: EntryPosition.of(ext['position'] as String? ?? _positionOf(j['position'])),
      depth: (j['depth'] as num?)?.toInt() ?? 4,
      role: EntryRole.of(ext['role'] as String? ?? _roleOf(j['role'])),
      inclusionGroup: '${j['group'] ?? ''}',
      groupWeight: (j['groupWeight'] as num?)?.toInt() ?? 100,
      priority: (j['order'] as num?)?.toInt() ?? 0,
      aiEditable: ext['aiEditable'] == true,
    );
  }

  static List<String> _keys(Object? raw) {
    if (raw is String) return [raw].where((e) => e.trim().isNotEmpty).toList();
    if (raw is List) return [for (final e in raw) '$e'.trim()]..removeWhere((e) => e.isEmpty);
    return const [];
  }

  static String _logicOf(Object? raw) {
    final i = raw is num ? raw.toInt() : 0;
    if (i < 0 || i >= _stSelectiveLogic.length) return _stSelectiveLogic.first;
    return _stSelectiveLogic[i];
  }

  static String _positionOf(Object? raw) {
    final i = raw is num ? raw.toInt() : 0;
    return switch (i) {
      1 => 'afterChar',
      4 || 5 || 6 || 7 => 'atDepth',
      _ => 'beforeChar',
    };
  }

  static String _roleOf(Object? raw) {
    final i = raw is num ? raw.toInt() : 0;
    return switch (i) { 1 => 'user', 2 => 'assistant', _ => 'system' };
  }

  static int _stIndex(List<String> names, String name) {
    final at = names.indexOf(name);
    return at < 0 ? 0 : at;
  }

  static Object _toStPosition(WorldEntry e) => switch (e.position) {
        EntryPosition.beforeChar => 0,
        EntryPosition.afterChar => 1,
        EntryPosition.bottomNote => 3,
        EntryPosition.atDepth => 4,
      };

  /// Merges parsed books into [store], re-identifying everything so a second
  /// import of the same file stacks rather than colliding. Returns what was
  /// created.
  static Future<List<WorldBook>> importInto(WorldStore store, String raw) async {
    final parsed = parse(raw);
    final created = <WorldBook>[];
    for (final book in parsed) {
      final entries = <WorldEntry>[];
      for (final e in book.entries) {
        if (e.content.trim().isEmpty) continue;
        entries.add(e.copy(id: store.newEntryId()));
      }
      final fresh = await store.create(
        name: book.name,
        kind: book.kind,
        description: book.description,
        entries: entries,
      );
      created.add(fresh);
    }
    return created;
  }
}
