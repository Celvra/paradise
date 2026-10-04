/// Replaces [before] with [after] as a unified diff with `@@` hunks.
///
/// The model never sees this. It exists so the write review sheet has something
/// to show and so the step row can say what changed without the model having to
/// narrate it in prose.
///
/// [maxLines] caps the output rather than trusting the input to be a reasonable
/// size. A 40 MB write produces a truncated diff and a count, not 40 MB of
/// patch text.
String unifiedDiff(String before, String after, String path, {int context = 3, int maxLines = 400}) {
  final a = before.split('\n');
  final b = after.split('\n');
  final changes = diffEdits(a, b);
  if (changes.isEmpty) return '';

  final hunks = groupIntoHunks(a, b, changes, context: context);
  final out = StringBuffer('--- a/$path\n+++ b/$path\n');
  var emitted = 0;
  for (final h in hunks) {
    final head = '@@ -${h.oldStart},${h.oldCount} +${h.newStart},${h.newCount} @@';
    if (emitted + h.lines.length > maxLines) {
      final room = maxLines - emitted;
      if (room > 0) {
        out.writeln(head);
        for (final l in h.lines.take(room)) {
          out.writeln(l);
        }
      }
      out.writeln('... diff truncated at $maxLines lines');
      return out.toString();
    }
    out.writeln(head);
    for (final l in h.lines) {
      out.writeln(l);
    }
    emitted += h.lines.length;
  }
  return out.toString();
}

String _show(String line) => line.endsWith('\r') ? line.substring(0, line.length - 1) : line;

/// One real change. Lines that both sides share are not here at all: they are
/// context, and the hunk builder pulls those from [a] or [b] when it needs
/// them. Keeping them out is what stops a one line change from reporting the
/// whole file.
class DiffEdit {
  const DiffEdit(this.added, this.text, this.oldLine, this.newLine);

  /// True for a line only in [b].
  final bool added;
  final String text;

  /// 1 based, 0 when the line does not exist on that side.
  final int oldLine;
  final int newLine;
}

/// The shortest edit script that turns [a] into [b]: only additions and
/// deletions, in output order.
///
/// Myers, not an LCS table. The table form is `a.length * b.length` ints, which
/// is gigabytes for two files of a few thousand lines and would have been the
/// first thing to crash on a large rewrite.
List<DiffEdit> diffEdits(List<String> a, List<String> b, {int maxSteps = 20000}) {
  final n = a.length;
  final m = b.length;
  // peel the common prefix and suffix off first. On a typical edit that removes
  // nearly everything and leaves the quadratic core tiny.
  var pre = 0;
  while (pre < n && pre < m && a[pre] == b[pre]) {
    pre++;
  }
  var suf = 0;
  while (suf < n - pre && suf < m - pre && a[n - 1 - suf] == b[m - 1 - suf]) {
    suf++;
  }
  return _myers(a.sublist(pre, n - suf), b.sublist(pre, m - suf), pre, maxSteps);
}

/// [oldBase] and [newBase] are where the slices start in the original files, so
/// the line numbers coming out are absolute rather than relative to the slice.
List<DiffEdit> _myers(List<String> a, List<String> b, int base, int maxSteps) {
  final n = a.length;
  final m = b.length;
  if (n == 0 && m == 0) return const [];
  if (n == 0) return [for (var j = 0; j < m; j++) DiffEdit(true, b[j], 0, base + j + 1)];
  if (m == 0) return [for (var i = 0; i < n; i++) DiffEdit(false, a[i], base + i + 1, 0)];

  final max = n + m;
  if (max > maxSteps) return _deleteThenInsert(a, b, base);

  final offset = max;
  var v = List<int>.filled(2 * max + 1, 0);
  final trace = <List<int>>[];
  var found = -1;

  outer:
  for (var d = 0; d <= max; d++) {
    trace.add(v);
    for (var k = -d; k <= d; k += 2) {
      final int x;
      if (k == -d || (k != d && v[k - 1 + offset] < v[k + 1 + offset])) {
        x = v[k + 1 + offset];
      } else {
        x = v[k - 1 + offset] + 1;
      }
      final y = x - k;
      var i = x;
      var j = y;
      while (i < n && j < m && a[i] == b[j]) {
        i++;
        j++;
      }
      v[k + offset] = i;
      if (i >= n && j >= m) {
        found = d;
        break outer;
      }
    }
    // a fresh array per step, trace[d] has to stay the state *before* step d
    v = List<int>.from(v);
  }
  if (found < 0) return _deleteThenInsert(a, b, base);

  final rev = <DiffEdit>[];
  var x = n;
  var y = m;
  for (var d = found; d > 0; d--) {
    final prev = trace[d - 1];
    final k = x - y;
    final prevK = (k == -d || (k != d && prev[k - 1 + offset] < prev[k + 1 + offset])) ? k + 1 : k - 1;
    final prevX = prev[prevK + offset];
    final prevY = prevX - prevK;
    // everything between prevX/prevY and x/y is a shared line, so it is context
    while (x > prevX && y > prevY) {
      x--;
      y--;
    }
    if (x > prevX) {
      x--;
      rev.add(DiffEdit(false, a[x], base + x + 1, base + y));
    } else if (y > prevY) {
      y--;
      rev.add(DiffEdit(true, b[y], base + x, base + y + 1));
    }
  }
  return rev.reversed.toList();
}

/// The fallback past [maxSteps]. Not minimal, so it reports a bigger change than
/// really happened, which is the safe direction for a confirmation dialog.
List<DiffEdit> _deleteThenInsert(List<String> a, List<String> b, int base) => [
      for (var i = 0; i < a.length; i++) DiffEdit(false, a[i], base + i + 1, base),
      for (var j = 0; j < b.length; j++) DiffEdit(true, b[j], base + a.length, base + j + 1),
    ];

class DiffHunk {
  const DiffHunk({required this.oldStart, required this.oldCount, required this.newStart, required this.newCount, required this.lines});
  final int oldStart;
  final int oldCount;
  final int newStart;
  final int newCount;

  /// Rendered lines, each already carrying its leading `+`, `-` or space.
  final List<String> lines;
}

/// Drops everything unchanged and merges what is left into hunks carrying
/// [context] shared lines on each side. Two change runs closer together than
/// twice the context end up in one hunk, which is what a reader expects and
/// what keeps a scattered edit from printing the file between every pair.
List<DiffHunk> groupIntoHunks(List<String> a, List<String> b, List<DiffEdit> changes, {int context = 3}) {
  if (changes.isEmpty) return const [];

  // deletions before additions at the same spot, which is the order every diff
  // tool prints a replacement in
  final sorted = [...changes]..sort((x, y) {
      final px = x.added ? x.newLine : x.oldLine;
      final py = y.added ? y.newLine : y.oldLine;
      if (px != py) return px - py;
      if (x.added == y.added) return 0;
      return x.added ? 1 : -1;
    });

  final runs = <List<DiffEdit>>[];
  for (final e in sorted) {
    if (runs.isEmpty) {
      runs.add([e]);
      continue;
    }
    final last = runs.last.last;
    final at = e.added ? e.newLine : e.oldLine;
    final lastAt = last.added ? last.newLine : last.oldLine;
    // the runs are close enough that the context windows would overlap
    if (at - lastAt <= context * 2 + 1) {
      runs.last.add(e);
    } else {
      runs.add([e]);
    }
  }

  return [for (final run in runs) _hunk(a, b, run, context)];
}

DiffHunk _hunk(List<String> a, List<String> b, List<DiffEdit> run, int context) {
  final hasDelete = run.any((e) => !e.added);
  // a deletion is surrounded by lines from a, a pure insertion by lines from b.
  // both are the same text where nothing changed, so this only decides which
  // copy of an identical line we reach for
  final src = hasDelete ? a : b;
  final first = run.first;
  final last = run.last;

  final lines = <String>[];
  for (var k = context; k >= 1; k--) {
    final idx = (hasDelete ? first.oldLine : first.newLine) - 1 - k;
    if (idx < 0) break;
    lines.add(' ${_show(src[idx])}');
  }
  for (final e in run) {
    lines.add('${e.added ? '+' : '-'}${_show(e.text)}');
  }
  for (var k = 0; k < context; k++) {
    final idx = (hasDelete ? last.oldLine : last.newLine) + k;
    if (idx >= src.length) break;
    lines.add(' ${_show(src[idx])}');
  }

  final oldStart = run.where((e) => !e.added).map((e) => e.oldLine).fold<int>(run.first.oldLine, (m, e) => e < m ? e : m);
  final newStart = run.map((e) => e.newLine).fold<int>(run.first.newLine, (m, e) => e > 0 && (e < m || m == 0) ? e : m);
  return DiffHunk(
    oldStart: oldStart == 0 ? run.first.oldLine : oldStart,
    oldCount: run.where((e) => !e.added).length,
    newStart: newStart == 0 ? run.first.newLine : newStart,
    newCount: run.where((e) => e.added).length,
    lines: lines,
  );
}

/// How many lines [after] adds and removes relative to [before], for the `+3 -1`
/// on the step row. Counts changes only, no context.
({int added, int removed}) diffCounts(String before, String after) {
  var added = 0;
  var removed = 0;
  for (final e in diffEdits(before.split('\n'), after.split('\n'))) {
    if (e.added) {
      added++;
    } else {
      removed++;
    }
  }
  return (added: added, removed: removed);
}