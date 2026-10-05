import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../workspace/app_dirs.dart';
import 'skill.dart';

/// Where skill records live in preferences.
const _recordsKey = 'skills_records';

/// Rejects archives larger than this before even looking inside.
const skillImportMaxBytes = 200 * 1024 * 1024;

/// Rejects an extraction whose contents exceed this in total.
const skillImportMaxExtractedBytes = 500 * 1024 * 1024;

/// Owner of the installed skills: the files under the app skills directory
/// plus one small record per skill in preferences.
///
/// A skill is a directory named by its id holding a `SKILL.md` with
/// frontmatter (`name`, `description`). The prompt only lists the installed
/// ids; the model fetches the full instructions through the `read_skill`
/// tool, which is why this store also counts uses.
class SkillStore extends ChangeNotifier {
  SkillStore._(this._sp, this._dir);

  final SharedPreferences _sp;
  final Directory? _dir;

  final List<Skill> _skills = [];

  /// The in-memory view, sorted by id.
  List<Skill> get skills => List.unmodifiable(_skills);

  /// The directory skills live in, null when the platform gave us none
  /// (tests without a documents directory). Reads still work from memory;
  /// imports report an error instead of crashing.
  Directory? get dir => _dir;

  static Future<SkillStore> load(SharedPreferences sp, {Directory? dir}) async {
    final root = dir ?? await _resolveRoot();
    final store = SkillStore._(sp, root);
    await store._rescan();
    return store;
  }

  static Future<Directory?> _resolveRoot() async {
    try {
      return await AppDirs.skills();
    } catch (_) {
      // path_provider is unavailable (unit tests). A fresh temp directory
      // keeps each load isolated instead of sharing state across tests.
      try {
        return await Directory.systemTemp.createTemp('paradise-skills');
      } catch (_) {
        return null;
      }
    }
  }

  Skill? byId(String id) {
    final needle = id.trim();
    for (final s in _skills) {
      if (s.id == needle) return s;
    }
    return null;
  }

  /// The enabled skills a role sees. A null [filter] follows the global
  /// set (every enabled skill); an explicit list names exactly the skills
  /// that role may use. Unknown ids are dropped silently so a deleted
  /// skill never breaks a role that named it.
  List<Skill> resolveFor(List<String>? filter) {
    final enabled = [for (final s in _skills) if (s.enabled) s];
    if (filter == null) return enabled;
    final allowed = filter.toSet();
    return [for (final s in enabled) if (allowed.contains(s.id)) s];
  }

  Future<void> rescan() async {
    await _rescan();
  }

  Future<void> _rescan() async {
    final root = _dir;
    if (root == null) {
      _skills.clear();
      notifyListeners();
      return;
    }
    if (!await root.exists()) {
      try {
        await root.create(recursive: true);
      } catch (_) {}
    }
    final records = _readRecords();
    // drop records whose directory went missing
    for (final id in records.keys.toList()) {
      final md = File(p.join(root.path, id, 'SKILL.md'));
      if (!await md.exists()) records.remove(id);
    }
    // adopt directories that have no record yet (user dropped files by hand)
    try {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final id = p.basename(entity.path);
        if (id.isEmpty || id.startsWith('.')) continue;
        if (records.containsKey(id)) continue;
        final md = File(p.join(root.path, id, 'SKILL.md'));
        if (!await md.exists()) continue;
        final now = DateTime.now().toUtc();
        records[id] = _Record(id: id, enabled: true, useCount: 0, source: SkillSource.file, installedAt: now, updatedAt: now);
      }
    } catch (_) {}
    _saveRecords(records);
    final next = <Skill>[];
    for (final record in records.values) {
      next.add(await _fromDisk(root, record));
    }
    next.sort((a, b) => a.id.compareTo(b.id));
    _skills
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  Map<String, _Record> _readRecords() {
    final out = <String, _Record>{};
    try {
      final raw = _sp.getString(_recordsKey);
      if (raw == null) return out;
      for (final e in (jsonDecode(raw) as List)) {
        final r = _Record.fromJson(Map<String, dynamic>.from(e as Map));
        if (r.id.isNotEmpty) out[r.id] = r;
      }
    } catch (_) {}
    return out;
  }

  void _saveRecords(Map<String, _Record> records) {
    try {
      _sp.setString(_recordsKey, jsonEncode([for (final r in records.values) r.toJson()]));
    } catch (_) {}
  }

  Future<void> _putRecord(_Record record) async {
    final records = _readRecords();
    records[record.id] = record;
    _saveRecords(records);
  }

  Future<Skill> _fromDisk(Directory root, _Record record) async {
    final dirPath = p.join(root.path, record.id);
    final mdPath = p.join(dirPath, 'SKILL.md');
    var name = record.id;
    var description = '';
    try {
      final doc = SkillDoc.parse(await File(mdPath).readAsString());
      if (doc.name.trim().isNotEmpty) name = doc.name.trim();
      description = doc.description.trim();
    } catch (_) {}
    return Skill(
      id: record.id,
      name: name,
      description: description,
      dir: dirPath,
      mdPath: mdPath,
      enabled: record.enabled,
      useCount: record.useCount,
      source: record.source,
      installedAt: record.installedAt,
      updatedAt: record.updatedAt,
    );
  }

  void _replace(Skill skill) {
    final at = _skills.indexWhere((e) => e.id == skill.id);
    if (at >= 0) {
      _skills[at] = skill;
    } else {
      _skills.add(skill);
      _skills.sort((a, b) => a.id.compareTo(b.id));
    }
  }

  Directory _requireRoot() {
    final root = _dir;
    if (root == null) throw StateError('Skills directory is unavailable.');
    return root;
  }

  /// Imports a pasted `SKILL.md` document.
  Future<Skill> importFromText(String markdown, [SkillSource source = SkillSource.paste]) async {
    final doc = SkillDoc.parse(markdown);
    final errors = doc.validate();
    if (errors.isNotEmpty) throw FormatException('Invalid skill: ${errors.join(', ')}.');
    final root = _requireRoot();
    final id = await _allocateId(root, skillSlug(doc.name));
    await _writeFiles(root, id, {'SKILL.md': utf8.encode(markdown)});
    return _register(root, id, source);
  }

  /// Imports a `.md` or `.zip` file from disk.
  Future<Skill> importFromFile(String hostPath) async {
    final file = File(hostPath);
    if (!await file.exists()) throw FileSystemException('File not found', hostPath);
    final ext = p.extension(hostPath).toLowerCase();
    if (ext == '.md') {
      return importFromText(await file.readAsString(), SkillSource.file);
    }
    if (ext == '.zip') {
      final root = _requireRoot();
      final files = _extractZip(await _readBounded(file, skillImportMaxBytes));
      return _commitFiles(root, files, SkillSource.file);
    }
    throw FormatException('Unsupported skill file type: $ext.');
  }

  /// Imports a skill from a GitHub URL: a repo, a `tree` subdirectory, or a
  /// direct link to a `SKILL.md`. The archive is downloaded as a zip and the
  /// skill inside it is installed.
  Future<Skill> importFromGitHub(String url, {Future<void>? cancelSignal}) async {
    final root = _requireRoot();
    var cancelled = false;
    unawaited(cancelSignal?.then((_) => cancelled = true));
    final ref = GitHubSkillRef.parse(url);
    final branch = await _defaultBranch(ref, cancelSignal: cancelSignal);
    if (cancelled) throw const FormatException('Import cancelled.');
    final bytes = await _downloadZip(ref, branch, cancelSignal: cancelSignal);
    if (cancelled) throw const FormatException('Import cancelled.');
    final files = _extractZip(bytes, subdir: ref.subdir, stripSingleRoot: true);
    return _commitFiles(root, files, SkillSource.url);
  }

  Future<Skill> _commitFiles(Directory root, Map<String, List<int>> files, SkillSource source) async {
    final md = files['SKILL.md'];
    if (md == null) throw const FormatException('SKILL.md not found.');
    final doc = SkillDoc.parse(utf8.decode(md));
    final errors = doc.validate();
    if (errors.isNotEmpty) throw FormatException('Invalid SKILL.md: ${errors.join(', ')}.');
    final id = await _allocateId(root, skillSlug(doc.name));
    await _writeFiles(root, id, files);
    try {
      return await _register(root, id, source);
    } catch (_) {
      try {
        await Directory(p.join(root.path, id)).delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  Future<Skill> _register(Directory root, String id, SkillSource source) async {
    final now = DateTime.now().toUtc();
    final record = _Record(id: id, enabled: true, useCount: 0, source: source, installedAt: now, updatedAt: now);
    await _putRecord(record);
    final skill = await _fromDisk(root, record);
    _replace(skill);
    notifyListeners();
    return skill;
  }

  Future<String> _allocateId(Directory root, String base) async {
    var id = base.isEmpty ? 'skill' : base;
    var n = 2;
    while (await _idTaken(root, id)) {
      id = '$base-$n';
      n++;
    }
    return id;
  }

  Future<bool> _idTaken(Directory root, String id) async {
    if (_skills.any((s) => s.id == id)) return true;
    if (_readRecords().containsKey(id)) return true;
    return Directory(p.join(root.path, id)).exists();
  }

  Future<void> _writeFiles(Directory root, String id, Map<String, List<int>> files) async {
    final dest = Directory(p.join(root.path, id));
    if (await dest.exists()) await dest.delete(recursive: true);
    await dest.create(recursive: true);
    final canonRoot = p.canonicalize(dest.path);
    for (final entry in files.entries) {
      final rel = entry.key.replaceAll('\\', '/');
      if (rel.isEmpty || rel.startsWith('/') || rel.split('/').contains('..')) {
        throw const FormatException('Archive entry escapes the skill directory.');
      }
      final destPath = p.join(dest.path, rel);
      final canonDest = p.canonicalize(destPath);
      if (canonDest != canonRoot && !p.isWithin(canonRoot, canonDest)) {
        throw const FormatException('Archive entry escapes the skill directory.');
      }
      await Directory(p.dirname(destPath)).create(recursive: true);
      await File(destPath).writeAsBytes(entry.value, flush: true);
    }
  }

  /// Reads the full instructions of one skill. Returns null when the skill
  /// is unknown or disabled. A successful read bumps the use count so the
  /// listing can put frequently used skills first.
  Future<String?> readSkill(String id) async {
    final skill = byId(id.trim());
    if (skill == null || !skill.enabled) return null;
    try {
      final text = await File(skill.mdPath).readAsString();
      unawaited(incrementUse(skill.id));
      const cap = 20000;
      if (text.length <= cap) return text;
      return '${text.substring(0, cap)}\n\n[truncated, ${text.length} characters in total]';
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String id) async {
    final root = _requireRoot();
    final records = _readRecords();
    records.remove(id);
    _saveRecords(records);
    try {
      final dir = Directory(p.join(root.path, id));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
    _skills.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final skill = byId(id);
    if (skill == null) return;
    final next = skill.copyWith(enabled: enabled, updatedAt: DateTime.now().toUtc());
    _replace(next);
    final records = _readRecords();
    final prev = records[id];
    records[id] = _Record(
      id: id,
      enabled: enabled,
      useCount: next.useCount,
      source: next.source,
      installedAt: prev?.installedAt ?? next.installedAt,
      updatedAt: next.updatedAt,
    );
    _saveRecords(records);
    notifyListeners();
  }

  Future<void> incrementUse(String id) async {
    final skill = byId(id);
    if (skill == null) return;
    final next = skill.copyWith(useCount: skill.useCount + 1, updatedAt: DateTime.now().toUtc());
    _replace(next);
    final records = _readRecords();
    final prev = records[id];
    if (prev != null) {
      records[id] = prev.copyWith(useCount: next.useCount, updatedAt: next.updatedAt);
      _saveRecords(records);
    }
    notifyListeners();
  }

  Future<void> updateBody(String id, String markdown) async {
    final skill = byId(id);
    if (skill == null) throw StateError('Unknown skill: $id');
    final doc = SkillDoc.parse(markdown);
    final errors = doc.validate();
    if (errors.isNotEmpty) throw FormatException('Invalid skill: ${errors.join(', ')}.');
    await File(skill.mdPath).writeAsString(markdown, flush: true);
    final next = skill.copyWith(
      name: doc.name.trim().isEmpty ? skill.name : doc.name.trim(),
      description: doc.description,
      updatedAt: DateTime.now().toUtc(),
    );
    _replace(next);
    final records = _readRecords();
    final prev = records[id];
    if (prev != null) {
      records[id] = prev.copyWith(updatedAt: next.updatedAt);
      _saveRecords(records);
    }
    notifyListeners();
  }

  Future<File> exportZip(String id, Directory outDir) async {
    final skill = byId(id);
    if (skill == null) throw StateError('Unknown skill: $id');
    final files = <String, List<int>>{};
    await for (final entity in Directory(skill.dir).list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = p.relative(entity.path, from: skill.dir).replaceAll('\\', '/');
      if (rel.split('/').contains('..')) throw const FormatException('Invalid file name.');
      files[rel] = await entity.readAsBytes();
    }
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final out = File(p.join(outDir.path, '$id.zip'));
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    await out.writeAsBytes(ZipEncoder().encode(archive), flush: true);
    return out;
  }

  // ------------------------------------------------------------ networking

  Future<String> _defaultBranch(GitHubSkillRef ref, {Future<void>? cancelSignal}) async {
    if (ref.ref != null && ref.ref!.isNotEmpty) return ref.ref!;
    var cancelled = false;
    unawaited(cancelSignal?.then((_) => cancelled = true));
    try {
      final res = await http.get(Uri.https('api.github.com', '/repos/${ref.owner}/${ref.repo}'), headers: const {'User-Agent': 'paradise', 'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 15));
      if (cancelled) return 'main';
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && '${decoded['default_branch'] ?? ''}'.trim().isNotEmpty) {
          return '${decoded['default_branch']}'.trim();
        }
      }
    } catch (_) {}
    return 'main';
  }

  Future<List<int>> _downloadZip(GitHubSkillRef ref, String branch, {Future<void>? cancelSignal}) async {
    var cancelled = false;
    unawaited(cancelSignal?.then((_) => cancelled = true));
    final client = http.Client();
    try {
      Future<http.StreamedResponse> get(String resolved) {
        final req = http.Request('GET', Uri.https('codeload.github.com', '/${ref.owner}/${ref.repo}/zip/$resolved'));
        req.headers['User-Agent'] = 'paradise';
        return client.send(req);
      }

      var response = await get(branch);
      if (response.statusCode == 404 && (ref.ref == null || ref.ref!.isEmpty) && branch == 'main') {
        await response.stream.listen(null).cancel();
        response = await get('master');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.listen(null).cancel();
        throw HttpException('Download failed (${response.statusCode}).');
      }
      final total = response.contentLength;
      if (total != null && total > skillImportMaxBytes) {
        await response.stream.listen(null).cancel();
        throw const FormatException('Archive exceeds 200 MB.');
      }
      final out = <int>[];
      await for (final chunk in response.stream) {
        if (cancelled) throw const FormatException('Import cancelled.');
        out.addAll(chunk);
        if (out.length > skillImportMaxBytes) throw const FormatException('Archive exceeds 200 MB.');
      }
      return out;
    } finally {
      client.close();
    }
  }
}

class _Record {
  _Record({required this.id, required this.enabled, required this.useCount, required this.source, required this.installedAt, required this.updatedAt});

  final String id;
  final bool enabled;
  final int useCount;
  final SkillSource source;
  final DateTime installedAt;
  final DateTime updatedAt;

  _Record copyWith({bool? enabled, int? useCount, DateTime? updatedAt}) => _Record(
        id: id,
        enabled: enabled ?? this.enabled,
        useCount: useCount ?? this.useCount,
        source: source,
        installedAt: installedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {'id': id, 'enabled': enabled, 'useCount': useCount, 'source': source.name, 'installedAt': installedAt.toIso8601String(), 'updatedAt': updatedAt.toIso8601String()};

  factory _Record.fromJson(Map<String, dynamic> j) => _Record(
        id: '${j['id'] ?? ''}',
        enabled: j['enabled'] as bool? ?? true,
        useCount: (j['useCount'] as num?)?.toInt() ?? 0,
        source: Skill.sourceOf(j['source'] as String?),
        installedAt: DateTime.tryParse('${j['installedAt'] ?? ''}')?.toUtc() ?? DateTime.now().toUtc(),
        updatedAt: DateTime.tryParse('${j['updatedAt'] ?? ''}')?.toUtc() ?? DateTime.now().toUtc(),
      );
}

Future<List<int>> _readBounded(File file, int max) async {
  final length = await file.length();
  if (length > max) throw const FormatException('Archive exceeds 200 MB.');
  return file.readAsBytes();
}

/// Unpacks a zip into `path -> bytes`, narrowed to the directory holding
/// `SKILL.md`. Runs synchronously; skills are small enough that an isolate
/// would cost more than it saves.
Map<String, List<int>> _extractZip(List<int> bytes, {String? subdir, bool stripSingleRoot = false}) {
  final archive = ZipDecoder().decodeBytes(bytes);
  var entries = <String, ArchiveFile>{};
  for (final file in archive) {
    if (!file.isFile) continue;
    final name = _safeEntryName(file.name);
    if (name == null) continue;
    entries[name] = file;
  }
  if (entries.isEmpty) throw const FormatException('Archive contains no files.');
  if (stripSingleRoot) entries = _stripSingleRoot(entries);
  if (subdir != null && subdir.trim().isNotEmpty) entries = _takePrefix(entries, _posixRel(subdir));
  entries = _narrowToSkillRoot(entries);
  var total = 0;
  final out = <String, List<int>>{};
  for (final entry in entries.entries) {
    final content = (entry.value.content as List<int>);
    total += content.length;
    if (total > skillImportMaxExtractedBytes) throw const FormatException('Extracted skill exceeds 500 MB.');
    out[entry.key] = content;
  }
  return out;
}

String? _safeEntryName(String raw) {
  var name = raw.replaceAll('\\', '/');
  while (name.startsWith('./')) {
    name = name.substring(2);
  }
  while (name.startsWith('/')) {
    name = name.substring(1);
  }
  if (name.isEmpty || name.endsWith('/')) return null;
  final normalized = p.posix.normalize(name);
  if (normalized.isEmpty || normalized == '.' || normalized.startsWith('/') || normalized.split('/').contains('..')) {
    throw const FormatException('Archive entry escapes its directory.');
  }
  return normalized;
}

String _posixRel(String value) {
  var path = value.replaceAll('\\', '/');
  while (path.startsWith('/')) {
    path = path.substring(1);
  }
  if (path.endsWith('/')) path = path.substring(0, path.length - 1);
  return p.posix.normalize(path);
}

Map<String, ArchiveFile> _stripSingleRoot(Map<String, ArchiveFile> files) {
  final roots = <String>{};
  for (final name in files.keys) {
    roots.add(name.split('/').first);
  }
  if (roots.length != 1) return files;
  final root = roots.single;
  if (root == 'SKILL.md') return files;
  return _takePrefix(files, root);
}

Map<String, ArchiveFile> _takePrefix(Map<String, ArchiveFile> files, String prefix) {
  if (prefix.isEmpty || prefix == '.') return files;
  final lead = '$prefix/';
  final out = <String, ArchiveFile>{};
  for (final entry in files.entries) {
    if (entry.key == prefix) continue;
    if (entry.key.startsWith(lead)) out[entry.key.substring(lead.length)] = entry.value;
  }
  if (out.isEmpty) throw FormatException('Archive is missing $prefix.');
  return out;
}

Map<String, ArchiveFile> _narrowToSkillRoot(Map<String, ArchiveFile> files) {
  if (files.containsKey('SKILL.md')) return files;
  final dirs = <String>{};
  for (final name in files.keys) {
    final parts = name.split('/');
    if (parts.length == 2 && parts[1] == 'SKILL.md') dirs.add(parts[0]);
  }
  if (dirs.isEmpty) throw const FormatException('SKILL.md not found.');
  final chosen = (dirs.toList()..sort()).first;
  return _takePrefix(files, chosen);
}

/// A GitHub location of a skill: a repo, an optional ref and an optional
/// subdirectory inside it.
class GitHubSkillRef {
  const GitHubSkillRef({required this.owner, required this.repo, this.ref, this.subdir});

  final String owner;
  final String repo;
  final String? ref;
  final String? subdir;

  static GitHubSkillRef parse(String raw) {
    final parsed = tryParse(raw);
    if (parsed == null) throw FormatException('Not a GitHub skill URL: $raw');
    return parsed;
  }

  static GitHubSkillRef? tryParse(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    final parts = [for (final s in uri.pathSegments) if (s.isNotEmpty) s];
    if (host == 'raw.githubusercontent.com') {
      if (parts.length < 3) return null;
      return GitHubSkillRef(owner: parts[0], repo: _stripGit(parts[1]), ref: parts[2], subdir: _dirOf(parts.skip(3).join('/')));
    }
    if (host != 'github.com' && host != 'www.github.com') return null;
    if (parts.length < 2) return null;
    final owner = parts[0];
    final repo = _stripGit(parts[1]);
    if (parts.length == 2) return GitHubSkillRef(owner: owner, repo: repo);
    final kind = parts[2];
    if (kind != 'tree' && kind != 'blob' && kind != 'raw') return GitHubSkillRef(owner: owner, repo: repo);
    if (parts.length < 4) return GitHubSkillRef(owner: owner, repo: repo);
    final ref = parts[3];
    final rest = parts.skip(4).join('/');
    if (kind == 'tree') return GitHubSkillRef(owner: owner, repo: repo, ref: ref, subdir: rest.isEmpty ? null : rest);
    return GitHubSkillRef(owner: owner, repo: repo, ref: ref, subdir: _dirOf(rest));
  }

  static String _stripGit(String repo) => repo.endsWith('.git') ? repo.substring(0, repo.length - 4) : repo;

  static String? _dirOf(String filePath) {
    if (filePath.isEmpty) return null;
    final dir = p.posix.dirname(filePath.replaceAll('\\', '/'));
    if (dir == '.' || dir == '/') return null;
    return dir;
  }
}
