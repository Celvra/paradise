import 'dart:convert';

/// Whole account backup.
///
/// One JSON document, following the envelope the sticker and memory exports
/// already use, so a file that is handed to somebody can be read without this
/// app. Attachments are deliberately not in it: the photo and file
/// messages only carry a path into app private storage, and pulling the bytes
/// in would make this a multi gigabyte archive rather than a document.
///
/// API keys are never written here. A provider config carries `apiKeyRef`,
/// which names where a secret lives rather than being one, and the secrets
/// themselves sit under their own preferences entry. A backup that followed the
/// keys around would be a credential in every file the user ever shares.
const backupKind = 'lib3.backup';

/// Bumped only for a change that older builds cannot read. An unknown higher
/// version is refused rather than half applied.
const backupVersion = 1;

class BackupReport {
  BackupReport();

  int chats = 0;
  int messages = 0;
  int personas = 0;
  int stickers = 0;
  int memories = 0;
  int settings = 0;
  bool ai = false;
  bool wallet = false;
  bool human = false;
  int tasks = 0;

  /// Records that were present in the file but could not be used. A backup that
  /// quietly drops half a conversation is worse than one that says which half.
  final List<String> warnings = [];

  bool get ok => warnings.isEmpty;

  @override
  String toString() => 'chats=$chats messages=$messages personas=$personas '
      'stickers=$stickers memories=$memories settings=$settings ai=$ai '
      'warnings=${warnings.length}';
}

/// A parsed file, held as plain maps so it can be inspected without a Store.
class BackupDoc {
  BackupDoc({
    required this.version,
    required this.appVersion,
    required this.exportedAt,
    required this.chats,
    required this.personas,
    required this.stickers,
    required this.memory,
    required this.wallet,
    required this.human,
    required this.tasks,
    required this.settings,
    required this.ai,
  });

  final int version;
  final String appVersion;
  final DateTime? exportedAt;
  final List<Map<String, dynamic>> chats;
  final List<Map<String, dynamic>> personas;

  /// The sticker and memory envelopes verbatim, so one section on its own is
  /// still a file the existing importer accepts.
  final Map<String, dynamic>? stickers;
  final Map<String, dynamic>? memory;

  /// The wallet ledger, the assistant settings and the scheduled messages, each
  /// in the shape the humanize layer already persists. They ride along so a
  /// restore brings the whole account back rather than only the chat half.
  final Map<String, dynamic>? wallet;
  final Map<String, dynamic>? human;
  final List<dynamic>? tasks;

  final Map<String, dynamic> settings;
  final Map<String, dynamic>? ai;

  int get messageCount => chats.fold(0, (n, c) => n + ((c['msgs'] as List?)?.length ?? 0));
}

/// Assembles the document from already serialised pieces.
///
/// Pure, so it can be tested without a store, a database or a device.
String buildBackup({
  required List<Map<String, dynamic>> chats,
  required List<Map<String, dynamic>> personas,
  Map<String, dynamic>? stickers,
  Map<String, dynamic>? memory,
  Map<String, dynamic>? wallet,
  Map<String, dynamic>? humanSettings,
  List<dynamic>? tasks,
  Map<String, dynamic> settings = const {},
  Map<String, dynamic>? ai,
  String appVersion = '',
  DateTime? exportedAt,
}) =>
    const JsonEncoder.withIndent('  ').convert({
      'kind': backupKind,
      'version': backupVersion,
      'app': appVersion,
      'at': (exportedAt ?? DateTime.now()).millisecondsSinceEpoch,
      'sections': {
        'chats': chats,
        'personas': personas,
        if (stickers != null) 'stickers': stickers,
        if (memory != null) 'memory': memory,
        if (wallet != null) 'wallet': wallet,
        if (humanSettings != null) 'human': humanSettings,
        if (tasks != null) 'tasks': tasks,
        if (settings.isNotEmpty) 'settings': settings,
        if (ai != null) 'ai': ai,
      },
    });

/// Reads a file, refusing anything that is not ours or is newer than us.
///
/// Throws [FormatException] with something worth showing a user, because the
/// only two ways to get here are picking the wrong file and restoring a backup
/// from a newer build.
BackupDoc parseBackup(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    throw const FormatException('That file is not valid JSON.');
  }
  if (decoded is! Map) throw const FormatException('That is not a Paradise backup.');
  final j = decoded.cast<String, dynamic>();
  if (j['kind'] != backupKind) {
    throw FormatException('Not a Paradise backup, it says "${j['kind'] ?? 'nothing'}".');
  }
  final version = (j['version'] as num?)?.toInt() ?? 0;
  if (version > backupVersion) {
    throw FormatException(
      'That backup is version $version and this build only reads up to $backupVersion. Update the app first.',
    );
  }
  if (version < 1) throw const FormatException('That backup has no readable version.');

  final sections = (j['sections'] as Map?)?.cast<String, dynamic>() ?? const {};
  List<Map<String, dynamic>> objects(String key) {
    final list = sections[key];
    if (list is! List) return const [];
    return [for (final e in list) if (e is Map) e.cast<String, dynamic>()];
  }

  return BackupDoc(
    version: version,
    appVersion: j['app'] as String? ?? '',
    exportedAt: (j['at'] as num?) == null ? null : DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
    chats: objects('chats'),
    personas: objects('personas'),
    stickers: sections['stickers'] is Map ? (sections['stickers'] as Map).cast<String, dynamic>() : null,
    memory: sections['memory'] is Map ? (sections['memory'] as Map).cast<String, dynamic>() : null,
    wallet: sections['wallet'] is Map ? (sections['wallet'] as Map).cast<String, dynamic>() : null,
    human: sections['human'] is Map ? (sections['human'] as Map).cast<String, dynamic>() : null,
    tasks: sections['tasks'] is List ? sections['tasks'] as List : null,
    settings: sections['settings'] is Map ? (sections['settings'] as Map).cast<String, dynamic>() : const {},
    ai: sections['ai'] is Map ? (sections['ai'] as Map).cast<String, dynamic>() : null,
  );
}

/// Picks the chats to keep.
///
/// With [overwrite] off a chat already on the device wins, so restoring an old
/// backup cannot quietly replace a conversation the user has since added to.
/// The id is matched, not the content, because the id is what the rest of the
/// app hangs a persona, a wallpaper and an unread badge off.
({List<Map<String, dynamic>> take, List<String> skipped}) selectChats(BackupDoc doc, Iterable<String> existingIds, {required bool overwrite}) {
  final have = existingIds.toSet();
  final take = <Map<String, dynamic>>[];
  final skipped = <String>[];
  for (final c in doc.chats) {
    final id = c['id'];
    if (id is! String || id.isEmpty) {
      skipped.add('a chat with no id');
      continue;
    }
    if (!overwrite && have.contains(id)) {
      skipped.add('chat $id, already here');
      continue;
    }
    take.add(c);
  }
  return (take: take, skipped: skipped);
}