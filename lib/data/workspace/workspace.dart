/// What owns the directory. `managed` lives under the app documents dir and is
/// ours to delete. `linked` is a folder the user picked and we never remove.
enum WorkspaceKind { managed, linked }

WorkspaceKind workspaceKindOf(String? raw) => WorkspaceKind.values.firstWhere((e) => e.name == raw, orElse: () => WorkspaceKind.managed);

/// One directory the model can be pointed at. The per-tool switches live here
/// rather than in settings so two workspaces can offer different tables without
/// the user visiting a settings page twice.
class Workspace {
  Workspace({
    required this.id,
    required this.name,
    this.kind = WorkspaceKind.managed,
    this.hostPath,
    this.defaultCwd = '',
    Set<String>? disabledTools,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastUsedAt,
  })  : // a copy rather than the argument, so the caller cannot reach in and
        // mutate a set this object is handing out as unmodifiable
        disabledTools = {...?disabledTools},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  final WorkspaceKind kind;

  /// Only set for `linked`. A managed workspace derives its root from its id,
  /// so storing it would let a stale row point at somebody else's directory.
  final String? hostPath;

  /// Model vocabulary, relative to the root. Empty means the root itself.
  String defaultCwd;

  /// Tools the user switched off here. Kept as a set so an unknown name from a
  /// newer version cannot turn into a permanent permission denial.
  final Set<String> disabledTools;

  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? lastUsedAt;

  bool isToolEnabled(String name) => !disabledTools.contains(name);

  Workspace copyWith({
    String? name,
    WorkspaceKind? kind,
    String? hostPath,
    String? defaultCwd,
    Set<String>? disabledTools,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
  }) =>
      Workspace(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        hostPath: hostPath ?? this.hostPath,
        defaultCwd: defaultCwd ?? this.defaultCwd,
        disabledTools: disabledTools ?? this.disabledTools,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );

  /// Sorted so a set that was built in a different order still writes the same
  /// bytes, which keeps a chat json diff readable.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        if (hostPath != null) 'hostPath': hostPath,
        'defaultCwd': defaultCwd,
        'disabledTools': disabledTools.toList()..sort(),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.millisecondsSinceEpoch,
      };

  factory Workspace.fromJson(Map<String, dynamic> j) => Workspace(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        kind: workspaceKindOf(j['kind'] as String?),
        hostPath: j['hostPath'] as String?,
        defaultCwd: j['defaultCwd'] as String? ?? '',
        disabledTools: {for (final e in (j['disabledTools'] as List? ?? const [])) '$e'},
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num?)?.toInt() ?? 0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch((j['updatedAt'] as num?)?.toInt() ?? 0),
        lastUsedAt: j['lastUsedAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch((j['lastUsedAt'] as num).toInt()),
      );
}

/// Which workspace a chat is pointed at. Stored inside the chat json under `ws`
/// rather than its own table: it is meaningless without the chat, and a chat is
/// already the unit that gets deleted and backed up.
///
/// Unbound serialises to an empty map and [Chat.toJson] then leaves the key out
/// entirely, so a chat that never bound one is byte identical to one written
/// before this feature existed.
class WorkspaceBinding {
  WorkspaceBinding({this.workspaceId, this.cwd = '', this.toolsUsed = false, this.allowAll = false});

  String? workspaceId;

  /// Model vocabulary, absolute inside the workspace. Empty means the root, which
  /// is what a fresh binding wants so the tool table has one obvious cwd.
  String cwd;

  /// Set the first time a tool actually runs. Unbinding after that is worth a
  /// confirmation, unbinding before it is not.
  bool toolsUsed;

  /// The user said yes to every write in this chat. Deliberately not exported:
  /// an allowAll that survived a restore would approve writes the user never saw.
  bool allowAll;

  bool get isBound => workspaceId?.isNotEmpty == true;

  /// Empty when unbound, and [Chat.toJson] then leaves the key out entirely.
  Map<String, dynamic> toJson() => isBound
      ? {
          'id': workspaceId,
          if (cwd.isNotEmpty) 'cwd': cwd,
          if (toolsUsed) 'toolsUsed': true,
          if (allowAll) 'allowAll': true,
        }
      : {};

  factory WorkspaceBinding.fromJson(Map<String, dynamic>? j) => j == null
      ? WorkspaceBinding()
      : WorkspaceBinding(
          workspaceId: j['id'] as String?,
          cwd: j['cwd'] as String? ?? '',
          toolsUsed: j['toolsUsed'] as bool? ?? false,
          allowAll: j['allowAll'] as bool? ?? false,
        );
}