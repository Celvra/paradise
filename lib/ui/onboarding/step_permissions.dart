import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:photo_manager/photo_manager.dart' as pm;

import '../../core/anim.dart';
import '../../core/overlays.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../l10n/x.dart';
import '../tg_cells.dart';
import 'common.dart';

/// Step 2: the permissions the app can actually use, one row each, every row
/// askable right here and deniable forever without blocking anything. Nothing
/// is requested on page enter; a row asks only when its Allow is tapped.
///
/// Only notifications and photos: the location and contacts attachment entries
/// were removed, so asking for them here would be a request with no purpose.
OnboardingStep buildPermissionsStep() => OnboardingStep(
      title: (l) => l.onboardPermTitle,
      body: (l) => l.onboardPermBody,
      build: (c, flow) => const _PermList(),
    );

class _PermList extends StatefulWidget {
  const _PermList();

  @override
  State<_PermList> createState() => _PermListState();
}

class _PermListState extends State<_PermList> with WidgetsBindingObserver {
  final Map<ph.Permission, ph.PermissionStatus> _states = {};
  // a second tap while the system dialog is up makes Android answer the extra
  // request with a plain denied, which used to read as the user refusing
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _probe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // back from the system dialog or the settings app: reread every row so
    // the granted check shows now, not after a page leave and return
    if (state == AppLifecycleState.resumed) _probe();
  }

  Future<void> _probe() async {
    // A status read never pops a dialog, so this is safe on page enter and
    // keeps the rows honest if the user came back from system settings — the
    // notification row included: allowing it in settings must flip the row
    // without another tap. It throws MissingPluginException on a platform
    // without the plugin (tests, desktop): treat that as "not granted yet"
    // and stay silent.
    for (final perm in _rows.map((r) => r.$1)) {
      try {
        // media goes through photo_manager, the same ask the in-app gallery
        // uses: on some vendors permission_handler's photos request returns
        // denied without ever showing the system prompt, while the gallery's
        // own ask works
        _states[perm] = perm == ph.Permission.photos ? await _mediaState() : await perm.status;
      } catch (_) {
        _states[perm] = ph.PermissionStatus.denied;
      }
    }
    if (mounted) setState(() {});
  }

  /// photo_manager's state read, translated onto permission_handler's enum so
  /// the row rendering stays in one vocabulary.
  Future<ph.PermissionStatus> _mediaState() async {
    final s = await pm.PhotoManager.getPermissionState(requestOption: _mediaReq);
    return switch (s) {
      pm.PermissionState.authorized || pm.PermissionState.limited => ph.PermissionStatus.granted,
      pm.PermissionState.restricted => ph.PermissionStatus.restricted,
      _ => ph.PermissionStatus.denied,
    };
  }

  /// image and video, no media location: exactly what the gallery asks for
  static const _mediaReq = pm.PermissionRequestOption(
    androidPermission: pm.AndroidPermission(type: pm.RequestType.common, mediaLocation: false),
  );

  static final _rows = <(ph.Permission, String Function(AppLocalizations), String Function(AppLocalizations), Ic)>[
    (
      ph.Permission.notification,
      (l) => l.onboardPermNotifName,
      (l) => l.onboardPermNotifWhy,
      Ic.bell,
    ),
    (
      ph.Permission.photos,
      (l) => l.onboardPermPhotosName,
      (l) => l.onboardPermPhotosWhy,
      Ic.image,
    ),
  ];

  Future<void> _ask(ph.Permission perm) async {
    if (_asking) return;
    _asking = true;
    final l = context.l;
    try {
      ph.PermissionStatus status;
      if (perm == ph.Permission.photos) {
        // the gallery's own ask: this is the prompt that provably shows on the
        // devices where permission_handler's photos request silently fails
        final s = await pm.PhotoManager.requestPermissionExtend();
        status = switch (s) {
          pm.PermissionState.authorized || pm.PermissionState.limited => ph.PermissionStatus.granted,
          pm.PermissionState.restricted => ph.PermissionStatus.restricted,
          _ => ph.PermissionStatus.denied,
        };
      } else {
        // permission_handler drives the notification row: on Android 13+ its
        // request reliably shows the system dialog, where the local-notifications
        // plugin's own ask could return denied without anything on screen
        status = await askPermission(perm);
      }
      if (!mounted) return;
      setState(() => _states[perm] = status);
      // only a permanent refusal earns the settings detour; a plain denied can
      // simply be asked again, and nagging here read as the app being broken
      if (status == ph.PermissionStatus.permanentlyDenied || status == ph.PermissionStatus.restricted) _suggestSettings(l);
    } finally {
      _asking = false;
    }
  }

  Future<void> _suggestSettings(AppLocalizations l) async {
    final open = await showTgDialog<bool>(
      context,
      title: l.onboardPermTitle,
      content: Text(l.onboardPermDenied, style: TextStyle(color: context.p.msg, fontSize: 15, decoration: TextDecoration.none, height: 1.4)),
      actions: [
        DialogAction(l.actionCancel, null),
        DialogAction(l.attachOpenSettings, true),
      ],
    );
    if (open == true) ph.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      children: [
        TgSection(
          children: [
            for (final (perm, name, why, icon) in _rows)
              _PermRow(
                icon: icon,
                title: name(l),
                subtitle: why(l),
                state: permissionStateLabel(_states[perm] ?? ph.PermissionStatus.denied, l),
                granted: _isGranted(_states[perm]),
                denied: _states[perm] == ph.PermissionStatus.permanentlyDenied,
                onAsk: () => _ask(perm),
              ),
          ],
        ),
      ],
    );
  }

  bool _isGranted(ph.PermissionStatus? s) =>
      s == ph.PermissionStatus.granted || s == ph.PermissionStatus.limited || s == ph.PermissionStatus.provisional;
}

class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.granted,
    required this.denied,
    required this.onAsk,
  });

  final Ic icon;
  final String title;
  final String subtitle;
  final String state;
  final bool granted;
  final bool denied;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: p.accent.withAlpha(28), borderRadius: BorderRadius.circular(10)),
          child: Center(child: TgIcon(icon, color: p.accent, size: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: p.title, fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none, height: 1.3)),
          ]),
        ),
        const SizedBox(width: 10),
        Tap(
          scale: .94,
          onTap: granted ? null : onAsk,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: granted ? p.accent.withAlpha(24) : p.accent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              state,
              style: TextStyle(
                color: granted ? p.accent : (p.dark ? const Color(0xFF0F1A24) : const Color(0xFFFFFFFF)),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
