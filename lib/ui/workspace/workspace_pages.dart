import 'dart:io';

import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';

import '../../core/anim.dart';
import '../../core/overlays.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/store.dart';
import '../../data/models.dart';
import '../../data/workspace/workspace.dart';
import '../../data/workspace/android_proot_runtime.dart';
import '../../data/workspace/workspace_tools.dart';
import '../../l10n/x.dart';
import '../human_pages.dart' show hOpen;
import '../tg_cells.dart';
import 'file_browser.dart';
import 'workspace_prompts.dart';
import 'environment_page.dart';
import 'terminal/terminal_page.dart';
import 'terminal/terminal_session_manager.dart';

/// The workspace list and the feature switch. Reached from settings and from
/// the chat menu.
void openWorkspaceSettings(BuildContext c) =>
    hOpen(c, const WorkspaceSettingsPage());

class WorkspaceSettingsPage extends StatefulWidget {
  const WorkspaceSettingsPage({super.key});

  static void open(BuildContext c) => hOpen(c, const WorkspaceSettingsPage());

  @override
  State<WorkspaceSettingsPage> createState() => _WorkspaceSettingsState();
}

class _WorkspaceSettingsState extends State<WorkspaceSettingsPage> {
  /// the header button, so the sort or row menu opens under it rather than
  /// under the page
  final GlobalKey _newKey = GlobalKey();
  final Map<String, GlobalKey> _rowMenuKeys = {};

  @override
  Widget build(BuildContext context) {
    final st = Store.of(context);
    return TgSettingsPage(
      title: context.l.wsTitle,
      actions: [
        TgIconButton(
            key: _newKey,
            icon: Ic.plus,
            tooltip: context.l.wsNew,
            onTap: () => _create(context, st))
      ],
      builder: (c, _) => ListenableBuilder(
        listenable: st.workspace,
        builder: (c, _) {
          final ws = st.workspace;
          final all = ws.sorted;
          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              TgSection(
                children: [
                  TgCheckCell(
                    title: context.l.wsToolsOn,
                    // the row says what the switch is doing right now, and the
                    // caption below the block says what every write costs. both
                    // are always on screen; only this one changes, and TgTextCell
                    // cross fades it
                    subtitle: ws.toolsEnabled
                        ? context.l.wsSubOn
                        : context.l.wsSubOff,
                    icon: Ic.terminal,
                    value: ws.toolsEnabled,
                    onChanged: ws.setToolsEnabled,
                  ),
                  TgCheckCell(
                    title: context.l.wsConfirmWrites,
                    icon: Ic.check2,
                    value: ws.confirmWrites,
                    onChanged: ws.setConfirmWrites,
                  ),
                ],
                // both explanations are always present. gating one on the switch
                // meant the row changed height as it was flipped and the thing
                // being explained appeared only after you had already decided
                footer: context.l.wsToolsFooter,
              ),
              TgSection(
                header: context.l.wsTitle,
                footer: all.isEmpty ? context.l.wsEmptyHint : null,
                children: [
                  for (final w in all) _row(context, st, w, c),
                  if (all.isEmpty) const SizedBox(height: 8),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(
      BuildContext context, Store st, Workspace w, BuildContext anchor) {
    final l = context.l;
    final on = WorkspaceTools.toolNames
        .where((t) => !w.disabledTools.contains(t))
        .length;
    return TgTextCell(
      title: w.name,
      icon: Ic.folder,
      subtitle: w.lastUsedAt == null
          ? l.wsNeverUsed
          : '${on}/${WorkspaceTools.toolNames.length}',
      onTap: () => hOpen(context, WorkspaceFilesPage(workspace: w)),
      onLongPress: () => _menu(context, st, w, anchor),
      trailing: TgIconButton(
          key: _rowMenuKeys.putIfAbsent(w.id, GlobalKey.new),
          icon: Ic.more,
          size: 20,
          onTap: () => _menuAt(context, st, w, _rowMenuKeys[w.id]!)),
    );
  }

  Future<void> _menu(
      BuildContext context, Store st, Workspace w, BuildContext anchor) async {
    await _showWorkspaceMenu(context, st, w, rectOf(anchor));
  }

  Future<void> _menuAt(
      BuildContext context, Store st, Workspace w, GlobalKey anchor) async {
    await _showWorkspaceMenu(context, st, w, anchorRect(anchor));
  }

  Future<void> _showWorkspaceMenu(
      BuildContext context, Store st, Workspace w, Rect anchor) async {
    final l = context.l;
    await showTgMenu(
      context,
      anchor: anchor,
      items: [
        MenuItem(l.wsRename, Ic.pencil, () => _rename(context, st, w)),
        MenuItem(l.wsFiles, Ic.folder,
            () => hOpen(context, WorkspaceFilesPage(workspace: w))),
        MenuItem(
            l.termTitle, Ic.terminal, () => openWorkspaceTerminal(context, w)),
        MenuItem(l.termSettings, Ic.download,
            () => openEnvironmentSettings(context)),
        MenuItem.gap(),
        MenuItem(l.wsDelete, Ic.trash, () => _delete(context, st, w),
            danger: true),
      ],
    );
  }

  Future<void> _create(BuildContext context, Store st) async {
    final name = await askName(context,
        title: context.l.wsNewTitle, hint: context.l.wsTitle);
    if (name == null || !context.mounted) return;
    final w = await st.workspace.create(name: name);
    if (!context.mounted) return;
    hOpen(context, WorkspaceFilesPage(workspace: w));
  }

  Future<void> _rename(BuildContext context, Store st, Workspace w) async {
    final name =
        await askName(context, title: context.l.wsRename, initial: w.name);
    if (name == null || !context.mounted) return;
    w.name = name;
    st.workspace.update(w);
  }

  /// A managed workspace's files go with it, and the switch is offered because
  /// "delete the row but keep the files" is the safe reading and the other way
  /// round loses work. A linked folder never offers it: that directory is the
  /// user's own and the app has no business deleting it.
  Future<void> _delete(BuildContext context, Store st, Workspace w) async {
    final l = context.l;
    final managed = w.kind == WorkspaceKind.managed;
    var withFiles = managed;
    final ok = await askConfirm(
      context,
      title: l.wsDelete,
      message: managed
          ? '${l.wsDeleteConfirm(w.name)}\n${l.wsDeleteFilesFooter}'
          : l.wsDeleteConfirm(w.name),
      confirmLabel: l.wsDelete,
    );
    if (!ok || !context.mounted) return;
    await st.workspace.remove(w.id, deleteFiles: withFiles);
  }
}

/// One workspace: its files, and which of the six tools it offers.
class WorkspaceFilesPage extends StatefulWidget {
  const WorkspaceFilesPage({super.key, required this.workspace});
  final Workspace workspace;

  @override
  State<WorkspaceFilesPage> createState() => _WorkspaceFilesPageState();
}

class _WorkspaceFilesPageState extends State<WorkspaceFilesPage> {
  final GlobalKey _menuKey = GlobalKey();
  var _tab = 0;

  Workspace get workspace => widget.workspace;

  @override
  Widget build(BuildContext context) {
    final st = Store.of(context);
    return TgSettingsPage(
      title: workspace.name,
      actions: [
        TgIconButton(
            key: _menuKey,
            icon: Ic.more,
            size: 20,
            onTap: () => _menu(context, st))
      ],
      bottom: TgTabStrip(
          labels: [context.l.wsFiles, context.l.wsToolsTab],
          index: _tab,
          onChange: (index) => setState(() => _tab = index)),
      builder: (c, _) => _body(context, st),
    );
  }

  Future<void> _menu(BuildContext context, Store st) async {
    final w = workspace;
    await showTgMenu(
      context,
      anchor: anchorRect(_menuKey),
      items: [
        MenuItem(context.l.wsRename, Ic.pencil, () async {
          final name = await askName(context,
              title: context.l.wsRename, initial: w.name);
          if (name == null || !context.mounted) return;
          w.name = name;
          st.workspace.update(w);
        }),
        MenuItem(context.l.wsDelete, Ic.trash,
            () => Navigator.of(context).maybePop(),
            danger: true),
      ],
    );
  }

  Widget _body(BuildContext context, Store st) {
    return FutureBuilder<String>(
      future: st.workspace.hostRootFor(workspace),
      builder: (c, snap) {
        if (snap.hasError) {
          return WsEmpty(icon: Ic.info, title: '${snap.error}');
        }
        final path = snap.data;
        if (path == null) {
          return Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: c.p.subtitle)));
        }
        return IndexedStack(
          index: _tab,
          children: [
            FileBrowser(
                key: ValueKey('${workspace.id}-$path'),
                root: Directory(path),
                title: workspace.name,
                initialPath: workspace.defaultCwd),
            _toolsPane(context, st),
          ],
        );
      },
    );
  }

  Widget _toolsPane(BuildContext context, Store st) {
    final w = workspace;
    return ColoredBox(
      color: context.p.bg,
      child: ListView(
          padding: EdgeInsets.only(
              bottom: 8 + MediaQuery.of(context).padding.bottom),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(21, 12, 21, 10),
              child: Text(context.l.wsToolsTabFooter,
                  style: TextStyle(
                      color: context.p.subtitle,
                      fontSize: 12.5,
                      height: 1.35,
                      decoration: TextDecoration.none)),
            ),
            for (final name in WorkspaceTools.toolNames)
              TgCheckCell(
                title: _label(context, name),
                icon: _icon(name),
                value: !w.disabledTools.contains(name),
                divider: name != WorkspaceTools.toolNames.last,
                onChanged: (v) {
                  final next = {...w.disabledTools};
                  if (v) {
                    next.remove(name);
                  } else {
                    next.add(name);
                  }
                  st.workspace.update(w.copyWith(disabledTools: next));
                },
              ),
          ]),
    );
  }

  static String _label(BuildContext c, String tool) => switch (tool) {
        'read_file' => c.l.wsToolRead,
        'write_file' => c.l.wsToolWrite,
        'edit_file' => c.l.wsToolEdit,
        'list_dir' => c.l.wsToolList,
        'glob' => c.l.wsToolGlob,
        'grep' => c.l.wsToolGrep,
        'shell' => c.l.wsToolShell,
        'view_image' => c.l.wsToolViewImage,
        _ => tool,
      };

  static Ic _icon(String tool) => switch (tool) {
        'read_file' || 'write_file' || 'edit_file' => Ic.file,
        'list_dir' => Ic.folder,
        'glob' => Ic.search,
        'grep' => Ic.list,
        'shell' => Ic.terminal,
        'view_image' => Ic.image,
        _ => Ic.file,
      };
}

/// Opens a terminal scoped to one managed workspace.
Future<void> openWorkspaceTerminal(
    BuildContext context, Workspace workspace) async {
  final stack = Store.of(context).workspaceStack;
  final runtime = stack?.runtime();
  if (runtime is! AndroidProotRuntime) {
    openEnvironmentSettings(context);
    return;
  }
  final workspaceRoot =
      await Store.of(context).workspace.hostRootFor(workspace);
  if (!context.mounted) return;
  hOpen(
    context,
    TerminalPage(
      sessionManager: TerminalSessionManager.shared,
      cwd: workspace.defaultCwd,
      title: workspace.name,
      workspaceId: workspace.id,
      mounts: runtime.zoneMounts(workspaceHost: workspaceRoot),
    ),
  );
}

/// Picks a workspace for a chat, or unbinds it.
///
/// Returns null for a cancel and [noWorkspace] as the sentinel for "unbind", so
/// the caller can tell the two apart without a second dialog.
const String kUnbindWorkspace = '__unbind__';

Future<String?> pickWorkspace(BuildContext context, {String? current}) {
  final st = Store.of(context);
  return WsSheet.open<String>(
    context,
    (c) => ListenableBuilder(
      listenable: st.workspace,
      builder: (c, _) {
        final all = st.workspace.sorted;
        final p = c.p;
        return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (current != null)
                _pickRow(c, p, context.l.wsUnbind, Ic.close,
                    () => Navigator.of(c).pop(kUnbindWorkspace)),
              for (final w in all)
                _pickRow(c, p, w.name, w.id == current ? Ic.check : Ic.folder,
                    () => Navigator.of(c).pop(w.id)),
              if (all.isEmpty)
                WsEmpty(
                    icon: Ic.folder,
                    title: context.l.wsEmpty,
                    hint: context.l.wsEmptyHint),
            ]);
      },
    ),
    title: context.l.wsBindTitle,
  );
}

Widget _pickRow(
        BuildContext c, Pal p, String title, Ic icon, VoidCallback onTap) =>
    Tap(
      highlight: true,
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Row(children: [
          const SizedBox(width: 21),
          TgIcon(icon, color: p.icon, size: 22),
          const SizedBox(width: 16),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: p.title,
                      fontSize: 16,
                      decoration: TextDecoration.none))),
          const SizedBox(width: 21),
        ]),
      ),
    );

/// The chat menu row: shows the current workspace and opens the picker.
class WorkspaceChatRow extends StatelessWidget {
  const WorkspaceChatRow({super.key, required this.chat});
  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final st = Store.of(context);
    final w = st.wsFor(chat);
    final l = context.l;
    return TgTextCell(
      title: w == null ? l.wsBind : w.name,
      subtitle: w == null ? null : st.wsSummary(chat),
      icon: w == null ? Ic.folder : Ic.folderOpen,
      onTap: () => bindWorkspace(context, st, chat),
    );
  }
}

/// Opens the picker and applies the answer.
///
/// Unbinding a chat whose tools have already run asks first: the files the
/// assistant wrote are still on the device either way, but the user may not
/// have realised the chat is currently pointed at them.
Future<void> bindWorkspace(BuildContext context, Store st, Chat chat) async {
  final l = context.l;
  final pick = await pickWorkspace(context, current: chat.ws.workspaceId);
  if (pick == null || !context.mounted) return;
  if (pick == kUnbindWorkspace) {
    if (chat.ws.toolsUsed) {
      final ok = await askConfirm(context,
          title: l.wsUnbind,
          message: l.wsUnbindConfirm,
          confirmLabel: l.wsUnbind);
      if (!ok || !context.mounted) return;
    }
    chat.ws = WorkspaceBinding();
  } else {
    chat.ws = WorkspaceBinding(
        workspaceId: pick, cwd: st.workspace.byId(pick)?.defaultCwd ?? '');
  }
  chat.touch();
  st.saveChat(chat);
}
