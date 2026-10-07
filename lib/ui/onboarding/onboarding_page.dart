import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

import '../../core/anim.dart';
import '../../core/overlays.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/ai_config.dart';
import '../../data/backup.dart' show parseBackup;
import '../../data/full_backup.dart';
import '../../data/store.dart';
import '../../l10n/x.dart';
import '../../main.dart' show TgApp, bootStore;
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

// First-run wizard, laid out one to one after Telegram Android's IntroActivity
// (the "Start Messaging" intro), minus its OpenGL illustration so no artwork
// is copied:
//
// - no top bar: the pages swipe, the dots sit under the content, the pill
//   button sits in the bottom quarter. Back is swipe-right / system back.
// - titles are 26sp bold centred, messages 15sp centred, the dots are 5dp on
//   an 11dp pitch with the selected one stretching while scrolling.
// - the bottom pill is 48dp, 16dp margins, capped at 320dp, accent gradient.
// - the small centred link above the button (TG's "Continue in …" slot) is
//   Skip, or Not-now on the privacy step. The sun slot top-right toggles day
//   / night, like TG's theme icon on its intro.
//
// Lives on [store.onboarded]: the last step flips the flag, the MaterialApp
// rebuilds and the dialog list is simply what home is now.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

/// The wizard's pages, in the order the plan fixed: brand, permissions,
/// privacy, theme, model, workspace, temper, self, personas.
List<OnboardingStep> buildSteps() => [
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
  late final List<OnboardingStep> _steps = buildSteps();
  final Set<String> _pickedPersonas = {};

  @override
  void initState() {
    super.initState();
    // Fresh install (or wiped data) with a backup on the device: offer the
    // restore before the wizard starts instead of letting the user rebuild
    // everything by hand. Runs after first frame so the page is up behind
    // the dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerRestore());
  }

  /// Reads the auto backup and offers a merge-import. Declining just starts
  /// the wizard; the backup file is left alone either way.
  Future<void> _offerRestore() async {
    final store = context.store;
    if (store.chats.isNotEmpty || store.personas.isNotEmpty || !mounted) return;
    // the full snapshot beats the curated document in every way: it carries
    // files the JSON exporter does not know about yet, so offer it first
    if (await store.hasFullBackupFile() && mounted) {
      final zip = await store.readFullBackup();
      if (zip != null && mounted) {
        await _runFullRestore(zip);
        return;
      }
    }
    final raw = await store.readAutoBackup();
    if (raw == null) {
      // A backup can exist yet be unreadable to a fresh install: Android keeps
      // the file the old install wrote in Download/Paradise but may refuse to
      // hand its bytes to a new signing identity without the user tapping it.
      // Seeing the file but not its content still gets the offer, with a
      // manual pick instead of a silent skip.
      if (!await store.hasAutoBackupFile() || !mounted) return;
      final pick = await showTgDialog<bool>(
        context,
        title: context.l.autoBackupRestoreTitle,
        message: context.l.autoBackupPickMessage,
        actions: [
          DialogAction(context.l.actionCancel, false),
          DialogAction(context.l.autoBackupPickAction, true),
        ],
      );
      if (pick != true || !mounted) return;
      final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      final path = picked.firstOrNull?.path;
      if (path == null || !mounted) return;
      try {
        await _runRestore(await File(path).readAsString());
      } catch (_) {
        if (context.mounted) showBulletin(context, context.l.autoBackupRestoreFailed);
      }
      return;
    }
    await _runRestore(raw);
  }

  /// The full zip restore: put the files back, rebuild the store on top of
  /// them and restart the app. The old instance is shut down first so nothing
  /// of its timers or connections survives into the restored world.
  Future<void> _runFullRestore(Uint8List zip) async {
    if (!mounted) return;
    final store = context.store;
    final l = context.l;
    final ok = await showTgDialog<bool>(
      context,
      title: l.fullBackupRestoreTitle,
      message: l.fullBackupRestoreMessage,
      actions: [
        DialogAction(l.actionCancel, false),
        DialogAction(l.fullBackupRestoreAction, true),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      await store.shutdownForReplace();
      await FullBackup.restore(zip);
      final freshStore = await Store.load();
      final freshAi = await AiConfig.load();
      freshStore.attachAi(freshAi);
      await freshStore.skills.rescan();
      themeCtl.setAccent(freshStore.wallpaperColor, BubbleGrad.values[freshStore.wallpaperBubbleGrad]);
      freshStore.addListener(() => themeCtl.setAccent(freshStore.wallpaperColor, BubbleGrad.values[freshStore.wallpaperBubbleGrad]));
      await bootStore(freshStore);
      // the restored prefs carry the onboarded flag, so the new tree lands
      // on the dialog list exactly like a normal launch would
      runApp(TgApp(store: freshStore, ai: freshAi));
    } catch (_) {
      if (context.mounted) showBulletin(context, l.fullBackupRestoreFailed);
    }
  }

  /// The shared tail of every restore path: parse for the timestamp, confirm,
  /// import, land on the dialog list.
  Future<void> _runRestore(String raw) async {
    if (!mounted) return;
    final store = context.store;
    final l = context.l;
    var when = '';
    try {
      final doc = parseBackup(raw);
      final at = doc.exportedAt;
      if (at != null) {
        String p(int v) => v.toString().padLeft(2, '0');
        when = '${at.year}-${p(at.month)}-${p(at.day)} ${p(at.hour)}:${p(at.minute)}';
      }
    } catch (_) {
      // unreadable doc: still offer it, the import dialog says what failed
    }
    final ok = await showTgDialog<bool>(
      context,
      title: l.autoBackupRestoreTitle,
      message: l.autoBackupRestoreMessage(when),
      actions: [
        DialogAction(l.actionCancel, false),
        DialogAction(l.autoBackupRestoreAction, true),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      await store.importBackupString(raw, overwrite: false);
      store.setOnboarded(true);
      Navigator.of(context).pushAndRemoveUntil(
        TgRoute(builder: (_) => const DialogsPage()),
        (route) => false,
      );
      if (context.mounted) showBulletin(context, l.autoBackupRestored);
    } catch (_) {
      if (context.mounted) showBulletin(context, l.autoBackupRestoreFailed);
    }
  }

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
    // Only the privacy step is non-skippable; its Agree owns the pill and its
    // decline borrows the link slot above it.
    final privacy = !step.skippable;
    final mainLabel = privacy ? l.onboardPrivacyAgree : (_last ? l.onboardStart : l.onboardNext);
    return PopScope(
      // Swiped past page zero there is somewhere to go back to; on page zero
      // the system back exits first-run.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index > 0) back();
      },
      child: ColoredBox(
        color: p.bg,
        child: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            // TG centres the button in the bottom quarter: link (30) + gap
            // (30) + button (48) = 108 centred in a quarter, the rest is the
            // air above and below.
            final quarter = (box.maxHeight * 0.25).clamp(150.0, 230.0);
            final side = ((quarter - 108) / 2).clamp(14.0, 64.0);
            return OnboardingScope(
              flow: this,
              child: Column(children: [
                // TG's theme slot, top-right. One static moon, no animation.
                const SizedBox(
                  height: 56,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _ThemeToggle(),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pager,
                    onPageChanged: (i) {
                      if (i != _index) setState(() => _index = i);
                    },
                    children: [
                      for (final s in _steps) _StepBody(step: s, flow: this),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                StepDots(count: _steps.length, controller: _pager, index: _index),
                SizedBox(height: side),
                // TG's "Continue in …" slot: Skip, or Not-now on privacy.
                SizedBox(
                  height: 30,
                  child: Center(
                    child: Tap(
                      scale: .94,
                      onTap: () => privacy ? showPrivacyDeclineDialog(context) : _finish(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(privacy ? l.onboardPrivacyDecline : l.onboardSkip,
                            style: TextStyle(color: privacy ? p.subtitle : p.accent, fontSize: 16, decoration: TextDecoration.none)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: TgIntroButton(label: mainLabel, onTap: next),
                    ),
                  ),
                ),
                SizedBox(height: side),
              ]),
            );
          }),
        ),
      ),
    );
  }
}

/// One page of the pager: the shared 26sp / 15sp header when the step has one
/// (brand paints its own), then the scrollable step content.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.step, required this.flow});

  final OnboardingStep step;
  final OnboardingFlow flow;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final title = step.title?.call(l);
    final body = step.body?.call(l);
    return Column(children: [
      if (title != null || body != null) StepHeader(title: title ?? '', body: body ?? ''),
      Expanded(
        child: Padding(padding: const EdgeInsets.only(top: 16), child: step.build(context, flow)),
      ),
    ]);
  }
}

/// TG's intro theme icon, static: moon, day / night on tap.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: context.store,
      builder: (context, _) {
        final st = context.store;
        return Tap(
          scale: .88,
          onTap: () => st.setDark(!st.dark),
          child: SizedBox(
            width: 64,
            height: 64,
            child: Center(
              child: TgIcon(Ic.moon, color: context.p.icon, size: 26, stroke: 1.8),
            ),
          ),
        );
      },
    );
  }
}
