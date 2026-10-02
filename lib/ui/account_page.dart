import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' as ip;

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'tg_cells.dart';
import 'user_persona.dart';

// My Account, laid out like the current Telegram Android "Edit profile"
// (UserInfoActivity): a centred avatar with a "Set Photo" link on top, then
// "Your name" and "Your bio" blocks made of bare EditTextCells with grey notes,
// the photo actions as TextCells, and the done check in the action bar that
// only scales in once something actually changed.
void openAccount(BuildContext context) {
  Navigator.of(context).push(TgRoute(builder: (_) => const AccountPage()));
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  // getAboutLimit, the bio cap the server enforces
  static const _aboutLimit = 70;

  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _scroll = ScrollController();
  String _name0 = '';
  String _bio0 = '';
  bool _raised = false;

  @override
  void initState() {
    super.initState();
    final st = Store.read(context);
    _name.text = st.userName;
    _bio.text = st.userBio;
    _name0 = st.userName;
    _bio0 = st.userBio;
    // the original silently drops anything past the cap as you type
    _bio.addListener(() {
      if (_bio.text.length > _aboutLimit) {
        _bio.value = TextEditingValue(text: _bio.text.substring(0, _aboutLimit), selection: const TextSelection.collapsed(offset: _aboutLimit));
      }
    });
    _name.addListener(_refresh);
    _bio.addListener(_refresh);
    _scroll.addListener(() {
      final r = _scroll.offset > 1;
      if (r != _raised) setState(() => _raised = r);
    });
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _dirty => _name.text != _name0 || _bio.text != _bio0;

  void _save() {
    if (_name.text.trim().isEmpty) {
      showBulletin(context, context.l.accountNameRequired);
      return;
    }
    Store.read(context).setProfile(name: _name.text, bio: _bio.text);
    Navigator.of(context).maybePop();
  }

  // Telegram asks before throwing edits away
  Future<void> _back() async {
    if (!_dirty) {
      Navigator.of(context).maybePop();
      return;
    }
    final l = context.l;
    final r = await showTgDialog<bool>(context, title: l.accountDiscardTitle, message: l.accountDiscardMessage, actions: [
      DialogAction(l.actionCancel, false),
      DialogAction(l.actionDiscard, true, danger: true),
    ]);
    if (r == true && mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final mq = MediaQuery.of(context);
    final st = context.store;
    final hasPhoto = st.userAvatar.isNotEmpty;
    return SwipeBack(
      child: ColoredBox(
        color: p.gray,
        child: Column(children: [
          _bar(p),
          Expanded(
            child: ListView(
              controller: _scroll,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(bottom: mq.padding.bottom + mq.viewInsets.bottom + 24),
              children: [
                _hero(p, st),
                const SizedBox(height: 12),
                TgSection(
                  header: l.accountNameHeader,
                  footer: l.accountNameFooter,
                  children: [TgEditCell(controller: _name, hint: l.accountNameHint)],
                ),
                TgSection(
                  header: l.accountBioHeader,
                  footer: l.accountBioFooter,
                  children: [TgEditCell(controller: _bio, hint: l.accountBioHint, lines: 5, max: _aboutLimit)],
                ),
                TgSection(
                  footer: hasPhoto ? l.accountPhotoFooter : null,
                  children: [
                    TgTextCell(icon: Ic.camera, title: hasPhoto ? l.accountSetNewPhoto : l.accountSetPhoto, color: p.accent, onTap: _pick, divider: hasPhoto),
                    if (hasPhoto) TgTextCell(icon: Ic.trash, title: l.accountRemovePhoto, color: p.danger, onTap: _confirmClear, divider: false),
                  ],
                ),
                const PersonaCardsSection(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _bar(Pal p) {
    final top = MediaQuery.of(context).padding.top;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: p.bar,
        boxShadow: [if (_raised) BoxShadow(color: p.dark ? const Color(0x40000000) : const Color(0x1A000000), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      padding: EdgeInsets.only(top: top),
      height: top + 56,
      child: Row(children: [
        Tap(scale: .88, onTap: _back, child: SizedBox(width: 56, height: 56, child: Center(child: TgIcon(Ic.back, color: p.icon, size: 24)))),
        const SizedBox(width: 8),
        Expanded(child: Text(context.l.accountTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 20, fontWeight: FontWeight.w600, decoration: TextDecoration.none))),
        TgDoneAction(visible: _dirty, onTap: _save),
      ]),
    );
  }

  // the centred avatar block, live preview of the name being typed
  Widget _hero(Pal p, Store st) {
    final name = _name.text.trim().isEmpty ? context.l.accountNameEmptyPreview : _name.text.trim();
    final bio = _bio.text.trim();
    return Container(
      color: p.bg,
      padding: const EdgeInsets.fromLTRB(21, 24, 21, 18),
      child: Column(children: [
        Tap(
          scale: .94,
          onTap: _pick,
          onLongPress: st.userAvatar.isEmpty ? null : _confirmClear,
          child: SizedBox(
            width: 104,
            height: 104,
            child: Stack(children: [
              Avatar(name: _name.text, color: 4, size: 104, path: st.userAvatar),
              // camera badge in the corner, the same affordance as the profile cover
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle, border: Border.all(color: p.bg, width: 3)),
                  child: const Center(child: TgIcon(Ic.camera, color: Color(0xFFFFFFFF), size: 16, stroke: 2)),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 22, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
        const SizedBox(height: 4),
        Text(bio.isEmpty ? context.l.accountOnlineFallback : bio, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(color: bio.isEmpty ? p.accent : p.subtitle, fontSize: 14, height: 1.3, fontWeight: FontWeight.w400, decoration: TextDecoration.none)),
        const SizedBox(height: 12),
        Tap(
          scale: .96,
          onTap: _pick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(color: p.accent.withAlpha(26), borderRadius: BorderRadius.circular(16)),
            child: Text(st.userAvatar.isEmpty ? context.l.accountPhotoActionSet : context.l.accountPhotoActionChange, style: TextStyle(color: p.accent, fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
          ),
        ),
      ]),
    );
  }

  Future<void> _pick() async {
    try {
      final x = await ip.ImagePicker().pickImage(source: ip.ImageSource.gallery, imageQuality: 92);
      if (x != null && mounted) Store.read(context).setAvatar(x.path);
    } catch (_) {
      if (mounted) showBulletin(context, context.l.galleryUnavailable);
    }
  }

  Future<void> _confirmClear() async {
    final l = context.l;
    final r = await showTgDialog<bool>(context, title: l.accountRemovePhotoTitle, message: l.accountRemovePhotoMessage, actions: [
      DialogAction(l.actionCancel, false),
      DialogAction(l.actionRemove, true, danger: true),
    ]);
    if (r != true || !mounted) return;
    Store.read(context).setAvatar('');
    showBulletin(context, l.accountPhotoRemoved);
  }
}
