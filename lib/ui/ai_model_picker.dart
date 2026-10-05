import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/provider_icons.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/ai/provider_model.dart';
import '../data/ai_config.dart';
import '../l10n/x.dart';

/// Inherited access to the AI config so any screen below the provider can read
/// and mutate it without threading it through every constructor.
class AiScope extends InheritedNotifier<AiConfig> {
  const AiScope({super.key, required AiConfig config, required super.child}) : super(notifier: config);

  static AiConfig of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AiScope>()!.notifier!;

  /// Read without subscribing, for callbacks that only write.
  static AiConfig read(BuildContext c) => (c.getElementForInheritedWidgetOfExactType<AiScope>()!.widget as AiScope).notifier!;
}

extension AiX on BuildContext {
  AiConfig get ai => AiScope.of(this);
}

/// Result of the model picker, an empty provider id means follow the chain.
typedef AiModelPick = ({String providerId, String modelId});

/// Rounded search field used at the top of the model picker.
class AiSearchBox extends StatefulWidget {
  const AiSearchBox({super.key, required this.value, required this.onChanged, required this.hint});

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<AiSearchBox> createState() => _AiSearchBoxState();
}

class _AiSearchBoxState extends State<AiSearchBox> {
  late final TextEditingController _ctl = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        TgIcon(Ic.search, color: p.subtitle, size: 19),
        const SizedBox(width: 10),
        Expanded(child: TgEdit(controller: _ctl, hint: widget.hint, style: TextStyle(color: p.title, fontSize: 15, decoration: TextDecoration.none), onChanged: widget.onChanged)),
        if (widget.value.isNotEmpty)
          Tap(scale: .9, onTap: () {
            _ctl.clear();
            widget.onChanged('');
          }, child: TgIcon(Ic.close, color: p.subtitle, size: 17)),
      ]),
    );
  }
}

/// One tappable row in the picker list.
class AiPickRow extends StatelessWidget {
  const AiPickRow({super.key, required this.icon, required this.title, this.subtitle, required this.onTap, this.avatar});

  final Ic icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Set when the row stands for one provider, so it carries the brand logo
  /// instead of the generic ai glyph.
  final ProviderAvatar? avatar;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Tap(
      highlight: true,
      onTap: onTap,
      child: Container(
        color: p.bg,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          if (avatar != null) avatar! else TgIcon(icon, color: p.subtitle, size: 19),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w500)),
              if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 12.5, decoration: TextDecoration.none)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Flattened model row used by the picker.
class AiModelOption {
  const AiModelOption({required this.providerId, required this.providerName, required this.baseUrl, required this.model});

  final String providerId;
  final String providerName;

  /// Carried so a custom provider with a meaningless name still gets its logo
  final String baseUrl;
  final ModelMeta model;
}

Future<AiModelPick?> showAiModelPicker(
  BuildContext context, {
  required AiConfig cfg,
  required String title,
  bool allowFollowChain = false,
  String? followTitle,
  String? followSubtitle,
}) =>
    Navigator.of(context, rootNavigator: true).push(
      _PickerRoute(cfg: cfg, title: title, allowFollowChain: allowFollowChain, followTitle: followTitle, followSubtitle: followSubtitle),
    );

class _PickerRoute extends PopupRoute<AiModelPick> {
  _PickerRoute({required this.cfg, required this.title, required this.allowFollowChain, required this.followTitle, required this.followSubtitle});

  final AiConfig cfg;
  final String title;
  final bool allowFollowChain;
  final String? followTitle;
  final String? followSubtitle;

  @override
  Color? get barrierColor => const Color(0x73000000);
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => 'dismiss';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(BuildContext context, Animation<double> a, Animation<double> s) => _PickerPage(cfg: cfg, title: title, allowFollowChain: allowFollowChain, followTitle: followTitle, followSubtitle: followSubtitle);

  // the picker is a full page over a scrim, so it rises and fades in rather
  // than fading in place. Leaving eases in so it accelerates away, the same
  // asymmetry the bottom sheet and provider pages use.
  @override
  Widget buildTransitions(BuildContext context, Animation<double> a, Animation<double> s, Widget child) => AnimatedBuilder(
        animation: a,
        child: child,
        builder: (_, ch) {
          final v = a.status == AnimationStatus.reverse ? Curves.easeIn.transform(a.value) : TgCurves.easeOutQuint.transform(a.value);
          return Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, 40 * (1 - v)), child: ch));
        },
      );
}

class _PickerPage extends StatefulWidget {
  const _PickerPage({required this.cfg, required this.title, required this.allowFollowChain, required this.followTitle, required this.followSubtitle});

  final AiConfig cfg;
  final String title;
  final bool allowFollowChain;
  final String? followTitle;
  final String? followSubtitle;

  @override
  State<_PickerPage> createState() => _PickerPageState();
}

class _PickerPageState extends State<_PickerPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final q = _query.trim().toLowerCase();

    final l = context.l;
    final followTitle = widget.followTitle ?? l.aiFollowChain;
    final followSubtitle = widget.followSubtitle ?? l.aiFollowChainSub;
    final options = <AiModelOption>[
      for (final provider in widget.cfg.settings.providers)
        for (final model in provider.models)
          if (q.isEmpty || model.id.toLowerCase().contains(q) || model.name.toLowerCase().contains(q) || provider.name.toLowerCase().contains(q)) AiModelOption(providerId: provider.id, providerName: provider.name, baseUrl: provider.baseUrl, model: model),
    ]..sort((a, b) {
        final byProvider = a.providerName.compareTo(b.providerName);
        if (byProvider != 0) return byProvider;
        return a.model.id.compareTo(b.model.id);
      });

    return ColoredBox(
      color: p.gray,
      child: SafeArea(
        child: Column(children: [
          Container(
            color: p.bar,
            height: 56,
            child: Row(children: [
              Tap(scale: .88, onTap: () => Navigator.of(context).pop(), child: SizedBox(width: 56, height: 56, child: Center(child: TgIcon(Ic.back, color: p.icon, size: 24)))),
              Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 20, fontWeight: FontWeight.w500, decoration: TextDecoration.none))),
              const SizedBox(width: 16),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: AiSearchBox(value: _query, onChanged: (v) => setState(() => _query = v), hint: l.aiSearchModels),
          ),
          // the follow chain row is always offered, it is a valid answer
          // even when no provider has any model loaded yet
          if (options.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  q.isEmpty ? l.aiNoModelsLoaded : l.aiNoModelMatches(_query),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.subtitle, fontSize: 14, height: 1.4, decoration: TextDecoration.none),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: options.length + (widget.allowFollowChain ? 1 : 0),
                itemBuilder: (context, i) {
                  if (widget.allowFollowChain && i == 0) {
                    return AiPickRow(
                      icon: Ic.ai,
                      title: followTitle,
                      subtitle: followSubtitle,
                      onTap: () => Navigator.of(context).pop((providerId: '', modelId: '')),
                    );
                  }
                  final o = options[i - (widget.allowFollowChain ? 1 : 0)];
                  return AiPickRow(
                    icon: Ic.ai,
                    title: modelDisplayLabel(widget.cfg.settings, o.providerId, o.model.id, () => l.relayAutoModel),                    subtitle: [o.providerName, o.model.reasoning ? 'reasoning' : null, o.model.vision ? 'vision' : null]
                        .whereType<String>()
                        .join(' · '),
                    avatar: ProviderAvatar(name: o.providerName, baseUrl: o.baseUrl, color: p.aiIcon(ready: context.ai.ready), size: 30, radius: 9),
                    onTap: () => Navigator.of(context).pop((providerId: o.providerId, modelId: o.model.id)),
                  );
                },
              ),
            ),
          if (options.isEmpty && widget.allowFollowChain)
            Tap(
              highlight: true,
              onTap: () => Navigator.of(context).pop((providerId: '', modelId: '')),
              child: Container(
                color: p.bg,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(children: [
                  TgIcon(Ic.ai, color: p.subtitle, size: 19),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(followTitle, style: TextStyle(color: p.title, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w500)),
                      Text(followSubtitle, style: TextStyle(color: p.subtitle, fontSize: 12.5, decoration: TextDecoration.none)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}