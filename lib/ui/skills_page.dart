import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/skills/skill.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'human_pages.dart' show hAsk, hOpen;
import 'tg_cells.dart';

/// Installed skills: what the assistant may read through the `read_skill`
/// tool. Reached from settings. Each role then picks which of these it
/// actually lists in its own prompt.
void openSkillsSettings(BuildContext c) => hOpen(c, const SkillsPage());

class SkillsPage extends StatelessWidget {
  const SkillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return TgSettingsPage(
      title: l.skillTitle,
      actions: [
        Tap(
          scale: .88,
          onTap: () => _importMenu(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TgIcon(Ic.plus, color: context.p.title, size: 24),
          ),
        ),
      ],
      builder: (c, _) => ListenableBuilder(
        listenable: Store.of(c).skills,
        builder: (c, _) {
          final st = Store.of(c);
          final all = st.skills.skills;
          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              TgSection(
                footer: l.skillEmptyBody,
                children: [
                  if (all.isEmpty)
                    TgTextCell(title: l.skillEmptyTitle, divider: false),
                  for (var i = 0; i < all.length; i++)
                    _row(c, st, all[i], last: i == all.length - 1),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, Store st, Skill skill, {required bool last}) {
    final l = context.l;
    return TgTextCell(
      title: skill.name,
      subtitle: '${skill.id} · ${skill.enabled ? l.skillEnabled : l.skillDisabled} · ${l.skillDetailUses(skill.useCount)}',
      icon: Ic.fileCode,
      divider: !last,
      trailing: TgSwitch(
        value: skill.enabled,
        onChanged: (v) => st.skills.setEnabled(skill.id, v),
      ),
      onTap: () => hOpen(context, SkillDetailPage(id: skill.id)),
    );
  }

  Future<void> _importMenu(BuildContext context) async {
    final l = context.l;
    final how = await showTgDialog<String>(
      context,
      title: l.skillImport,
      actions: [
        DialogAction(l.actionCancel, null),
        DialogAction(l.skillImportPaste, 'paste'),
        DialogAction(l.skillImportFile, 'file'),
        DialogAction(l.skillImportUrl, 'url'),
      ],
    );
    if (how == null || !context.mounted) return;
    if (how == 'paste') {
      await _importPaste(context);
    } else if (how == 'file') {
      await _importFile(context);
    } else {
      await _importUrl(context);
    }
  }

  Future<void> _importPaste(BuildContext context) async {
    final st = Store.read(context);
    final l = context.l;
    final text = await hAsk(context, l.skillPasteTitle, l.skillPasteHint, lines: 8);
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    try {
      final skill = await st.skills.importFromText(text);
      if (!context.mounted) return;
      hOpen(context, SkillDetailPage(id: skill.id));
    } catch (_) {
      if (context.mounted) showBulletin(context, l.skillInvalid);
    }
  }

  Future<void> _importFile(BuildContext context) async {
    final st = Store.read(context);
    final l = context.l;
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['md', 'zip']);
    final path = picked.firstOrNull?.path;
    if (path == null || !context.mounted) return;
    try {
      final skill = await st.skills.importFromFile(path);
      if (!context.mounted) return;
      hOpen(context, SkillDetailPage(id: skill.id));
    } catch (_) {
      if (context.mounted) showBulletin(context, l.skillInvalid);
    }
  }

  Future<void> _importUrl(BuildContext context) async {
    final st = Store.read(context);
    final l = context.l;
    final url = await hAsk(context, l.skillUrlTitle, l.skillUrlHint);
    if (url == null || url.trim().isEmpty || !context.mounted) return;
    showBulletin(context, l.skillImporting);
    try {
      final skill = await st.skills.importFromGitHub(url.trim());
      if (!context.mounted) return;
      hOpen(context, SkillDetailPage(id: skill.id));
    } catch (_) {
      if (context.mounted) showBulletin(context, l.skillUrlError);
    }
  }
}

/// One skill: its description, usage, the raw instructions and management.
class SkillDetailPage extends StatefulWidget {
  const SkillDetailPage({super.key, required this.id});
  final String id;

  @override
  State<SkillDetailPage> createState() => _SkillDetailState();
}

class _SkillDetailState extends State<SkillDetailPage> {
  String? _body;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = Store.read(context);
    final skill = st.skills.byId(widget.id);
    if (skill == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final text = await File(skill.mdPath).readAsString();
      if (mounted) setState(() {
        _body = text;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return TgSettingsPage(
      title: widget.id,
      builder: (c, _) => ListenableBuilder(
        listenable: Store.of(c).skills,
        builder: (c, _) {
          final st = Store.of(c);
          final skill = st.skills.byId(widget.id);
          if (skill == null) {
            return ListView(children: [TgSection(children: [TgTextCell(title: l.skillInvalid, divider: false)])]);
          }
          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              TgSection(
                footer: l.skillOpenFile,
                children: [
                  TgTextCell(title: skill.name, subtitle: skill.id, divider: true),
                  TgTextCell(title: skill.description.isEmpty ? l.skillEmptyTitle : skill.description, divider: true),
                  TgTextCell(title: l.skillDetailUses(skill.useCount), divider: false),
                  TgCheckCell(
                    title: l.skillEnabled,
                    icon: Ic.check2,
                    value: skill.enabled,
                    divider: false,
                    onChanged: (v) => st.skills.setEnabled(skill.id, v),
                  ),
                ],
              ),
              TgSection(
                header: 'SKILL.md',
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(21, 12, 21, 12),
                    child: Text(
                      _loading ? '…' : (_body ?? l.skillInvalid),
                      style: TextStyle(color: c.p.title, fontSize: 13.5, height: 1.45, decoration: TextDecoration.none, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
              TgSection(children: [
                TgTextCell(
                  title: l.skillDeleteTitle,
                  color: c.p.danger,
                  divider: false,
                  onTap: () => _delete(c, st, skill),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, Store st, Skill skill) async {
    final l = context.l;
    final ok = await showTgDialog<bool>(
      context,
      title: l.skillDeleteTitle,
      message: l.skillDeleteMessage(skill.name),
      actions: [DialogAction(l.actionCancel, false), DialogAction(l.actionDelete, true, danger: true)],
    );
    if (ok != true || !context.mounted) return;
    await st.skills.delete(skill.id);
    if (context.mounted) Navigator.of(context).maybePop();
  }
}

/// Picker used by the role editor: follow the global set or name exactly
/// the skills this role may use.
///
/// Returns `(changed, ids)`: `changed` is false when the sheet was
/// dismissed, `ids` is null for "follow global".
Future<(bool, List<String>?)> pickRoleSkills(BuildContext context, List<String>? current) async {
  final st = Store.of(context);
  final all = st.skills.resolveFor(null);
  if (all.isEmpty) return (false, null);
  final l = context.l;
  // null = follow global. A copy is edited in the sheet; cancel drops it.
  List<String>? selected = current == null ? null : [...current];
  final result = await showTgSheet<(bool, List<String>?)>(context, (c) {
    return StatefulBuilder(builder: (c, setSheet) {
      final following = selected == null;
      return TgSheet(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text(l.personaSkillsPickTitle, style: TextStyle(color: c.p.title, fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
          ),
          Tap(
            scale: .99,
            onTap: () => setSheet(() => selected = null),
            child: _pickCell(c, l.personaSkillsFollowGlobal, following),
          ),
          Tap(
            scale: .99,
            onTap: () => setSheet(() => selected = [for (final s in all) s.id]),
            child: _pickCell(c, l.personaSkillsCustom, !following),
          ),
          if (!following)
            for (final s in all)
              Tap(
                scale: .99,
                onTap: () => setSheet(() {
                  final List<String> list = [...(selected ?? <String>[])];
                  if (list.contains(s.id)) {
                    list.remove(s.id);
                  } else {
                    list.add(s.id);
                  }
                  selected = list;
                }),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: (selected ?? []).contains(s.id) ? c.p.accent.withAlpha(28) : c.p.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (selected ?? []).contains(s.id) ? c.p.accent : const Color(0x00000000), width: .6),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.name, style: TextStyle(color: c.p.title, fontSize: 16, decoration: TextDecoration.none)),
                        const SizedBox(height: 2),
                        Text(s.id, style: TextStyle(color: c.p.subtitle, fontSize: 13, decoration: TextDecoration.none)),
                      ]),
                    ),
                    if ((selected ?? []).contains(s.id)) TgIcon(Ic.check, color: c.p.accent, size: 20, stroke: 2.2),
                  ]),
                ),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TgButton(
              label: l.actionOk,
              onTap: () => Navigator.of(c).pop((true, selected)),
            ),
          ),
        ]),
      );
    });
  });
  return result ?? (false, null);
}

Widget _pickCell(BuildContext c, String label, bool on) {
  return Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: on ? c.p.accent.withAlpha(28) : c.p.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: on ? c.p.accent : const Color(0x00000000), width: .6),
    ),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: c.p.title, fontSize: 16, decoration: TextDecoration.none))),
      if (on) TgIcon(Ic.check, color: c.p.accent, size: 20, stroke: 2.2),
    ]),
  );
}
