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
import 'tg_cells.dart';

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
({String label, String sub}) positionOption(
        AppLocalizations l, PersonaPosition at) =>
    switch (at) {
      PersonaPosition.topNote => (label: l.posTopNote, sub: l.posTopNoteSub),
      PersonaPosition.bottomNote => (
          label: l.posBottomNote,
          sub: l.posBottomNoteSub
        ),
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

/// My own persona cards, the user side of a SillyTavern persona.
///
/// Laid out like the rest of My Account: white blocks separated by the 12 tall
/// shadow gap, accent header cells, plain rows with a value on the right, bare
/// inputs with no box around them, and centred text actions at the bottom. No
/// rounded cards, no filled or outlined buttons, nothing to break the run of
/// blocks the page is made of.
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
      // typing never reaches the section on its own, and the save row decides
      // whether it is armed by reading the three controllers. Without these the
      // row stayed asleep after an edit, so the text could not be stored at all
      _name.addListener(_refresh);
      _title.addListener(_refresh);
      _desc.addListener(_refresh);
      _name0 = _card.name;
      _title0 = _card.title;
      _desc0 = _card.description;
      _loaded = true;
      return;
    }
    // a switch from the picker or from a chat lock repoints the editors
    if (_card.id != _st.activePersona.id) {
      setState(_sync);
    }
  }

  /// Repoint the editors at the card the store now considers active. A switch
  /// can come from the picker, from a chat lock, or from a card deleted
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

  /// a key stroke in any of the three editors, the save row reads them
  void _refresh() {
    if (mounted) setState(() {});
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

  bool get _dirty =>
      _name.text != _name0 || _title.text != _title0 || _desc.text != _desc0;

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

  /// A fresh card becomes the one in hand, the store moves on and the listener
  /// repoints the editors, so the caller only has to hand the card back.
  UserPersona _newCard() {
    _commit();
    return _st.createPersonaCard();
  }

  void _duplicate() {
    _commit();
    _st.duplicatePersonaCard(_card.id);
    showBulletin(context, context.l.cardDuplicated);
  }

  Future<void> _remove() async {
    final l = context.l;
    final ok = await showTgDialog<bool>(
      context,
      title: l.cardDeleteTitle,
      message: l.cardDeleteMessage(
          _card.name.trim().isEmpty ? l.cardDeleteThisCard : _card.name.trim()),
      actions: [
        DialogAction(l.actionCancel, false),
        DialogAction(l.actionDelete, true, danger: true)
      ],
    );
    if (ok != true || !mounted) return;
    _st.deletePersonaCard(_card.id);
    // the store already moved on to the next card, the editors follow it
    setState(_sync);
    showBulletin(context, l.cardDeleted);
  }

  /// The picker hands back the card it wants in hand. A pending edit is stored
  /// against the card it was typed into before the switch.
  Future<void> _pickCard() async {
    final id = await showTgSheet<String>(
        context,
        (_) => _CardPickerSheet(
            cards: _st.personas,
            active: _card.id,
            fallback: _st.defaultPersona?.id ?? '',
            onCreate: _newCard));
    if (id == null || !mounted) return;
    if (id == _card.id) return;
    _commit();
    _st.selectPersona(id);
  }

  void _clearPhoto() {
    _st.updatePersonaCard(_card.id, (p) => p.avatarPath = '');
    showBulletin(context, context.l.cardRemovePhoto);
  }

  Future<void> _pickAvatar(String id) async {
    try {
      final x = await ip.ImagePicker()
          .pickImage(source: ip.ImageSource.gallery, imageQuality: 92);
      if (x != null) _st.updatePersonaCard(id, (p) => p.avatarPath = x.path);
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
      options: [
        for (final o in _positionOptions)
          (
            value: o,
            label: positionOption(l, o).label,
            sub: positionOption(l, o).sub
          )
      ],
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
      options: [
        for (final o in _roleOptions)
          (value: o.$1, label: roleLabel(l, o.$1), sub: null)
      ],
    );
    if (picked == null) return;
    _st.updatePersonaCard(_card.id, (p) => p.role = picked);
  }

  /// the characters this card can be pinned to, the ST character lock dialog
  List<String> _characters() => _st.chats
      .map((c) => c.persona.name)
      .where((n) => n.trim().isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  Future<void> _linkCharacter() async {
    final l = context.l;
    _commit();
    final names = _characters();
    if (names.isEmpty) {
      showBulletin(context, l.cardNoChat);
      return;
    }
    await showTgSheet<void>(context,
        (_) => _CharLinkSheet(names: names, cardId: _card.id, store: _st));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    _st = Store.read(context);
    final cards = _st.personas;
    if (!cards.any((e) => e.id == _card.id)) _card = _st.activePersona;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cards.isEmpty)
          _empty(p)
        else ...[
          _whichCard(p),
          _editor(p),
          _inject(p),
          _connections(p),
          _actions(p),
        ],
      ],
    );
  }

  /// Nothing saved yet, so only the create row and a note under the block.
  Widget _empty(Pal p) {
    final l = context.l;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TgSection(
          header: l.profileLabelPersonaCard,
          children: [
            TgTextCell(
                icon: Ic.plus,
                title: l.cardCreate,
                color: p.accent,
                onTap: _newCard,
                divider: false)
          ],
          gap: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 14, 21, 0),
          child: Column(children: [
            Text(l.cardEmptyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: p.title,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none)),
            const SizedBox(height: 4),
            Text(l.cardEmptyBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: p.subtitle,
                    fontSize: 14,
                    height: 1.35,
                    decoration: TextDecoration.none)),
          ]),
        ),
      ],
    );
  }

  /// Which card is in hand. One row, the name on the right, the sheet behind
  /// it carries the whole list, so nothing has to be laid out as a strip.
  Widget _whichCard(Pal p) {
    final l = context.l;
    final card = _card;
    final desc = card.description.trim();
    return TgSection(
      header: l.profileLabelPersonaCard,
      children: [
        TgTextCell(
          leading: AnimatedAvatar(
              path: card.avatarPath,
              name: card.name,
              color: card.color,
              size: 34),
          title: l.cardCurrentLabel,
          subtitle: desc.isEmpty ? null : desc,
          value:
              card.name.trim().isEmpty ? l.lockSheetUnnamed : card.name.trim(),
          // the whole list now lives behind this row, so it has to say it opens
          trailing:
              TgIcon(Ic.chevron, color: p.subtitle, size: 18, stroke: 1.8),
          onTap: _pickCard,
          divider: true,
        ),
        TgTextCell(
            icon: Ic.plus,
            title: l.cardNew,
            color: p.accent,
            onTap: _newCard,
            divider: false),
      ],
    );
  }

  /// Avatar, then the three bare inputs. Edit profile's shape: the picture on
  /// its own with the accent link under it, no box drawn around any field.
  Widget _editor(Pal p) {
    final l = context.l;
    final card = _card;
    return TgSection(
      header: l.cardEditing,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 18, 21, 16),
          child: Column(children: [
            AnimatedAvatar(
              path: card.avatarPath,
              name: card.name,
              color: card.color,
              size: 64,
              onTap: () => _pickAvatar(card.id),
              onLongPress: card.avatarPath.isEmpty ? null : _clearPhoto,
            ),
            const SizedBox(height: 10),
            Tap(
              onTap: () => _pickAvatar(card.id),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(l.cardSetPhoto,
                    style: TextStyle(
                        color: p.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none)),
              ),
            ),
          ]),
        ),
        TgEditCell(
            controller: _name,
            hint: l.cardFieldNameHint,
            label: l.cardFieldName,
            divider: true),
        TgEditCell(
            controller: _title,
            hint: l.cardFieldTitleHint,
            label: l.cardFieldTitle,
            divider: true),
        _descCell(p),
      ],
      footer: l.cardInfoFooter,
    );
  }

  /// The description is the one field that gets a live readout, so the counter
  /// rides the label row the way the bio cell's countdown rides its own.
  Widget _descCell(Pal p) {
    final l = context.l;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 10, 21, 0),
          child: Row(children: [
            Text(l.cardFieldDescription,
                style: TextStyle(
                    color: p.subtitle,
                    fontSize: 13,
                    height: 1.2,
                    decoration: TextDecoration.none)),
            const Spacer(),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _desc,
              builder: (_, v, __) => Text(
                  l.pluralTokens(estimateTokens(v.text)),
                  style: TextStyle(
                      color: p.subtitle,
                      fontSize: 12,
                      decoration: TextDecoration.none)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 4, 21, 0),
          child: TgEdit(
            controller: _desc,
            hint: l.cardDescHint,
            maxLines: 6,
            style: TextStyle(
                color: p.title,
                fontSize: 17,
                height: 1.35,
                decoration: TextDecoration.none),
            hintStyle: TextStyle(
                color: p.hint,
                fontSize: 17,
                height: 1.35,
                decoration: TextDecoration.none),
            cursor: p.accent,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 10, 21, 15),
          child: Text(l.cardPlaceholdersHint,
              style: TextStyle(
                  color: p.subtitle,
                  fontSize: 13,
                  height: 1.3,
                  decoration: TextDecoration.none)),
        ),
      ],
    );
  }

  /// Where the card lands in the prompt, and the two controls that position
  /// brings with it. Plain rows, the value on the right like every settings
  /// row, the seek bar under the row it belongs to.
  Widget _inject(Pal p) {
    final l = context.l;
    final card = _card;
    final atDepth = card.position == PersonaPosition.atDepth;
    final opt = positionOption(l, card.position);
    return TgSection(
      children: [
        TgTextCell(
            title: l.cardPositionLabel,
            subtitle: opt.sub,
            value: opt.label,
            onTap: _pickPosition,
            divider: atDepth),
        if (atDepth)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TgTextCell(
                  title: l.cardDepthLabel,
                  value: l.cardDepthMessages(card.depth),
                  divider: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: TgSlider(
                    value: card.depth.toDouble(),
                    min: 1,
                    max: 20,
                    onChanged: (v) => _st.updatePersonaCard(
                        card.id, (c) => c.depth = v.toInt())),
              ),
              TgTextCell(
                  title: l.cardRoleLabel,
                  value: roleLabel(l, card.role),
                  onTap: _pickRole,
                  divider: false),
            ],
          ),
      ],
    );
  }

  /// Default marker, chat lock and character lock, the ST connections rows.
  Widget _connections(Pal p) {
    final l = context.l;
    final card = _card;
    final isDefault = _st.isDefault(card.id);
    final lockedChars = _characters()
        .where((n) => _st.lockedTo(n).any((e) => e.id == card.id))
        .toList();
    return TgSection(
      header: l.cardConnectionsHeader,
      children: [
        TgTextCell(
          // the icon slot, not leading: leading is the avatar column at 13,
          // which pulled the crown left of the chats and ai icons below
          icon: Ic.crown,
          iconColor: isDefault ? _crown : p.icon,
          title: l.cardDefaultLabel,
          subtitle: isDefault ? l.cardFallbackSub : l.cardSetFallback,
          color: isDefault ? p.accent : null,
          trailing: isDefault
              ? TgIcon(Ic.check, color: p.accent, size: 22, stroke: 2.2)
              : null,
          onTap: () => _st.toggleDefaultPersona(card.id),
          divider: true,
        ),
        TgTextCell(
          icon: Ic.chats,
          title: l.cardChatLabel,
          subtitle: l.cardLockToChat,
          onTap: () {
            _commit();
            showBulletin(
                context, _st.chats.isEmpty ? l.cardNoChat : l.cardNoChatSub);
          },
          divider: true,
        ),
        TgTextCell(
          icon: Ic.ai,
          title: l.cardCharacterLabel,
          subtitle:
              lockedChars.isEmpty ? l.cardLinkPersona : lockedChars.join(', '),
          trailing:
              TgIcon(Ic.chevron, color: p.subtitle, size: 18, stroke: 1.8),
          onTap: _linkCharacter,
          divider: false,
        ),
      ],
    );
  }

  /// Centred text actions, the way a Telegram profile ends. The save row greys
  /// out instead of disappearing, so the block keeps its shape either way.
  Widget _actions(Pal p) {
    final l = context.l;
    final many = _st.personas.length > 1;
    return TgSection(
      children: [
        TgActionRow(
            label: l.cardSave, onTap: _dirty ? _commit : null, divider: true),
        TgActionRow(label: l.cardDuplicate, onTap: _duplicate, divider: many),
        if (many)
          TgActionRow(
              label: l.cardDeleteTitle,
              onTap: _remove,
              danger: true,
              divider: false),
      ],
      gap: false,
    );
  }
}

/// avatar with the photo link under it, also used by the chat header
class AnimatedAvatar extends StatelessWidget {
  const AnimatedAvatar(
      {super.key,
      required this.path,
      required this.name,
      required this.color,
      required this.size,
      this.onTap,
      this.onLongPress});
  final String path;
  final String name;
  final int color;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final g = _avatarPalette[color % _avatarPalette.length];
    final ch = name.trim().isEmpty
        ? '?'
        : String.fromCharCodes(name.trim().runes.take(1)).toUpperCase();
    return Tap(
      scale: .95,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: g)),
        child: path.isEmpty
            ? Center(
                child: Text(ch,
                    style: TextStyle(
                        color: const Color(0xFFFFFFFF),
                        fontSize: size * .4,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none)))
            : Image.file(File(path),
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                errorBuilder: (_, __, ___) => Center(
                    child: Text(ch,
                        style: TextStyle(
                            color: const Color(0xFFFFFFFF),
                            fontSize: size * .4,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none)))),
      ),
    );
  }
}

/// The sheet behind the "current card" row: every card as one flat row, the
/// one in hand ticked, the default one crowned, and the create row Telegram
/// puts at the bottom of a list like this.
class _CardPickerSheet extends StatelessWidget {
  const _CardPickerSheet(
      {required this.cards,
      required this.active,
      required this.fallback,
      required this.onCreate});

  final List<UserPersona> cards;
  final String active;
  final String fallback;
  final UserPersona Function() onCreate;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final mq = MediaQuery.of(context);
    return TgSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * .66),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(l.cardPickTitle,
                    style: TextStyle(
                        color: p.title,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (var i = 0; i < cards.length; i++)
                      _row(context, p, cards[i], last: i == cards.length - 1),
                    _rule(p),
                    TgTextCell(
                      icon: Ic.plus,
                      title: l.cardNew,
                      color: p.accent,
                      onTap: () => Navigator.of(context).pop(onCreate().id),
                      divider: false,
                    ),
                  ],
                ),
              ),
            ]),
      ),
    );
  }

  /// the thin rule between two sheet rows, it starts at the text column so it
  /// lines up with the names instead of cutting through the avatars
  Widget _rule(Pal p) => Padding(
      padding: const EdgeInsets.only(left: 72, right: 21),
      child: Container(height: .5, color: p.divider));

  Widget _row(BuildContext context, Pal p, UserPersona c,
      {required bool last}) {
    final l = context.l;
    final on = c.id == active;
    final name = c.name.trim().isEmpty ? l.lockSheetUnnamed : c.name.trim();
    final desc = c.description.trim();
    return Tap(
      onTap: () => Navigator.of(context).pop(c.id),
      child: SizedBox(
        height: 60,
        child: Stack(children: [
          Positioned(
              left: 21,
              top: 0,
              bottom: 0,
              child: Center(
                  child: AnimatedAvatar(
                      path: c.avatarPath,
                      name: c.name,
                      color: c.color,
                      size: 34))),
          Positioned.fill(
            left: 72,
            child: Row(children: [
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: on ? p.accent : p.title,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.none)),
                      if (desc.isNotEmpty)
                        Text(desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: p.subtitle,
                                fontSize: 13.5,
                                decoration: TextDecoration.none)),
                    ]),
              ),
              if (on)
                TgIcon(Ic.check, color: p.accent, size: 22, stroke: 2.2)
              else if (c.id == fallback)
                TgIcon(Ic.crown, color: _crown, size: 18, stroke: 1.8),
              const SizedBox(width: 21),
            ]),
          ),
          if (!last)
            Positioned(
                left: 72,
                right: 0,
                bottom: 0,
                child: Container(height: .5, color: p.divider)),
        ]),
      ),
    );
  }
}

/// Character lock picker, the ST character lock dialog: the same flat rows, a
/// tick per character this card is already pinned to.
class _CharLinkSheet extends StatelessWidget {
  const _CharLinkSheet(
      {required this.names, required this.cardId, required this.store});

  final List<String> names;
  final String cardId;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final mq = MediaQuery.of(context);
    return TgSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * .66),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(l.cardLinkCharacter,
                    style: TextStyle(
                        color: p.title,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (var i = 0; i < names.length; i++)
                      TgTextCell(
                        title: names[i],
                        trailing:
                            store.lockedTo(names[i]).any((e) => e.id == cardId)
                                ? TgIcon(Ic.check,
                                    color: p.accent, size: 22, stroke: 2.2)
                                : null,
                        onTap: () => store.toggleCharLock(names[i], cardId),
                        divider: i != names.length - 1,
                      ),
                  ],
                ),
              ),
              TgActionRow(
                  label: l.actionDone,
                  onTap: () => Navigator.of(context).pop()),
            ]),
      ),
    );
  }
}
