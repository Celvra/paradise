import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/anim.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/store.dart';
import '../../data/workspace/android_proot_runtime.dart';
import '../../data/workspace/environment_installer.dart';
import '../../data/workspace/workspace_bootstrap.dart';
import '../../l10n/x.dart';
import '../tg_cells.dart';
import 'common.dart';

/// Step 5: the workspace switches plus the optional Linux environment. The
/// install streams its progress into the card; the installer owns the state,
/// this step only listens and shows it.
OnboardingStep buildWorkspaceStep() => OnboardingStep(
      title: (l) => l.onboardWsTitle,
      body: (l) => l.onboardWsBody,
      build: (c, flow) => const _WorkspaceBody(),
    );

class _WorkspaceBody extends StatefulWidget {
  const _WorkspaceBody();

  @override
  State<_WorkspaceBody> createState() => _WorkspaceBodyState();
}

class _WorkspaceBodyState extends State<_WorkspaceBody> {
  StreamSubscription<EnvState>? _sub;
  EnvState _env = const EnvState();
  RootfsImage? _image;
  String _arch = '';

  WorkspaceStack? get _stack => context.store.workspaceStack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final stack = _stack;
    if (stack == null) return;
    _sub?.cancel();
    _sub = stack.installer.states.listen((s) {
      if (mounted) setState(() => _env = s);
    });
    final probe = await stack.channel.probe();
    _arch = AndroidProotRuntime.rootfsArchForAbi(probe.abi) ?? '';
    _image ??= [for (final i in rootfsCatalog) if (i.urls.containsKey(_arch)) i].firstOrNull;
    final state = await stack.installer.refresh();
    if (mounted) setState(() => _env = state);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get _installing => switch (_env.phase) {
        EnvPhase.downloading || EnvPhase.verifying || EnvPhase.extracting || EnvPhase.patching => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = context.p;
    // The switches write to WorkspaceStore, which is its own notifier. Without
    // this ListenableBuilder the row never repaints and the toggle reads dead.
    return ListenableBuilder(
      listenable: context.store.workspace,
      builder: (context, _) {
        final ws = context.store.workspace;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          children: [
            TgSection(
              children: [
                TgCheckCell(
                  title: l.onboardWsTools,
                  icon: Ic.terminal,
                  value: ws.toolsEnabled,
                  onChanged: ws.setToolsEnabled,
                ),
                TgCheckCell(
                  title: l.onboardWsConfirm,
                  icon: Ic.check2,
                  value: ws.confirmWrites,
                  onChanged: ws.setConfirmWrites,
                  divider: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: p.gray, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.onboardWsEnvTitle, style: TextStyle(color: p.title, fontSize: 16.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                const SizedBox(height: 6),
                Text(l.onboardWsEnvBody, style: TextStyle(color: p.msg, fontSize: 13.5, decoration: TextDecoration.none, height: 1.4)),
                const SizedBox(height: 12),
                if (_installing) ...[
                  Text(
                    switch (_env.phase) {
                      EnvPhase.downloading => l.envDownloading,
                      EnvPhase.verifying => l.envVerifying,
                      EnvPhase.extracting => l.envExtracting,
                      _ => l.envPatching,
                    },
                    style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none),
                  ),
                  const SizedBox(height: 8),
                  _MiniProgress(value: _env.phase == EnvPhase.downloading && _env.bytesTotal > 0 ? _env.bytesDone / _env.bytesTotal : null),
                ] else ...[
                  Row(children: [
                    TgIcon(_env.phase == EnvPhase.ready ? Ic.check2 : Ic.download, color: _env.phase == EnvPhase.ready ? p.accent : p.icon, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _env.phase == EnvPhase.ready ? l.onboardWsEnvReady : (_env.phase == EnvPhase.error ? l.envUnknownError : l.onboardWsEnvInstall),
                        style: TextStyle(color: p.msg, fontSize: 13.5, decoration: TextDecoration.none),
                      ),
                    ),
                    if (_env.phase != EnvPhase.ready && _image != null && _arch.isNotEmpty)
                      Tap(
                        scale: .95,
                        onTap: () => _stack?.installer.install(_image!, _arch),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(9)),
                          child: Text(l.onboardWsEnvInstall, style: TextStyle(color: p.dark ? const Color(0xFF0F1A24) : const Color(0xFFFFFFFF), fontSize: 13.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                        ),
                      ),
                  ]),
                ],
              ]),
            ),
          ],
        );
      },
    );
  }
}

/// A 4dp linear bar, indeterminate as a slow sweep. The material
/// LinearProgressIndicator pulls in a theme this app never configured, so
/// this is the whole thing by hand.
class _MiniProgress extends StatefulWidget {
  const _MiniProgress({this.value});

  /// 0..1, or null for the indeterminate sweep.
  final double? value;

  @override
  State<_MiniProgress> createState() => _MiniProgressState();
}

class _MiniProgressState extends State<_MiniProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SizedBox(
      height: 4,
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, _) {
          final t = _ctl.value;
          final v = widget.value;
          final start = v ?? (t < .5 ? t * 2 : (t - .5) * 2);
          final width = v ?? .3;
          return Stack(children: [
            Container(height: 4, decoration: BoxDecoration(color: p.subtitle.withAlpha(40), borderRadius: BorderRadius.circular(2))),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: v != null ? v.clamp(0.0, 1.0) : width,
                child: Container(height: 4, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2))),
              ),
            ),
            if (v == null)
              Align(
                alignment: Alignment(-1 + start * 2, 0),
                child: Container(width: 24, height: 4, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2))),
              ),
          ]);
        },
      ),
    );
  }
}
