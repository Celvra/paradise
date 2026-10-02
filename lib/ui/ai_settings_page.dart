import 'package:flutter/widgets.dart';

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
/// stays mounted so switching back neither refetches nor loses the scroll.
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

  @override
  void initState() {
    super.initState();
    _current = widget.index;
  }

  @override
  void didUpdateWidget(Switcher old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    setState(() {
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
        return Stack(fit: StackFit.expand, children: [
          for (var i = 0; i < widget.children.length; i++)
            if (turning && i == _outgoing)
              IgnorePointer(child: _slide(widget.children[i], t * dir * _shift, 1 - t))
            else if (i == _current)
              _slide(widget.children[i], (1 - t) * dir * _shift, t)
            else
              Offstage(child: widget.children[i]),
        ]);
      },
    );
  }

  Widget _slide(Widget child, double dx, double opacity) => FractionalTranslation(
        translation: Offset(dx, 0),
        child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
      );
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ready ? const Color(0xFF5A9EE8) : const Color(0xFF6E8397),
              ),
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
      leading: ProviderAvatar(name: provider.name, baseUrl: provider.baseUrl, size: 42, radius: 21),
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
          title: node.modelId,
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
            TgCheckCell(
              icon: Ic.palette,
              title: l.aiStripMarkdown,
              value: s.stripMarkdownInCharacterMode,
              divider: false,
              onChanged: (v) => cfg.update((x) => x.copyWith(stripMarkdownInCharacterMode: v)),
            ),
          ],
        ),
        TgSection(
          header: l.aiSamplingHeader,
          footer: l.aiSamplingFooter,
          children: [
            TgTextCell(icon: Ic.textSize, title: l.aiTemperature, value: s.temperature.toStringAsFixed(2), onTap: () => _pickTemperature(context)),
            TgTextCell(icon: Ic.list, title: l.aiMaxOutput, value: s.maxOutput > 0 ? l.pluralTokens(s.maxOutput) : l.aiModelDefault, divider: false, onTap: () => _pickMaxOutput(context)),
          ],
        ),
      ],
    );
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
  return '${provider?.name ?? node.providerId} - ${node.modelId}';
}
