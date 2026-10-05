import 'package:flutter/widgets.dart';

import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/store.dart';
import '../../l10n/x.dart';
import '../tg_cells.dart';
import '../wallpaper_page.dart' show WallpaperSwatches, openWallpaperSheet;
import 'common.dart';

/// Step 4: how the app looks. Night mode, wallpaper and the two dials that
/// change the feel of every bubble. The wallpaper swatches only appear once a
/// picture is behind them, matching the settings page.
OnboardingStep buildThemeStep() => OnboardingStep(
      title: (l) => l.onboardThemeTitle,
      body: (l) => l.onboardThemeBody,
      build: (c, flow) => const _ThemeBody(),
    );

class _ThemeBody extends StatelessWidget {
  const _ThemeBody();

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = context.p;
    return ListenableBuilder(
      listenable: context.store,
      builder: (context, _) {
        final st = context.store;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          children: [
            TgSection(
              header: l.appearanceTheme,
              children: [
                TgCheckCell(
                  title: l.appearanceNightMode,
                  icon: Ic.moon,
                  value: st.dark,
                  onChanged: st.setDark,
                  divider: false,
                ),
              ],
            ),
            TgSection(
              header: l.wallpaperHeader,
              children: [
                TgTextCell(
                  title: l.wallpaperRow,
                  icon: Ic.image,
                  value: st.wallpaperPath.isEmpty ? l.wallpaperNone : null,
                  onTap: () => openWallpaperSheet(context),
                  divider: st.wallpaperPath.isNotEmpty,
                ),
                if (st.wallpaperPath.isNotEmpty)
                  TgCheckCell(
                    title: l.wallpaperBlur,
                    icon: Ic.image,
                    value: st.wallpaperBlur,
                    onChanged: st.setWallpaperBlur,
                    divider: false,
                  ),
              ],
            ),
            if (st.wallpaperPath.isNotEmpty)
              TgSection(
                header: l.wallpaperColorHeader,
                children: [
                  WallpaperSwatches(path: st.wallpaperPath),
                  if (st.wallpaperColor != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      child: TgSegmented(
                        labels: [l.wallpaperBubbleGradSubtle, l.wallpaperBubbleGradMedium, l.wallpaperBubbleGradStrong],
                        index: st.wallpaperBubbleGrad,
                        onChanged: st.setWallpaperBubbleGrad,
                      ),
                    ),
                ],
              ),
            TgSection(
              header: l.appearanceTextSize,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(children: [
                    Expanded(child: Text(l.appearanceSize, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none))),
                    Text(L10n.number('#,##0').format(st.textSize.round()), style: TextStyle(color: p.accent, fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                  child: TgSlider(value: st.textSize, min: 12, max: 30, onChanged: st.setTextSize),
                ),
              ],
            ),
            TgSection(
              header: l.appearanceCorners,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(children: [
                    Expanded(child: Text(l.appearanceSize, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none))),
                    Text(L10n.number('#,##0').format(st.bubbleRadius.round()), style: TextStyle(color: p.accent, fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                  child: TgSlider(value: st.bubbleRadius, min: 0, max: 24, onChanged: st.setRadius),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
