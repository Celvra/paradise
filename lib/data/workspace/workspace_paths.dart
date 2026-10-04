import 'dart:io';

import 'package:path/path.dart' as p;

/// Which root a resolved path landed in. Everything the model can reach is one
/// of the first five; `outside` is the answer for a path we refused to map and
/// for, in sandboxed mode, a host path that happens to sit nowhere in particular.
enum WorkspaceZone { workspace, chat, skills, tmp, external, outside }

/// A model path after it has been turned into something on disk. [zone] is
/// recomputed after symlink resolution, which is the only reason [modelPath]
/// can come back different from what the caller asked for.
///
/// [hostPath] is always canonical, so comparing two of them with `==` is fine.
class ResolvedPath {
  const ResolvedPath({required this.hostPath, required this.modelPath, required this.zone});
  final String hostPath;
  final String modelPath;
  final WorkspaceZone zone;
}

class PathResolutionException implements Exception {
  PathResolutionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The two subdirectories of the per chat session dir. Separate because the
/// model is told they are separate and a glob should not cross between them.
enum ChatZone { attachments, outputs }

/// A host folder bound into the guest. Empty until external mounts land, but
/// the type is here so the path layer does not have to change shape when they do.
class ExternalMount {
  const ExternalMount({required this.id, required this.name, required this.hostPath, this.readOnly = false});
  final String id;
  final String name;
  final String hostPath;
  final bool readOnly;

  String get guestRoot => '${WorkspacePaths.guestMounts}/$name';
}

/// Turns the paths the model writes into paths on this device, and refuses the
/// ones that would leave the roots it is allowed to see.
///
/// The model is told about `/workspace` and friends and has no way to know they
/// are a fiction, so it will happily try `/etc/passwd` and `../../data`. Every
/// entry point here goes through [resolveReal], never the model string directly.
class WorkspacePaths {
  WorkspacePaths({
    required String workspaceHostRoot,
    required String chatHostRoot,
    required String skillsHostRoot,
    required String tmpHostRoot,
    this.externalMounts = const [],
    String cwd = guestWorkspace,
  })  : cwd = _normalizeCwd(cwd) {
    _workspaceRoot = _canon(workspaceHostRoot);
    _chatRoot = _canon(chatHostRoot);
    _skillsRoot = _canon(skillsHostRoot);
    _tmpRoot = _canon(tmpHostRoot);
  }

  factory WorkspacePaths.sandboxed({
    required String workspaceHostRoot,
    required String chatHostRoot,
    required String skillsHostRoot,
    required String tmpHostRoot,
    List<ExternalMount> externalMounts = const [],
    String cwd = guestWorkspace,
  }) =>
      WorkspacePaths(
        workspaceHostRoot: workspaceHostRoot,
        chatHostRoot: chatHostRoot,
        skillsHostRoot: skillsHostRoot,
        tmpHostRoot: tmpHostRoot,
        externalMounts: externalMounts,
        cwd: cwd,
      );

  static const String guestWorkspace = '/workspace';
  static const String guestChat = '/chat';
  static const String guestSkills = '/skills';
  static const String guestTmp = '/tmp';
  static const String guestMounts = '/mounts';

  /// The vocabulary the model is given. Where the workspace zone starts.
  String get modelRoot => guestWorkspace;

  late final String _workspaceRoot;
  late final String _chatRoot;
  late final String _skillsRoot;
  late final String _tmpRoot;

  String get workspaceHostRoot => _workspaceRoot;
  String get chatHostRoot => _chatRoot;
  String get skillsHostRoot => _skillsRoot;
  String get tmpHostRoot => _tmpRoot;

  /// Model vocabulary, absolute. The workspace root when nothing narrower was
  /// asked for.
  final String cwd;

  final List<ExternalMount> externalMounts;

  static String _canon(String path) => p.normalize(p.canonicalize(path));

  /// A binding that never picked a directory sends '', and a caller that saved
  /// a relative one sends that. Both mean "somewhere under /workspace" once
  /// they are folded onto the root, and leaving them raw would make an empty
  /// base classify every path as outside — the shell tool then fails its very
  /// first call with a path error that names an empty path.
  static String _normalizeCwd(String raw) {
    final c = raw.trim();
    if (c.isEmpty || c == '.') return guestWorkspace;
    return p.posix.normalize(p.posix.isAbsolute(c) ? c : p.posix.join(guestWorkspace, c));
  }

  /// The zones a write may land in. Skills and outside never are.
  static bool isWritableZone(WorkspaceZone zone) =>
      zone == WorkspaceZone.workspace || zone == WorkspaceZone.chat || zone == WorkspaceZone.tmp || zone == WorkspaceZone.external;

  bool isReadOnlyPath(String hostPath) {
    if (_hostInside(_skillsRoot, hostPath)) return true;
    return externalMounts.any((m) => m.readOnly && _hostInside(m.hostPath, hostPath));
  }

  /// A cwd the model passed, folded back onto something inside the workspace.
  /// A blank or dotted cwd means the root, which is what a fresh binding wants.
  String normalizeCwd(String? cwd) {
    final c = (cwd ?? '').trim();
    if (c.isEmpty || c == '.') return guestWorkspace;
    return _resolve(c, base: guestWorkspace).modelPath;
  }

  /// Lexical only. [resolveReal] is what a tool should call; this one exists for
  /// the prompt builder, which wants to print a path without touching the disk.
  ResolvedPath resolve(String modelPath, {String? cwd}) => _resolve(modelPath, base: cwd == null ? this.cwd : _absModel(cwd));

  /// Lexical resolve, then follow symlinks, then classify again. A link inside
  /// the workspace pointing at /data therefore reads back as `outside` and the
  /// write gate refuses it, which a purely lexical check would have let through.
  Future<ResolvedPath> resolveReal(String modelPath, {String? cwd}) async {
    final lex = resolve(modelPath, cwd: cwd);
    final real = await _resolveHostPath(lex.hostPath);
    return ResolvedPath(hostPath: real, modelPath: toModelPath(real), zone: _classifyHost(real));
  }

  ResolvedPath _resolve(String modelPath, {required String base}) {
    if (modelPath.contains('\x00')) throw PathResolutionException('path contains a null byte');
    if (base.contains('\x00')) throw PathResolutionException('cwd contains a null byte');
    final raw = p.posix.isAbsolute(modelPath) ? modelPath : p.posix.join(base, modelPath);

    // classify where the path *says* it is going, which is the part before the
    // first `..`. without this `/workspace/../tmp/x` would normalize into the
    // tmp zone and then be judged as a legal tmp write
    final intended = _classifyGuest(_lexicalAnchor(raw));
    final normalized = p.posix.normalize(raw);
    final mapped = _mapGuest(normalized);
    if (mapped == null || intended == WorkspaceZone.outside) {
      throw PathResolutionException('path escapes a workspace zone: $modelPath');
    }

    // each external mount is its own boundary, so /mounts/a/../b/x cannot hop
    // from one into another
    for (final m in externalMounts) {
      if (_isUnder(_lexicalAnchor(raw), m.guestRoot) && !_isUnder(normalized, m.guestRoot)) {
        throw PathResolutionException('path escapes external mount ${m.name}: $modelPath');
      }
    }
    // external is settled per mount above, the other zones are one root each
    if (intended != WorkspaceZone.external && intended != WorkspaceZone.outside) {
      if (!_hostInside(_hostRootOf(intended), mapped)) {
        throw PathResolutionException('path escapes a workspace zone: $modelPath');
      }
    }
    return ResolvedPath(hostPath: mapped, modelPath: normalized, zone: intended);
  }

  /// The inverse. Returns the host path unchanged when nothing claims it, which
  /// is how an `outside` path stays a host path in metadata and ends up with no
  /// link behind it.
  String toModelPath(String hostPath) {
    for (final m in externalMounts) {
      final rel = _relativeTo(m.hostPath, hostPath);
      if (rel != null) return rel.isEmpty ? m.guestRoot : p.posix.join(m.guestRoot, rel);
    }
    for (final e in [(guestWorkspace, _workspaceRoot), (guestChat, _chatRoot), (guestSkills, _skillsRoot), (guestTmp, _tmpRoot)]) {
      final rel = _relativeTo(e.$2, hostPath);
      if (rel != null) return rel.isEmpty ? e.$1 : p.posix.join(e.$1, rel);
    }
    return _canon(hostPath);
  }

  String _hostRootOf(WorkspaceZone zone) => switch (zone) {
        WorkspaceZone.workspace => _workspaceRoot,
        WorkspaceZone.chat => _chatRoot,
        WorkspaceZone.skills => _skillsRoot,
        WorkspaceZone.tmp => _tmpRoot,
        // external is checked per mount and outside never maps at all
        _ => '',
      };

  /// Everything before the first `..` segment. `/a/b/../c` gives `/a/b`, which
  /// is what the path claims to be about, while `/a/../c` gives `/a`.
  static String _lexicalAnchor(String path) {
    final segs = p.posix.split(path);
    for (var i = 0; i < segs.length; i++) {
      if (segs[i] == '..') return p.posix.joinAll(segs.sublist(0, i));
    }
    return path;
  }

  static bool _isUnder(String path, String root) => path == root || p.posix.isWithin(root, path);

  WorkspaceZone _classifyGuest(String path) {
    for (final m in externalMounts) {
      if (_isUnder(path, m.guestRoot)) return WorkspaceZone.external;
    }
    if (_isUnder(path, guestWorkspace)) return WorkspaceZone.workspace;
    if (_isUnder(path, guestChat)) return WorkspaceZone.chat;
    if (_isUnder(path, guestSkills)) return WorkspaceZone.skills;
    if (_isUnder(path, guestTmp)) return WorkspaceZone.tmp;
    return WorkspaceZone.outside;
  }

  WorkspaceZone _classifyHost(String hostPath) {
    for (final m in externalMounts) {
      if (_hostInside(m.hostPath, hostPath)) return WorkspaceZone.external;
    }
    if (_hostInside(_workspaceRoot, hostPath)) return WorkspaceZone.workspace;
    if (_hostInside(_chatRoot, hostPath)) return WorkspaceZone.chat;
    if (_hostInside(_skillsRoot, hostPath)) return WorkspaceZone.skills;
    if (_hostInside(_tmpRoot, hostPath)) return WorkspaceZone.tmp;
    return WorkspaceZone.outside;
  }

  String? _mapGuest(String guestPath) {
    for (final m in externalMounts) {
      if (_isUnder(guestPath, m.guestRoot)) {
        final rel = p.posix.relative(guestPath, from: m.guestRoot);
        return rel.isEmpty ? _canon(m.hostPath) : p.normalize(p.join(_canon(m.hostPath), rel));
      }
    }
    const builtins = [guestWorkspace, guestChat, guestSkills, guestTmp];
    for (final g in builtins) {
      if (_isUnder(guestPath, g)) {
        final host = switch (g) {
          guestWorkspace => _workspaceRoot,
          guestChat => _chatRoot,
          guestSkills => _skillsRoot,
          _ => _tmpRoot,
        };
        final rel = p.posix.relative(guestPath, from: g);
        return rel.isEmpty ? host : p.normalize(p.join(host, rel));
      }
    }
    return null;
  }

  String _absModel(String cwd) => p.posix.isAbsolute(cwd) ? cwd : p.posix.join(guestWorkspace, cwd);

  /// Relative to [root], or null when [hostPath] is not under it. Empty string
  /// means the path is the root itself.
  static String? _relativeTo(String root, String hostPath) {
    final variants = _variants(hostPath);
    for (final r in _variants(root)) {
      for (final c in variants) {
        if (p.equals(r, c)) return '';
        if (p.isWithin(r, c)) return p.relative(c, from: r);
      }
    }
    return null;
  }

  /// Lexical form plus the symlink resolved form. A root reached through a
  /// symlinked parent only matches on the second one.
  static List<String> _variants(String path) {
    final out = <String>{_canon(path)};
    for (final read in [Link.new, File.new, Directory.new]) {
      try {
        out.add(_canon(read(path).resolveSymbolicLinksSync()));
      } catch (_) {
        // not there yet, the lexical form is all there is
      }
    }
    return out.toList();
  }

  static bool _hostInside(String root, String hostPath) => _relativeTo(root, hostPath) != null;

  /// Resolves symlinks for a path that may not exist yet, by walking up to the
  /// nearest ancestor that does and re-joining the tail. Without this, creating
  /// `/workspace/new/../../escape` would sail past the zone check because there
  /// was nothing to resolve.
  static Future<String> _resolveHostPath(String hostPath) async {
    final tail = <String>[];
    var cur = _canon(hostPath);
    while (true) {
      for (final read in [Link.new, File.new, Directory.new]) {
        try {
          return p.normalize(p.joinAll([_canon(read(cur).resolveSymbolicLinksSync()), ...tail]));
        } catch (_) {
          // try the next flavour
        }
      }
      final parent = p.dirname(cur);
      if (parent == cur) return _canon(hostPath);
      tail.insert(0, p.basename(cur));
      cur = parent;
    }
  }
}