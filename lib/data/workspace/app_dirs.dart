import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the app keeps what it owns.
///
/// Three call sites were each building a timestamped file name by hand already
/// (the wallpaper, the stickers, the ai uploads), so this is not new machinery,
/// it is the one copy of it. Nothing here caches: [root] hits path_provider on
/// every call and callers are all off the hot path.
class AppDirs {
  static Future<Directory> root() => getApplicationDocumentsDirectory();

  /// The documents dir with a subdirectory created on demand. Everything below
  /// lives under it so a backup of the app documents is a backup of all of this.
  static Future<Directory> _sub(String name) async {
    final d = Directory(p.join((await root()).path, name));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Parent of every managed workspace. Not itself a workspace.
  static Future<Directory> workspaces() => _sub('workspaces');

  /// The root of one managed workspace, created if missing.
  static Future<Directory> workspace(String id) async {
    final d = Directory(p.join((await workspaces()).path, id, 'files'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<Directory> sessions() => _sub('sessions');

  /// Per chat scratch. Two zones rather than one directory because the model is
  /// told they are separate and a glob should not cross between them.
  static Future<Directory> session(String chatId, String zone) async {
    final d = Directory(p.join((await sessions()).path, chatId, zone));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<Directory> skills() => _sub('skills');

  /// The Linux environment, which is large and so kept beside the rest rather
  /// than inside any one workspace.
  static Future<Directory> environment() => _sub('environment');

  /// Not under the documents dir: this is the zone the model may write freely,
  /// and anything left there is meant to be disposable.
  static Future<Directory> tmp() => _sub('workspace-tmp');
}

/// A file name that cannot escape its directory. Used for every name that came
/// from a model, a message or a file picker.
///
/// Deliberately keeps the extension. Losing it would break preview routing and
/// content sniffing, and none of the callers need the original stem back.
String safeFileName(String raw, {String fallback = 'file'}) {
  var n = raw.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
  if (n.length > 120) n = n.substring(n.length - 120);
  // a leading dot would make the browser hide it and glob skip it, which is
  // exactly the wrong outcome for a file the user just created
  while (n.startsWith('.')) {
    n = n.substring(1);
  }
  if (n.isEmpty || n == '.' || n == '..') return fallback;
  return n;
}

/// `name (2).txt`, `name (3).txt` until [taken] says the name is free. The
/// extension stays on the stem so `report (2).md` is still markdown.
String uniqueName(String wanted, Set<String> taken) {
  final lower = {for (final t in taken) t.toLowerCase()};
  if (!lower.contains(wanted.toLowerCase())) return wanted;
  final ext = p.extension(wanted);
  final stem = ext.isEmpty ? wanted : wanted.substring(0, wanted.length - ext.length);
  for (var i = 2; i < 1000; i++) {
    final n = '$stem ($i)$ext';
    if (!lower.contains(n.toLowerCase())) return n;
  }
  return '${stem}_${DateTime.now().microsecondsSinceEpoch}$ext';
}

/// Timestamp prefix plus a cleaned name. The prefix keeps uploads of the same
/// name from colliding, and sorting by name then sorts by upload time.
Future<File> stampedFile(String dir, String name) async {
  final d = Directory(dir);
  if (!await d.exists()) await d.create(recursive: true);
  return File(p.join(dir, '${DateTime.now().millisecondsSinceEpoch}_${safeFileName(name)}'));
}