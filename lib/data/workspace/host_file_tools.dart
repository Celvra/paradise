import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import 'file_diff.dart';
import 'workspace_paths.dart';

/// Thrown for anything the caller can fix: a missing file, a binary read, an
/// edit that matched nowhere. The message is written to be shown to the model,
/// so it says what to do next rather than what went wrong.
class HostFileException implements Exception {
  HostFileException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReadFileResult {
  ReadFileResult({this.lines = const [], this.nextOffset, this.binary = false, this.hexPreview, this.imageBytes, this.imageMime, this.truncatedLine = false});

  /// Numbered, one entry per line, `000012|text`.
  final List<String> lines;

  /// Where the next page starts, set only when the read stopped early.
  final int? nextOffset;
  final bool binary;
  final String? hexPreview;
  final Uint8List? imageBytes;
  final String? imageMime;

  /// A single line longer than the per line cap was cut here.
  final bool truncatedLine;

  bool get isImage => imageBytes != null;
}

/// The filesystem half of the workspace. Knows nothing about the model, the
/// tools or the UI, which is what makes the read cap and the traversal rules
/// testable without a chat anywhere in sight.
class HostFileTools {
  HostFileTools(this.paths, {this.checkCancelled});

  final WorkspacePaths paths;

  /// Called between the steps of a long write. A cancel that arrives mid write
  /// is better than one that only lands on the next tool call.
  final void Function()? checkCancelled;

  /// Total text budget for one read_file call. A model asking for a whole
  /// minified bundle gets the first slice and an offset, not a blown context.
  static const int readCapBytes = 32 * 1024;

  /// How much of a file is checked for a null byte before calling it text.
  static const int binaryProbeBytes = 8 * 1024;

  /// Ceiling on one line. A file that is one 40 MB line is not a text file.
  static const int lineCapBytes = 2048;

  static const int listCap = 500;
  static const int globCap = 500;
  static const int defaultGrepLimit = 100;

  /// grep skips anything larger. A 300 MB log is not worth a regex pass and the
  /// model did not ask for it in the first place.
  static const int defaultMaxFileBytes = 2 * 1024 * 1024;

  static const Set<String> imageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'};

  static bool looksLikeImage(String path) => imageExtensions.contains(p.extension(path).toLowerCase());

  /// Whether a file is small and NUL free enough to be treated as text. The
  /// caller decides what to do with the answer; this only does the sniff.
  static Future<bool> sniffsAsText(File f) async {
    if (!await f.exists()) return false;
    final len = await f.length();
    if (len == 0) return true;
    final raf = await f.open();
    try {
      final n = len < binaryProbeBytes ? len : binaryProbeBytes;
      final buf = await raf.read(n);
      if (buf.indexOf(0) != -1) return false;
      utf8.decode(buf, allowMalformed: false);
      return true;
    } on FormatException {
      return false;
    } finally {
      await raf.close();
    }
  }

  static String _mimeFor(String path) {
    final e = p.extension(path).toLowerCase();
    if (e == '.png') return 'image/png';
    if (e == '.gif') return 'image/gif';
    if (e == '.webp') return 'image/webp';
    if (e == '.bmp') return 'image/bmp';
    return 'image/jpeg';
  }

  Future<ReadFileResult> readFile(String modelPath, {int? offset, int? limit, String? cwd}) async {
    final r = await _resolve(modelPath, cwd: cwd);
    final f = File(r.hostPath);
    // directory first. a path is one or the other, and when it is the directory the
    // useful message is the one naming the tool that would have worked
    if (await Directory(r.hostPath).exists()) throw HostFileException('${r.modelPath} is a directory, use list_dir');
    if (!await f.exists()) throw HostFileException('no such file: ${r.modelPath}');

    if (looksLikeImage(r.hostPath)) {
      return ReadFileResult(imageBytes: await f.readAsBytes(), imageMime: _mimeFor(r.hostPath));
    }
    final len = await f.length();
    final raf = await f.open();
    try {
      final probe = await raf.read(len < binaryProbeBytes ? len : binaryProbeBytes);
      if (probe.indexOf(0) != -1) return ReadFileResult(binary: true, hexPreview: _hexPreview(probe));
    } finally {
      await raf.close();
    }

    final from = (offset ?? 1) < 1 ? 1 : (offset ?? 1);
    return _readBoundedLines(f, start: from, limit: limit);
  }

  /// Reads by splitting bytes rather than by decoding the whole string, because
  /// a single 100 MB line decoded up front is a 100 MB string in the heap and
  /// then a second copy in the transcript.
  ///
  /// [start] is honoured by scanning and discarding the earlier lines rather
  /// than by decoding them, so paging through a huge file costs file size in
  /// time and one page in memory.
  ///
  /// A CR only ends a line when the next byte is not an LF, otherwise a CRLF
  /// file comes out with a blank line between every pair.
  Future<ReadFileResult> _readBoundedLines(File f, {required int start, int? limit}) async {
    final out = <String>[];
    var budget = readCapBytes;
    var number = 0;
    var nextOffset = 0;
    var cutLine = false;
    var pending = <int>[];

    ReadFileResult? flush() {
      number++;
      final line = _decodeLine(pending, cutLine);
      pending = <int>[];
      cutLine = false;
      if (number < start) return null;
      out.add('${number.toString().padLeft(6)}|$line');
      final cost = line.length + 8;
      if ((limit != null && out.length >= limit) || budget - cost <= 0) {
        nextOffset = number + 1;
        return ReadFileResult(lines: out, nextOffset: nextOffset);
      }
      budget -= cost;
      return null;
    }

    try {
      var at = 0;
      await for (final chunk in f.openRead()) {
        for (var i = 0; i < chunk.length; i++) {
          final b = chunk[i];
          if (b == 10) {
            // the LF of a CRLF, the line already ended on the CR
            if (at == 0 || chunk[i - 1] != 13) {
              final stop = flush();
              if (stop != null) return stop;
            }
            continue;
          }
          if (b == 13 && i + 1 >= chunk.length && chunk.length < 1 << 16) {
            // a CR at a chunk edge: hold it, the next chunk says whether an LF follows
            pending.add(b);
            continue;
          }
          if (b == 13) {
            final stop = flush();
            if (stop != null) return stop;
            if (chunk[i + 1] == 10) i++;
            continue;
          }
          if (pending.length < lineCapBytes) {
            pending.add(b);
          } else if (!cutLine) {
            // mark once and stop growing, the line is already over budget
            cutLine = true;
          }
        }
        at += chunk.length;
      }
      if (pending.isNotEmpty) {
        final stop = flush();
        if (stop != null) return stop;
      }
    } catch (_) {
      // whatever was collected before the read failed is still worth returning
    }
    return ReadFileResult(lines: out, nextOffset: nextOffset, truncatedLine: cutLine);
  }

  /// Trims to the cap without splitting a code point. Without the backoff a CJK
  /// line cut at the boundary decodes to a replacement character.
  static String _decodeLine(List<int> bytes, bool truncated) {
    var end = bytes.length;
    while (end > 0 && (bytes[end - 1] & 0xc0) == 0x80) {
      end--;
    }
    while (end > 0 && (bytes[end - 1] & 0xc0) == 0x80) {
      end--;
    }
    if (end > 0 && (bytes[end - 1] & 0x80) != 0) {
      final lead = bytes[end - 1];
      final need = lead >= 0xf0 ? 4 : lead >= 0xe0 ? 3 : lead >= 0xc0 ? 2 : 1;
      if (end - 1 + need > bytes.length) end--;
    }
    return '${utf8.decode(bytes.sublist(0, end), allowMalformed: true)}${truncated ? ' [line truncated]' : ''}';
  }

  static String _hexPreview(Uint8List probe) {
    final n = probe.length < 256 ? probe.length : 256;
    return [for (var i = 0; i < n; i++) probe[i].toRadixString(16).padLeft(2, '0')].join(' ');
  }

  /// [created] is sampled before the directory is made, so a write that fails
  /// partway does not report a file it never wrote.
  Future<WriteFileResult> writeFile(String modelPath, String content, {String? cwd}) async {
    final r = await _resolve(modelPath, cwd: cwd);
    if (paths.isReadOnlyPath(r.hostPath)) throw HostFileException('${r.modelPath} is read only');
    final f = File(r.hostPath);
    final created = !await f.exists();
    checkCancelled?.call();
    await f.parent.create(recursive: true);
    checkCancelled?.call();
    await f.writeAsString(content, flush: true);
    return WriteFileResult(hostPath: r.hostPath, modelPath: r.modelPath, bytes: utf8.encode(content).length, created: created);
  }

  /// Reads and rewrites in one step with no await between them, so there is no
  /// window for something else to change the file between the two halves.
  Future<EditFileResult> editFile(String modelPath, String oldText, String newText, {bool replaceAll = false, String? cwd}) async {
    final r = await _resolve(modelPath, cwd: cwd);
    if (paths.isReadOnlyPath(r.hostPath)) throw HostFileException('${r.modelPath} is read only');
    final f = File(r.hostPath);
    if (!await f.exists()) throw HostFileException('no such file: ${r.modelPath}, write_file creates it');
    final original = await f.readAsString();
    final applied = applyEdit(original, oldText, newText, replaceAll: replaceAll);
    if (!applied.ok) throw HostFileException(applied.message);
    checkCancelled?.call();
    await f.writeAsString(applied.updated, flush: true);
    return EditFileResult(
      hostPath: r.hostPath,
      modelPath: r.modelPath,
      updated: applied.updated,
      replacements: applied.replacements,
      strategy: applied.strategy,
      diff: unifiedDiff(original, applied.updated, r.modelPath),
      added: applied.added,
      removed: applied.removed,
    );
  }

  /// Exact, then line trimmed, then block anchored. Models reproduce whitespace
  /// from context imperfectly and refusing on that basis wastes a round trip on
  /// something the model could fix immediately.
  ///
  /// A trimmed or anchored match is one replacement by construction, so
  /// replace_all does not apply to those two and the count is reported as one.
  static EditOutcome applyEdit(String original, String oldText, String newText, {bool replaceAll = false}) {
    if (oldText.isEmpty) return const EditOutcome._fail('old_string is empty, there is nothing to replace');

    final count = _countOccurrences(original, oldText);
    if (count > 0) {
      if (count > 1 && !replaceAll) {
        return EditOutcome._fail('old_string matches $count places, pass replace_all or include more surrounding lines to make it unique');
      }
      final n = replaceAll ? count : 1;
      return EditOutcome._ok(original.replaceAll(oldText, newText), n, 'exact', _linesOf(newText), _linesOf(oldText));
    }

    final trimmed = _matchLines(original, oldText, anchorOnly: false);
    if (trimmed != null) return _splice(original, trimmed, newText, 'line-trimmed', _linesOf(oldText));

    final anchored = _matchLines(original, oldText, anchorOnly: true);
    if (anchored != null) return _splice(original, anchored, newText, 'block-anchor', _linesOf(oldText));

    return const EditOutcome._fail('old_string was not found, read_file the file again and copy the exact text of the lines to change');
  }

  static int _linesOf(String s) => s.isEmpty ? 0 : const LineSplitter().convert(s).length;

  static int _countOccurrences(String haystack, String needle) {
    var n = 0;
    var at = haystack.indexOf(needle);
    while (at != -1) {
      n++;
      at = haystack.indexOf(needle, at + needle.length);
    }
    return n;
  }

  /// The char range in [original] that [needle] stands for, or null.
  ///
  /// Lines are compared trimmed so the model's indentation drift does not
  /// matter, but the range returned is the original text with its real
  /// indentation, so the splice leaves everything around the change alone.
  ///
  /// [anchorOnly] matches the first and last line and treats what is between
  /// them as unknown. That is the shape of a function the model remembered by
  /// its signature but rewrote the body of, and the span is then however long
  /// the real block is rather than however long the needle was.
  static ({int start, int end})? _matchLines(String original, String needle, {required bool anchorOnly}) {
    final needleLines = const LineSplitter().convert(needle);
    if (needleLines.isEmpty) return null;
    if (anchorOnly && needleLines.length < 3) return null;
    final spans = _lineSpans(original);
    final first = needleLines.first.trim();
    final last = needleLines.last.trim();

    for (var i = 0; i < spans.length; i++) {
      if (_spanText(original, spans[i]).trim() != first) continue;
      if (!anchorOnly) {
        if (i + needleLines.length > spans.length) break;
        if (_spanText(original, spans[i + needleLines.length - 1]).trim() != last) continue;
        var hit = true;
        for (var j = 1; j < needleLines.length - 1; j++) {
          if (_spanText(original, spans[i + j]).trim() != needleLines[j].trim()) {
            hit = false;
            break;
          }
        }
        if (hit) return (start: spans[i].start, end: spans[i + needleLines.length - 1].end);
        continue;
      }
      // anchored: take the whole block between this line and the next that closes it
      for (var j = i + 1; j < spans.length; j++) {
        if (_spanText(original, spans[j]).trim() != last) continue;
        return (start: spans[i].start, end: spans[j].end);
      }
      return null;
    }
    return null;
  }

  static EditOutcome _splice(String original, ({int start, int end}) span, String newText, String strategy, int removed) =>
      EditOutcome._ok('${original.substring(0, span.start)}$newText${original.substring(span.end)}', 1, strategy, _linesOf(newText), removed);

  static String _spanText(String src, ({int start, int end}) span) => src.substring(span.start, span.end);

  /// Char range of every line including its terminator. Rebuilt from the
  /// original rather than by re-joining split lines, because \r\n would
  /// otherwise shift every offset after it.
  static List<({int start, int end})> _lineSpans(String s) {
    final out = <({int start, int end})>[];
    var start = 0;
    for (var i = 0; i < s.length; i++) {
      if (s.codeUnitAt(i) != 10) continue;
      out.add((start: start, end: i + 1));
      start = i + 1;
    }
    if (start < s.length) out.add((start: start, end: s.length));
    return out;
  }

  Future<ListDirResult> listDir(String modelPath, {int depth = 1, String? cwd}) async {
    final r = await _resolve(modelPath.isEmpty ? '.' : modelPath, cwd: cwd);
    final dir = Directory(r.hostPath);
    if (!await dir.exists()) throw HostFileException('no such directory: ${r.modelPath}');
    final entries = <ListDirEntry>[];
    final truncated = await _walk(dir, depth, entries);
    return ListDirResult(entries: entries, modelPath: r.modelPath, truncated: truncated);
  }

  /// Explicit stack rather than recursion, so a deep tree cannot blow the
  /// isolate's stack. [followLinks] stays false throughout: a link loop inside
  /// the workspace would otherwise hang the listing.
  /// [out.length] is the only stop condition. Returns whether it was hit, so the
  /// caller can tell a full listing from a capped one.
  Future<bool> _walk(Directory dir, int depth, List<ListDirEntry> out) async {
    final stack = <(Directory, int)>[(dir, depth)];
    while (stack.isNotEmpty) {
      final (d, left) = stack.removeLast();
      List<FileSystemEntity> kids;
      try {
        kids = await d.list(followLinks: false).toList();
      } catch (_) {
        continue;
      }
      kids.sort((x, y) {
        final dx = x is Directory ? 0 : 1;
        final dy = y is Directory ? 0 : 1;
        if (dx != dy) return dx - dy;
        return p.basename(x.path).toLowerCase().compareTo(p.basename(y.path).toLowerCase());
      });
      for (final k in kids) {
        final name = p.basename(k.path);
        if (name.startsWith('.')) continue;
        final isDir = k is Directory;
        int size = 0;
        DateTime? modified;
        try {
          final stat = k.statSync();
          size = stat.size;
          modified = stat.modified;
        } catch (_) {
          // a dangling link still belongs in the listing, just without a size
        }
        out.add(ListDirEntry(name: name, hostPath: k.path, isDirectory: isDir, size: size, modified: modified));
        if (out.length >= listCap) return true;
        if (isDir && left > 1) stack.add((k, left - 1));
      }
    }
    return false;
  }

  Future<GlobResult> glob(String pattern, {String? path, String? cwd}) async {
    final root = path == null || path.isEmpty ? paths.modelRoot : path;
    final r = await _resolve(root, cwd: cwd);
    final base = Directory(r.hostPath);
    if (!await base.exists()) throw HostFileException('no such directory: ${r.modelPath}');

    // A pattern that names a dot segment anywhere opts into the hidden tree. The
    // decision is about matching, not about walking, so dot directories are
    // always descended into and filtered at the file instead: the glob package
    // does match `.git/config` against `**/*`, which is not what a shell means.
    final skipDot = !pattern.split('/').any((e) => e.startsWith('.'));
    final matcher = Glob(pattern, recursive: true);
    final hits = <GlobHit>[];
    var truncated = false;
    final stack = <Directory>[base];
    while (stack.isNotEmpty) {
      final d = stack.removeLast();
      List<FileSystemEntity> kids;
      try {
        kids = await d.list(followLinks: false).toList();
      } catch (_) {
        continue;
      }
      for (final k in kids) {
        if (k is Directory) {
          stack.add(k);
          continue;
        }
        final rel = p.posix.joinAll(p.split(p.relative(k.path, from: base.path)));
        if (skipDot && rel.split('/').any((e) => e.startsWith('.'))) continue;
        if (matcher.matches(rel)) hits.add(GlobHit(modelPath: p.posix.join(r.modelPath, rel), hostPath: k.path));
        if (hits.length >= globCap) {
          truncated = true;
          break;
        }
      }
      if (truncated) break;
    }
    hits.sort((a, b) => a.modelPath.compareTo(b.modelPath));
    return GlobResult(hits: hits, truncated: truncated);
  }

  Future<GrepResult> grep(String pattern, {String? path, bool ignoreCase = false, int limit = defaultGrepLimit, int maxFileBytes = defaultMaxFileBytes, String? cwd}) async {
    final root = path == null || path.isEmpty ? paths.modelRoot : path;
    final r = await _resolve(root, cwd: cwd);
    final base = Directory(r.hostPath);
    final matches = <GrepMatch>[];
    var truncated = false;
    if (await base.exists()) {
      RegExp re;
      try {
        re = RegExp(pattern, caseSensitive: !ignoreCase);
      } catch (_) {
        // an invalid regex is almost always a literal the model wanted
        re = RegExp(RegExp.escape(pattern), caseSensitive: !ignoreCase);
      }
      final stack = <Directory>[base];
      while (stack.isNotEmpty && matches.length < limit) {
        final d = stack.removeLast();
        List<FileSystemEntity> kids;
        try {
          kids = await d.list(followLinks: false).toList();
        } catch (_) {
          continue;
        }
        for (final k in kids) {
          final name = p.basename(k.path);
          if (name.startsWith('.')) continue;
          if (k is Directory) {
            stack.add(k);
            continue;
          }
          final f = File(k.path);
          try {
            if (await f.length() > maxFileBytes) continue;
            final probe = await _probe(f);
            if (probe.indexOf(0) != -1) continue;
            final rel = p.relative(k.path, from: base.path);
            final lines = await f.readAsLines();
            for (var i = 0; i < lines.length; i++) {
              if (!re.hasMatch(lines[i])) continue;
              matches.add(GrepMatch(modelPath: p.posix.join(r.modelPath, p.split(rel).join('/')), line: i + 1, text: lines[i].trim()));
              if (matches.length >= limit) {
                truncated = true;
                break;
              }
            }
          } catch (_) {
            // unreadable or vanished, move on
          }
          if (matches.length >= limit) break;
        }
      }
    }
    return GrepResult(matches: matches, truncated: truncated);
  }

  static Future<Uint8List> _probe(File f) async {
    final raf = await f.open();
    try {
      final len = await f.length();
      return await raf.read(len < binaryProbeBytes ? len : binaryProbeBytes);
    } finally {
      await raf.close();
    }
  }

  Future<ResolvedPath> _resolve(String modelPath, {String? cwd}) async {
    try {
      return await paths.resolveReal(modelPath, cwd: cwd);
    } on PathResolutionException catch (e) {
      throw HostFileException(e.message);
    }
  }
}

class WriteFileResult {
  const WriteFileResult({required this.hostPath, required this.modelPath, required this.bytes, required this.created});
  final String hostPath;
  final String modelPath;
  final int bytes;

  /// Whether the file was not there before this call. Sampled before the
  /// directory is created, so a write that failed halfway does not claim to
  /// have made a file it never wrote.
  final bool created;
}

class EditFileResult {
  const EditFileResult({required this.hostPath, required this.modelPath, required this.updated, required this.replacements, required this.strategy, required this.diff, required this.added, required this.removed});
  final String hostPath;
  final String modelPath;
  final String updated;
  final int replacements;

  /// `exact`, `line-trimmed` or `block-anchor`, reported so the user can tell a
  /// clean replace from one the model got only approximately right.
  final String strategy;

  /// Never sent to the model. The step row and the review sheet show this.
  final String diff;
  final int added;
  final int removed;
}

class EditOutcome {
  const EditOutcome._ok(this.updated, this.replacements, this.strategy, this.added, this.removed)
      : ok = true,
        message = '';
  const EditOutcome._fail(this.message)
      : ok = false,
        updated = '',
        replacements = 0,
        strategy = '',
        added = 0,
        removed = 0;

  final bool ok;
  final String updated;

  /// Written to be shown to the model, so it says what to do next.
  final String message;
  final int replacements;
  final String strategy;
  final int added;
  final int removed;
}

class ListDirEntry {
  const ListDirEntry({required this.name, required this.hostPath, required this.isDirectory, required this.size, this.modified});
  final String name;
  final String hostPath;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
}

class ListDirResult {
  const ListDirResult({required this.entries, required this.modelPath, required this.truncated});
  final List<ListDirEntry> entries;
  final String modelPath;
  final bool truncated;
}

class GlobHit {
  const GlobHit({required this.modelPath, required this.hostPath});
  final String modelPath;
  final String hostPath;
}

class GlobResult {
  const GlobResult({required this.hits, required this.truncated});
  final List<GlobHit> hits;
  final bool truncated;
}

class GrepMatch {
  const GrepMatch({required this.modelPath, required this.line, required this.text});
  final String modelPath;
  final int line;
  final String text;
}

class GrepResult {
  const GrepResult({required this.matches, required this.truncated});
  final List<GrepMatch> matches;
  final bool truncated;
}
