import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' as ip;

import '../../core/anim.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../l10n/x.dart';
import '../tg_cells.dart';
import '../user_persona.dart' show positionOption, roleLabel;
import 'common.dart';

/// Step 7: who the assistants talk to. Writes onto the user's persona card,
/// the same one My Account edits, so nothing the user types here lives in a
/// parallel world. Full fields: photo, name, title, description, injection
/// position and role. Depth only matters for atDepth and keeps the card
/// default, editable later in My Account.
OnboardingStep buildSelfStep() => OnboardingStep(
      title: (l) => l.onboardSelfTitle,
      body: (l) => l.onboardSelfBody,
      build: (c, flow) => const _SelfBody(),
    );

class _SelfBody extends StatefulWidget {
  const _SelfBody();

  @override
  State<_SelfBody> createState() => _SelfBodyState();
}

class _SelfBodyState extends State<_SelfBody> {
  late final Store _st = context.store;
  late UserPersona _card = _st.personas.isNotEmpty ? _st.activePersona : _st.createPersonaCard();
  late final TextEditingController _name = TextEditingController(text: _card.name == 'You' ? '' : _card.name);
  late final TextEditingController _title = TextEditingController(text: _card.title);
  late final TextEditingController _desc = TextEditingController(text: _card.description);

  @override
  void dispose() {
    _save();
    _name.dispose();
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  /// Persists the three text fields onto the card and mirrors the name into
  /// the legacy flat profile the rest of the app reads. A completely empty
  /// step removes the stub card this page created instead of saving "You".
  void _save() {
    final name = _name.text.trim();
    final title = _title.text.trim();
    final desc = _desc.text.trim();
    if (name.isEmpty && title.isEmpty && desc.isEmpty && _card.avatarPath.isEmpty) {
      if (_st.personas.length == 1) _st.deletePersonaCard(_card.id);
      return;
    }
    _st.updatePersonaCard(_card.id, (p) {
      p.name = name.isEmpty ? 'You' : name;
      p.title = title;
      p.description = desc;
    });
    _st.setProfile(name: name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = context.p;
    // the card object is replaced by updatePersonaCard, so re-read it
    _card = _st.activePersona;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      children: [
        Center(
          child: Column(children: [
            Avatar(name: _name.text, color: _card.color, size: 88, path: _card.avatarPath),
            const SizedBox(height: 10),
            Tap(
              scale: .94,
              onTap: _pickPhoto,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: p.accent.withAlpha(24), borderRadius: BorderRadius.circular(9)),
                child: Text(l.onboardSelfPhoto, style: TextStyle(color: p.accent, fontSize: 13.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        TgSection(
          header: l.onboardSelfName,
          children: [
            TgEditCell(controller: _name, hint: l.onboardSelfName),
          ],
        ),
        TgSection(
          header: l.onboardSelfTitleLabel,
          children: [
            TgEditCell(controller: _title, hint: l.onboardSelfTitleLabel),
          ],
        ),
        TgSection(
          header: l.onboardSelfDesc,
          footer: l.onboardSelfDescHint,
          children: [
            TgEditCell(controller: _desc, hint: l.onboardSelfDescHint, lines: 4),
          ],
        ),
        TgSection(
          header: l.onboardSelfInjected,
          children: [
            for (final at in PersonaPosition.values)
              RadioRow(
                title: positionOption(l, at).label,
                subtitle: positionOption(l, at).sub,
                selected: _card.position == at,
                onTap: () => setState(() => _st.updatePersonaCard(_card.id, (x) => x.position = at)),
              ),
          ],
        ),
        TgSection(
          header: l.onboardSelfRole,
          children: [
            for (final role in PersonaRole.values)
              RadioRow(
                title: roleLabel(l, role),
                selected: _card.role == role,
                onTap: () => setState(() => _st.updatePersonaCard(_card.id, (x) => x.role = role)),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final x = await ip.ImagePicker().pickImage(source: ip.ImageSource.gallery, imageQuality: 92);
      if (x == null) return;
      _st.updatePersonaCard(_card.id, (p) => p.avatarPath = x.path);
      if (mounted) setState(() {});
    } catch (_) {}
  }
}
