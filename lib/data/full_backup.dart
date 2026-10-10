import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

/// The full backup: the entire data directory as one zip.
///
/// The JSON auto backup is a curated document that imports record by record.
/// This is the other end of the trade: a byte for byte snapshot of everything
/// the app owns — chat database (including rows the JSON exporter does not
/// know about yet), persona cards, humanize state, workspace files, avatars,
/// stickers, wallpapers — plus a dump of SharedPreferences, which is where
/// the provider configuration and the API keys actually live. Restoring it
/// puts the files back and restarts the app on top of them, so nothing has to
/// translate between formats.
///
/// Zip layout:
///   _prefs.json       every SharedPreferences entry (contains the API keys)
///   docs/<rel>        the whole documents directory, relative paths kept
///   db/paradise.db    the chat database, plus -wal / -shm when present
class FullBackup {
  static const prefsEntry = '_prefs.json';
  static const dbPrefix = 'db/';
  static const docsPrefix = 'docs/';
  static const dbNames = ['paradise.db', 'paradise.db-wal', 'paradise.db-shm'];

  static Future<Uint8List> build({Directory? docs, Directory? dbDir, SharedPreferences? sp}) async {
    docs ??= await getApplicationDocumentsDirectory();
    dbDir ??= Directory(await getDatabasesPath());
    sp ??= await SharedPreferences.getInstance();
    final archive = Archive();

    // the prefs ride along as one json entry: dumping every key is deliberate,
    // a curated list is how the API keys got left behind once already
    final prefs = <String, dynamic>{for (final k in sp.getKeys()) k: sp.get(k)};
    final prefsBytes = utf8.encode(jsonEncode(prefs));
    archive.addFile(ArchiveFile(prefsEntry, prefsBytes.length, prefsBytes));

    if (await docs.exists()) {
      await for (final entity in docs.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: docs.path).replaceAll('\\', '/');
        // the private fallback copy of the JSON auto backup only duplicates
        // what this zip already carries, and resurrecting it on restore would
        // shadow the newer shared one
        if (rel == 'backup/paradise_autobackup.json') continue;
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile('$docsPrefix$rel', bytes.length, bytes));
      }
    }

    // the database is included with its WAL sidecars so the snapshot is the
    // whole story, not whatever pages happened to be checkpointed. SQLite
    // files barely compress, so they are stored raw.
    for (final name in dbNames) {
      final f = File(p.join(dbDir.path, name));
      if (!await f.exists()) continue;
      final bytes = await f.readAsBytes();
      archive.addFile(ArchiveFile('$dbPrefix$name', bytes.length, bytes)..compression = CompressionType.none);
    }

    return ZipEncoder().encodeBytes(archive);
  }

  /// Writes the zip back onto disk and returns how many files landed.
  /// [docs], [dbDir] and [sp] are test seams; production callers pass nothing.
  static Future<int> restore(Uint8List zip, {Directory? docs, Directory? dbDir, SharedPreferences? sp}) async {
    docs ??= await getApplicationDocumentsDirectory();
    dbDir ??= Directory(await getDatabasesPath());
    sp ??= await SharedPreferences.getInstance();
    final archive = ZipDecoder().decodeBytes(zip);
    final files = <String, Uint8List>{};
    Map<String, dynamic>? prefs;
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = f.name.replaceAll('\\', '/');
      // zip slip guard: no absolute paths, no parent traversal, ever
      if (name.startsWith('/') || name.split('/').contains('..')) continue;
      final bytes = f.content;
      if (name == prefsEntry) {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is Map) prefs = decoded.cast<String, dynamic>();
        continue;
      }
      files[name] = bytes;
    }

    var n = 0;
    for (final e in files.entries) {
      final isDb = e.key.startsWith(dbPrefix);
      final rel = e.key.substring((isDb ? dbPrefix : docsPrefix).length);
      final target = File(p.join(isDb ? dbDir.path : docs.path, rel));
      if (isDb && rel == 'paradise.db') {
        // replacing a database: drop all three of its files first, otherwise
        // a stale -wal could replay old pages over the restored main file
        for (final suffix in const ['', '-wal', '-shm']) {
          try {
            await File('${target.path}$suffix').delete();
          } catch (_) {}
        }
      }
      await target.parent.create(recursive: true);
      await target.writeAsBytes(e.value, flush: true);
      n++;
    }

    if (prefs != null) {
      // exact restore: keys the backup never heard of belong to a different
      // life of the install and go away, otherwise a half restored state
      // masquerades as a clean one
      for (final k in sp.getKeys().toList()) {
        if (!prefs.containsKey(k)) await sp.remove(k);
      }
      for (final e in prefs.entries) {
        final v = e.value;
        if (v is String) {
          await sp.setString(e.key, v);
        } else if (v is int) {
          await sp.setInt(e.key, v);
        } else if (v is double) {
          await sp.setDouble(e.key, v);
        } else if (v is bool) {
          await sp.setBool(e.key, v);
        } else if (v is List) {
          await sp.setStringList(e.key, [for (final x in v) '$x']);
        }
      }
    }
    return n;
  }
}
