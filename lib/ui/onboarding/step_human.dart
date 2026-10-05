import 'package:flutter/widgets.dart';

import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/human/human_models.dart';
import '../../l10n/x.dart';
import 'common.dart';
import '../tg_cells.dart';
import '../human_pages.dart' show HLive;
import '../../core/anim.dart';

/// Step 6: how much of a person the assistants act like. Five temper cards,
/// one live at a time, plus the two switches worth exposing on day one.
/// Everything else stays where Settings > Humanize keeps it.
OnboardingStep buildHumanStep() => OnboardingStep(
      title: (l) => l.onboardHumanTitle,
      body: (l) => l.onboardHumanBody,
      build: (c, flow) => const _HumanBody(),
    );

class _HumanBody extends StatelessWidget {
  const _HumanBody();

  // display order of the five tempers, balanced last so the extras read
  // before the safe default
  static const _order = <HumanTemper>[
    HumanTemper.clingy,
    HumanTemper.cold,
    HumanTemper.chatty,
    HumanTemper.quiet,
    HumanTemper.balanced,
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return HLive(
      builder: (c, h, p) {
        final live = temperOf(h.settings);
        String title(HumanTemper t) => switch (t) {
              HumanTemper.clingy => l.onboardHumanPresetClingy,
              HumanTemper.cold => l.onboardHumanPresetCold,
              HumanTemper.chatty => l.onboardHumanPresetChatty,
              HumanTemper.quiet => l.onboardHumanPresetQuiet,
              HumanTemper.balanced => l.onboardHumanPresetBalanced,
            };
        String sub(HumanTemper t) => switch (t) {
              HumanTemper.clingy => l.onboardHumanPresetClingySub,
              HumanTemper.cold => l.onboardHumanPresetColdSub,
              HumanTemper.chatty => l.onboardHumanPresetChattySub,
              HumanTemper.quiet => l.onboardHumanPresetQuietSub,
              HumanTemper.balanced => l.onboardHumanPresetBalancedSub,
            };
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          children: [
            TgSection(
              footer: l.humanFooter,
              children: [
                TgCheckCell(
                  title: l.onboardHumanEnabled,
                  subtitle: l.humanSubtitle,
                  icon: Ic.smile,
                  value: h.settings.enabled,
                  onChanged: (v) {
                    h.settings.enabled = v;
                    h.changed();
                  },
                  divider: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final t in _order)
              _TemperCard(
                title: title(t),
                subtitle: sub(t),
                live: live == t,
                onTap: () {
                  applyTemper(h.settings, t);
                  h.changed();
                },
              ),
          ],
        );
      },
    );
  }
}

/// One temper: a radio row with a title and what it does. The live one keeps
/// its pill filled and the section does not fold, matching the cell grammar
/// the rest of the settings use.
class _TemperCard extends StatelessWidget {
  const _TemperCard({required this.title, required this.subtitle, required this.live, required this.onTap});

  final String title;
  final String subtitle;
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Tap(
      scale: .98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: live ? p.accent.withAlpha(22) : p.gray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: live ? p.accent : const Color(0x00000000), width: 1.2),
        ),
        child: Row(children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: live ? p.accent : p.subtitle, width: 1.6)),
            child: live ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent))) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: live ? p.accent : p.title, fontSize: 15.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: p.subtitle, fontSize: 12.5, decoration: TextDecoration.none, height: 1.3)),
            ]),
          ),
        ]),
      ),
    );
  }
}
