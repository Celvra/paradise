import 'package:flutter/widgets.dart';
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

/// The app mark, painted by hand from the committed svg's paths (P monoline
/// plus the dot on a 100 box) in the theme title color. Hand-painted because
/// the svg is not a declared bundle asset and uses currentColor, which
/// flutter_svg cannot resolve, so loading it here renders nothing.
class OnboardingLogo extends StatelessWidget {
  const OnboardingLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _LogoPainter(context.p.title));
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    final sp = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final p = Path()
      ..moveTo(38, 72)
      ..lineTo(38, 28)
      ..lineTo(56, 28)
      ..arcToPoint(const Offset(56, 56), radius: const Radius.circular(14))
      ..lineTo(38, 56);
    canvas.drawPath(p, sp);
    canvas.drawCircle(const Offset(72, 72), 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LogoPainter o) => o.color != color;
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

/// Port of Telegram Android's BottomPagesView: 5dp dots on an 11dp pitch, the
/// selected one stretching across the gap while the pager scrolls. Grey is
/// #BBBBBB on day and #555555 on night, selected is the accent.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.count, required this.controller, required this.index});

  final int count;
  final PageController controller;

  /// Fallback page before the controller attaches to the PageView.
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final selected = p.accent;
    final track = p.dark ? const Color(0xFF555555) : const Color(0xFFBBBBBB);
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        double page;
        try {
          page = controller.page ?? index.toDouble();
        } catch (_) {
          page = index.toDouble();
        }
        return CustomPaint(
          size: Size(count * 11.0 - 6, 5),
          painter: _TgDotsPainter(count, page, selected, track),
        );
      },
    );
  }
}

class _TgDotsPainter extends CustomPainter {
  _TgDotsPainter(this.count, this.page, this.selected, this.track);

  final int count;
  final double page;
  final Color selected;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const dot = 5.0, pitch = 11.0, r = 2.5;
    final cur = page.round().clamp(0, count - 1);
    final pos = page.floor().clamp(0, count - 1);
    final prog = (page - pos).clamp(0.0, 1.0);
    final tp = Paint()..color = track;
    for (var i = 0; i < count; i++) {
      if (i == cur) continue;
      final x = i * pitch;
      canvas.drawRRect(RRect.fromLTRBR(x, 0, x + dot, dot, const Radius.circular(r)), tp);
    }
    final sp = Paint()..color = selected;
    final x = cur * pitch;
    final RRect rect;
    if (prog == 0) {
      rect = RRect.fromLTRBR(x, 0, x + dot, dot, const Radius.circular(r));
    } else if (pos >= cur) {
      rect = RRect.fromLTRBR(x, 0, x + dot + pitch * prog, dot, const Radius.circular(r));
    } else {
      rect = RRect.fromLTRBR(x - pitch * (1 - prog), 0, x + dot, dot, const Radius.circular(r));
    }
    canvas.drawRRect(rect, sp);
  }

  @override
  bool shouldRepaint(_TgDotsPainter o) =>
      o.count != count || o.page != page || o.selected != selected || o.track != track;
}

/// Port of Telegram Android's Start Messaging button: a 48dp pill, full width
/// with 16dp margins and capped at 320dp, left-right accent gradient, 15sp
/// bold white label. The gradient's second stop is the accent pushed 10%
/// towards black, the same family as TG's featuredStickers_addButton pair.
class TgIntroButton extends StatelessWidget {
  const TgIntroButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final dark = Color.lerp(p.accent, const Color(0xFF000000), 0.10)!;
    return Tap(
      scale: .98,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 34),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(colors: [p.accent, dark]),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 15, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
      ),
    );
  }
}

/// Asks through permission_handler, the one place the wizard talks to it.
/// Returns the state after the ask so the row can render granted, denied or
/// permanently-denied without a second probe. A platform without the plugin
/// (tests, desktop) reports denied rather than throwing.
Future<ph.PermissionStatus> askPermission(ph.Permission permission) async {
  try {
    return await permission.request();
  } catch (_) {
    return ph.PermissionStatus.denied;
  }
}

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
