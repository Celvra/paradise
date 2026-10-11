import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'world_book.dart';

/// Where the records live in preferences.
const _booksKey = 'world_books';

/// Budget setting, in kilo characters, capped by [WorldStore.maxBudgetK].
const _budgetKey = 'world_budget_chars';

/// Owner of every world book in the app.
///
/// Books are global; the per persona selection lives on the persona itself
/// (`worldBookIds`), the same split the skill store already uses, so one
/// book can serve several roles and a restored chat keeps its binding.
///
/// Everything is one JSON list in SharedPreferences. A world book is a
/// user-authored artefact of a few kilobytes at most, unlike message
/// history, so a dedicated database would buy nothing.
class WorldStore extends ChangeNotifier {
  WorldStore._(this._sp);

  final SharedPreferences _sp;

  final List<WorldBook> _books = [];

  /// The in-memory view, ordered by name.
  List<WorldBook> get books => List.unmodifiable(_books);

  /// Budget in kilo characters. [unlimited] disables the cap, any other value
  /// is 1..maxBudgetK. Unlimited is a user choice with a warning attached:
  /// everything that fires goes in, and a world large enough to need it
  /// usually pays for it in attention.
  int budgetK = 4;

  /// The "no cap" value of [budgetK].
  static const int unlimited = 0;

  bool get budgetUnlimited => budgetK <= unlimited;

  /// The character cap the injector enforces.
  ///
  /// Unlimited is not infinity but a number no authored world can reach, so
  /// `_assemble` keeps its plain int comparison instead of branching on a
  /// flag, and a restored snapshot from before the option existed loads as
  /// the cap it always had.
  static const int _unlimitedBudgetChars = 1 << 62;

  int get budgetChars => budgetUnlimited ? _unlimitedBudgetChars : budgetK * 1000;
  int get maxBudgetK => 64;

  static Future<WorldStore> load(SharedPreferences sp) async {
    final store = WorldStore._(sp);
    final raw = sp.getString(_booksKey);
    if (raw != null) {
      try {
        for (final e in (jsonDecode(raw) as List)) {
          final b = WorldBook.fromJson(Map<String, dynamic>.from(e as Map));
          if (b.id.isNotEmpty && b.name.isNotEmpty) store._books.add(b);
        }
      } catch (_) {
        // a corrupted list drops to empty rather than blocking startup; the
        // user can re-import from a backup
      }
    }
    store._books.sort((a, b) => a.name.compareTo(b.name));
    store.budgetK = (sp.getInt(_budgetKey) ?? 4).clamp(WorldStore.unlimited, store.maxBudgetK);
    return store;
  }

  WorldBook? byId(String id) {
    final needle = id.trim();
    for (final b in _books) {
      if (b.id == needle) return b;
    }
    return null;
  }

  /// The books [ids] names, in the order the ids list gives them, skipping
  /// unknown and disabled ones. Null and empty both mean "no world", which
  /// is what every persona written before the world book expects.
  List<WorldBook> resolve(List<String>? ids) {
    if (ids == null) return const [];
    final out = <WorldBook>[];
    for (final id in ids) {
      final b = byId(id);
      if (b != null && b.enabled) out.add(b);
    }
    return out;
  }

  /// Total entry count across every book, for the settings row subtitle.
  int get entryCount => _books.fold(0, (a, b) => a + b.entries.length);

  // ------------------------------------------------------------- mutation

  /// Creates a book and persists it. Entries may be seeded right away, which
  /// is what the character card migration uses.
  Future<WorldBook> create({
    required String name,
    BookKind kind = BookKind.general,
    String description = '',
    List<WorldEntry> entries = const [],
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final book = WorldBook(
      id: _allocate('wb'),
      name: name.trim().isEmpty ? 'World' : name.trim(),
      description: description.trim(),
      kind: kind,
      entries: entries,
      createdAt: now,
      updatedAt: now,
    );
    _books.add(book);
    _books.sort((a, b) => a.name.compareTo(b.name));
    await _save();
    return book;
  }

  Future<void> remove(String id) async {
    final at = _books.indexWhere((b) => b.id == id);
    if (at < 0) return;
    _books.removeAt(at);
    await _save();
  }

  /// Replaces a book wholesale: the editor page saves the whole object it
  /// came in with, renames and entry edits land in one write.
  Future<void> put(WorldBook book) async {
    final at = _books.indexWhere((b) => b.id == book.id);
    if (at < 0) {
      _books.add(book);
      _books.sort((a, b) => a.name.compareTo(b.name));
    } else {
      book.updatedAt = DateTime.now().millisecondsSinceEpoch;
      _books[at] = book;
    }
    await _save();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final book = byId(id);
    if (book == null || book.enabled == enabled) return;
    book.enabled = enabled;
    book.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _save();
  }

  Future<void> setBudget(int kiloChars) async {
    final next = kiloChars.clamp(WorldStore.unlimited, maxBudgetK);
    if (next == budgetK) return;
    budgetK = next;
    await _sp.setInt(_budgetKey, next);
    notifyListeners();
  }

  /// Adds or replaces one entry inside its book. Used by the editor and by
  /// the world book tool.
  Future<void> upsertEntry(String bookId, WorldEntry entry) async {
    final book = byId(bookId);
    if (book == null) return;
    final at = book.entries.indexWhere((e) => e.id == entry.id);
    if (at >= 0) {
      book.entries[at] = entry;
    } else {
      book.entries.add(entry);
    }
    book.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _save();
  }

  Future<void> removeEntry(String bookId, String entryId) async {
    final book = byId(bookId);
    if (book == null) return;
    book.entries.removeWhere((e) => e.id == entryId);
    book.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _save();
  }

  /// A fresh entry id, not yet attached to any book.
  String newEntryId() => _allocate('we');

  /// A fresh book id, for a draft the import layer is still building.
  String newBookId() => _allocate('wb');

  String _allocate(String prefix) {
    while (true) {
      final id = '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      var taken = _books.any((b) => b.id == id);
      if (!taken) {
        for (final b in _books) {
          if (b.entries.any((e) => e.id == id)) {
            taken = true;
            break;
          }
        }
      }
      if (!taken) return id;
    }
  }

  Future<void> _save() async {
    try {
      await _sp.setString(_booksKey, jsonEncode([for (final b in _books) b.toJson()]));
    } catch (_) {
      // the in-memory list stays authoritative; the next successful write
      // carries everything, exactly as the skill store does
    }
    notifyListeners();
  }
}
