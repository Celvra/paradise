import 'package:flutter/widgets.dart';

import '../../core/overlays.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../l10n/x.dart';
import 'common.dart';

/// Step 3: the privacy agreement, the one step with no skip. The wizard shell
/// owns the bottom (TG intro style): Agree is the pill, decline is the small
/// link above it, both wired by [OnboardingPage].
OnboardingStep buildPrivacyStep() => OnboardingStep(
      skippable: false,
      // The lock animation keeps the legal wall from reading as a bare text
      build: (c, flow) => const _PrivacyBody(),
    );

/// The decline dialog the shell's link slot opens. Staying on the step after
/// it: agreement is the gate, and re-reading is cheaper than a dead end.
Future<void> showPrivacyDeclineDialog(BuildContext context) async {
  final l = context.l;
  await showTgDialog<void>(
    context,
    title: l.onboardPrivacyDeclineTitle,
    content: Text(l.onboardPrivacyDeclineBody, style: TextStyle(color: context.p.msg, fontSize: 15, decoration: TextDecoration.none, height: 1.45)),
    actions: [DialogAction(l.actionOk, null)],
  );
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
