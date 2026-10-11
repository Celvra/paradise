import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
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

  /// Relative paths whose bytes are themselves backups.
  ///
  /// The walk folds none of them into the snapshot. The private fallback
  /// json duplicates what the curated archive carries, and the full zip of
  /// the previous tick is the dangerous one: without this rule every
  /// snapshot is the previous snapshot plus the day's changes, so the file
  /// grows without bound and each tick re-zips a megabyte count that
  /// compounds every time.
  static bool isBackupArtifact(String rel) {
    final norm = rel.replaceAll('\\', '/');
    if (norm == 'backup/paradise_autobackup.json') return true;
    final base = p.basename(norm);
    return base.startsWith('paradise_full') && base.endsWith('.zip');
  }

  /// The databases directory as a path. Lives here rather than at the call
  /// site because this library already depends on sqflite and the store's
  /// part files deliberately do not.
  static Future<String> dbDirPath() async => await getDatabasesPath();

  /// Streams the snapshot to a file and returns it.
  ///
  /// The build never holds more than one file in memory, because the whole
  /// data directory is the input: a user with a workspace environment
  /// installed owns gigabytes there, and `readAsBytes` per entry plus an
  /// in-memory `Archive` is a heap the process cannot afford on a phone.
  /// The caller owns the returned file and deletes it once the sink has
  /// taken its copy.
  static Future<File> buildToFile({
    Directory? docs,
    Directory? dbDir,
    SharedPreferences? sp,
    Map<String, Object?>? prefs,
    Directory? tmp,
    String? outPath,
  }) async {
    docs ??= await getApplicationDocumentsDirectory();
    dbDir ??= Directory(await getDatabasesPath());
    if (sp == null && prefs == null) sp = await SharedPreferences.getInstance();
    prefs ??= {for (final k in sp!.getKeys()) k: sp.get(k)};
    tmp ??= await getTemporaryDirectory();

    final out = File(outPath ?? p.join(tmp.path, 'paradise_full-${DateTime.now().microsecondsSinceEpoch}.zip'));
    if (await out.exists()) await out.delete();

    final encoder = ZipFileEncoder();
    encoder.create(out.path);

    // the prefs ride along as one json entry: dumping every key is
    // deliberate, a curated list is how the API keys got left behind once
    // already
    final prefsFile = File(p.join(tmp.path, '_prefs-${DateTime.now().microsecondsSinceEpoch}.json'));
    await prefsFile.writeAsBytes(utf8.encode(jsonEncode(prefs)), flush: true);
    await encoder.addFile(prefsFile, prefsEntry);
    await prefsFile.delete();

    if (await docs.exists()) {
      await for (final entity in docs.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: docs.path).replaceAll('\\', '/');
        if (isBackupArtifact(rel)) continue;
        await encoder.addFile(entity, '$docsPrefix$rel');
      }
    }

    // the database is included with its WAL sidecars so the snapshot is the
    // whole story, not whatever pages happened to be checkpointed. SQLite
    // files barely compress, so they are stored raw.
    for (final name in dbNames) {
      final f = File(p.join(dbDir.path, name));
      if (!await f.exists()) continue;
      await encoder.addFile(f, '$dbPrefix$name', 0);
    }

    await encoder.close();
    return out;
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

/// What a worker isolate needs to build a snapshot: plain paths and a prefs
/// dump, because neither the Store nor SharedPreferences crosses an isolate
/// boundary (and must not: the worker runs while the UI keeps touching the
/// store).
class FullBackupJob {
  const FullBackupJob({
    required this.docsPath,
    required this.dbDirPath,
    required this.tmpPath,
    required this.prefs,
  });

  final String docsPath;
  final String dbDirPath;
  final String tmpPath;
  final Map<String, Object?> prefs;
}

/// [compute] entry point for the full snapshot.
///
/// Returns null on any failure: a snapshot that could not be built is a
/// warning, never a reason to take the backup schedule down. The half
/// written zip is removed here because the caller never received a handle.
Future<File?> runFullBackupJob(FullBackupJob job) async {
  File? out;
  try {
    out = File(p.join(job.tmpPath, 'paradise_full-${DateTime.now().microsecondsSinceEpoch}.zip'));
    final f = await FullBackup.buildToFile(
      docs: Directory(job.docsPath),
      dbDir: Directory(job.dbDirPath),
      prefs: job.prefs,
      tmp: Directory(job.tmpPath),
      outPath: out.path,
    );
    return f;
  } catch (_) {
    try {
      if (out != null && await out.exists()) await out.delete();
    } catch (_) {}
    return null;
  }
}
