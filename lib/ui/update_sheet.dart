import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart' show appVersion;
import 'bubble.dart' show mdBlocks;
import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/app_update.dart';
import '../data/store.dart';
import '../l10n/x.dart';

/// Set once the automatic check has fired, so it nags at most once per run.
/// A manual check from settings always goes through.
bool _autoFired = false;

/// Fetches the latest GitHub release and raises the update sheet when it is
/// newer than the running build.
///
/// Silent unless [manual]: a failed fetch or an up to date build only says
/// so when the user asked from settings. A skipped tag only suppresses the
/// automatic prompt, a manual check still shows it.
Future<void> checkAndShowUpdate(BuildContext context, {bool manual = false}) async {
  if (!manual) {
    if (_autoFired) return;
    _autoFired = true;
  }
  final store = Store.read(context);
  final rel = await fetchLatestRelease();
  if (!context.mounted) return;
  final l = context.l;
  if (rel == null) {
    if (manual) showBulletin(context, l.updateCheckFailed);
    return;
  }
  if (!isNewerVersion(appVersion, rel.tag)) {
    if (manual) showBulletin(context, l.updateUpToDate);
    return;
  }
  if (!manual && store.isUpdateSkipped(rel.tag)) return;
  if (!context.mounted) return;
  // lives outside the sheet state so a drag dismiss keeps the choice too
  final skipBox = [false];
  await showTgSheet<void>(context, (_) => _UpdateSheet(release: rel, skipBox: skipBox));
  if (skipBox[0]) store.setSkippedRelease(rel.tag);
}

/// Bottom sheet with the release notes, a download button, a close button and
/// a "skip this version" checkbox.
class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet({required this.release, required this.skipBox});
  final AppRelease release;
  final List<bool> skipBox;

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  bool _skip = false;

  void _toggleSkip() {
    setState(() => _skip = !_skip);
    widget.skipBox[0] = _skip;
  }

  Future<bool> _launch(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _download() async {
    final ok = await _launch(widget.release.htmlUrl);
    if (!mounted) return;
    if (!ok) {
      showBulletin(context, L10n.current.aboutLinkFailed);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _openLink(String url) async {
    final ok = await _launch(url);
    if (!mounted) return;
    if (!ok) showBulletin(context, L10n.current.aboutLinkFailed);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final mq = MediaQuery.of(context);
    final rel = widget.release;
    final notes = rel.body.trim().isEmpty ? l.updateNoNotes : rel.body.trim();
    return TgSheet(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(children: [
            Expanded(child: Text(l.updateTitle, style: TextStyle(color: p.title, fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: p.accent.withAlpha(28), borderRadius: BorderRadius.circular(12)),
              child: Text(rel.tag, style: TextStyle(color: p.accent, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Text(l.updateSubtitle(appVersion, rel.tag), style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Container(
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.34),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12)),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: mdBlocks(
                  context,
                  notes,
                  TextStyle(color: p.title, fontSize: 14.5, height: 1.55, decoration: TextDecoration.none, fontWeight: FontWeight.w400),
                  p.codeIn,
                  p.accent,
                  0,
                  onWebLink: _openLink,
                ),
              ),
            ),
          ),
        ),
        Tap(
          onTap: _toggleSkip,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _skip ? p.accent : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _skip ? p.accent : p.divider, width: 1.2),
                ),
                child: _skip ? Center(child: TgIcon(Ic.check, color: const Color(0xFFFFFFFF), size: 14, stroke: 2.4)) : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(l.updateSkipVersion, style: TextStyle(color: p.subtitle, fontSize: 14, decoration: TextDecoration.none, fontWeight: FontWeight.w400))),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: TgButton(label: l.updateDownload, onTap: _download),
        ),
        Center(
          child: Tap(
            scale: .96,
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Text(l.updateClose, style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ]),
    );
  }
}
