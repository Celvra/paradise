/// The v2 backup container: a zip of many `.oii` files plus asset bytes.
///
/// Layout (all paths inside the zip use `/`):
///
/// * `manifest.oii` — node `backup [ kind, version, app, at, files, missing ]`.
///   `files` is an array of `(map)`s with `path`, `sha`, `size`, `mime` and
///   `owner` (which chat/sticker/setting referenced it); `missing` lists
///   referenced files that could not be read at export time.
/// * `chats/<safe id>.oii` — node `chat`, attributes are the `Chat.toJson()`
///   map verbatim (msgs ride as an array of maps).
/// * `personas.oii` — node `personas [ items: [...] ]`.
/// * `stickers.oii` / `memory.oii` — nodes `stickers` / `memory` holding the
///   existing `{kind, version, items}` envelopes verbatim, so one section on
///   its own is still shaped like the file the old importer accepts.
/// * `settings.oii` — node `settings` with the flat settings map.
/// * `ai.oii` — node `ai` with the sanitized ai settings map.
/// * `human.oii` — node `human [ settings, tasks, wallet, speech ]`.
/// * `files/<sha>_<name>` — raw asset bytes (wallpapers, stickers, avatars,
///   chat attachments...). The document never carries absolute device paths:
///   export rewrites them to these relative entries, import copies the bytes
///   into its own documents directory and rewrites them back.
///
/// This module is pure: it packs text and bytes and unpacks them. Collecting
/// asset bytes from disk and rewriting paths lives in `backup_store.dart`,
/// which owns the store. v1 (a single JSON string) is untouched and stays
/// readable through `backup.dart`'s `parseBackup`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'oii_codec.dart';

/// Bumped only for a change older builds cannot read. v1 is the JSON string.
const backupArchiveVersion = 2;

/// Same kind string as the v1 envelope, so a reader can tell ours from a
/// foreign file before looking at the version.
const backupArchiveKind = 'lib3.backup';

String shaHex(List<int> bytes) => sha256.convert(bytes).toString();

bool looksLikeZip(Uint8List bytes) => bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04;

/// Lossless filename: unlike replacing punctuation with `_`, distinct chat
/// IDs can never collide and silently drop a conversation from the backup.
String safeChatFileName(String id) => 'id_${base64Url.encode(utf8.encode(id)).replaceAll('=', '')}';

/// Detect the new format without decoding asset contents. The older ZIP has
/// `backup.json` instead; the caller retains its original reader.
bool hasOiiBackupManifest(List<int> bytes) {
  final decoder = ZipDecoder();
  try {
    decoder.decodeBytes(bytes);
    return decoder.directory.fileHeaders.any((e) => e.filename == 'manifest.oii');
  } catch (_) {
    throw const FormatException('That file is not a zip archive.');
  }
}

/// Builds the zip. [oiiFiles] maps zip entry path (`manifest.oii`,
/// `chats/<id>.oii`, ...) to decoded field maps; they are encoded here so a
/// caller can assemble documents without touching oii text. [assets] maps
/// entry path (`files/...`) to bytes. [missing] lists referenced files that
/// could not be read. Returns the zip bytes plus the manifest that was
/// written, so the caller can report what landed in the file.
({Uint8List bytes, Map<String, Object?> manifest}) buildBackupArchive({
  required Map<String, Map<String, Object?>> oiiFiles,
  required Map<String, List<int>> assets,
  required List<String> missing,
  String appVersion = '',
  DateTime? exportedAt,
}) {
  final files = <Object?>[];
  for (final e in assets.entries) {
    files.add({
      'path': e.key,
      'sha': shaHex(e.value),
      'size': e.value.length,
    });
  }
  final manifest = <String, Object?>{
    'kind': backupArchiveKind,
    'version': backupArchiveVersion,
    'app': appVersion,
    'at': (exportedAt ?? DateTime.now()).millisecondsSinceEpoch,
    'files': files,
    if (missing.isNotEmpty) 'missing': missing,
  };
  final archive = Archive();
  void addText(String name, String text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  addText('manifest.oii', oiiEncodeDoc('backup', manifest));
  for (final e in oiiFiles.entries) {
    final node = _nodeFor(e.key);
    addText(e.key, oiiEncodeDoc(node, e.value));
  }
  for (final e in assets.entries) {
    archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
  }
  final out = ZipEncoder().encode(archive);
  return (bytes: Uint8List.fromList(out), manifest: manifest);
}

String _nodeFor(String entryPath) {
  if (entryPath.startsWith('chats/')) return 'chat';
  final base = entryPath.split('/').last;
  final stem = base.endsWith('.oii') ? base.substring(0, base.length - 4) : base;
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(stem)) {
    throw ArgumentError('bad oii entry name "$entryPath"');
  }
  return stem;
}

/// A parsed archive: decoded `.oii` documents keyed by zip entry path,
/// asset bytes keyed by zip entry path, and non-fatal problems.
class ParsedBackupArchive {
  final int version;
  final String appVersion;
  final DateTime? exportedAt;

  /// Every `.oii` entry except the manifest, decoded to field maps.
  final Map<String, Map<String, Object?>> docs;

  /// Every `files/...` entry that matched its manifest sha.
  final Map<String, List<int>> assets;

  /// Files the exporter already knew were gone. Kept apart from [warnings]
  /// so import can word the two cases differently.
  final List<String> missing;

  /// Asset entries whose bytes failed the manifest sha, plus manifest
  /// entries with no bytes and bytes with no manifest entry. Import turns
  /// these into report warnings rather than failing the whole restore.
  final List<String> warnings;

  ParsedBackupArchive({
    required this.version,
    required this.appVersion,
    required this.exportedAt,
    required this.docs,
    required this.assets,
    required this.missing,
    required this.warnings,
  });
}

/// Reads a zip built by [buildBackupArchive]. Throws [FormatException] when
/// the bytes are not a zip at all, or when the manifest or any `.oii` entry
/// cannot be decoded; per-asset damage lands in [ParsedBackupArchive.warnings].
ParsedBackupArchive parseBackupArchive(Uint8List bytes) {
  // The decoder leaves file bodies lazy. Refuse oversized/duplicate entries
  // using the central directory metadata before reading any decompressed data.
  if (bytes.length > 256 * 1024 * 1024) {
    throw const FormatException('That backup archive is too large.');
  }
  final Archive archive;
  final decoder = ZipDecoder();
  try {
    archive = decoder.decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('That file is not a Paradise backup archive.');
  }
  final seen = <String>{};
  var total = 0;
  for (final header in decoder.directory.fileHeaders) {
    if (!seen.add(header.filename)) throw const FormatException('Duplicate entry in the backup archive.');
    if (seen.length > 10000) throw const FormatException('Too many files in the backup archive.');
    final size = header.uncompressedSize;
    if (size < 0 || size > 200 * 1024 * 1024) throw const FormatException('An archive entry is too large.');
    total += size;
    if (total > 300 * 1024 * 1024) throw const FormatException('The backup archive is too large.');
  }
  final texts = <String, String>{};
  final rawAssets = <String, List<int>>{};
  for (final f in archive) {
    if (!f.isFile) continue;
    if (f.name.endsWith('.oii')) {
      if (f.size > 64 * 1024 * 1024) throw const FormatException('An OII document is too large.');
      try {
        texts[f.name] = utf8.decode(f.content as List<int>);
      } catch (_) {
        throw FormatException('Could not read text in ${f.name}.');
      }
    } else if (f.name.startsWith('files/')) {
      final data = f.content as List<int>;
      rawAssets[f.name] = data;
    }
    // unknown entries are ignored so a newer build can add siblings freely
  }
  final manifestText = texts.remove('manifest.oii');
  if (manifestText == null) throw const FormatException('That archive has no manifest.');
  final Map<String, Object?> manifest;
  try {
    final doc = oiiDecodeDoc(manifestText);
    if (doc.name != 'backup') throw const FormatException('That archive has no manifest.');
    manifest = doc.fields;
  } catch (e) {
    if (e is FormatException) rethrow;
    throw const FormatException('That archive has no readable manifest.');
  }
  if (manifest['kind'] != backupArchiveKind) {
    throw FormatException('Not a Paradise backup, it says "${manifest['kind'] ?? 'nothing'}".');
  }
  final version = (manifest['version'] as num?)?.toInt() ?? 0;
  if (version > backupArchiveVersion) {
    throw FormatException(
      'That backup is version $version and this build only reads up to $backupArchiveVersion. Update the app first.',
    );
  }
  if (version < 2) throw const FormatException('That backup has no readable version.');

  final docs = <String, Map<String, Object?>>{};
  for (final e in texts.entries) {
    try {
      final parsed = oiiDecodeDoc(e.value);
      if (parsed.name != _nodeFor(e.key)) throw const FormatException('Wrong OII document type.');
      docs[e.key] = parsed.fields;
    } catch (_) {
      throw FormatException('Could not read ${e.key}.');
    }
  }

  final warnings = <String>[];
  final assets = <String, List<int>>{};
  final listed = <String>{};
  final files = manifest['files'];
  if (files is! List) throw const FormatException('The asset manifest is unreadable.');
  for (final e in files) {
    if (e is! Map || e['path'] is! String || e['sha'] is! String || e['size'] is! int) {
      throw const FormatException('The asset manifest is unreadable.');
    }
    final path = e['path'] as String;
    final want = e['sha'] as String;
    if (!RegExp(r'^files/[0-9a-f]{64}_[A-Za-z0-9._-]+$').hasMatch(path) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(want) ||
        !path.startsWith('files/${want}_') ||
        !listed.add(path)) {
      throw const FormatException('The asset manifest contains an invalid or duplicate path.');
    }
    final data = rawAssets[path];
    if (data == null) {
      warnings.add('file $path, listed but not in the archive');
      continue;
    }
    if (data.length != e['size'] || shaHex(data) != want) {
      warnings.add('file $path, damaged in transit');
      continue;
    }
    assets[path] = data;
  }
  for (final path in rawAssets.keys) {
    if (!listed.contains(path)) warnings.add('file $path, in the archive but not listed');
  }
  final missing = <String>[];
  final missingRaw = manifest['missing'];
  if (missingRaw is List) {
    for (final e in missingRaw) {
      missing.add('$e');
    }
  }

  final at = (manifest['at'] as num?)?.toInt();
  return ParsedBackupArchive(
    version: version,
    appVersion: manifest['app'] as String? ?? '',
    exportedAt: at == null ? null : DateTime.fromMillisecondsSinceEpoch(at),
    docs: docs,
    assets: assets,
    missing: missing,
    warnings: warnings,
  );
}
