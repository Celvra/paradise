import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' as ip;

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/ai/tokenizer.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'ai_widgets.dart';

// crown, the default persona marker, drawn on the same 24 grid as every TgIcon
const _crown = Color(0xFFFFC107);

/// Order the picker lists the positions in. The wording comes from
/// [positionOption], so the labels stay translatable and never drift.
const _positionOptions = <PersonaPosition>[
  PersonaPosition.inPrompt,
  PersonaPosition.topNote,
  PersonaPosition.bottomNote,
  PersonaPosition.atDepth,
  PersonaPosition.none,
];

/// The position labels, keyed by the position rather than the tuple so the
/// switch stays exhaustive if a new one is ever added.
({String label, String sub}) positionOption(AppLocalizations l, PersonaPosition at) => switch (at) {
      PersonaPosition.topNote => (label: l.posTopNote, sub: l.posTopNoteSub),
      PersonaPosition.bottomNote => (label: l.posBottomNote, sub: l.posBottomNoteSub),
      PersonaPosition.atDepth => (label: l.posAtDepth, sub: l.posAtDepthSub),
      PersonaPosition.none => (label: l.posNone, sub: l.posNoneSub),
      PersonaPosition.inPrompt => (label: l.posInPrompt, sub: l.posInPromptSub),
    };

const _roleOptions = <(PersonaRole, String)>[
  (PersonaRole.system, 'roleSystem'),
  (PersonaRole.user, 'roleUser'),
  (PersonaRole.assistant, 'roleAssistant'),
];

/// The role labels, resolved from the keys the tuple carries.
String roleLabel(AppLocalizations l, PersonaRole role) => switch (role) {
      PersonaRole.user => l.roleUser,
      PersonaRole.assistant => l.roleAssistant,
      PersonaRole.system => l.roleSystem,
    };

const _avatarPalette = <List<Color>>[
  [Color(0xFFFF845E), Color(0xFFD45246)],
  [Color(0xFFFEBB5B), Color(0xFFF68136)],
  [Color(0xFFB694F9), Color(0xFF6C61DF)],
  [Color(0xFF9AD164), Color(0xFF46BA43)],
  [Color(0xFF5BCBE3), Color(0xFF359AD4)],
  [Color(0xFF5CAFFA), Color(0xFF408ACF)],
  [Color(0xFFFF8AAC), Color(0xFFD95574)],
];

/// My own persona cards, the user side of a SillyTavern persona. Sits inside
/// My Account between the bio and the footer.
class PersonaCardsSection extends StatefulWidget {
  const PersonaCardsSection({super.key});

  @override
  State<PersonaCardsSection> createState() => _PersonaCardsSectionState();
}

class _PersonaCardsSectionState extends State<PersonaCardsSection> {
  late Store _st;
  late UserPersona _card;
  late final TextEditingController _name;
  late final TextEditingController _title;
  late final TextEditingController _desc;
  String _name0 = '';
  String _title0 = '';
  String _desc0 = '';
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _st = Store.read(context);
      // the section is responsible for its own rebuilds, a store change made
      // from inside it would otherwise only repaint the ancestor
      _st.addListener(_onStore);
      _card = _st.activePersona;
      _name = TextEditingController(text: _card.name);
      _title = TextEditingController(text: _card.title);
      _desc = TextEditingController(text: _card.description);
      _name0 = _card.name;
      _title0 = _card.title;
      _desc0 = _card.description;
      _loaded = true;
      return;
    }
    // a switch from the strip or from a chat lock repoints the editors
    if (_card.id != _st.activePersona.id) {
      setState(_sync);
    }
  }

  /// Repoint the editors at the card the store now considers active. A switch
  /// can come from the strip, from a chat lock, or from a card deleted
  /// elsewhere, and committing a stale controller would write the old card's
  /// text over whatever is selected now.
  void _sync() {
    final next = _st.activePersona;
    _card = next;
    _name.text = next.name;
    _title.text = next.title;
    _desc.text = next.description;
    _name0 = next.name;
    _title0 = next.title;
    _desc0 = next.description;
  }

  /// a lock or a selection moved outside this widget, catch up and repaint
  void _onStore() {
    if (!mounted) return;
    if (_card.id != _st.activePersona.id) {
      setState(_sync);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _st.removeListener(_onStore);
    _name.dispose();
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  bool get _dirty => _name.text != _name0 || _title.text != _title0 || _desc.text != _desc0;

  void _commit() {
    // if the store moved to another card while this one was open, the editors
    // still hold the old card's text and writing them would overwrite whatever
    // is selected now
    if (_card.id != _st.activePersona.id) {
      _sync();
      return;
    }
    _st.updatePersonaCard(_card.id, (p) {
      p.name = _name.text.trim();
      p.title = _title.text.trim();
      p.description = _desc.text;
    });
    _name0 = _name.text;
    _title0 = _title.text;
    _desc0 = _desc.text;
    setState(() {});
  }

  void _newCard() {
    _commit();
    final created = _st.createPersonaCard();
    setState(() {
      _card = created;
      _name.text = '';
      _title.text = '';
      _desc.text = '';
      _name0 = '';
      _title0 = '';
      _desc0 = '';
    });
  }

  void _duplicate() {
    _commit();
    final copy = _st.duplicatePersonaCard(_card.id);
    setState(() {
      _card = copy;
      _name.text = copy.name;
      _title.text = copy.title;
      _desc.text = copy.description;
      _name0 = copy.name;
      _title0 = copy.title;
      _desc0 = copy.description;
    });
    showBulletin(context, context.l.cardDuplicated);
  }

  Future<void> _remove() async {
    final l = context.l;
    final ok = await showTgDialog<bool>(
      context,
      title: l.cardDeleteTitle,
      message: l.cardDeleteMessage(_card.name.trim().isEmpty ? l.cardDeleteThisCard : _card.name.trim()),
      actions: [DialogAction(l.actionCancel, false), DialogAction(l.actionDelete, true, danger: true)],
    );
    if (ok != true || !mounted) return;
    _st.deletePersonaCard(_card.id);
    // the store already moved on to the next card, the editors follow it
    setState(_sync);
    showBulletin(context, l.cardDeleted);
  }

  Future<void> _pickAvatar() async {
    try {
      final x = await ip.ImagePicker().pickImage(source: ip.ImageSource.gallery, imageQuality: 92);
      if (x != null) _st.updatePersonaCard(_card.id, (p) => p.avatarPath = x.path);
    } catch (_) {
      if (mounted) showBulletin(context, context.l.galleryUnavailable);
    }
  }

  Future<void> _pickPosition() async {
    final l = context.l;
    final picked = await showAiSelect<PersonaPosition>(
      context,
      title: l.cardPositionTitle,
      value: _card.position,
      options: [for (final o in _positionOptions) (value: o, label: positionOption(l, o).label, sub: positionOption(l, o).sub)],
    );
    if (picked == null) return;
    _st.updatePersonaCard(_card.id, (p) => p.position = picked);
  }

  Future<void> _pickRole() async {
    final l = context.l;
    final picked = await showAiSelect<PersonaRole>(
      context,
      title: l.cardRoleTitle,
      value: _card.role,
      options: [for (final o in _roleOptions) (value: o.$1, label: roleLabel(l, o.$1), sub: null)],
    );
    if (picked == null) return;
    _st.updatePersonaCard(_card.id, (p) => p.role = picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    _st = Store.read(context);
    final cards = _st.personas;
    if (!_st.personas.any((e) => e.id == _card.id)) _card = _st.activePersona;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // header row with the create action on the right
      SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 7, 12, 0),
          child: Row(children: [
            // the title gives way first, the actions are the useful part
            Expanded(
              child: Text(context.l.profileLabelPersonaCard, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.accent, fontSize: 14, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
            ),
            if (cards.isNotEmpty) _mini(p, context.l.cardDuplicate, Ic.copy, _duplicate),
            _mini(p, context.l.cardNew, Ic.plus, _newCard),
          ]),
        ),
      ),
      if (cards.isEmpty)
        _empty(p)
      else ...[
        SizedBox(height: 84, child: _strip(p, cards)),
        _editor(p),
        _connections(p),
        _info(p, context.l.cardInfoFooter),
      ],
    ]);
  }

  // header icon button, same 40 tall row as the section title
  Widget _mini(Pal p, String label, Ic ic, VoidCallback onTap) => Tap(
        scale: .88,
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [TgIcon(ic, color: p.accent, size: 17, stroke: 2), const SizedBox(width: 4), Text(label, style: TextStyle(color: p.accent, fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none))])),
      );

  Widget _empty(Pal p) => Container(
        color: p.bg,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
        child: Column(children: [
          TgIcon(Ic.user, color: p.subtitle.withAlpha(120), size: 40, stroke: 1.6),
          const SizedBox(height: 12),
          Text(context.l.cardEmptyTitle, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text(context.l.cardEmptyBody, textAlign: TextAlign.center, style: TextStyle(color: p.subtitle, fontSize: 14, height: 1.35, decoration: TextDecoration.none)),
          const SizedBox(height: 16),
          TgButton(label: context.l.cardCreate, onTap: _newCard),
        ]),
      );

  // horizontal card strip, the mobile stand in for the ST persona list column
  Widget _strip(Pal p, List<UserPersona> cards) => ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, i) => _cardTile(p, cards[i]),
      );

  Widget _cardTile(Pal p, UserPersona c) {
    final on = c.id == _card.id;
    final isDefault = _st.isDefault(c.id);
    return Tap(
      scale: .96,
      onTap: () {
        _commit();
        _st.selectPersona(c.id);
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: TgCurves.easeOut,
        width: 168,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: on ? p.accent.withAlpha(p.dark ? 26 : 18) : p.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDefault ? _crown : (on ? p.accent : p.divider),
            width: isDefault ? 1.8 : (on ? 1.4 : .5),
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _avatar(p, c, 34),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text(c.name.trim().isEmpty ? context.l.lockSheetUnnamed : c.name.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 15, fontWeight: FontWeight.w600, decoration: TextDecoration.none))),
                if (isDefault) const Padding(padding: EdgeInsets.only(left: 4), child: TgIcon(Ic.crown, color: _crown, size: 14, stroke: 1.8)),
              ]),
              if (c.title.trim().isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(c.title.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 12.5, decoration: TextDecoration.none)),
              ],
              const SizedBox(height: 3),
              Text(c.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: on ? p.title.withAlpha(190) : p.subtitle, fontSize: 12, height: 1.28, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _avatar(Pal p, UserPersona c, double size) {
    final g = _avatarPalette[c.color % _avatarPalette.length];
    final ring = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: TgCurves.easeOutBack,
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _st.isDefault(c.id) ? _crown : const Color(0x00000000), width: 1.6)),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: g)),
        clipBehavior: Clip.antiAlias,
        child: c.avatarPath.isEmpty
            ? Center(child: Text(c.initial, style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: size * .42, fontWeight: FontWeight.w500, decoration: TextDecoration.none)))
            : Image.file(File(c.avatarPath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(c.initial, style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: size * .42, fontWeight: FontWeight.w500, decoration: TextDecoration.none)))),
      ),
    );
    return SizedBox(width: size, height: size, child: Tap(scale: .9, onTap: _pickAvatar, child: Stack(children: [ring, Positioned(right: 0, bottom: 0, child: Container(width: 15, height: 15, alignment: Alignment.center, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle, border: Border.all(color: p.bg, width: 1.5)), child: TgIcon(Ic.camera, color: const Color(0xFFFFFFFF), size: 9, stroke: 2.2))) ])));
  }

  // name / title / description editors for the card in hand
  Widget _editor(Pal p) {
    final card = _card;
    return Container(
      color: p.bg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
          child: Row(children: [
            AnimatedAvatar(path: card.avatarPath, name: card.name, color: card.color, size: 54, onTap: _pickAvatar, onLongPress: card.avatarPath.isEmpty ? null : () => _st.updatePersonaCard(card.id, (c) => c.avatarPath = '')),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.l.cardEditing, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none)),
                const SizedBox(height: 2),
                Text(card.name.trim().isEmpty ? context.l.lockSheetUnnamed : card.name.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        _row(p, context.l.cardFieldName, _name, context.l.cardFieldNameHint),
        _row(p, context.l.cardFieldTitle, _title, context.l.cardFieldTitleHint),
        _descRow(p),
        _positionRow(p, card),
        if (card.position == PersonaPosition.atDepth) _depthRow(p, card),
      ]),
    );
  }

  Widget _row(Pal p, String label, TextEditingController c, String hint) => Container(
        color: p.bg,
        padding: const EdgeInsets.fromLTRB(18, 9, 18, 9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(label, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none)),
          const SizedBox(height: 2),
          TgEdit(controller: c, hint: hint, maxLines: 1, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none), hintStyle: TextStyle(color: p.hint, fontSize: 16, decoration: TextDecoration.none), cursor: p.accent),
        ]),
      );

  Widget _descRow(Pal p) {
    return Container(
      color: p.bg,
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(context.l.cardFieldDescription, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none)),
          const Spacer(),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _desc,
            builder: (_, v, __) => Text(context.l.pluralTokens(estimateTokens(v.text)), style: TextStyle(color: p.subtitle, fontSize: 12, decoration: TextDecoration.none)),
          ),
        ]),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: p.gray, borderRadius: BorderRadius.circular(10), border: Border.all(color: p.divider, width: .5)),
          child: TgEdit(controller: _desc, hint: context.l.cardDescHint, maxLines: 10, style: TextStyle(color: p.title, fontSize: 15, height: 1.35, decoration: TextDecoration.none), hintStyle: TextStyle(color: p.hint, fontSize: 15, height: 1.35, decoration: TextDecoration.none), cursor: p.accent),
        ),
        const SizedBox(height: 5),
        Text(context.l.cardPlaceholdersHint, style: TextStyle(color: p.subtitle, fontSize: 12, height: 1.3, decoration: TextDecoration.none)),
      ]),
    );
  }

  Widget _positionRow(Pal p, UserPersona card) {
    final l = L10n.current;
    final opt = positionOption(l, card.position);
    return Tap(
      highlight: true,
      onTap: _pickPosition,
      child: SizedBox(
        height: 52,
        child: Row(children: [
          const SizedBox(width: 18),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.cardPositionLabel, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none)),
            Text(opt.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 12.5, decoration: TextDecoration.none)),
          ])),
          Text(opt.label, style: TextStyle(color: p.subtitle, fontSize: 14.5, decoration: TextDecoration.none)),
          const SizedBox(width: 6),
          TgIcon(Ic.chevron, color: p.subtitle, size: 18, stroke: 1.8),
          const SizedBox(width: 14),
        ]),
      ),
    );
  }

  Widget _depthRow(Pal p, UserPersona card) {
    final l = L10n.current;
    return Container(
        color: p.bg,
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text(l.cardDepthLabel, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none)),
            const Spacer(),
            Text(l.cardDepthMessages(card.depth), style: TextStyle(color: p.subtitle, fontSize: 14, decoration: TextDecoration.none)),
          ]),
          TgSlider(value: card.depth.toDouble(), min: 1, max: 20, onChanged: (v) => _st.updatePersonaCard(card.id, (c) => c.depth = v.toInt())),
          const SizedBox(height: 6),
          Tap(
            highlight: true,
            onTap: _pickRole,
            child: SizedBox(
              height: 40,
              child: Row(children: [
                Text(l.cardRoleLabel, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none)),
                const Spacer(),
                Text(switch (card.role) { PersonaRole.system => l.roleSystem, PersonaRole.user => l.roleUser, PersonaRole.assistant => l.roleAssistant }, style: TextStyle(color: p.subtitle, fontSize: 15, decoration: TextDecoration.none)),
                const SizedBox(width: 6),
                TgIcon(Ic.chevron, color: p.subtitle, size: 18, stroke: 1.8),
              ]),
            ),
          ),
        ]),
      );
  }

  // default crown, chat lock and character lock, the ST connections row
  Widget _connections(Pal p) {
    final l = L10n.current;
    final card = _card;
    final isDefault = _st.isDefault(card.id);
    final charNames = _st.chats.map((c) => c.persona.name).where((n) => n.trim().isNotEmpty).toSet().toList()..sort();
    final lockedChars = charNames.where((n) => _st.lockedTo(n).any((e) => e.id == card.id)).toList();
    return Container(
      color: p.bg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
          child: Text(l.cardConnectionsHeader, style: TextStyle(color: p.accent, fontSize: 13, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
        ),
        _connTile(p, Ic.crown, l.cardDefaultLabel, isDefault ? l.cardFallbackSub : l.cardSetFallback, isDefault ? _crown : null, () => _st.toggleDefaultPersona(card.id)),
        _connTile(p, Ic.chats, l.cardChatLabel, l.cardLockToChat, null, () {
          _commit();
          if (_st.chats.isEmpty) {
            showBulletin(context, l.cardNoChat);
          } else {
            showBulletin(context, l.cardNoChatSub);
          }
        }),
        _connTile(p, Ic.ai, l.cardCharacterLabel, lockedChars.isEmpty ? l.cardLinkPersona : lockedChars.join(', '), null, () {
          _commit();
          if (charNames.isEmpty) {
            showBulletin(context, l.cardNoChat);
            return;
          }
          showTgSheet<void>(context, (_) => _CharLinkSheet(names: charNames, cardId: card.id, store: _st));
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
          child: Row(children: [
            Expanded(child: TgOutline(label: l.cardSave, onTap: _dirty ? _commit : null)),
            const SizedBox(width: 10),
            if (_st.personas.length > 1) _deleteBtn(p),
          ]),
        ),
      ]),
    );
  }

  Widget _connTile(Pal p, Ic ic, String title, String sub, Color? active, VoidCallback onTap) => Tap(
        highlight: true,
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Row(children: [
            const SizedBox(width: 18),
            TgIcon(ic, color: active ?? p.subtitle, size: 21, stroke: 1.9),
            const SizedBox(width: 14),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: active ?? p.title, fontSize: 16, decoration: TextDecoration.none)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 12.5, decoration: TextDecoration.none)),
            ])),
            if (active != null) TgIcon(Ic.check, color: active, size: 20, stroke: 2.2) else TgIcon(Ic.chevron, color: p.subtitle, size: 18, stroke: 1.8),
            const SizedBox(width: 14),
          ]),
        ),
      );

  Widget _deleteBtn(Pal p) => Tap(
        scale: .96,
        onTap: _remove,
        child: Container(
          width: 96,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.danger.withAlpha(30), borderRadius: BorderRadius.circular(10)),
          child: Text('Delete', style: TextStyle(color: p.danger, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
        ),
      );

  // TextInfoPrivacyCell, the note under a block
  Widget _info(Pal p, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 17),
        child: Text(text, style: TextStyle(color: p.subtitle, fontSize: 14, height: 1.35, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
      );
}

/// avatar with the camera badge used by the strip and the editor
class AnimatedAvatar extends StatelessWidget {
  const AnimatedAvatar({super.key, required this.path, required this.name, required this.color, required this.size, this.onTap, this.onLongPress});
  final String path;
  final String name;
  final int color;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final g = _avatarPalette[color % _avatarPalette.length];
    final ch = name.trim().isEmpty ? '?' : String.fromCharCodes(name.trim().runes.take(1)).toUpperCase();
    return Tap(
      scale: .95,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: g)),
        child: path.isEmpty
            ? Center(child: Text(ch, style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: size * .4, fontWeight: FontWeight.w500, decoration: TextDecoration.none)))
            : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(ch, style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: size * .4, fontWeight: FontWeight.w500, decoration: TextDecoration.none)))),
      ),
    );
  }
}

/// outlined button for the save action
class TgOutline extends StatelessWidget {
  const TgOutline({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: onTap == null ? .45 : 1,
      child: Tap(
        scale: .97,
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.accent.withAlpha(p.dark ? 28 : 18), borderRadius: BorderRadius.circular(10), border: Border.all(color: p.accent, width: 1)),
          child: Text(label, style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
        ),
      ),
    );
  }
}

// character link picker, the ST character lock dialog
class _CharLinkSheet extends StatefulWidget {
  const _CharLinkSheet({required this.names, required this.cardId, required this.store});
  final List<String> names;
  final String cardId;
  final Store store;

  @override
  State<_CharLinkSheet> createState() => _CharLinkSheetState();
}

class _CharLinkSheetState extends State<_CharLinkSheet> {
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    return TgSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.66),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text(context.l.cardLinkCharacter, style: TextStyle(color: p.title, fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                for (final n in widget.names)
                  Builder(builder: (_) {
                    final on = widget.store.lockedTo(n).any((e) => e.id == widget.cardId);
                    return Tap(
                      scale: .99,
                      onTap: () => widget.store.toggleCharLock(n, widget.cardId),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                        decoration: BoxDecoration(color: on ? p.accent.withAlpha(28) : p.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? p.accent : const Color(0x00000000), width: .6)),
                        child: Row(children: [
                          Expanded(child: Text(n, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none))),
                          if (on) TgIcon(Ic.check, color: p.accent, size: 20, stroke: 2.2),
                        ]),
                      ),
                    );
                  }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TgButton(label: context.l.actionDone, onTap: () => Navigator.of(context).pop()),
          ),
        ]),
      ),
    );
  }
}