import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_info.dart';
import '../core/overlays.dart';
import '../l10n/x.dart';

const _kSeenVersion = 'whatsNewSeenVersion';

/// Shows the "what's new" dialog once per app version, right after the app
/// first builds. Called from main.dart rather than from a page's initState on
/// purpose: widget tests pump pages directly and would trip over the dialog.
///
/// The seen marker is a SharedPreferences string, so a version bump brings
/// the sheet back and a reinstall resets it. [showWhatsNewDialog] is public
/// so the settings row can replay the same dialog on demand.
void maybeShowWhatsNew(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!context.mounted) return;
    final String seen;
    try {
      final sp = await SharedPreferences.getInstance();
      seen = sp.getString(_kSeenVersion) ?? '';
    } catch (_) {
      // no shared preferences (test env, corrupt store): the dialog is
      // best-effort, never worth crashing or blocking the first frame over
      return;
    }
    if (seen == appVersion) return;
    await showWhatsNewDialog(context);
    try {
      await SharedPreferences.getInstance().then((sp) => sp.setString(_kSeenVersion, appVersion));
    } catch (_) {
      // same best-effort contract as above
    }
  });
}

/// The dialog itself, without the once-per-version gating. The body is a
/// bounded scrollable (not the dialog `message:`) because a long bullet list
/// must not overflow on small screens or at large font scales.
Future<void> showWhatsNewDialog(BuildContext context) async {
  if (!context.mounted) return;
  final l = context.l;
  await showTgDialog<void>(
    context,
    title: l.whatsNewTitle(appVersion),
    content: Builder(
      builder: (c) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .5),
        child: SingleChildScrollView(child: Text(l.whatsNewBody, style: const TextStyle(fontSize: 16, height: 1.25, decoration: TextDecoration.none))),
      ),
    ),
    actions: [DialogAction(l.actionOk, null)],
  );
}
