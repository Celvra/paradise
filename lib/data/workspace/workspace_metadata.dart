import 'dart:convert';

import 'workspace_paths.dart';

/// What a step row shows for a workspace tool call.
///
/// Persisted on the trace row and read back by the UI. Never sent to the model:
/// the diff and the file list are the user's business, and echoing them into
/// the transcript would cost tokens to say something the user can read on
/// screen instead.
class WorkspaceToolMeta {
  WorkspaceToolMeta({this.tool = '', this.status = 'ok', this.code = '', this.path = '', this.files = const [], this.diff = '', this.added = 0, this.removed = 0, this.created = false, this.bytes = 0, this.count = 0, this.truncated = false, this.strategy = '', this.lines = 0});

  /// `ok`, `denied`, `error`.
  final String status;

  /// Machine readable failure name, one of the codes in workspace_tools.dart.
  final String code;
  final String tool;

  /// Model vocabulary, which is what the user should read because it is the
  /// path they would have to type.
  final String path;
  final List<WorkspaceToolFile> files;
  final String diff;
  final int added;
  final int removed;

  /// Whether a write made the file rather than replacing one.
  final bool created;
  final int bytes;
  final int count;
  final bool truncated;

  /// How edit_file matched, so a replacement the model only got approximately
  /// right is visible rather than silent.
  final String strategy;
  final int lines;

  Map<String, dynamic> toJson() => {
        'tool': tool,
        'status': status,
        if (code.isNotEmpty) 'code': code,
        if (path.isNotEmpty) 'path': path,
        if (files.isNotEmpty) 'files': [for (final f in files) f.toJson()],
        if (diff.isNotEmpty) 'diff': diff,
        if (added != 0) 'added': added,
        if (removed != 0) 'removed': removed,
        if (created) 'created': true,
        if (bytes != 0) 'bytes': bytes,
        if (count != 0) 'count': count,
        if (truncated) 'truncated': true,
        if (strategy.isNotEmpty) 'strategy': strategy,
        if (lines != 0) 'lines': lines,
      };

  factory WorkspaceToolMeta.fromJson(Map<String, dynamic>? j) => j == null
      ? WorkspaceToolMeta()
      : WorkspaceToolMeta(
          tool: j['tool'] as String? ?? '',
          status: j['status'] as String? ?? 'ok',
          code: j['code'] as String? ?? '',
          path: j['path'] as String? ?? '',
          files: [for (final f in (j['files'] as List? ?? const [])) WorkspaceToolFile.fromJson(Map<String, dynamic>.from(f as Map))],
          diff: j['diff'] as String? ?? '',
          added: (j['added'] as num?)?.toInt() ?? 0,
          removed: (j['removed'] as num?)?.toInt() ?? 0,
          created: j['created'] as bool? ?? false,
          bytes: (j['bytes'] as num?)?.toInt() ?? 0,
          count: (j['count'] as num?)?.toInt() ?? 0,
          truncated: j['truncated'] as bool? ?? false,
          strategy: j['strategy'] as String? ?? '',
          lines: (j['lines'] as num?)?.toInt() ?? 0,
        );
}

enum WorkspaceFileRole { referenced, created, modified }

/// One file a tool touched, so the step row can offer to open it.
class WorkspaceToolFile {
  const WorkspaceToolFile({required this.modelPath, this.role = WorkspaceFileRole.referenced, this.isDirectory = false});
  final String modelPath;
  final WorkspaceFileRole role;
  final bool isDirectory;

  bool get isChanged => role != WorkspaceFileRole.referenced;

  Map<String, dynamic> toJson() => {'path': modelPath, 'r': role.name, if (isDirectory) 'd': true};

  factory WorkspaceToolFile.fromJson(Map<String, dynamic> j) => WorkspaceToolFile(
        modelPath: j['path'] as String? ?? '',
        role: WorkspaceFileRole.values.firstWhere((e) => e.name == j['r'], orElse: () => WorkspaceFileRole.referenced),
        isDirectory: j['d'] as bool? ?? false,
      );
}

/// The `paradise://` link scheme.
///
/// Only used inside the app and in this app's own prompts, so the prefix is
/// this project's rather than a general one. The model is told the syntax in
/// the workspace prompt fragment and uses it to cite a file it produced, which
/// is what makes a generated plot or report tappable in the transcript.
class FileLink {
  const FileLink._(this.zone, this.rel);

  final WorkspaceZone zone;

  /// Path relative to the zone root, already percent decoded.
  final String rel;

  static const String scheme = 'paradise';

  /// Null for a path no zone claims. An outside file has no link because in
  /// sandboxed mode its model path is the host path, and handing that to a link
  /// handler would put a real path on disk into the transcript.
  ///
  /// The model path is resolved lexically here rather than through
  /// [WorkspacePaths.resolveReal]: building a link is not a reason to touch the
  /// disk, and a path that does not exist yet still has a zone.
  static String? forPath(String modelPath, WorkspacePaths paths) {
    final ResolvedPath resolved;
    try {
      resolved = paths.resolve(modelPath);
    } on PathResolutionException {
      return null;
    }
    final host = resolved.hostPath;
    for (final m in paths.externalMounts) {
      final rel = _relTo(m.hostPath, host);
      if (rel != null) return '$scheme://mounts/${Uri.encodeComponent(m.name)}${rel.isEmpty ? '' : _encodePath(rel)}';
    }
    for (final e in [
      (WorkspacePaths.guestWorkspace, paths.workspaceHostRoot),
      (WorkspacePaths.guestChat, paths.chatHostRoot),
      (WorkspacePaths.guestSkills, paths.skillsHostRoot),
      (WorkspacePaths.guestTmp, paths.tmpHostRoot),
    ]) {
      final rel = _relTo(e.$2, host);
      if (rel == null) continue;
      return rel.isEmpty ? '$scheme://${_zoneName(e.$1)}' : '$scheme://${_zoneName(e.$1)}/${_encodePath(rel)}';
    }
    return null;
  }

  /// One segment at a time. Encoding the whole path would turn the separators
  /// into %2F and leave the link unparseable.
  static String _encodePath(String rel) => rel.split('/').map(Uri.encodeComponent).join('/');

  static String _zoneName(String guestRoot) => switch (guestRoot) {
        WorkspacePaths.guestWorkspace => 'workspace',
        WorkspacePaths.guestChat => 'chat',
        WorkspacePaths.guestSkills => 'skills',
        WorkspacePaths.guestTmp => 'tmp',
        _ => 'workspace',
      };

  /// Parses a link back into a model path. Returns null for anything that is
  /// not ours, so a link from a message body that happens to start with the
  /// prefix cannot steer the resolver somewhere else.
  static FileLink? tryParse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != scheme) return null;
    if (uri.host == 'mounts') {
      return FileLink._(WorkspaceZone.external, uri.pathSegments.skip(1).join('/'));
    }
    final zone = switch (uri.host) {
      'workspace' => WorkspaceZone.workspace,
      'chat' => WorkspaceZone.chat,
      'skills' => WorkspaceZone.skills,
      'tmp' => WorkspaceZone.tmp,
      _ => WorkspaceZone.outside,
    };
    if (zone == WorkspaceZone.outside) return null;
    return FileLink._(zone, uri.pathSegments.join('/'));
  }

  /// The model vocabulary this link stands for.
  String get modelPath {
    if (zone == WorkspaceZone.external) return '/mounts/$rel';
    final root = switch (zone) {
      WorkspaceZone.workspace => WorkspacePaths.guestWorkspace,
      WorkspaceZone.chat => WorkspacePaths.guestChat,
      WorkspaceZone.skills => WorkspacePaths.guestSkills,
      _ => WorkspacePaths.guestTmp,
    };
    return rel.isEmpty ? root : '$root/$rel';
  }

  static String? _relTo(String root, String hostPath) {
    final norm = _normalize(root);
    final target = _normalize(hostPath);
    if (target == norm) return '';
    if (!target.startsWith('$norm/')) return null;
    return target.substring(norm.length + 1);
  }

  static String _normalize(String p) {
    // cheap, no path package here: the roots are already canonical and the
    // separators are the host's
    var s = p.replaceAll('\\', '/');
    while (s.length > 1 && s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}

/// One result a tool hands back to the model.
///
/// [text] is what goes into the transcript. Kept short on purpose: the whole
/// point of [WorkspaceToolMeta] is that the long parts belong on screen instead.
String toolResultText(Map<String, dynamic> payload) => jsonEncode(payload);

/// The error envelope every failing workspace tool returns.
///
/// The model gets a machine readable `error` and a `message` that says what to
/// do next. Returning the raw exception instead would produce a reply that
/// quotes "PathResolutionException: ..." at the user.
String toolError(String code, String message) => jsonEncode({'type': 'tool_error', 'error': code, 'message': message});