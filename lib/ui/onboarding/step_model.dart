import 'package:flutter/widgets.dart';

import '../../core/anim.dart';
import '../../core/overlays.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/store.dart';
import '../../l10n/x.dart';
import '../ai_settings_page.dart';
import 'common.dart';

/// Step 4: pick a brain. The relay card is the one-tap road; the own-provider
/// card drops the user into the existing AI settings, which already knows how
/// to edit providers, keys and chains. Nothing here is mandatory: skipping
/// leaves the app without a model, and the settings summary will say so.
OnboardingStep buildModelStep() => OnboardingStep(
      title: (l) => l.onboardModelTitle,
      body: (l) => l.onboardModelBody,
      build: (c, flow) => const _ModelCards(),
    );

class _ModelCards extends StatefulWidget {
  const _ModelCards();

  @override
  State<_ModelCards> createState() => _ModelCardsState();
}

class _ModelCardsState extends State<_ModelCards> {
  bool _busy = false;

  Future<void> _enableRelay() async {
    if (_busy) return;
    setState(() => _busy = true);
    final cfg = context.store.aiConfig;
    final warning = await cfg.enableRelay();
    if (!mounted) return;
    setState(() => _busy = false);
    if (warning.isNotEmpty) {
      showBulletin(context, context.l.onboardModelRelayEnableFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = context.p;
    final cfg = context.store.aiConfig;
    final on = cfg.relayEnabled;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      children: [
        // the relay card, the recommended road
        _Card(
          title: l.onboardModelRelayTitle,
          body: l.onboardModelRelayBody,
          actionLabel: on ? l.onboardModelRelayOn : l.onboardModelRelayEnable,
          actionOn: on,
          busy: _busy,
          onAction: _enableRelay,
        ),
        const SizedBox(height: 10),
        // the notice the operator asked to show verbatim, styled as a caution
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.accent.withAlpha(18), borderRadius: BorderRadius.circular(10)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: TgIcon(Ic.info, color: p.accent, size: 15)),
            const SizedBox(width: 8),
            Expanded(child: Text(l.onboardModelRelayNotice, style: TextStyle(color: p.msg, fontSize: 12.5, decoration: TextDecoration.none, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 18),
        _Card(
          title: l.onboardModelOwnTitle,
          body: l.onboardModelOwnBody,
          actionLabel: l.onboardModelOwnOpen,
          actionOn: false,
          onAction: () => Navigator.of(context).push(TgRoute(builder: (_) => const AiSettingsPage())),
        ),
      ],
    );
  }
}

/// One selectable road: title, body, and a trailing action pill. Mirrors the
/// permission row shape so the two steps read as one design.
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.actionOn,
    required this.onAction,
    this.busy = false,
  });

  final String title;
  final String body;
  final String actionLabel;
  final bool actionOn;
  final VoidCallback onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.gray, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: p.title, fontSize: 16.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
        const SizedBox(height: 6),
        Text(body, style: TextStyle(color: p.msg, fontSize: 13.5, decoration: TextDecoration.none, height: 1.4)),
        const SizedBox(height: 14),
        Row(children: [
          const Spacer(),
          Tap(
            scale: .95,
            onTap: (actionOn || busy) ? null : onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: actionOn ? p.accent.withAlpha(24) : p.accent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  color: actionOn ? p.accent : (p.dark ? const Color(0xFF0F1A24) : const Color(0xFFFFFFFF)),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
