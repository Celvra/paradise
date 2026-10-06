import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' as ip;

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/ai/provider_model.dart';
import '../data/models.dart';
import '../data/speech_config.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'ai_model_picker.dart';
import 'ai_widgets.dart';
import 'skills_page.dart' show pickRoleSkills, openSkillsSettings;
import 'tg_cells.dart';

/// Emoji, the one line pitch the user sees and the system prompt that goes to
/// the model. Only the first two are translated, the prompt stays english so
/// the model reads the same instructions in every language.
const _presets = <(String, String, String, String)>[
  (
    'Assistant',
    '✨',
    'presetAssistantBio',
    'You are a helpful, concise assistant.'
  ),
  (
    'Coder',
    '💻',
    'presetCoderBio',
    'You are a senior software engineer. Answer with short explanations and runnable code in fenced blocks.'
  ),
  (
    'Translator',
    '🌐',
    'presetTranslatorBio',
    'You translate between English and Chinese. Detect the language and reply only with the translation.'
  ),
  (
    'Writer',
    '✍️',
    'presetWriterBio',
    'You are a sharp editor and writer. Improve clarity and rhythm and keep the voice of the author.'
  ),
  (
    'Tutor',
    '🎓',
    'presetTutorBio',
    'You are a patient tutor. Explain step by step with simple examples and check understanding.'
  ),
];

/// The preset one liner, resolved from the key the tuple carries.
String _presetBio(AppLocalizations l, int i) => switch (_presets[i].$3) {
      'presetAssistantBio' => l.presetAssistantBio,
      'presetCoderBio' => l.presetCoderBio,
      'presetTranslatorBio' => l.presetTranslatorBio,
      'presetWriterBio' => l.presetWriterBio,
      _ => l.presetTutorBio,
    };

// full page persona card with a live profile style preview
Future<Chat?> openPersonaCard(BuildContext context, {Chat? chat}) {
  return Navigator.of(context)
      .push<Chat>(TgRoute(builder: (_) => PersonaCardPage(chat: chat)));
}

class PersonaCardPage extends StatefulWidget {
  const PersonaCardPage({super.key, this.chat});
  final Chat? chat;

  @override
  State<PersonaCardPage> createState() => _PersonaCardPageState();
}

class _PersonaCardPageState extends State<PersonaCardPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.chat?.persona.name ?? '');
  late final TextEditingController _bio =
      TextEditingController(text: widget.chat?.persona.bio ?? '');
  late final TextEditingController _prompt =
      TextEditingController(text: widget.chat?.persona.prompt ?? '');
  late final TextEditingController _greet =
      TextEditingController(text: widget.chat?.persona.greeting ?? '');
  late int _color = widget.chat?.persona.color ?? 5;
  late String _emoji = widget.chat?.persona.emoji ?? '';

  /// local photo, empty falls back to the emoji or the initial
  late String _avatar = widget.chat?.persona.avatarPath ?? '';
  // model override, an empty provider means this persona follows the chain
  late String _modelProvider = widget.chat?.persona.modelProvider ?? '';
  late String _modelId = widget.chat?.persona.modelId ?? '';
  late bool _modelFallback = widget.chat?.persona.modelFallback ?? true;
  // per persona answer to the two global reply switches, null follows them
  late bool? _thinking = widget.chat?.persona.thinking;
  late bool? _agent = widget.chat?.persona.agent;
  // clingy: proactive check-ins after the user stays quiet, plus an optional
  // cap on how many proactive messages in a row the persona may send
  late bool _clingy = widget.chat?.persona.clingy ?? false;
  late int _clingySilentMin = widget.chat?.persona.clingySilentMin ?? 90;
  late bool _clingyCap = widget.chat?.persona.clingyCap ?? false;
  late int _clingyMax = widget.chat?.persona.clingyMax ?? 3;
  // skills this role may use, null follows the global set
  late List<String>? _skillIds = widget.chat?.persona.skillIds == null ? null : [...widget.chat!.persona.skillIds!];
  // drawing and speaking, per role. The switches are plain bools (off
  // unless turned on); the endpoint strings are empty when the role follows
  // the global default, the same rule the model override already follows.
  late bool _imageOn = widget.chat?.persona.imageEnabled ?? false;
  late String _imageProvider = widget.chat?.persona.imageProvider ?? '';
  late String _imageModel = widget.chat?.persona.imageModel ?? '';
  late String _imageSize = widget.chat?.persona.imageSize ?? '';
  late bool _ttsOn = widget.chat?.persona.ttsEnabled ?? false;
  late TtsEngine? _ttsEngine = widget.chat?.persona.ttsEngine;
  // endpoint and model overrides: empty follows the voice module, which is the
  // common case; a role that must use a different server can name its own.
  late String _ttsBaseUrl = widget.chat?.persona.ttsBaseUrl ?? '';
  late String _ttsModel = widget.chat?.persona.ttsModel ?? '';
  late String _ttsVoice = widget.chat?.persona.ttsVoice ?? '';
  late bool _ttsAutoSpeak = widget.chat?.persona.ttsAutoSpeak ?? false;
  int _preset = -1;

  bool get _editing => widget.chat != null;

  /// both halves have to be there, a provider with no model is treated as unset
  bool get _override =>
      _modelProvider.trim().isNotEmpty && _modelId.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // PopScope.canPop reads _dirty at build time, so every keystroke has to
    // rebuild the page or the back button would act on a stale answer
    for (final c in [_name, _bio, _prompt, _greet]) {
      c.addListener(_onFieldChange);
    }
  }

  void _onFieldChange() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _bio, _prompt, _greet]) {
      c.removeListener(_onFieldChange);
    }
    _name.dispose();
    _bio.dispose();
    _prompt.dispose();
    _greet.dispose();
    super.dispose();
  }

  void _pickPreset(int i) {
    final e = _presets[i];
    setState(() {
      _preset = i;
      _emoji = e.$2;
      if (_name.text.trim().isEmpty) _name.text = e.$1;
      _bio.text = _presetBio(context.l, i);
      _prompt.text = e.$4;
    });
  }

  Future<void> _pickModel() async {
    final cfg = AiScope.read(context);
    final l = context.l;
    final picked = await showAiModelPicker(
      context,
      cfg: cfg,
      title: l.personaModelForThis,
      allowFollowChain: true,
      followTitle: l.personaModelGlobal,
      followSubtitle: l.personaModelGlobalSub,
    );
    if (picked == null) return;
    setState(() {
      _modelProvider = picked.providerId;
      _modelId = picked.modelId;
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final x = await ip.ImagePicker()
          .pickImage(source: ip.ImageSource.gallery, imageQuality: 92);
      if (x != null && mounted) setState(() => _avatar = x.path);
    } catch (_) {
      if (mounted) showBulletin(context, context.l.galleryUnavailable);
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final prompt = _prompt.text.trim().isEmpty
        ? 'You are a helpful assistant.'
        : _prompt.text.trim();
    final st = Store.read(context);
    // an override that was never completed is stored as no override at all
    final mp = _override ? _modelProvider.trim() : '';
    final mi = _override ? _modelId.trim() : '';
    if (_editing) {
      st.editPersona(widget.chat!, name, prompt,
          bio: _bio.text.trim(),
          greeting: _greet.text.trim(),
          emoji: _emoji,
          avatarPath: _avatar,
          color: _color,
          modelProvider: mp,
          modelId: mi,
          modelFallback: _modelFallback,
          thinking: _thinking,
          agent: _agent,
          clingy: _clingy,
          clingySilentMin: _clingySilentMin,
          clingyCap: _clingyCap,
          clingyMax: _clingyMax,
          skillIds: _skillIds == null ? null : [..._skillIds!],
          clearSkillIds: _skillIds == null);
      st.setPersonaGen(widget.chat!,
          imageEnabled: _imageOn,
          imageProvider: _imageProvider,
          imageModel: _imageModel,
          imageSize: _imageSize,
          ttsEnabled: _ttsOn,
          ttsEngine: _ttsEngine,
          ttsBaseUrl: _ttsBaseUrl,
          ttsModel: _ttsModel,
          ttsVoice: _ttsVoice,
          ttsAutoSpeak: _ttsAutoSpeak);
      Navigator.of(context).pop(widget.chat);
    } else {
      Navigator.of(context).pop(st.createChat(name, prompt,
          bio: _bio.text.trim(),
          greeting: _greet.text.trim(),
          emoji: _emoji,
          avatarPath: _avatar,
          color: _color,
          modelProvider: mp,
          modelId: mi,
          modelFallback: _modelFallback,
          thinking: _thinking,
          agent: _agent,
clingy: _clingy,
          clingySilentMin: _clingySilentMin,
          clingyCap: _clingyCap,
          clingyMax: _clingyMax,
          skillIds: _skillIds == null ? null : [..._skillIds!],
          imageEnabled: _imageOn,
          imageProvider: _imageProvider,
          imageModel: _imageModel,
          imageSize: _imageSize,
          ttsEnabled: _ttsOn,
          ttsEngine: _ttsEngine,
          ttsBaseUrl: _ttsBaseUrl,
          ttsModel: _ttsModel,
          ttsVoice: _ttsVoice,
          ttsAutoSpeak: _ttsAutoSpeak));
    }
  }

  /// 'Follow global' / 'On' / 'Off' as the row on the right
  String _tri(bool? v) {
    final l = context.l;
    return v == null
        ? l.personaReplyFollowGlobal
        : (v ? l.profileOn : l.profileOff);
  }

  Future<void> _pickOverride(
      String title, bool? current, void Function(bool?) set) async {
    final l = context.l;
    final v = await showAiSelect<bool?>(
      context,
      title: title,
      value: current,
      options: [
        (
          value: null,
          label: l.personaReplyFollowGlobal,
          sub: l.personaReplyUseGlobal
        ),
        (value: true, label: l.profileOn, sub: l.personaReplyAlwaysOn),
        (value: false, label: l.profileOff, sub: l.personaReplyAlwaysOff),
      ],
    );
    if (v == null && current == null) return;
    setState(() => set(v));
  }

  // anything typed counts as a change worth confirming before leaving
  bool get _dirty {
    final c = widget.chat?.persona;
    if (c == null)
      return _name.text.trim().isNotEmpty ||
          _bio.text.trim().isNotEmpty ||
          _prompt.text.trim().isNotEmpty ||
          _greet.text.trim().isNotEmpty ||
          _skillIds != null;
    return _name.text != c.name ||
        _bio.text != c.bio ||
        _prompt.text != c.prompt ||
        _greet.text != c.greeting ||
        _emoji != c.emoji ||
        _avatar != c.avatarPath ||
        _color != c.color ||
        _modelProvider != c.modelProvider ||
        _modelId != c.modelId ||
        _modelFallback != c.modelFallback ||
        _thinking != c.thinking ||
        _agent != c.agent ||
_clingy != c.clingy ||
        _clingySilentMin != c.clingySilentMin ||
        _clingyCap != c.clingyCap ||
        _clingyMax != c.clingyMax ||
        !_sameSkills(_skillIds, c.skillIds) ||
        _imageOn != c.imageEnabled ||
        _imageProvider != c.imageProvider ||
        _imageModel != c.imageModel ||
        _imageSize != c.imageSize ||
        _ttsOn != c.ttsEnabled ||
        _ttsEngine != c.ttsEngine ||
        _ttsBaseUrl != c.ttsBaseUrl ||
        _ttsModel != c.ttsModel ||
        _ttsVoice != c.ttsVoice ||
        _ttsAutoSpeak != c.ttsAutoSpeak;
  }

  static bool _sameSkills(List<String>? a, List<String>? b) {
    if (a == null || b == null) return a == null && b == null;
    if (a.length != b.length) return false;
    final set = b.toSet();
    return a.every(set.contains);
  }

  /// Whether leaving is safe: true pops, false stays. The close button, the
  /// system back and the right-swipe gesture all funnel through here so no
  /// exit path skips the discard confirmation.
  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final l = context.l;
    final r = await showTgDialog<bool>(context,
        title: l.accountDiscardTitle,
        message: _editing ? l.personaDiscardExisting : l.personaDiscardNew,
        actions: [
          DialogAction(l.actionCancel, false),
          DialogAction(l.actionDiscard, true, danger: true),
        ]);
    return r == true;
  }

  Future<void> _back() async {
    if (await _confirmLeave() && mounted) Navigator.of(context).pop();
  }

  double _offset = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    // the bar fades from transparent over the cover to the solid action bar
    final heroH = 268 + top;
    final solid = ((_offset - (heroH - top - 56 - 40)) / 40).clamp(0.0, 1.0);
    // Every exit asks before discarding: system back goes through PopScope,
    // the finger swipe through SwipeBack.confirm, the close button through
    // _back, and all three end up in _confirmLeave.
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !mounted) return;
        // confirmed: a direct pop, so the guard does not see its own attempt
        if (await _confirmLeave() && mounted) Navigator.of(context).pop();
      },
      child: SwipeBack(
        confirm: _confirmLeave,
      child: ColoredBox(
        color: p.gray,
        child: Stack(children: [
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.axis == Axis.vertical &&
                    n.metrics.pixels != _offset)
                  setState(() => _offset = n.metrics.pixels);
                return false;
              },
              child: ListView(
                padding: EdgeInsets.only(
                    bottom: mq.padding.bottom + mq.viewInsets.bottom + 96),
                physics: const ClampingScrollPhysics(),
                children: [
                  _preview(p, top, heroH),
                  const SizedBox(height: 12),
                  _templates(p),
                  TgSection(header: l.personaNameHeader, children: [
                    TgEditCell(
                        controller: _name, hint: l.personaNameHint, max: 32)
                  ]),
                  TgSection(
                    header: l.personaAboutHeader,
                    footer: l.personaAboutFooter,
                    children: [
                      TgEditCell(
                          controller: _bio,
                          hint: l.accountBioHint,
                          lines: 3,
                          max: 70)
                    ],
                  ),
                  _appearance(p),
                  TgSection(
                    header: l.personaInstructionsHeader,
                    footer: l.personaInstructionsFooter,
                    children: [
                      TgEditCell(
                          controller: _prompt,
                          hint: l.personaInstructionsHint,
                          lines: 8,
                          max: 1200)
                    ],
                  ),
                  TgSection(
                    header: l.personaGreetingHeader,
                    footer: l.personaGreetingFooter,
                    children: [
                      TgEditCell(
                          controller: _greet,
                          hint: l.personaGreetingHint,
                          lines: 4,
                          max: 300)
                    ],
                  ),
                  _modelSection(p),
                  _replySection(),
_clingySection(),
                  _voiceImageSection(p),
                  _skillsSection(),
                ],
              ),
            ),
          ),
          // ActionBar over the cover, white icons that turn into the regular bar
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: top + 56,
              padding: EdgeInsets.only(top: top),
              decoration: BoxDecoration(
                color: Color.lerp(const Color(0x00000000), p.bar, solid),
                boxShadow: [
                  if (solid >= 1)
                    BoxShadow(
                        color: p.dark
                            ? const Color(0x40000000)
                            : const Color(0x1A000000),
                        blurRadius: 3,
                        offset: const Offset(0, 1))
                ],
              ),
              child: Row(children: [
                Tap(
                    scale: .88,
                    onTap: _back,
                    child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                            child: TgIcon(Ic.back,
                                color: Color.lerp(
                                    const Color(0xFFFFFFFF), p.icon, solid)!,
                                size: 24)))),
                const SizedBox(width: 8),
                Expanded(
                  child: Opacity(
                    opacity: solid,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _name,
                      builder: (_, v, __) => Text(
                          v.text.trim().isEmpty
                              ? (_editing
                                  ? l.headerMenuEditPersona
                                  : l.chatsNewPersona)
                              : v.text.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: p.title,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none)),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _name,
                  builder: (_, v, __) => TgDoneAction(
                      visible: v.text.trim().isNotEmpty, onTap: _save),
                ),
              ]),
            ),
          ),
          // the large bottom button newer Telegram flows end with
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, mq.padding.bottom + mq.viewInsets.bottom + 12),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [p.gray.withAlpha(0), p.gray, p.gray],
                      stops: const [0, .35, 1])),
              child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _name,
                  builder: (_, v, __) => TgButton(
                      label: _editing ? l.personaSave : l.personaCreate,
                      enabled: v.text.trim().isNotEmpty,
                      onTap: _save)),
            ),
          ),
        ]),
      ),
      ),
    );
  }

  // presets as the rounded chips Telegram uses for folder and topic suggestions
  Widget _templates(Pal p) {
    final l = context.l;
    return TgSection(
      header: l.personaTemplatesHeader,
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            itemCount: _presets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final on = _preset == i;
              return Tap(
                scale: .95,
                onTap: () => _pickPreset(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: TgCurves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? p.accent.withAlpha(30) : p.gray,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: on ? p.accent : const Color(0x00000000),
                        width: 1.2),
                  ),
                  child: Text('${_presets[i].$2}  ${_presets[i].$1}',
                      style: TextStyle(
                          color: on ? p.accent : p.title,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none)),
                ),
              );
            },
          ),
        ),
      ],
      footer: _preset < 0 ? null : _presetBio(l, _preset),
    );
  }

  // Profile color picker, the two tone circles with a check on the active one,
  // followed by the emoji that is drawn on the cover pattern
  Widget _appearance(Pal p) {
    final hasPhoto = _avatar.isNotEmpty;
    final l = context.l;
    return TgSection(
      header: l.personaAppearanceHeader,
      footer: hasPhoto
          ? l.personaAppearanceFooterPhoto
          : l.personaAppearanceFooterColor,
      children: [
        // the photo row, tap to pick and long press to drop it again
        SizedBox(
          height: 84,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(21, 12, 21, 12),
            child: Row(children: [
              Tap(
                scale: .9,
                onTap: _pickPhoto,
                onLongPress:
                    hasPhoto ? () => setState(() => _avatar = '') : null,
                child: Container(
                  width: 60,
                  height: 60,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: p.avatar(_color)),
                  ),
                  child: _avatar.isEmpty
                      ? Center(
                          child: Text(
                              _name.text.trim().isEmpty
                                  ? '?'
                                  : _name.text
                                      .trim()
                                      .characters
                                      .first
                                      .toUpperCase(),
                              style: const TextStyle(
                                  color: Color(0xFFFFFFFF),
                                  fontSize: 25,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none)))
                      : Image.file(File(_avatar),
                          fit: BoxFit.cover,
                          cacheWidth: 240,
                          errorBuilder: (_, __, ___) => const Center(
                              child: TgIcon(Ic.camera,
                                  color: Color(0xFFFFFFFF),
                                  size: 22,
                                  stroke: 1.8))),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          hasPhoto
                              ? l.personaPhotoTitle
                              : l.personaPhotoTitleEmpty,
                          style: TextStyle(
                              color: p.title,
                              fontSize: 16,
                              decoration: TextDecoration.none)),
                      const SizedBox(height: 2),
                      Text(
                          hasPhoto
                              ? l.personaPhotoSubFull
                              : l.personaPhotoSubEmpty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: p.subtitle,
                              fontSize: 13.5,
                              decoration: TextDecoration.none,
                              fontWeight: FontWeight.w400)),
                    ]),
              ),
              // a plain text button, TgTextCell is a full width row and cannot
              // sit inside another Row, its stack asks for unbounded width
              Tap(
                scale: .95,
                onTap:
                    hasPhoto ? () => setState(() => _avatar = '') : _pickPhoto,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(hasPhoto ? l.actionRemove : l.personaChoose,
                      style: TextStyle(
                          color: hasPhoto ? p.danger : p.accent,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none)),
                ),
              ),
            ]),
          ),
        ),
        if (!hasPhoto) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: LayoutBuilder(builder: (_, box) {
              final n = avatarColorCount;
              final d = ((box.maxWidth - (n - 1) * 8) / n).clamp(28.0, 44.0);
              return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < n; i++)
                      Tap(
                        scale: .88,
                        onTap: () => setState(() => _color = i),
                        child: Container(
                          width: d,
                          height: d,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: p.avatar(i))),
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 220),
                            curve: TgCurves.easeOutBack,
                            scale: _color == i ? 1 : .2,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 160),
                              opacity: _color == i ? 1 : 0,
                              child: Container(
                                margin: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: p.bg, width: 2.5)),
                                child: const Center(
                                    child: TgIcon(Ic.check,
                                        color: Color(0xFFFFFFFF),
                                        size: 18,
                                        stroke: 2.6)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]);
            }),
          ),
        ],
      ],
    );
  }

  // The two global reply switches as a per persona decision. Three states
  // instead of two because a persona that says nothing has to be able to follow
  // the global switch it was born before it was ever edited.
  Widget _replySection() {    final l = context.l;
    return TgSection(
      header: l.aiReplyTitle,
      footer: l.personaReplyFooter,
      children: [
        TgTextCell(
          icon: Ic.ai,
          title: l.aiReplyShowThinking,
          subtitle: _thinking == null ? l.personaReplyFollowingGlobal : null,
          value: _tri(_thinking),
          onTap: () => _pickOverride(
              l.aiReplyShowThinking, _thinking, (v) => _thinking = v),
        ),
        TgTextCell(
          icon: Ic.gear,
          title: l.aiReplyAgentMode,
          subtitle: _agent == null ? l.personaReplyFollowingGlobal : null,
          value: _tri(_agent),
          divider: false,
          onTap: () =>
              _pickOverride(l.aiReplyAgentMode, _agent, (v) => _agent = v),
        ),
      ],
    );
  }

  // Clinginess: how soon this persona speaks up on its own after the user
  // goes quiet, and an optional cap on consecutive proactive messages. The
  // scheduler measures silence from the newest message on either side, so a
  // check-in never chains straight into the next one.
  Widget _clingySection() {
    final l = context.l;
    // the gate drops every proactive task while the global switch is off, so
    // a clingy persona would silently stay quiet: say so right in the editor
    final proactiveOn = Store.read(context).human?.settings.proactive ?? false;
    return TgSection(
      header: l.personaClingyHeader,
      footer: _clingy && !proactiveOn ? l.personaClingyNeedsProactive : l.personaClingyFooter,
      children: [
        TgCheckCell(
          icon: Ic.bell,
          title: l.personaClingyTitle,
          subtitle: l.personaClingySub,
          value: _clingy,
          divider: _clingy,
          onChanged: (v) => setState(() => _clingy = v),
        ),
        if (_clingy) ...[
          TgTextCell(
            icon: Ic.calendar,
            title: l.personaClingyInterval,
            value: _fmtMin(_clingySilentMin),
            onTap: _pickInterval,
          ),
          TgCheckCell(
            icon: Ic.minus,
            title: l.personaClingyCap,
            subtitle: l.personaClingyCapSub,
            value: _clingyCap,
            divider: _clingyCap,
            onChanged: (v) => setState(() => _clingyCap = v),
          ),
          if (_clingyCap)
            TgTextCell(
              icon: Ic.list,
              title: l.personaClingyMax,
              value: '$_clingyMax',
              divider: false,
              onTap: _pickMax,
            ),
        ],
      ],
    );
  }

  String _fmtMin(int m) {
    final l = context.l;
    return m % 60 == 0 ? l.personaClingyHours(m ~/ 60) : l.personaClingyMinutes(m);
  }

  Future<void> _pickInterval() async {
    final l = context.l;
    const opts = [15, 30, 60, 120, 240, 480];
    final v = await showAiSelect<int>(
      context,
      title: l.personaClingyInterval,
      value: _clingySilentMin,
      options: [
        for (final m in opts) (value: m, label: _fmtMin(m), sub: null),
      ],
    );
    if (v != null) setState(() => _clingySilentMin = v);
  }

  Future<void> _pickMax() async {
    final l = context.l;
    final v = await showAiSelect<int>(
      context,
      title: l.personaClingyMax,
      value: _clingyMax,
      options: [
        for (var n = 1; n <= 8; n++) (value: n, label: '$n', sub: null),
      ],
    );
    if (v != null) setState(() => _clingyMax = v);
  }

  // Skills this role may use. Null follows the global set (every enabled
  // skill), an explicit list names exactly the ones in its prompt.
  Widget _skillsSection() {
    final l = context.l;
    final st = Store.read(context);
    final installed = st.skills.skills;
    final label = _skillIds == null ? l.personaSkillsFollowGlobal : l.personaSkillsCount(_skillIds!.length);
    return TgSection(
      header: l.personaSkillsHeader,
      footer: l.personaSkillsFooter,
      children: [
        TgTextCell(
          icon: Ic.fileCode,
          title: label,
          subtitle: installed.isEmpty ? l.skillSubEmpty : null,
          value: installed.isEmpty ? null : l.actionEdit,
          divider: false,
          onTap: () => _pickSkills(),
        ),
      ],
    );
  }

  // Drawing and speaking for this role alone.
  //
  // The two channels share a section because they are the same kind of
  // decision: a tool the model gains, backed by an endpoint. The endpoint rows
  // only appear once the channel is on, so a role that asked for neither keeps
  // a short card, and a half configured pair cannot be saved by accident:
  // leaving the endpoint empty means "use the global default", which is a
  // working state rather than a broken one.
  Widget _voiceImageSection(Pal p) {
    final l = context.l;
    final cfg = AiScope.read(context);
    final settings = cfg.settings;
    final speech = SpeechScope.read(context);

    final globalImage = settings.imageProviderId.isNotEmpty && settings.imageModelId.isNotEmpty;

    String pair(String id, String model, String fallbackLabel) {
      if (id.trim().isEmpty && model.trim().isEmpty) return fallbackLabel;
      final pv = findProvider(settings, id);
      final name = pv?.name ?? id;
      return model.trim().isEmpty ? name : '$name · ${model.trim()}';
    }

    final imageReady = _imageOn &&
        (globalImage || (_imageProvider.trim().isNotEmpty && _imageModel.trim().isNotEmpty));
    final engine = _ttsEngine ?? speech.engine;
    final ttsReady = _ttsOn &&
        (engine == TtsEngine.system ||
            (speech.baseUrl.isNotEmpty && speech.apiKey.isNotEmpty) ||
            (_ttsBaseUrl.trim().isNotEmpty && _ttsModel.trim().isNotEmpty));

    return TgSection(
      header: l.voiceImageHeader,
      footer: l.voiceImageFooter,
      children: [
        TgCheckCell(
          icon: Ic.image,
          title: l.voiceImageDraw,
          subtitle: l.voiceImageDrawSub,
          value: _imageOn,
          divider: _imageOn,
          onChanged: (v) => setState(() => _imageOn = v),
        ),
        if (_imageOn) ...[
          TgTextCell(
            icon: Ic.ai,
            title: l.voiceImageDrawModel,
            subtitle: pair(_imageProvider, _imageModel,
                globalImage ? l.voiceImageFollowGlobal : l.voiceImageNotConfigured),
            value: l.personaModelChange,
            onTap: () => _pickGenModel(forImage: true),
          ),
          TgTextCell(
            icon: Ic.image,
            title: l.voiceImageDrawSize,
            subtitle: _imageSize.trim().isEmpty ? settings.imageSize : _imageSize.trim(),
            value: l.personaModelChange,
            divider: false,
            onTap: _pickImageSize,
          ),
          if (!imageReady)
            TgTextCell(
              icon: Ic.info,
              title: l.voiceImageNotConfigured,
              color: p.danger,
              divider: false,
            ),
        ],
        TgCheckCell(
          icon: Ic.unmute,
          title: l.voiceImageSpeak,
          subtitle: l.voiceImageSpeakSub,
          value: _ttsOn,
          divider: _ttsOn,
          onChanged: (v) => setState(() => _ttsOn = v),
        ),
        if (_ttsOn) ...[
          TgTextCell(
            icon: Ic.gear,
            title: l.voiceImageEngine,
            subtitle: engine == TtsEngine.system ? l.voiceImageEngineSystemSub : l.voiceImageEngineApiSub,
            value: engine == TtsEngine.system ? l.voiceImageEngineSystem : l.voiceImageEngineApi,
            onTap: _pickTtsEngine,
          ),
          if (engine == TtsEngine.api) ...[
            TgTextCell(
              icon: Ic.globe,
              title: l.speechBaseUrl,
              subtitle: _ttsBaseUrl.trim().isEmpty
                  ? (speech.baseUrl.isEmpty ? l.voiceImageNotConfigured : speech.baseUrl)
                  : _ttsBaseUrl.trim(),
              value: l.personaModelChange,
              onTap: _pickTtsEndpoint,
            ),
            TgTextCell(
              icon: Ic.unmute,
              title: l.voiceImageVoice,
              subtitle: _ttsVoice.trim().isEmpty
                  ? (speech.voice.trim().isEmpty ? l.voiceImageFollowGlobal : speech.voice.trim())
                  : _ttsVoice.trim(),
              value: l.personaModelChange,
              onTap: _pickVoice,
            ),
          ],
          TgCheckCell(
            icon: Ic.music,
            title: l.voiceImageAutoSpeak,
            subtitle: l.voiceImageAutoSpeakSub,
            value: _ttsAutoSpeak,
            divider: false,
            onChanged: (v) => setState(() => _ttsAutoSpeak = v),
          ),
          if (!ttsReady)
            TgTextCell(
              icon: Ic.info,
              title: l.voiceImageNotConfigured,
              color: p.danger,
              divider: false,
            ),
        ],
      ],
    );
  }

  /// Picks the image endpoint. The picker's follow row clears both halves
  /// back to the global default, which is the empty string.
  Future<void> _pickGenModel({required bool forImage}) async {
    final cfg = AiScope.read(context);
    final l = context.l;
    final picked = await showAiModelPicker(
      context,
      cfg: cfg,
      title: l.voiceImageDrawModel,
      allowFollowChain: true,
      followTitle: l.voiceImageFollowGlobal,
      followSubtitle: l.personaModelFollowsSettings,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _imageProvider = picked.providerId;
      _imageModel = picked.modelId;
    });
  }

  /// The voice endpoint override is free text: a role that must use a different
  /// server names its base url here. Empty follows the voice module's own.
  Future<void> _pickTtsEndpoint() async {
    final l = context.l;
    final speech = SpeechScope.read(context);
    final v = await showTgInput(
      context,
      title: l.speechBaseUrl,
      initial: _ttsBaseUrl,
      hint: speech.baseUrl.isEmpty ? 'https://api.openai.com/v1' : speech.baseUrl,
    );
    if (v == null || !mounted) return;
    setState(() => _ttsBaseUrl = v.trim());
  }

  /// Which engine speaks for this role: the device, an endpoint, or the voice
  /// module's own setting. The sheet takes a non nullable value, so "follow"
  /// is a sentinel string rather than null.
  Future<void> _pickTtsEngine() async {
    final l = context.l;
    final speech = SpeechScope.read(context);
    const follow = '__follow__';
    final current = _ttsEngine == null
        ? follow
        : (_ttsEngine == TtsEngine.system ? 'system' : 'api');
    final v = await showAiSelect<String>(
      context,
      title: l.voiceImageEngine,
      value: current,
      options: [
        (
          value: follow,
          label: l.voiceImageFollowGlobal,
          sub: speech.engine == TtsEngine.system
              ? l.voiceImageEngineSystem
              : l.voiceImageEngineApi,
        ),
        (value: 'system', label: l.voiceImageEngineSystem, sub: l.voiceImageEngineSystemSub),
        (value: 'api', label: l.voiceImageEngineApi, sub: l.voiceImageEngineApiSub),
      ],
    );
    if (v == null || !mounted) return;
    setState(() => _ttsEngine = v == follow ? null : ttsEngineOf(v));
  }

  Future<void> _pickImageSize() async {
    final l = context.l;
    const sizes = ['1024x1024', '1536x1024', '1024x1536', '1792x1024', '1024x1792', '512x512'];
    final v = await showAiSelect<String>(
      context,
      title: l.voiceImageDrawSize,
      value: _imageSize.trim().isEmpty ? '1024x1024' : _imageSize.trim(),
      options: [for (final s in sizes) (value: s, label: s, sub: null)],
    );
    if (v == null || !mounted) return;
    setState(() => _imageSize = v);
  }

  /// The voice id is free text: a gateway with cloned voices takes ids no fixed
  /// list could carry, so the documented set is only a hint in the field.
  Future<void> _pickVoice() async {
    final l = context.l;
    final speech = SpeechScope.read(context);
    final v = await showTgInput(
      context,
      title: l.voiceImageVoice,
      initial: _ttsVoice,
      hint: speech.voice.trim().isEmpty ? 'alloy' : speech.voice,
    );
    if (v == null || !mounted) return;
    setState(() => _ttsVoice = v.trim());
  }

  Future<void> _pickSkills() async {
    final st = Store.read(context);
    if (st.skills.skills.isEmpty) {
      openSkillsSettings(context);
      return;
    }
    final (changed, ids) = await pickRoleSkills(context, _skillIds);
    if (!changed || !mounted) return;
    setState(() => _skillIds = ids == null ? null : [...ids]);
  }

  Widget _modelSection(Pal p) {
    final cfg = AiScope.read(context);
    final provider = _modelProvider.trim().isEmpty
        ? null
        : findProvider(cfg.settings, _modelProvider.trim());
    final l = context.l;
    return TgSection(
      header: l.profileLabelModel,
      footer:
          _override ? l.personaModelFooterOverride : l.personaModelFooterGlobal,
      children: [
        TgTextCell(
          icon: Ic.ai,
          title: _override ? _modelId.trim() : l.personaModelGlobalChain,
          subtitle: _override
              ? '${provider?.name ?? _modelProvider} · ${l.personaModelOnlyThis}'
              : l.personaModelFollowsSettings,
          value: _override ? null : l.personaModelChange,
          divider: _override,
          onTap: _pickModel,
        ),
        if (_override)
          TgCheckCell(
            icon: Ic.regen,
            title: l.personaModelFallback,
            value: _modelFallback,
            onChanged: (v) => setState(() => _modelFallback = v),
          ),
        if (_override)
          TgTextCell(
            icon: Ic.close,
            title: l.personaModelUseGlobal,
            color: p.danger,
            divider: false,
            onTap: () => setState(() {
              _modelProvider = '';
              _modelId = '';
            }),
          ),
      ],
    );
  }

  // coloured profile cover with the emoji pattern, the avatar and the name
  Widget _preview(Pal p, double top, double height) {
    final g = p.avatar(_color);
    return TweenAnimationBuilder<List<Color>>(
      tween: _GradTween(end: g),
      duration: const Duration(milliseconds: 380),
      curve: TgCurves.easeOutQuint,
      builder: (_, cols, __) => Container(
        height: height,
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: cols)),
        child: CustomPaint(
          painter: _PatternPainter(_emoji.isEmpty ? '✦' : _emoji),
          child: Padding(
            padding: EdgeInsets.only(top: top + 44),
            child: ListenableBuilder(
              listenable: Listenable.merge([_name, _bio]),
              builder: (_, __) {
                final n = _name.text.trim();
                final initial =
                    n.isEmpty ? '?' : n.characters.first.toUpperCase();
                return Column(children: [
                  _avatar.isEmpty
                      // no photo, the glyph sits on a translucent disc
                      ? Container(
                          width: 100,
                          height: 100,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0x33FFFFFF),
                              border: Border.all(
                                  color: const Color(0x66FFFFFF), width: 2)),
                          child: Text(_emoji.isEmpty ? initial : _emoji,
                              style: TextStyle(
                                  color: const Color(0xFFFFFFFF),
                                  fontSize: _emoji.isEmpty ? 42 : 48,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none)),
                        )
                      // a photo is clipped into a circle with a white ring
                      : Container(
                          width: 100,
                          height: 100,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0x66FFFFFF), width: 2)),
                          child: Image.file(File(_avatar),
                              fit: BoxFit.cover,
                              cacheWidth: 360,
                              errorBuilder: (_, __, ___) => Center(
                                  child: Text(initial,
                                      style: const TextStyle(
                                          color: Color(0xFFFFFFFF),
                                          fontSize: 42,
                                          fontWeight: FontWeight.w500,
                                          decoration: TextDecoration.none)))),
                        ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                        n.isEmpty
                            ? (_editing
                                ? context.l.headerMenuEditPersona
                                : context.l.chatsNewPersona)
                            : n,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none)),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                        _bio.text.trim().isEmpty
                            ? context.l.chatStatusBot
                            : _bio.text.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xD9FFFFFF),
                            fontSize: 14,
                            decoration: TextDecoration.none,
                            fontWeight: FontWeight.w400)),
                  ),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GradTween extends Tween<List<Color>> {
  _GradTween({required List<Color> end}) : super(end: end);
  @override
  List<Color> lerp(double t) {
    final a = begin ?? end!;
    return [Color.lerp(a[0], end![0], t)!, Color.lerp(a[1], end![1], t)!];
  }
}

// ring of the persona emoji around the avatar at low alpha
class _PatternPainter extends CustomPainter {
  _PatternPainter(this.glyph);
  final String glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(3);
    final cx = size.width / 2;
    final cy = size.height - 120;
    for (var ring = 0; ring < 3; ring++) {
      final r = 74.0 + ring * 52;
      final n = 8 + ring * 4;
      for (var i = 0; i < n; i++) {
        final a = i / n * math.pi * 2 + ring * .4;
        final o = Offset(cx + math.cos(a) * r * 1.5, cy + math.sin(a) * r * .8);
        if (o.dx < -10 ||
            o.dx > size.width + 10 ||
            o.dy < 0 ||
            o.dy > size.height) continue;
        final tp = TextPainter(
            text: TextSpan(
                text: glyph,
                style: TextStyle(
                    fontSize: 14 + rnd.nextDouble() * 8,
                    color: const Color(0x2EFFFFFF))),
            textDirection: TextDirection.ltr)
          ..layout();
        canvas.save();
        canvas.translate(o.dx, o.dy);
        canvas.rotate(rnd.nextDouble() * .8 - .4);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter o) => o.glyph != glyph;
}
