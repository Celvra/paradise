import 'package:flutter/widgets.dart';

import '../app_info.dart';
import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/provider_icons.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/ai/provider_model.dart';
import '../data/ai/tokenizer.dart';
import '../data/ai_config.dart';
import '../l10n/x.dart';
import 'ai_model_picker.dart';
import 'ai_widgets.dart';
import 'provider_detail_page.dart';
import 'tg_cells.dart';

/// Root AI screen in the layout of a current Telegram Android settings page:
/// a flat action bar with a ScrollSlidingTextTabStrip underneath, white
/// blocks with HeaderCells inside, TextCells with 24dp glyphs and grey
/// TextInfoPrivacyCells between the blocks. No cards, no chevrons.
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final cfg = AiScope.of(context);
    final p = context.p;
    final l = context.l;
    return SwipeBack(
      child: ColoredBox(
        color: p.gray,
        child: Column(children: [
          TgActionBar(
            title: l.aiTitle,
            raised: true,
            bottom: TgTabStrip(labels: [l.aiTabProviders, l.aiTabChain, l.aiTabAdvanced], index: _tab, onChange: (i) => setState(() => _tab = i)),
          ),
          Expanded(
            child: Switcher(
              index: _tab,
              children: [
                _ProvidersTab(cfg: cfg),
                _ChainTab(cfg: cfg),
                const _AdvancedTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Slides and fades between tabs the way the strip indicator moves. Every tab
/// stays mounted so switching back neither refetches nor loses the scroll. A
/// switch made mid-flight picks the moving panes up where they are, so tapping
/// back and forth rewinds instead of snapping.
class Switcher extends StatefulWidget {
  const Switcher({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<Switcher> createState() => _SwitcherState();
}

class _SwitcherState extends State<Switcher> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 280);
  static const _shift = 0.18;

  late final AnimationController _c = AnimationController(vsync: this, duration: _duration)..value = 1;
  int _current = 0;
  int _outgoing = -1;
  // panes still on their way out, each remembered at the pose it was caught
  // at, so a switch made mid-flight carries on instead of snapping to the ends
  List<({int i, double dx, double op})> _leaving = const [];
  // where the incoming pane starts: the strip side, or its own pose when it
  // was caught heading out
  (double, double) _inFrom = (_shift, 0);

  @override
  void initState() {
    super.initState();
    _current = widget.index;
    // once a flight settles, drop the leaving records so those panes go back
    // to being plainly offstage
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && _leaving.isNotEmpty) setState(() => _leaving = const []);
    });
  }

  @override
  void didUpdateWidget(Switcher old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    final turning = !_c.isCompleted;
    final e = TgCurves.easeOutQuint.transform(_c.value);
    final dir = _outgoing < 0 || _current > _outgoing ? 1.0 : -1.0; // the flight in progress
    final ndir = widget.index > _current ? 1.0 : -1.0; // the flight we start now
    setState(() {
      var inFrom = (ndir * _shift, 0.0);
      final leaving = <({int i, double dx, double op})>[
        // the pane being left keeps going from exactly where it is
        (i: _current, dx: turning ? (1 - e) * dir * _shift : 0.0, op: turning ? e : 1.0),
      ];
      if (turning) {
        for (final r in _leaving) {
          if (r.i == widget.index) {
            inFrom = (r.dx + e * (-dir * _shift - r.dx), r.op * (1 - e)); // caught heading out, comes back
          } else {
            leaving.add((i: r.i, dx: r.dx + e * (-dir * _shift - r.dx), op: r.op * (1 - e)));
          }
        }
      }
      _leaving = leaving;
      _inFrom = inFrom;
      _outgoing = _current;
      _current = widget.index;
    });
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = _outgoing < 0 || _current > _outgoing ? 1.0 : -1.0;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final turning = !_c.isCompleted;
        final t = TgCurves.easeOutQuint.transform(_c.value);
        final exit = -dir * _shift; // the side a leaving pane departs to
        return Stack(fit: StackFit.expand, children: [
          // every pane always sits in the same wrapper chain, only parameters
          // change, so switching roles never remounts it and tabs keep their
          // scroll and state; the current pane is last so ghosts draw under it
          for (var i = 0; i < widget.children.length; i++)
            if (i != _current) _pane(i, turning, t, exit),
          _pane(_current, turning, t, exit),
        ]);
      },
    );
  }

  Widget _pane(int i, bool turning, double t, double exit) {
    final (dx, op) = _pose(i, turning, t, exit);
    final leaving = turning && _leaving.any((r) => r.i == i);
    final visible = i == _current || leaving;
    return Offstage(
      // keyed so a pane keeps its element (and state) even when its slot in
      // the stack changes as the current pane moves to the end
      key: ValueKey(i),
      offstage: !visible,
      child: IgnorePointer(
        ignoring: leaving,
        child: FractionalTranslation(
          translation: Offset(dx, 0),
          child: Opacity(opacity: op.clamp(0.0, 1.0), child: widget.children[i]),
        ),
      ),
    );
  }

  (double, double) _pose(int i, bool turning, double t, double exit) {
    if (!turning) return (0, 1);
    if (i == _current) return (_inFrom.$1 * (1 - t), _inFrom.$2 + (1 - _inFrom.$2) * t);
    for (final r in _leaving) {
      if (r.i == i) return (r.dx + (exit - r.dx) * t, r.op * (1 - t));
    }
    return (0, 1);
  }
}

EdgeInsets _listPad(BuildContext context) => EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24);

// ───────────────────────────── Providers ─────────────────────────────

class _ProvidersTab extends StatelessWidget {
  const _ProvidersTab({required this.cfg});
  final AiConfig cfg;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final settings = cfg.settings;
    final active = activeChain(settings);
    final ready = cfg.ready;

    return ListView(
      padding: _listPad(context),
      physics: const ClampingScrollPhysics(),
      children: [
        // status header, the centred sticker-and-caption block Telegram puts on
        // top of Premium, Stats and Passcode screens
        Container(
          color: p.bg,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.aiIcon(ready: ready)),
              child: const Center(child: TgIcon(Ic.ai, color: Color(0xFFFFFFFF), size: 40, stroke: 2)),
            ),
            const SizedBox(height: 14),
            Text(ready ? l.aiReadyTitle : l.aiNotReadyTitle, style: TextStyle(color: p.title, fontSize: 20, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
            const SizedBox(height: 6),
            Text(
              ready ? cfg.chainSummary : l.aiNotReadyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.subtitle, fontSize: 14, height: 1.35, decoration: TextDecoration.none, fontWeight: FontWeight.w400),
            ),
            if (active.isNotEmpty) ...[
              const SizedBox(height: 12),
              TgChip(l.aiOnChainCount(active.length), accent: true),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        TgSection(
          header: l.aiProvidersHeader,
          footer: l.aiProvidersFooter,
          children: [
            for (final pr in settings.providers) _ProviderCell(provider: pr, cfg: cfg),
            TgTextCell(icon: Ic.plus, title: l.aiAddProvider, color: p.accent, divider: false, onTap: () => _addCustom(context, cfg)),
          ],
        ),
      ],
    );
  }

  Future<void> _addCustom(BuildContext context, AiConfig cfg) async {
    final name = await showTgInput(context, title: context.l.aiAddProviderTitle, initial: '', hint: context.l.aiAddProviderHint);
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    cfg.addProvider(Provider.defaults(id: id, name: name.trim()));
    if (!context.mounted) return;
    openProviderDetail(context, id);
  }
}

/// UserCell shape: round 42 avatar, name, a status line in accent when usable.
class _ProviderCell extends StatelessWidget {
  const _ProviderCell({required this.provider, required this.cfg});

  final Provider provider;
  final AiConfig cfg;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final hasKey = cfg.keyOf(provider.id).isNotEmpty;
    final inChain = activeChain(cfg.settings).where((n) => n.providerId == provider.id).length;
    final models = provider.models.length;
    final parts = <String>[
      hasKey ? l.aiKeySet : l.aiNoKey,
      if (inChain > 0) l.aiProviderOnChain(inChain),
      if (models > 0) l.aiProviderModels(models),
    ];
    return TgTextCell(
      leading: ProviderAvatar(name: provider.name, baseUrl: provider.baseUrl, color: p.aiIcon(ready: cfg.ready), size: 42, radius: 21),
      title: provider.name,
      subtitle: parts.join(' · '),
      subtitleColor: hasKey ? p.accent : p.subtitle,
      onTap: () => openProviderDetail(context, provider.id),
    );
  }
}

// ───────────────────────────── Chain ─────────────────────────────

class _ChainTab extends StatelessWidget {
  const _ChainTab({required this.cfg});
  final AiConfig cfg;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final s = cfg.settings;
    final c = s.compaction;
    final activeCount = s.chain.where((n) => n.enabled).length;

    return ListView(
      padding: _listPad(context),
      physics: const ClampingScrollPhysics(),
      children: [
        const SizedBox(height: 12),
        Container(
          color: p.bg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TgHeaderCell(
              l.aiChainHeader,
              trailing: s.chain.isEmpty ? null : Text(l.aiChainActiveCount(activeCount, s.chain.length), style: TextStyle(color: p.subtitle, fontSize: 14, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
            ),
            if (s.chain.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(21, 8, 21, 14),
                child: Text(l.aiChainEmptyHint, style: TextStyle(color: p.subtitle, fontSize: 15, height: 1.35, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
              )
            else
              for (var i = 0; i < s.chain.length; i++) _NodeCell(cfg: cfg, node: s.chain[i], index: i, total: s.chain.length),
            TgTextCell(icon: Ic.plus, title: l.aiAddModel, color: p.accent, divider: false, onTap: () => _addNode(context)),
          ]),
        ),
        TgInfoCell(l.aiChainFooter),
        TgSection(
          header: l.aiCompactionHeader,
          footer: l.aiCompactionFooter,
          children: [
            TgCheckCell(
              title: l.aiCompactionToggle,
              subtitle: l.aiCompactionToggleSub,
              value: c.enabled,
              onChanged: (v) => cfg.patchCompaction((x) => x.copyWith(enabled: v)),
            ),
            TgTextCell(
              title: l.aiSummaryModel,
              subtitle: c.providerId.isEmpty ? l.aiSummaryModelFollows : '${findProvider(s, c.providerId)?.name ?? c.providerId} · ${c.modelId}',
              onTap: () => _pickCompactionModel(context),
            ),
            TgTextCell(
              title: l.aiSummaryLength,
              value: l.pluralChars(c.targetChars),
              divider: false,
              onTap: () => _pickTarget(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addNode(BuildContext context) async {
    final picked = await showAiModelPicker(context, cfg: cfg, title: context.l.aiAddToChainTitle);
    if (picked == null || picked.providerId.isEmpty || picked.modelId.isEmpty) return;
    cfg.addChainNode(picked.providerId, picked.modelId);
  }

  Future<void> _pickCompactionModel(BuildContext context) async {
    final picked = await showAiModelPicker(context, cfg: cfg, title: context.l.aiSummaryModelPickerTitle, allowFollowChain: true);
    if (picked == null) return;
    cfg.patchCompaction((c) => c.copyWith(providerId: picked.providerId, modelId: picked.modelId));
  }

  Future<void> _pickTarget(BuildContext context) async {
    const options = [600, 1200, 2000, 3000, 4000, 6000];
    final cur = cfg.settings.compaction.targetChars;
    final l = context.l;
    final v = await showAiSelect<int>(
      context,
      title: l.aiSummaryLengthTitle,
      value: cur,
      options: [
        if (!options.contains(cur)) (value: cur, label: l.pluralChars(cur), sub: l.actionCurrent),
        for (final o in options) (value: o, label: l.pluralChars(o), sub: o <= 1200 ? l.aiLengthTight : (o <= 3000 ? l.aiLengthBalanced : l.aiLengthDetailed)),
      ],
    );
    if (v == null) return;
    cfg.patchCompaction((c) => c.copyWith(targetChars: v));
  }
}

/// One step on the chain: numbered badge, model id, provider and window under
/// it, a switch on the right. Tapping opens the Telegram popup menu.
class _NodeCell extends StatelessWidget {
  const _NodeCell({required this.cfg, required this.node, required this.index, required this.total});

  final AiConfig cfg;
  final ChainNode node;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final s = cfg.settings;
    final provider = findProvider(s, node.providerId);
    final model = findModel(s, node.providerId, node.modelId);
    final caps = <String>[
      if ((model?.contextWindow ?? 0) > 0) formatTokens(model!.contextWindow),
      if (model?.reasoning ?? false) l.aiCapsReasoning,
      if (model?.vision ?? false) l.aiCapsVision,
      if (node.retries > 0) l.pluralRetries(node.retries),
    ];
    return Builder(
      builder: (cellContext) => AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: node.enabled ? 1 : .5,
        child: TgTextCell(
          leading: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: node.enabled ? p.accent : p.unreadMuted),
            child: Text('${index + 1}', style: TextStyle(color: p.dark ? const Color(0xFF0F1A24) : const Color(0xFFFFFFFF), fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
          ),
          title: modelDisplayLabel(s, node.providerId, node.modelId, () => l.relayAutoModel),
          subtitle: [provider?.name ?? node.providerId, ...caps].join(' · '),
          trailing: TgSwitch(value: node.enabled, onChanged: (_) => cfg.toggleChainNode(node.id)),
          onTap: () => _menu(cellContext),
        ),
      ),
    );
  }

  void _menu(BuildContext context) {
    final r = rectOf(context);
    final l = context.l;
    showTgMenu(context, anchor: Rect.fromLTWH(r.right - 220, r.top, 200, r.height), items: [
      if (index > 0) MenuItem(l.actionMoveUp, Ic.up, () => cfg.moveChainNode(node.id, -1)),
      if (index < total - 1) MenuItem(l.actionMoveDown, Ic.down, () => cfg.moveChainNode(node.id, 1)),
      MenuItem(l.aiChainMenuRetries, Ic.regen, () => _retries(context), value: L10n.number('#,##0').format(node.retries)),
      MenuItem(node.enabled ? l.actionDisable : l.actionEnable, node.enabled ? Ic.close : Ic.check, () => cfg.toggleChainNode(node.id)),
      const MenuItem.gap(),
      MenuItem(l.actionRemoveShort, Ic.trash, () => cfg.removeChainNode(node.id), danger: true),
    ]);
  }

  Future<void> _retries(BuildContext context) async {
    final l = context.l;
    final v = await showAiSelect<int>(
      context,
      title: l.aiRetriesTitle,
      value: node.retries,
      options: [for (final n in const [0, 1, 2, 3, 4]) (value: n, label: n == 0 ? l.aiRetriesNone : l.pluralRetries(n), sub: null)],
    );
    if (v == null) return;
    cfg.setChainRetries(node.id, v);
  }
}

// ───────────────────────────── Advanced ─────────────────────────────

class _AdvancedTab extends StatelessWidget {
  const _AdvancedTab();

  @override
  Widget build(BuildContext context) {
    final cfg = AiScope.of(context);
    final s = cfg.settings;
    final l = context.l;

    return ListView(
      padding: _listPad(context),
      physics: const ClampingScrollPhysics(),
      children: [
        const SizedBox(height: 12),
        TgSection(
          header: l.aiRepliesHeader,
          footer: l.aiRepliesFooter,
          children: [
            TgTextCell(
              icon: Ic.chats,
              title: l.aiReplyStyle,
              value: s.replyMode == ReplyMode.full ? l.aiReplyStyleFull : l.aiReplyStyleCharacter,
              onTap: () => _pickReplyMode(context),
            ),
          ],
        ),
        TgSection(
          header: l.aiSamplingHeader,
          footer: l.aiSamplingFooter,
          children: [
            TgTextCell(icon: Ic.textSize, title: l.aiTemperature, value: s.temperature.toStringAsFixed(2), onTap: () => _pickTemperature(context)),
            TgTextCell(icon: Ic.list, title: l.aiMaxOutput, value: s.maxOutput > 0 ? l.pluralTokens(s.maxOutput) : l.aiModelDefault, onTap: () => _pickMaxOutput(context)),
          ],
        ),
        TgSection(
          header: l.aiNetworkHeader,
          footer: l.aiNetworkFooter,
          children: [
            TgTextCell(icon: Ic.user, title: l.aiUserAgent, subtitle: s.userAgent.trim().isEmpty ? defaultUserAgent : null, value: s.userAgent.trim().isEmpty ? null : s.userAgent, onTap: () => _pickUserAgent(context)),
            TgTextCell(icon: Ic.list, title: l.aiGlobalHeaders, subtitle: s.globalHeaders.any((h) => h.key.trim().isNotEmpty) ? [for (final h in s.globalHeaders) if (h.key.trim().isNotEmpty) h.key.trim()].join(', ') : l.aiHeadersNone, divider: false, onTap: () => _pickGlobalHeaders(context)),
          ],
        ),
        _genSection(context, s),
      ],
    );
  }

  /// Default image endpoint settings.
  ///
  /// Image generation is a provider and a model chosen from the AI list, so it
  /// lives here next to the chain. Speech is deliberately not here: it has its
  /// own module (openSpeechSettings) because a voice endpoint is not a chat
  /// provider and folding it into this list made a user add a fake provider
  /// just to hear a character talk.
  Widget _genSection(BuildContext context, AiSettings s) {
    final l = context.l;
    final imageProvider = s.imageProviderId.trim().isEmpty ? null : findProvider(s, s.imageProviderId);

    return TgSection(
      header: l.aiSettingsVoiceImage,
      footer: l.aiSettingsVoiceImageSub,
      children: [
        TgTextCell(
          icon: Ic.image,
          title: l.aiSettingsImageProvider,
          subtitle: imageProvider?.name ?? (s.imageProviderId.trim().isEmpty ? l.voiceImageNotConfigured : s.imageProviderId),
          value: l.personaModelChange,
          onTap: () => _pickGenProvider(context),
        ),
        TgTextCell(
          icon: Ic.ai,
          title: l.aiSettingsImageModel,
          subtitle: s.imageModelId.trim().isEmpty ? l.voiceImageNotConfigured : s.imageModelId,
          value: l.personaModelChange,
          onTap: () => _pickImageModel(context),
        ),
        TgTextCell(
          icon: Ic.image,
          title: l.aiSettingsImageSize,
          subtitle: s.imageSize,
          value: l.personaModelChange,
          divider: false,
          onTap: () => _pickGenImageSize(context),
        ),
      ],
    );
  }

  Future<void> _pickGenProvider(BuildContext context) async {
    final cfg = AiScope.read(context);
    final l = context.l;
    final picked = await showAiModelPicker(
      context,
      cfg: cfg,
      title: l.aiSettingsImageProvider,
      allowFollowChain: false,
      followTitle: l.actionNone,
      followSubtitle: l.aiModelDefault,
    );
    if (picked == null) return;
    cfg.update((s) => s.copyWith(imageProviderId: picked.providerId, imageModelId: picked.modelId));
  }

  Future<void> _pickImageModel(BuildContext context) async {
    final cfg = AiScope.read(context);
    final l = context.l;
    final v = await showTgInput(
      context,
      title: l.aiSettingsImageModel,
      initial: cfg.settings.imageModelId,
      hint: 'gpt-image-1',
    );
    if (v == null) return;
    cfg.update((s) => s.copyWith(imageModelId: v.trim()));
  }

  Future<void> _pickGenImageSize(BuildContext context) async {
    final cfg = AiScope.read(context);
    final l = context.l;
    const sizes = ['1024x1024', '1536x1024', '1024x1536', '1792x1024', '1024x1792', '512x512'];
    final v = await showAiSelect<String>(
      context,
      title: l.aiSettingsImageSize,
      value: cfg.settings.imageSize,
      options: [for (final s in sizes) (value: s, label: s, sub: null)],
    );
    if (v == null) return;
    cfg.update((s) => s.copyWith(imageSize: v));
  }

  Future<void> _pickUserAgent(BuildContext context) async {
    final cfg = AiScope.read(context);
    final l = context.l;
    final v = await showTgInput(context, title: l.aiUserAgent, initial: cfg.settings.userAgent, hint: l.aiUserAgentHint);
    if (v == null) return;
    cfg.update((s) => s.copyWith(userAgent: v.trim()));
  }

  /// One `Name: Value` header per line, sent with every ai request.
  Future<void> _pickGlobalHeaders(BuildContext context) async {
    final cfg = AiScope.read(context);
    final l = context.l;
    final current = cfg.settings.globalHeaders;
    final text = [for (final h in current) if (h.key.trim().isNotEmpty) '${h.key.trim()}: ${h.value}'].join('\n');
    final v = await showTgInput(context, title: l.aiGlobalHeaders, initial: text, hint: l.aiHeadersHint, maxLines: 4);
    if (v == null) return;
    final rows = <KeyValue>[];
    for (final line in v.split('\n')) {
      final i = line.indexOf(':');
      if (i <= 0) continue;
      final key = line.substring(0, i).trim();
      if (key.isEmpty) continue;
      rows.add(KeyValue(key, line.substring(i + 1).trim()));
    }
    cfg.update((s) => s.copyWith(globalHeaders: rows));
  }

  Future<void> _pickReplyMode(BuildContext context) async {
    final cfg = AiScope.read(context);
    final l = context.l;
    final v = await showAiSelect<ReplyMode>(
      context,
      title: l.aiReplyStyle,
      value: cfg.settings.replyMode,
      options: [
        (value: ReplyMode.full, label: l.aiReplyStyleFull, sub: l.aiReplyStyleFullSub),
        (value: ReplyMode.character, label: l.aiReplyStyleCharacter, sub: l.aiReplyStyleCharacterSub),
      ],
    );
    if (v == null) return;
    cfg.update((s) => s.copyWith(replyMode: v));
  }

  Future<void> _pickTemperature(BuildContext context) async {
    final cfg = AiScope.read(context);
    final l = context.l;
    final v = await showAiSelect<double>(
      context,
      title: l.aiTemperature,
      value: cfg.settings.temperature,
      options: [for (final t in const [0.0, 0.2, 0.4, 0.7, 1.0, 1.3]) (value: t, label: t.toStringAsFixed(2), sub: t == 0 ? l.aiTempDeterministic : (t <= 0.4 ? l.aiTempFocused : (t <= 1.0 ? l.aiTempBalanced : l.aiTempLoose)))],
    );
    if (v == null) return;
    cfg.update((s) => s.copyWith(temperature: v));
  }

  Future<void> _pickMaxOutput(BuildContext context) async {
    final cfg = AiScope.read(context);
    const options = [0, 512, 1024, 2048, 4096, 8192, 16384];
    final l = context.l;
    final v = await showAiSelect<int>(
      context,
      title: l.aiMaxOutput,
      value: cfg.settings.maxOutput,
      options: [for (final o in options) (value: o, label: o == 0 ? l.aiModelDefault : l.pluralTokens(o), sub: o == 0 ? l.aiUseCatalogDefault : null)],
    );
    if (v == null) return;
    cfg.update((s) => s.copyWith(maxOutput: v));
  }
}

/// exposed so the entry row in the settings tab can show a live summary
String aiProviderSummary(AiConfig cfg, AppLocalizations l) {
  final node = activeChain(cfg.settings).firstOrNull;
  if (node == null) return l.aiChainEmpty;
  final provider = findProvider(cfg.settings, node.providerId);
  return '${provider?.name ?? node.providerId} - ${modelDisplayLabel(cfg.settings, node.providerId, node.modelId, () => l.relayAutoModel)}';
}
