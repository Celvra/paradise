import 'dart:async';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:flutter/widgets.dart';

import '../../core/overlays.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/store.dart';
import '../../data/workspace/android_proot_runtime.dart';
import '../../data/workspace/environment_installer.dart';
import '../../l10n/x.dart';
import '../human_pages.dart' show hOpen;
import '../tg_cells.dart';
import 'workspace_prompts.dart';

void openEnvironmentSettings(BuildContext context) =>
    hOpen(context, const EnvironmentPage());

class EnvironmentPage extends StatefulWidget {
  const EnvironmentPage({super.key});

  @override
  State<EnvironmentPage> createState() => _EnvironmentPageState();
}

class _EnvironmentPageState extends State<EnvironmentPage> {
  StreamSubscription<EnvState>? _sub;
  EnvState _state = const EnvState();
  String _arch = '';
  String _abi = '';
  RootfsImage? _selected;
  bool _busyAction = false;

  EnvironmentInstaller? get _installer =>
      Store.of(context).workspaceStack?.installer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final stack = Store.of(context).workspaceStack;
    if (stack == null) return;
    _sub = stack.installer.states.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    final status = await stack.channel.probe();
    if (!mounted) return;
    setState(() {
      _abi = status.abi;
      _arch = AndroidProotRuntime.rootfsArchForAbi(status.abi) ?? '';
      _selected ??= _availableImages().firstOrNull;
    });
    final state = await stack.installer.refresh();
    if (mounted) setState(() => _state = state);
  }

  List<RootfsImage> _availableImages() => [
        for (final image in rootfsCatalog)
          if (image.urls.containsKey(_arch)) image
      ];

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _phaseLabel(AppLocalizations l) => switch (_state.phase) {
        EnvPhase.downloading => l.envDownloading,
        EnvPhase.verifying => l.envVerifying,
        EnvPhase.extracting => l.envExtracting,
        EnvPhase.patching => l.envPatching,
        EnvPhase.ready => l.envReady,
        EnvPhase.error => _errorLabel(l, _state.error),
        EnvPhase.notInstalled => l.envNotInstalled,
      };

  String _errorLabel(AppLocalizations l, String code) => switch (code) {
        EnvError.unsupportedAbi ||
        EnvError.architectureMismatch =>
          l.envErrorArchitecture,
        EnvError.prootMissing => l.envErrorProot,
        EnvError.insufficientDisk => l.envErrorDisk,
        EnvError.network => l.envErrorNetwork,
        EnvError.checksumMismatch => l.envErrorChecksum,
        EnvError.extractFailed => l.envErrorExtract,
        EnvError.patchFailed => l.envErrorPatch,
        EnvError.cancelled => l.envErrorCancelled,
        EnvError.invalidRootfs => l.envErrorInvalid,
        _ => l.envUnknownError,
      };

  Future<void> _install(RootfsImage image) async {
    final installer = _installer;
    if (installer == null || _busyAction) return;
    final confirmed = await askConfirm(context,
        title: l10n.envInstall,
        message: l10n.envInstallConfirm,
        confirmLabel: l10n.envInstall);
    if (!confirmed || !mounted) return;
    setState(() => _busyAction = true);
    try {
      await installer.install(image, _arch);
    } catch (_) {
      if (mounted) showBulletin(context, _errorLabel(l10n, installer.state.error));
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _remove() async {
    final installer = _installer;
    if (installer == null || _busyAction) return;
    final ok = await askTypeDelete(
      context,
      title: l10n.envRemove,
      message: l10n.envRemoveConfirm,
    );
    if (!ok || !mounted) return;
    setState(() => _busyAction = true);
    try {
      await installer.reset();
    } catch (_) {
      if (mounted) showBulletin(context, l10n.envUnknownError);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  AppLocalizations get l10n => L10n.current;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = context.p;
    final images = _availableImages();
    final installed = _state.phase == EnvPhase.ready;
    final busy = _state.busy || _busyAction;
    return TgSettingsPage(
      title: l.envTitle,
      builder: (c, _) => ListView(
        physics: const ClampingScrollPhysics(),
        padding:
            EdgeInsets.only(bottom: 32 + MediaQuery.of(context).padding.bottom),
        children: [
          TgSection(
            header: l.envTitle,
            children: [
              TgTextCell(
                title: _phaseLabel(l),
                subtitle: installed
                    ? '${distroName(_state.distro)} ${_state.version} · ${_state.arch}'
                    : (_abi.isEmpty
                        ? l.envChecking
                        : '${l.envArch}: ${_arch.isEmpty ? _abi : _arch}'),
                icon: installed
                    ? Ic.check2
                    : (_state.phase == EnvPhase.error ? Ic.info : Ic.terminal),
                divider: _state.phase == EnvPhase.error,
              ),
              if (busy) _progress(context),
              if (_state.phase == EnvPhase.error)
                Padding(
                  padding: const EdgeInsets.fromLTRB(21, 10, 21, 14),
                  child: Text(_phaseLabel(l),
                      style: TextStyle(
                          color: p.danger,
                          fontSize: 13,
                          height: 1.4,
                          decoration: TextDecoration.none)),
                ),
              if (_state.availableVersion.isNotEmpty && installed)
                TgTextCell(
                    title: l.envUpdate,
                    subtitle: _state.availableVersion,
                    icon: Ic.download,
                    divider: false),
            ],
          ),
          TgSection(
            header: l.envChoose,
            footer: _arch.isEmpty ? l.envUnsupportedDevice(_abi) : null,
            children: [
              for (final image in images)
                TgTextCell(
                  title: image.label,
                  subtitle: l.envMinFree(image.minFreeMb),
                  icon: Ic.folderOpen,
                  value: _selected?.id == image.id ? '✓' : null,
                  onTap: busy ? null : () => setState(() => _selected = image),
                  divider: image != images.last,
                ),
              if (images.isEmpty)
                TgTextCell(
                    title: l.envUnsupported, icon: Ic.info, divider: false),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(children: [
              if (busy)
                TgButton(
                    label: l.envCancel,
                    enabled: !_busyAction,
                    onTap: () => _installer?.cancel())
              else if (installed)
                TgButton(label: l.envRemove, enabled: !_busyAction, onTap: _remove)
              else
                TgButton(
                    label: l.envInstall,
                    enabled:
                        !_busyAction && _selected != null && _arch.isNotEmpty,
                    onTap: () {
                      final image = _selected;
                      if (image != null) unawaited(_install(image));
                    }),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _progress(BuildContext context) {
    final p = context.p;
    final progress =
        _state.phase == EnvPhase.extracting ? null : _state.progress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(21, 4, 21, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRect(
            child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                color: p.accent,
                backgroundColor: p.bg)),
        const SizedBox(height: 7),
        Text(
          _state.phase == EnvPhase.extracting
              ? '${_state.entries} · ${_state.currentEntry}'
              : _state.bytesTotal > 0
                  ? '${_formatBytes(_state.bytesDone)} / ${_formatBytes(_state.bytesTotal)}'
                  : _phaseLabel(context.l),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: p.subtitle, fontSize: 12, decoration: TextDecoration.none),
        ),
      ]),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
