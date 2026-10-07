import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The archive a backup travels as: the readable JSON document plus the binary
/// files it points at.
///
/// A backup used to be the JSON alone. Every picture it mentioned was a path
/// into the exporting device's private storage, so a restore on another phone
/// brought the conversation back with broken avatars, missing stickers and a
/// wallpaper that had never left. Carrying the bytes alongside the document is
/// the only way those come back.
///
/// A zip rather than base64 inside the JSON: the pictures are already
/// compressed formats, so deflate buys little, and a zip opens in any file
/// manager when the user wants to look inside a backup without this app.

/// The document, identical in shape to what the old export wrote.
const backupJsonName = 'backup.json';

/// The list that maps every carried file back to the path the document refers
/// to. Kept separate from the document so a reader that only understands the
/// JSON can still ignore it.
const backupManifestName = 'assets.json';

const _filesDir = 'files';

/// One file to carry into an archive. [orig] is the absolute path it had on the
/// exporting device, which is what the document points at.
class BackupAsset {
  BackupAsset({required this.orig, required this.data});

  final String orig;
  final Uint8List data;
}

/// One file read back out of an archive.
class BackupAssetFile {
  BackupAssetFile({required this.orig, required this.data});

  /// The path this file had on the exporting device.
  final String orig;

  final Uint8List data;
}

/// A parsed archive: the document text and the binary files beside it.
class BackupArchive {
  BackupArchive({required this.json, required this.assets});

  final String json;
  final List<BackupAssetFile> assets;
}

/// Builds the zip. [json] lands as `backup.json`, every asset under `files/`
/// with a manifest recording which original path it belongs to.
///
/// Empty assets are dropped: a path that pointed at a file already gone is not
/// worth a zero byte entry that a restore would write back as an empty picture.
Uint8List buildBackupZip({required String json, required List<BackupAsset> assets}) {
  final archive = Archive();
  final manifest = <Map<String, dynamic>>[];
  var n = 0;
  for (final a in assets) {
    if (a.data.isEmpty) continue;
    final name = '$_filesDir/${n.toString().padLeft(4, '0')}_${_baseName(a.orig)}';
    n++;
    archive.addFile(ArchiveFile(name, a.data.length, a.data));
    manifest.add({'orig': a.orig, 'path': name});
  }
  final jsonBytes = utf8.encode(json);
  archive.addFile(ArchiveFile(backupJsonName, jsonBytes.length, jsonBytes));
  final manifestBytes = utf8.encode(jsonEncode(manifest));
  archive.addFile(ArchiveFile(backupManifestName, manifestBytes.length, manifestBytes));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Reads an archive back. Throws [FormatException] with something worth showing
/// a user when the bytes are not a backup this build understands.
BackupArchive readBackupZip(List<int> bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('That file is not a zip archive.');
  }
  final byName = <String, List<int>>{};
  for (final f in archive) {
    if (!f.isFile) continue;
    byName[f.name] = f.content as List<int>;
  }
  final doc = byName[backupJsonName];
  if (doc == null) throw const FormatException('The archive has no backup.json.');

  final assets = <BackupAssetFile>[];
  final manifestRaw = byName[backupManifestName];
  if (manifestRaw != null) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(manifestRaw, allowMalformed: true));
    } catch (_) {
      throw const FormatException('The archive manifest is unreadable.');
    }
    if (decoded is List) {
      for (final e in decoded) {
        if (e is! Map) continue;
        final orig = '${e['orig'] ?? ''}';
        final path = '${e['path'] ?? ''}';
        final data = byName[path];
        if (orig.isEmpty || data == null) continue;
        assets.add(BackupAssetFile(orig: orig, data: Uint8List.fromList(data)));
      }
    }
  }

  return BackupArchive(json: utf8.decode(doc, allowMalformed: true), assets: assets);
}

/// True when the bytes look like a zip, so a caller can tell an old JSON backup
/// from a new archive without a store.
bool looksLikeZip(List<int> bytes) =>
    bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b && (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);

String _baseName(String path) {
  final i = path.lastIndexOf('/');
  final raw = i < 0 ? path : path.substring(i + 1);
  final clean = raw.replaceAll(RegExp(r'[^\w.\-]'), '_');
  return clean.isEmpty ? 'file' : clean;
}
