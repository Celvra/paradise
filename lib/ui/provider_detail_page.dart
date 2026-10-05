import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/ai/adapter.dart';
import '../data/ai/chain.dart';
import '../data/ai/content.dart';
import '../data/ai/fetcher.dart';
import '../data/ai/provider_model.dart';
import '../data/ai/registry.dart';
import '../data/ai/tokenizer.dart';
import '../data/ai_config.dart';
import '../l10n/x.dart';
import 'ai_model_picker.dart';
import 'ai_widgets.dart';

Future<void> openProviderDetail(BuildContext context, String providerId) {
  Navigator.of(context).push(_ProviderRoute(providerId: providerId));
  return Future.value();
}

class _ProviderRoute extends PopupRoute<void> {
  _ProviderRoute({required this.providerId});

  final String providerId;

  @override
  Color? get barrierColor => const Color(0x00000000);
  @override
  bool get barrierDismissible => false;
  @override
  String? get barrierLabel => 'dismiss';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(BuildContext context, Animation<double> a, Animation<double> s) => ProviderDetailPage(providerId: providerId);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> a, Animation<double> s, Widget child) => AnimatedBuilder(
        animation: a,
        child: child,
        builder: (_, ch) {
          final v = a.status == AnimationStatus.reverse ? Curves.easeIn.transform(a.value) : 1 - Curves.easeIn.transform(1 - a.value);
          return Opacity(opacity: a.value.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, 40 * (1 - v)), child: ch));
        },
      );
}

/// Per provider screen: connection settings, model list and chain membership.
class ProviderDetailPage extends StatefulWidget {
  const ProviderDetailPage({super.key, required this.providerId});

  final String providerId;

  @override
  State<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends State<ProviderDetailPage> {
  String _filter = '';
  bool _busy = false;
  String? _testOk;
  String? _testFail;
  bool _editingName = false;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final cfg = AiScope.of(context);
    final provider = findProvider(cfg.settings, widget.providerId);

    if (provider == null) {
      return ColoredBox(
        color: p.gray,
        child: Column(children: [
          _bar(context, l.provTitle),
          Expanded(child: Center(child: Text(l.provMissing, style: TextStyle(color: p.subtitle, fontSize: 14, decoration: TextDecoration.none)))),
        ]),
      );
    }

    final q = _filter.trim().toLowerCase();
    final visible = [
      ...provider.models.where((m) => q.isEmpty || m.id.toLowerCase().contains(q) || m.name.toLowerCase().contains(q)),
    ]..sort((a, b) {
        if (b.contextWindow != a.contextWindow) return b.contextWindow - a.contextWindow;
        return a.id.compareTo(b.id);
      });

    return ColoredBox(
      color: p.gray,
      child: Column(children: [
        _bar(context, provider.name),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            physics: const ClampingScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                child: AiSearchBox(value: _filter, onChanged: (v) => setState(() => _filter = v), hint: l.provSearchHint),
              ),
              TgGroup(
                header: l.provConnection,
                children: [
                  if (_editingName)
                    _InlineNameField(
                      initial: provider.name,
                      onDone: (v) {
                        cfg.patchProvider(provider.id, (x) => x.name = v.trim().isEmpty ? provider.name : v.trim());
                        setState(() => _editingName = false);
                      },
                      onCancel: () => setState(() => _editingName = false),
                    )
                  else
                    AiRow(
                      icon: Ic.pencil,
                      title: l.provName,
                      subtitle: provider.name,
                      onTap: () => setState(() => _editingName = true),
                    ),
                  AiRow(
                    icon: Ic.ai,
                    title: l.provProtocol,
                    subtitle: providerKindLabel(provider.kind),
                    onTap: () => _pickKind(provider, cfg),
                  ),
                  AiRow(
                    icon: Ic.lock,
                    title: l.provAuthStyle,
                    subtitle: authStyleLabel(provider.authStyle),
                    onTap: () => _pickAuthStyle(provider, cfg),
                  ),
                  AiRow(
                    icon: Ic.key,
                    title: l.provApiKey,
                    subtitle: _mask(cfg.keyOf(provider.id)),
                    onTap: () => _editKey(provider, cfg),
                  ),
                  AiRow(
                    icon: Ic.globe,
                    title: l.provBaseUrl,
                    subtitle: provider.baseUrl.isEmpty ? l.provBaseUrlEmpty : provider.baseUrl,
                    onTap: () => _editText(provider, cfg, l.provBaseUrl, provider.baseUrl, 'https://api.example.com/v1', (v) => cfg.patchProvider(provider.id, (x) => x.baseUrl = v.trim())),
                  ),
                  AiRow(
                    icon: Ic.file,
                    title: l.provChatPath,
                    subtitle: pathIsEditable(provider.kind) ? provider.chatPath : l.provChatPathFixed,
                    onTap: pathIsEditable(provider.kind) ? () => _editText(provider, cfg, l.provChatPath, provider.chatPath, '/chat/completions', (v) => cfg.patchProvider(provider.id, (x) => x.chatPath = v.trim())) : null,
                  ),
                  AiRow(
                    icon: Ic.link,
                    title: l.provSessionHeader,
                    subtitle: provider.sessionHeader.trim().isEmpty ? l.provSessionHeaderEmpty : provider.sessionHeader,
                    onTap: () => _editText(provider, cfg, l.provSessionHeader, provider.sessionHeader, l.provSessionHeaderHint, (v) => cfg.patchProvider(provider.id, (x) => x.sessionHeader = v.trim())),
                  ),
                  AiRow(
                    icon: Ic.user,
                    title: l.provUserAgent,
                    subtitle: provider.userAgent.trim().isEmpty ? l.provUserAgentDefault : provider.userAgent,
                    onTap: () => _editText(provider, cfg, l.provUserAgent, provider.userAgent, l.provUserAgentHint, (v) => cfg.patchProvider(provider.id, (x) => x.userAgent = v.trim())),
                  ),
                  AiRow(
                    icon: Ic.list,
                    title: l.provExtraHeaders,
                    subtitle: _headerSummary(provider.extraHeaders, l.provHeadersNone),
                    last: true,
                    onTap: () => _editHeaders(provider, cfg, l.provExtraHeaders, provider.extraHeaders, (v) => cfg.patchProvider(provider.id, (x) => x.extraHeaders = v)),
                  ),
                ],
              ),
              TgGroup(
                header: l.provModels,
                children: [
                  AiRow(
                    icon: Ic.storage,
                    title: l.provFetchModels,
                    subtitle: _busy
                        ? l.provFetchBusy
                        : provider.modelsFetchedAt > 0
                            ? l.provFetchDone(provider.models.length, provider.modelsSource == ModelSource.api ? l.provSourceApi : l.provSourceCatalog)
                            : l.provFetchNever,
                    onTap: _busy ? null : () => _loadModels(provider, cfg),
                  ),
                  AiRow(
                    icon: Ic.check2,
                    title: l.provTest,
                    subtitle: _testFail != null
                        ? l.provTestFailed(_testFail!)
                        : (_testOk != null ? l.provTestOk(_testOk!) : l.provTestNever),
                    onTap: _busy ? null : () => _runTest(provider, cfg),
                  ),
                  AiRow(
                    icon: Ic.pencil,
                    title: l.provAddManual,
                    subtitle: l.provAddManualSub,
                    last: true,
                    onTap: () => _addManualModel(provider, cfg),
                  ),
                ],
              ),
              if (visible.isNotEmpty)
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Text(l.provCountModels(provider.models.length), style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                  ),
                  Container(color: p.bg, child: Column(children: [
                    for (final model in visible) _ModelRow(provider: provider, model: model, cfg: cfg),
                  ])),
                ]),
              if (cfg.settings.chain.any((n) => n.providerId == provider.id))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Text(l.provOnChain, style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                ),
              if (cfg.settings.chain.any((n) => n.providerId == provider.id))
                Container(color: p.bg, child: Column(children: [
                  for (final node in cfg.settings.chain.where((n) => n.providerId == provider.id))
                    _InChainRow(node: node, cfg: cfg),
                ])),
              if (!provider.builtIn)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Tap(
                    scale: .98,
                    onTap: () => _confirmDelete(context, provider, cfg),
                    child: SizedBox(
                      height: 50,
                      child: Center(child: Text(l.provDelete, style: TextStyle(color: p.danger, fontSize: 15, decoration: TextDecoration.none))),
                    ),
                  ),
                ),
              TgFootnote(l.provFootnote),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _bar(BuildContext context, String title) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    return Container(
      color: p.bar,
      padding: EdgeInsets.only(top: mq.padding.top),
      height: mq.padding.top + 56,
      child: Row(children: [
        Tap(scale: .88, onTap: () => Navigator.of(context).maybePop(), child: SizedBox(width: 56, height: 56, child: Center(child: TgIcon(Ic.back, color: p.icon, size: 24)))),
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 20, fontWeight: FontWeight.w500, decoration: TextDecoration.none))),
        const SizedBox(width: 16),
      ]),
    );
  }

  String _mask(String key) => key.isEmpty ? L10n.current.humanNotSet : '${key.substring(0, key.length < 6 ? key.length : 6)}****';

  String _headerSummary(List<KeyValue> headers, String empty) {
    final rows = headers.where((h) => h.key.trim().isNotEmpty).toList();
    if (rows.isEmpty) return empty;
    return rows.map((h) => h.key.trim()).join(', ');
  }

  /// One multiline prompt, one `Name: Value` header per line. A sharp format
  /// would need a form per row; this stays readable, copyable and restorable
  /// from a backup with no schema work.
  Future<void> _editHeaders(Provider provider, AiConfig cfg, String title, List<KeyValue> initial, void Function(List<KeyValue>) apply) async {
    final l = context.l;
    final text = [for (final h in initial) if (h.key.trim().isNotEmpty) '${h.key.trim()}: ${h.value}'].join('\n');
    final v = await showTgInput(context, title: title, initial: text, hint: l.provHeadersHint, maxLines: 4);
    if (v == null) return;
    final rows = <KeyValue>[];
    for (final line in v.split('\n')) {
      final i = line.indexOf(':');
      if (i <= 0) continue;
      final key = line.substring(0, i).trim();
      if (key.isEmpty) continue;
      rows.add(KeyValue(key, line.substring(i + 1).trim()));
    }
    apply(rows);
    if (mounted) showBulletin(context, l.provSaved);
  }

  Future<void> _pickAuthStyle(Provider provider, AiConfig cfg) async {
    final l = context.l;
    final v = await showAiSelect<AuthStyle>(
      context,
      title: l.provAuthStyle,
      value: provider.authStyle,
      options: [
        (value: AuthStyle.bearer, label: authStyleLabel(AuthStyle.bearer), sub: l.provAuthBearerSub),
        (value: AuthStyle.xApiKey, label: authStyleLabel(AuthStyle.xApiKey), sub: null),
        (value: AuthStyle.queryKey, label: authStyleLabel(AuthStyle.queryKey), sub: l.provAuthQuerySub),
      ],
    );
    if (v == null || v == provider.authStyle) return;
    cfg.patchProvider(provider.id, (x) => x.authStyle = v);
  }

  Future<void> _editKey(Provider provider, AiConfig cfg) async {
    final l = context.l;
    final v = await showTgInput(context, title: l.provApiKey, initial: cfg.keyOf(provider.id), hint: l.provPasteKey, obscure: true);
    if (v == null) return;
    cfg.saveApiKey(provider.id, v);
    if (mounted) showBulletin(context, l.provSaved);
  }

  Future<void> _editText(Provider provider, AiConfig cfg, String title, String initial, String hint, void Function(String) apply) async {
    final v = await showTgInput(context, title: title, initial: initial, hint: hint);
    if (v == null) return;
    apply(v);
  }

  Future<void> _pickKind(Provider provider, AiConfig cfg) async {
    final l = context.l;
    final v = await showAiSelect<ProviderKind>(
      context,
      title: l.provProtocol,
      value: provider.kind,
      options: [
        for (final k in ProviderKind.values) (value: k, label: providerKindLabel(k), sub: k == ProviderKind.openaiCompatible ? l.provProtocolSub : null),
      ],
    );
    if (v == null) return;
    cfg.patchProvider(provider.id, (x) {
      x.kind = v;
      // the old path belonged to the previous protocol, so reset it either way
      // otherwise switching responses -> chat would keep sending /responses
      x.chatPath = chatPathForKind(v);
    });
  }

  Future<void> _loadModels(Provider provider, AiConfig cfg) async {
    final l = context.l;
    setState(() => _busy = true);
    final result = await fetchProviderModels(provider, cfg.keyOf(provider.id), settings: cfg.settings);
    if (!mounted) return;
    if (result.ok) {
      cfg.patchProvider(provider.id, (x) {
        x.models = result.models;
        x.modelsFetchedAt = result.fetchedAt;
        x.modelsSource = ModelSource.api;
      });
      showBulletin(context, l.provFetchedBulletin(result.models.length));
    } else {
      final fallback = await catalogModels(provider.id);
      if (!mounted) return;
      if (fallback.isNotEmpty) {
        cfg.patchProvider(provider.id, (x) {
          x.models = fallback;
          x.modelsFetchedAt = result.fetchedAt;
          x.modelsSource = ModelSource.catalog;
        });
        showBulletin(context, result.warning ?? l.provUsingCatalog);
      } else {
        showBulletin(context, result.warning ?? l.provFetchFailed);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _addManualModel(Provider provider, AiConfig cfg) async {
    final l = context.l;
    final id = await showTgInput(context, title: l.provAddManual, initial: '', hint: l.provModelIdHint);
    if (id == null || id.trim().isEmpty) return;
    final trimmed = id.trim();
    // a hand typed id is the case where models.dev helps most, so make sure
    // the remote feed is loaded before enriching it
    await warmCatalog();
    final model = enrich(emptyModel(trimmed), provider.id);
    cfg.patchProvider(provider.id, (x) => x.models = [...x.models.where((m) => m.id != trimmed), model]);
    if (mounted) showBulletin(context, l.provAdded);
  }

  Future<void> _runTest(Provider provider, AiConfig cfg) async {
    final l = context.l;
    if (cfg.keyOf(provider.id).trim().isEmpty) {
      setState(() => _testFail = l.provNoKeyFirst);
      return;
    }
    setState(() {
      _busy = true;
      _testOk = null;
      _testFail = null;
    });

    final key = cfg.keyOf(provider.id);
    final first = provider.models.isNotEmpty ? provider.models.first.id : 'gpt-4o-mini';
    // probe against the real provider rather than a chain that may not include it
    final probeSettings = cfg.settings.copyWith(chain: [ChainNode(id: 'test', providerId: provider.id, modelId: first, retries: 0, enabled: true)]);
    var collected = '';

    final outcome = await runChain(
      settings: probeSettings,
      apiKeys: {provider.id: key},
      system: 'You are a connectivity test assistant.',
      messages: [ChatTurn('user', [textPart('Reply with exactly two words: OK')])],
      nodes: [ChainNode(id: 'test', providerId: provider.id, modelId: first, retries: 0, enabled: true)],
      options: ChainOptions(
        // a gateways that requires its session header would reject the probe
        // without one, and the probe must fail exactly where a chat would
        sessionId: 'test:${provider.id}',
        onChunk: (chunk) {
          if (chunk.isText) collected += chunk.delta;
        },
        backoffMs: const [400],
      ),
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      final error = outcome.error;
      if (error != null) {
        _testFail = error.message;
      } else {
        final text = collected.trim();
        _testOk = text.isEmpty ? l.provConnectionWorks : (text.length > 40 ? '${text.substring(0, 40)}...' : text);
      }
    });
  }

  Future<void> _confirmDelete(BuildContext context, Provider provider, AiConfig cfg) async {
    final l = context.l;
    final ok = await showTgDialog<bool>(
      context,
      title: l.provDeleteTitle(provider.name),
      message: l.provDeleteMessage,
      actions: [DialogAction(l.actionCancel, false), DialogAction(l.actionDelete, true, danger: true)],
    );
    if (ok != true) return;
    cfg.removeProvider(provider.id);
    if (context.mounted) {
      showBulletin(context, l.provDeleted);
      Navigator.of(context).maybePop();
    }
  }
}

String chatPathForKind(ProviderKind kind) => switch (kind) {
      ProviderKind.openaiResponses => '/responses',
      ProviderKind.anthropic => '/messages',
      ProviderKind.gemini => '/models',
      _ => '/chat/completions',
    };

String authStyleLabel(AuthStyle style) => switch (style) {
      AuthStyle.bearer => 'Authorization: Bearer',
      AuthStyle.xApiKey => 'x-api-key',
      AuthStyle.queryKey => '?key=',
    };

class _InlineNameField extends StatefulWidget {
  const _InlineNameField({required this.initial, required this.onDone, required this.onCancel});

  final String initial;
  final ValueChanged<String> onDone;
  final VoidCallback onCancel;

  @override
  State<_InlineNameField> createState() => _InlineNameFieldState();
}

class _InlineNameFieldState extends State<_InlineNameField> {
  late final TextEditingController _ctl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    return Container(
      height: 52,
      color: p.bg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(children: [
        Expanded(child: TgEdit(controller: _ctl, hint: l.provName, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none), onSubmitted: widget.onDone)),
        Tap(scale: .95, onTap: () => widget.onDone(_ctl.text), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text(l.actionSave, style: TextStyle(color: p.accent, fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.none)))),
        Tap(scale: .95, onTap: widget.onCancel, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text(l.actionCancel, style: TextStyle(color: p.accent, fontSize: 14, decoration: TextDecoration.none)))),
      ]),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.provider, required this.model, required this.cfg});

  final Provider provider;
  final ModelMeta model;
  final AiConfig cfg;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final node = cfg.settings.chain.where((n) => n.providerId == provider.id && n.modelId == model.id).firstOrNull;

    return Tap(
      highlight: true,
      onTap: () {
        if (node != null) {
          cfg.toggleChainNode(node.id);
        } else {
          cfg.addChainNode(provider.id, model.id);
        }
      },
      child: Container(
        color: p.bg,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(model.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
              const SizedBox(height: 4),
              Wrap(spacing: 7, runSpacing: 3, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(l.provWindow(formatTokens(model.contextWindow)), style: TextStyle(color: p.subtitle, fontSize: 11.5, decoration: TextDecoration.none)),
                if (model.maxOutput > 0) Text(l.provOut(formatTokens(model.maxOutput)), style: TextStyle(color: p.subtitle, fontSize: 11.5, decoration: TextDecoration.none)),
                if (model.reasoning) AiTag(l.aiCapsReasoning),
                if (model.vision) AiTag(l.aiCapsVision),
                if (model.textToImage) AiTag(l.provTagImage),
                if (model.contextWindow == 0) AiTag(l.provTagUnknownWindow),
              ]),
            ]),
          ),
          TgIcon(node != null ? Ic.check : Ic.plus, color: node != null && node.enabled ? p.accent : p.subtitle, size: 20),
        ]),
      ),
    );
  }
}

class _InChainRow extends StatelessWidget {
  const _InChainRow({required this.node, required this.cfg});

  final ChainNode node;
  final AiConfig cfg;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    return Container(
      color: p.bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        Expanded(child: Text(node.modelId, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 13.5, decoration: TextDecoration.none))),
        Text(node.enabled ? l.provChainNodeMetaOn(node.retries) : l.provChainNodeMeta(node.retries), style: TextStyle(color: p.subtitle, fontSize: 11.5, decoration: TextDecoration.none)),
        Tap(scale: .9, onTap: () => cfg.removeChainNode(node.id), child: Padding(padding: const EdgeInsets.only(left: 12), child: TgIcon(Ic.close, color: p.subtitle, size: 18))),
      ]),
    );
  }
}