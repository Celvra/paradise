import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_dirs.dart';
import 'workspace.dart';
import 'workspace_paths.dart';

/// Owner of the workspace list and of the feature switch.
///
/// Separate ChangeNotifier rather than more Store fields because the file
/// browser and the tool pane both rebuild on every change and neither of them
/// has any business rebuilding the chat list with it.
class WorkspaceStore extends ChangeNotifier {
  WorkspaceStore._(this._sp);

  final SharedPreferences _sp;
  final List<Workspace> _workspaces = [];
  var _seq = 0;

  /// Off by default. The tools are the part that can change files on the
  /// device, and a user who has not asked for that should not get it because a
  /// chat happened to be bound to a directory.
  bool toolsEnabled = false;

  /// Ask before every write. On by default and separate from the tool
  /// permission, because that one is per tool and this is per write.
  bool confirmWrites = true;

  List<Workspace> get all => List.unmodifiable(_workspaces);

  String _id() => 'ws_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${_seq++}';

  static Future<WorkspaceStore> load(SharedPreferences sp) async {
    final w = WorkspaceStore._(sp);
    try {
      final raw = sp.getString('w_workspaces');
      if (raw != null) {
        for (final e in (jsonDecode(raw) as Map)['items'] as List? ?? const []) {
          w._workspaces.add(Workspace.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      }
    } catch (_) {
      // a damaged blob must not keep the app from starting
      w._workspaces.clear();
    }
    w.toolsEnabled = sp.getBool('w_tools_on') ?? false;
    w.confirmWrites = sp.getBool('w_confirm_writes') ?? true;
    return w;
  }

  void _save() {
    _sp.setString('w_workspaces', jsonEncode({'items': [for (final w in _workspaces) w.toJson()]}));
  }

  void changed() {
    _save();
    notifyListeners();
  }

  Workspace? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final w in _workspaces) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Last used first, never used last, then by name. The order a user expects
  /// from a list they have visited before.
  List<Workspace> get sorted {
    final out = [..._workspaces];
    out.sort((a, b) {
      final al = a.lastUsedAt;
      final bl = b.lastUsedAt;
      if (al == null && bl != null) return 1;
      if (al != null && bl == null) return -1;
      if (al != null && bl != null && al != bl) return bl.compareTo(al);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  Future<Workspace> create({required String name, WorkspaceKind kind = WorkspaceKind.managed, String? hostPath}) async {
    final w = Workspace(id: _id(), name: name.trim().isEmpty ? 'workspace' : name.trim(), kind: kind, hostPath: hostPath);
    if (kind == WorkspaceKind.managed) {
      // materialise now so a workspace that was created and never opened is
      // still a real directory rather than a row pointing at nothing
      await AppDirs.workspace(w.id);
    }
    _workspaces.add(w);
    changed();
    return w;
  }

  void update(Workspace w) {
    final next = w.copyWith(updatedAt: DateTime.now());
    final at = _workspaces.indexWhere((e) => e.id == w.id);
    if (at < 0) {
      _workspaces.add(next);
    } else {
      _workspaces[at] = next;
    }
    changed();
  }

  Future<void> remove(String id, {bool deleteFiles = true}) async {
    final w = byId(id);
    _workspaces.removeWhere((e) => e.id == id);
    // a linked directory is the user's own file system and is never ours to
    // delete, whatever the switch says
    if (deleteFiles && w != null && w.kind == WorkspaceKind.managed) {
      final dir = Directory('${(await AppDirs.workspaces()).path}/$id');
      if (await dir.exists()) await dir.delete(recursive: true);
    }
    changed();
  }

  void touchLastUsed(String id) {
    final w = byId(id);
    if (w == null) return;
    w.lastUsedAt = DateTime.now();
    _save();
    notifyListeners();
  }

  /// The root of a managed workspace, created on demand. A linked workspace
  /// returns the path it was given and does not create anything.
  Future<String> hostRootFor(Workspace w) async {
    if (w.kind == WorkspaceKind.linked) {
      final p = w.hostPath;
      if (p == null || p.isEmpty) throw StateError('linked workspace ${w.id} has no path');
      return p;
    }
    return (await AppDirs.workspace(w.id)).path;
  }

  /// The four roots the path layer needs, plus the cwd this chat asked for.
  Future<WorkspacePaths> pathsFor(Workspace w, String chatId, {String? cwd}) async {
    return WorkspacePaths.sandboxed(
      workspaceHostRoot: await hostRootFor(w),
      chatHostRoot: (await AppDirs.session(chatId, 'attachments')).parent.path,
      skillsHostRoot: (await AppDirs.skills()).path,
      tmpHostRoot: (await AppDirs.tmp()).path,
      cwd: cwd == null || cwd.isEmpty ? w.defaultCwd : cwd,
    );
  }

  void setToolsEnabled(bool v) {
    toolsEnabled = v;
    _sp.setBool('w_tools_on', v);
    notifyListeners();
  }

  void setConfirmWrites(bool v) {
    confirmWrites = v;
    _sp.setBool('w_confirm_writes', v);
    notifyListeners();
  }

  // --------------------------------------------------------------- backup

  String exportJson() => const JsonEncoder.withIndent('  ').convert({'kind': 'lib3.workspaces', 'version': 1, 'items': [for (final w in _workspaces) w.toJson()]});

  /// Merges by id. [overwrite] clears the list first, which is what a restore
  /// wants and what a plain import does not.
  void importJson(String raw, {required bool overwrite}) {
    final j = jsonDecode(raw);
    if (j is! Map || j['kind'] != 'lib3.workspaces') throw const FormatException('not a workspace export');
    final items = j['items'] as List? ?? const [];
    if (overwrite) _workspaces.clear();
    for (final e in items) {
      final w = Workspace.fromJson(Map<String, dynamic>.from(e as Map));
      if (byId(w.id) == null) _workspaces.add(w);
    }
    changed();
  }
}