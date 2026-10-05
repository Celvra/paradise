import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../core/anim.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/store.dart';
import '../../l10n/x.dart';

// Shared scaffolding for the onboarding steps: the portrait title block every
// step opens with, the pill row of dots that tracks the wizard position, and
// the permission gate helper the permissions step and the self photo picker
// both go through.

/// One step of the wizard, built by [OnboardingPage].
class OnboardingStep {
  const OnboardingStep({
    required this.build,
    this.title,
    this.body,
    this.skippable = true,
    this.bottomBuilder,
  });

  /// The 26sp centered heading. Null on the steps that paint their own hero
  /// (brand, privacy) so the shared header stays out of the way.
  final String Function(AppLocalizations l)? title;

  /// The 15sp centered paragraph under the heading.
  final String Function(AppLocalizations l)? body;

  /// The content below the heading. Receives the wizard state so a step can
  /// move the pager or read the store.
  final Widget Function(BuildContext c, OnboardingFlow flow) build;

  /// False only for the privacy step, the one screen with no way around.
  final bool skippable;

  /// Overrides the default Next row. The privacy step replaces it with its
  /// Agree / decline pair.
  final Widget? Function(BuildContext, OnboardingFlow, bool)? bottomBuilder;

  /// The bottom button row. Defaults to a single Next that turns into Start
  /// on the last page.
  Widget bottom(BuildContext c, OnboardingFlow flow, bool onLast) {
    final custom = bottomBuilder?.call(c, flow, onLast);
    if (custom != null) return custom;
    return BottomRow(nextLabel: onLast ? c.l.onboardStart : c.l.onboardNext, flow: flow);
  }
}

/// The default bottom row: one full width Next, or Start when done.
class BottomRow extends StatelessWidget {
  const BottomRow({super.key, required this.nextLabel, required this.flow, this.leading});

  final String nextLabel;
  final OnboardingFlow flow;

  /// An optional widget docked left of the button, the steps that carry a
  /// second action (the relay disable, the persona count) use it.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final button = Expanded(
      child: TgButton(label: nextLabel, onTap: flow.next),
    );
    return Row(children: [if (leading != null) leading!, button]);
  }
}

/// The OnboardingFlow the page implements, plus the persona picker state the
/// last step collects into. Kept on the flow so the step stays stateless.
abstract class OnboardingFlow {
  Store get store;

  /// Moves to the next step, or finishes the wizard from the last one.
  void next();

  void back();

  /// Jumps to the last step. The privacy decline dialog uses it to send the
  /// user around once more instead of stranding them on one screen.
  void toEnd();

  /// The template ids picked on the last step, toggled by [togglePersona].
  Set<String> get pickedPersonas;

  void togglePersona(String id);
}

/// Puts the flow under the build context so a step deep in its own subtree
/// can move the pager without it being threaded through every widget.
class OnboardingScope extends InheritedWidget {
  const OnboardingScope({super.key, required this.flow, required super.child});

  final OnboardingFlow flow;

  static OnboardingFlow of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<OnboardingScope>()!.flow;

  @override
  bool updateShouldNotify(OnboardingScope oldWidget) => false;
}

/// The centered title + body every step shares, worded to the Telegram intro
/// sizes: 26sp bold heading, 15sp paragraph, both centered.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(children: [
        Text(title, textAlign: TextAlign.center, style: TextStyle(color: p.title, fontSize: 26, fontWeight: FontWeight.w700, decoration: TextDecoration.none, height: 1.2)),
        const SizedBox(height: 10),
        Text(body, textAlign: TextAlign.center, style: TextStyle(color: p.msg, fontSize: 15, fontWeight: FontWeight.w400, decoration: TextDecoration.none, height: 1.35)),
      ]),
    );
  }
}

/// The app mark, drawn from the committed svg so the wizard never depends on
/// the launcher icon being readable against either theme.
class OnboardingLogo extends StatelessWidget {
  const OnboardingLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/icon/icon.svg', width: size, height: size);
  }
}

/// A radio row for a small, fixed set of choices: title, subtitle and a dot
/// that fills when selected. Used by the self step for the two injection
/// knobs. The whole row is the target and the fill animates.
class RadioRow extends StatelessWidget {
  const RadioRow({super.key, required this.title, required this.selected, required this.onTap, this.subtitle});

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Tap(
      scale: .99,
      highlight: true,
      radius: 0,
      onTap: onTap,
      child: SizedBox(
        height: subtitle == null ? 50 : 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 21),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: TgCurves.easeOut,
              width: 20,
              height: 20,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? p.accent : p.subtitle, width: 1.8)),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                curve: TgCurves.easeOutBack,
                scale: selected ? 1 : 0,
                child: Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: p.title, fontSize: 16, height: 1.25, decoration: TextDecoration.none)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 13.5, height: 1.25, decoration: TextDecoration.none)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The row of 5dp pills under the header, selected one stretched and tinted.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: TgCurves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 5,
            width: i == index ? 18 : 5,
            decoration: BoxDecoration(color: i == index ? p.accent : p.subtitle.withAlpha(70), borderRadius: BorderRadius.circular(2.5)),
          ),
      ],
    );
  }
}

/// Asks through permission_handler, the one place the wizard talks to it.
/// Returns the state after the ask so the row can render granted, denied or
/// permanently-denied without a second probe.
Future<ph.PermissionStatus> askPermission(ph.Permission permission) => permission.request();

/// The wizard's eight pages live with the page itself (onboarding_page.dart):
/// importing them here would be a cycle, since every step builds on this file.

/// Maps a status onto what the row says: granted, askable, or sent to settings.
String permissionStateLabel(ph.PermissionStatus status, AppLocalizations l) => switch (status) {
      ph.PermissionStatus.granted ||
      ph.PermissionStatus.limited ||
      ph.PermissionStatus.provisional => l.onboardPermGranted,
      ph.PermissionStatus.permanentlyDenied || ph.PermissionStatus.restricted => l.onboardPermDenied,
      _ => l.onboardPermAllow,
    };
