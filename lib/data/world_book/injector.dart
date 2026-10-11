import 'dart:math' as math;

import 'world_book.dart';
// Which lore entries fire for one request, and where they land.
//
// The pipeline, in order:
//
//   1. key match      (literal, whole word, or regex, case sensitivity)
//   2. secondary gate (any / not any / all / not all)
//   3. probability    (a rolled chance per entry, reproducible via the seed)
//   4. group scoring  (one winner per inclusion group per book)
//   5. recursion      (newly fired content is scanned for further keys)
//   6. budget         (priority keeps the survivors inside the character cap)
//
// Steps 1 to 4 are the SillyTavern behaviour. Step 5 is what makes a world
// feel connected instead of a bag of independent triggers, and step 6 is
// the guard that keeps a big world from crowding out the conversation.

/// Result of one evaluation, including what was dropped, so the test sandbox
/// in the UI can explain itself.
class WorldEval {
  WorldEval(this.context, this.dropped, this.recursionPasses);

  final WorldContext context;

  /// Hits lost to the budget, ranked as they were dropped.
  final List<WorldHit> dropped;

  /// How many extra passes the recursion ran, 0 when nothing chained.
  final int recursionPasses;

  int get spent => context.totalChars;
}

class WorldInjector {
  const WorldInjector._();

  /// Evaluates [books] against [recentMessages], where index 0 is the oldest
  /// message of the window.
  ///
  /// [rng] is seeded by the caller so the same chat and turn replay the same
  /// dice; pass null for a fresh one.
  static WorldEval evaluate(
    List<WorldBook> books, {
    required List<String> recentMessages,
    math.Random? rng,
    int budgetChars = 4000,
    int maxRecursion = 2,
  }) {
    final dice = rng ?? math.Random();
    var hits = <WorldHit>[];
    var passes = 0;

    for (var pass = 0; pass <= maxRecursion; pass++) {
      final chained = pass == 0 ? null : _chainText(hits);
      if (pass > 0) {
        if (chained == null || chained.trim().isEmpty) break;
        passes = pass;
      }
      final newThisPass = <WorldHit>[];
      for (final book in books) {
        if (!book.enabled) continue;
        final bookHits = <WorldHit>[];
        for (final e in book.entries) {
          if (!e.enabled) continue;
          if (e.content.trim().isEmpty) continue;
          // constant entries fire on the first pass only: re-running them
          // would just duplicate them on every recursion
          if (e.constant && pass > 0) continue;
          final hit = WorldHit(book, e);
          if (hits.contains(hit)) continue;
          final text = pass == 0 ? scanWindow(recentMessages, e.scanDepth).join('\n') : chained!;
          if (!e.constant && !_fires(e, text)) continue;
          if (!_rolls(e, dice)) continue;
          bookHits.add(hit);
        }
        final surviving = _pickGroups(bookHits);
        hits.addAll(surviving);
        newThisPass.addAll(surviving);
      }
      if (pass == maxRecursion) break;
      // recursion only follows keyed entries: a constant pulling in further
      // lore is the same as having made that lore constant too, and the
      // group and budget logic below runs on the union anyway
      if (newThisPass.where((h) => !h.constant).isEmpty) break;
    }

    return _assemble(hits, budgetChars, passes);
  }

  /// The text recursion scans: everything that fired so far, minus what was
  /// always there.
  static String _chainText(List<WorldHit> hits) => [for (final h in hits) if (!h.constant) h.entry.content].join('\n');

  /// Whether [entry]'s keys fire against [text].
  static bool _fires(WorldEntry e, String text) {
    if (!e.hasKeys) return false;
    final primary = e.keys.map((k) => k.trim()).where((k) => k.isNotEmpty);
    if (!primary.any((k) => _matches(k, text, e))) return false;
    final secondary = e.secondaryKeys.map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
    if (secondary.isEmpty) return true;
    final anyHit = secondary.any((k) => _matches(k, text, e));
    final allHit = secondary.every((k) => _matches(k, text, e));
    return switch (e.logic) {
      KeyLogic.anySecondary => anyHit,
      KeyLogic.notAnySecondary => !anyHit,
      KeyLogic.allSecondary => allHit,
      KeyLogic.notAllSecondary => !allHit,
    };
  }

  /// One key against one text. A malformed regex degrades to a literal
  /// search rather than throwing: the user typed it, the world still works.
  static bool _matches(String key, String text, WorldEntry e) {
    if (e.useRegex) {
      try {
        return RegExp(key, caseSensitive: e.caseSensitive).hasMatch(text);
      } catch (_) {
        return text.contains(key);
      }
    }
    if (e.matchWholeWords) {
      // custom boundaries instead of \b: \b is ascii-only and never fires
      // between two CJK characters, where a whole word match matters just
      // as much ("arc" must not fire inside "architect", 龙 must not fire
      // inside 龙王 would be wrong too, but the boundary has to be drawn by
      // something the engine can see on both sides)
      try {
        return RegExp('(?<![A-Za-z0-9_])(?:$key)(?![A-Za-z0-9_])', caseSensitive: e.caseSensitive).hasMatch(text);
      } catch (_) {
        return text.contains(key);
      }
    }
    if (e.caseSensitive) return text.contains(key);
    return text.toLowerCase().contains(key.toLowerCase());
  }

  static bool _rolls(WorldEntry e, math.Random dice) {
    if (e.probability >= 1) return true;
    if (e.probability <= 0) return false;
    return dice.nextDouble() < e.probability;
  }

  /// Keeps one winner per inclusion group: the highest weight, then the
  /// highest priority, then the earliest entry. Entries without a group all
  /// stay.
  static List<WorldHit> _pickGroups(List<WorldHit> hits) {
    final grouped = hits.where((h) => h.entry.inclusionGroup.trim().isNotEmpty).toList();
    if (grouped.length <= 1) return hits;
    final winners = <String, WorldHit>{};
    for (final h in grouped) {
      final g = h.entry.inclusionGroup.trim();
      final prev = winners[g];
      if (prev == null || _beats(h.entry, prev.entry)) winners[g] = h;
    }
    final keep = winners.values.toSet();
    return [for (final h in hits) if (h.entry.inclusionGroup.trim().isEmpty || keep.contains(h)) h];
  }

  static bool _beats(WorldEntry a, WorldEntry b) {
    if (a.groupWeight != b.groupWeight) return a.groupWeight > b.groupWeight;
    if (a.priority != b.priority) return a.priority > b.priority;
    return false;
  }

  /// Sorts into the request slots and enforces the budget. Constant entries
  /// are kept even when the budget is blown: the facts the author marked
  /// must-never-miss are precisely the ones that must never be dropped.
  static WorldEval _assemble(List<WorldHit> hits, int budgetChars, int passes) {
    final sorted = [...hits]..sort((a, b) => b.entry.priority.compareTo(a.entry.priority));
    final kept = <WorldHit>[];
    final dropped = <WorldHit>[];
    var spent = 0;
    for (final h in sorted) {
      if (h.constant || spent + h.entry.budgetCost <= budgetChars) {
        kept.add(h);
        spent += h.entry.budgetCost;
      } else {
        dropped.add(h);
      }
    }

    List<WorldHit> slot(EntryPosition p) => [for (final h in kept) if (h.entry.position == p) h];
    return WorldEval(
      WorldContext(
        beforeChar: slot(EntryPosition.beforeChar),
        afterChar: slot(EntryPosition.afterChar),
        bottomNote: slot(EntryPosition.bottomNote),
        atDepth: slot(EntryPosition.atDepth),
      ),
      dropped,
      passes,
    );
  }

  /// Deterministic seed for one chat and turn, so a probability entry rolls
  /// the same way for the same request when the request is retried.
  static int seedFor(String chatId, int turn) => chatId.hashCode ^ (turn * 7919);
}

/// The last [depth] messages of a window, oldest first. 0 means all of them.
List<String> scanWindow(List<String> recentMessages, int depth) {
  if (depth <= 0 || depth >= recentMessages.length) return recentMessages;
  return recentMessages.sublist(recentMessages.length - depth);
}

/// Clamps a user facing budget, in kilo characters.
int clampBudget(int kiloChars) => math.max(1, math.min(64, kiloChars));
