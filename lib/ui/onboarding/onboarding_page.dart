import 'package:flutter/widgets.dart';

import '../../core/anim.dart';
import '../../core/overlays.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/store.dart';
import '../../l10n/x.dart';
import '../dialogs_page.dart';
import 'common.dart';
import 'step_brand.dart';
import 'step_human.dart';
import 'step_model.dart';
import 'step_permissions.dart';
import 'step_personas.dart';
import 'step_privacy.dart';
import 'step_self.dart';
import 'step_theme.dart';
import 'step_workspace.dart';

/// The first-run wizard. Eight steps, every one skippable except the privacy
/// agreement. Lives on [store.onboarded]: the last step flips the flag, the
/// MaterialApp rebuilds and the dialog list is simply what home is now.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.replay = false});

  /// True when opened from Settings. Nothing persists, nothing is asked; the
  /// wizard is a read-only tour and the finish button just pops back.
  final bool replay;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

/// The wizard's pages, in the order the plan fixed: brand, permissions,
/// privacy, theme, model, workspace, temper, self, personas.
List<OnboardingStep> buildSteps(bool replay) => [
      buildBrandStep(),
      buildPermissionsStep(),
      buildPrivacyStep(),
      buildThemeStep(),
      buildModelStep(),
      buildWorkspaceStep(),
      buildHumanStep(),
      buildSelfStep(),
      buildPersonasStep(),
    ];

class _OnboardingPageState extends State<OnboardingPage> implements OnboardingFlow {
  final PageController _pager = PageController();
  int _index = 0;
  late final List<OnboardingStep> _steps = buildSteps(widget.replay);
  final Set<String> _pickedPersonas = {};

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Store get store => context.store;

  bool get _last => _index == _steps.length - 1;

  @override
  void next() {
    if (_last) {
      _finish();
      return;
    }
    _go(_index + 1);
  }

  @override
  void back() {
    if (_index > 0) _go(_index - 1);
  }

  @override
  void toEnd() => _go(_steps.length - 1);

  @override
  Set<String> get pickedPersonas => _pickedPersonas;

  @override
  void togglePersona(String id) => setState(() {
        if (!_pickedPersonas.add(id)) _pickedPersonas.remove(id);
      });

  void _go(int index) {
    setState(() => _index = index);
    _pager.animateToPage(index, duration: const Duration(milliseconds: 260), curve: TgCurves.easeOut);
  }

  void _finish() {
    // Replay is a pushed route: nothing persists, just pop back to Settings.
    if (widget.replay) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    createPickedChats(store, _pickedPersonas, context.l);
    store.setOnboarded(true);
    // Changing MaterialApp.home does not replace the route that is already on
    // the stack, so the wizard would sit there forever. Navigate explicitly and
    // clear the stack so back cannot return to it.
    Navigator.of(context).pushAndRemoveUntil(
      TgRoute(builder: (_) => const DialogsPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final step = _steps[_index];
    return ColoredBox(
      color: p.bg,
      child: SafeArea(
        child: Column(children: [
          // top bar: back on the left, dots dead-centre, skip on the right.
          // A Stack, not a Row: the skip label changes width between locales
          // and a Row would push the dots off the screen centre with it.
          SizedBox(
            height: 56,
            child: Stack(children: [
              Align(
                alignment: Alignment.center,
                child: StepDots(count: _steps.length, index: _index),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Tap(
                      scale: .88,
                      onTap: _index == 0 ? null : back,
                      child: TgIcon(Ic.back, color: _index == 0 ? p.subtitle.withAlpha(80) : p.icon, size: 22, stroke: 1.8),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Tap(
                  scale: .92,
                  onTap: step.skippable ? _finish : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(l.onboardSkip, style: TextStyle(color: step.skippable ? p.accent : p.subtitle.withAlpha(70), fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: OnboardingScope(
              flow: this,
              child: PageView(
                controller: _pager,
                // Pages turn through the buttons only, so a step can never be
                // swiped past before its work is done.
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final s in _steps) _StepScaffold(step: s, flow: this, onLast: _last),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// One page of the pager: header, scrollable step content, bottom button row.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.step, required this.flow, required this.onLast});

  final OnboardingStep step;
  final OnboardingFlow flow;
  final bool onLast;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final title = step.title?.call(l);
    final body = step.body?.call(l);
    return Column(children: [
      // Steps that paint their own hero (brand, privacy) leave both null and
      // the header collapses out of the layout entirely.
      if (title != null || body != null) StepHeader(title: title ?? '', body: body ?? ''),
      Expanded(
        child: Padding(padding: const EdgeInsets.only(top: 16), child: step.build(context, flow)),
      ),
      // The privacy step owns its bottom row, so it passes a builder that
      // returns its Agree / decline pair.
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: step.bottom(context, flow, onLast),
      ),
    ]);
  }
}
