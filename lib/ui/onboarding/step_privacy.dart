import 'package:flutter/widgets.dart';

import '../../core/anim.dart';
import '../../core/overlays.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../l10n/x.dart';
import 'common.dart';

/// Step 3: the privacy agreement, the one step with no skip. Agree lives in
/// the bottom bar so it is always on screen, decline keeps the wizard open
/// and says why.
OnboardingStep buildPrivacyStep() => OnboardingStep(
      skippable: false,
      build: (c, flow) => const _PrivacyBody(),
      bottomBuilder: (c, flow, onLast) => const _PrivacyButtons(),
    );

/// The always-visible action pair. Agree is the only road into the app, so it
/// takes the full width; decline is the small link under it.
class _PrivacyButtons extends StatelessWidget {
  const _PrivacyButtons();

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = context.p;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TgButton(label: l.onboardPrivacyAgree, onTap: () => OnboardingScope.of(context).next()),
      const SizedBox(height: 8),
      Center(
        child: Tap(
          scale: .94,
          onTap: () => _decline(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(l.onboardPrivacyDecline, style: TextStyle(color: p.subtitle, fontSize: 14, decoration: TextDecoration.none)),
          ),
        ),
      ),
    ]);
  }

  Future<void> _decline(BuildContext context) async {
    final l = context.l;
    await showTgDialog<void>(
      context,
      title: l.onboardPrivacyDeclineTitle,
      content: Text(l.onboardPrivacyDeclineBody, style: TextStyle(color: context.p.msg, fontSize: 15, decoration: TextDecoration.none, height: 1.45)),
      actions: [DialogAction(l.actionOk, null)],
    );
    // Stay on the step: agreement is the gate, and re-reading is cheaper
    // than a dead end.
  }
}

class _PrivacyBody extends StatelessWidget {
  const _PrivacyBody();

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = context.p;
    final clauses = <(String, String)>[
      (l.onboardPrivacy1Title, l.onboardPrivacy1Body),
      (l.onboardPrivacy2Title, l.onboardPrivacy2Body),
      (l.onboardPrivacy3Title, l.onboardPrivacy3Body),
      (l.onboardPrivacy4Title, l.onboardPrivacy4Body),
      (l.onboardPrivacy5Title, l.onboardPrivacy5Body),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      children: [
        Text(l.onboardPrivacyIntro, textAlign: TextAlign.center, style: TextStyle(color: p.msg, fontSize: 14, decoration: TextDecoration.none, height: 1.4)),
        const SizedBox(height: 16),
        for (final (title, body) in clauses) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: TgIcon(Ic.check2, color: p.accent, size: 14, stroke: 2.4),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: p.title, fontSize: 15.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                const SizedBox(height: 3),
                Text(body, style: TextStyle(color: p.msg, fontSize: 14, decoration: TextDecoration.none, height: 1.42)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
