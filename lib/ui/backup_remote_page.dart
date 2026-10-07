import 'package:flutter/widgets.dart';

import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/backup_remote.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'tg_cells.dart';

/// Settings for the remote backup target.
///
/// The fields live in controllers and are only written back when an action
/// runs, so a half typed URL never becomes the live target half way through a
/// keystroke. "Test connection" runs the same probe the automatic push uses,
/// because "are the credentials right" is the one question this screen exists
/// to answer.
class RemoteBackupPage extends StatefulWidget {
  const RemoteBackupPage({super.key});

  @override
  State<RemoteBackupPage> createState() => _RemoteBackupPageState();
}

class _RemoteBackupPageState extends State<RemoteBackupPage> {
  bool _loaded = false;

  RemoteKind _kind = RemoteKind.webdav;
  bool _enabled = false;
  bool _pathStyle = false;

  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _endpoint = TextEditingController();
  final _region = TextEditingController();
  final _bucket = TextEditingController();
  final _accessKey = TextEditingController();
  final _secretKey = TextEditingController();
  final _prefix = TextEditingController();

  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final cfg = context.store.remoteBackup;
    _kind = cfg.kind;
    _enabled = cfg.enabled;
    _pathStyle = cfg.forcePathStyle;
    _url.text = cfg.url;
    _user.text = cfg.user;
    _pass.text = cfg.pass;
    _endpoint.text = cfg.endpoint;
    _region.text = cfg.region;
    _bucket.text = cfg.bucket;
    _accessKey.text = cfg.accessKey;
    _secretKey.text = cfg.secretKey;
    _prefix.text = cfg.prefix;
  }

  @override
  void dispose() {
    for (final c in [_url, _user, _pass, _endpoint, _region, _bucket, _accessKey, _secretKey, _prefix]) {
      c.dispose();
    }
    super.dispose();
  }

  RemoteConfig _collect() => RemoteConfig(
        kind: _kind,
        enabled: _enabled,
        url: _url.text.trim(),
        user: _user.text.trim(),
        pass: _pass.text,
        endpoint: _endpoint.text.trim(),
        region: _region.text.trim().isEmpty ? 'us-east-1' : _region.text.trim(),
        bucket: _bucket.text.trim(),
        accessKey: _accessKey.text.trim(),
        secretKey: _secretKey.text,
        prefix: _prefix.text.trim(),
        forcePathStyle: _pathStyle,
      );

  Future<void> _save() async {
    await context.store.setRemoteBackup(_collect());
    if (mounted) showBulletin(context, context.l.remoteBackupSaved);
  }

  Future<void> _pickKind() async {
    final l = context.l;
    final r = await showTgDialog<RemoteKind>(
      context,
      title: l.remoteBackupKind,
      message: l.remoteBackupSub,
      actions: [
        DialogAction(l.remoteBackupKindWebdav, RemoteKind.webdav),
        DialogAction(l.remoteBackupKindS3, RemoteKind.s3),
        DialogAction(l.actionCancel, null),
      ],
    );
    if (r == null || !mounted) return;
    setState(() => _kind = r);
  }

  /// Writes the fields, then runs [body]. Keeps the busy flag balanced and says
  /// the right thing when the target is not configured yet.
  Future<void> _run(Future<void> Function() body) async {
    final l = context.l;
    await context.store.setRemoteBackup(_collect());
    if (!context.store.remoteBackup.isConfigured) {
      if (mounted) showBulletin(context, l.remoteBackupNotConfigured);
      return;
    }
    setState(() => _busy = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() => _run(() async {
        final l = context.l;
        final r = await context.store.testRemoteBackup();
        if (!mounted) return;
        showBulletin(context, r.ok ? l.remoteBackupTestOk : '${l.remoteBackupTestFail}: ${r.message}');
      });

  Future<void> _upload() => _run(() async {
        final l = context.l;
        if (!mounted) return;
        try {
          await context.store.backupToRemoteNow();
          if (mounted) showBulletin(context, l.remoteBackupUploaded);
        } catch (e) {
          if (mounted) showBulletin(context, '${l.remoteBackupUploadFail}: $e');
        }
      });

  Future<void> _restore() => _run(() async {
        final l = context.l;
        final List<RemoteEntry> list;
        try {
          list = await context.store.listRemoteBackups();
        } catch (e) {
          if (mounted) showBulletin(context, '${l.remoteBackupTestFail}: $e');
          return;
        }
        if (!mounted) return;
        if (list.isEmpty) {
          showBulletin(context, l.remoteBackupNone);
          return;
        }
        final pick = await showTgDialog<String>(
          context,
          title: l.remoteBackupRestorePick,
          message: l.remoteBackupRestore,
          actions: [
            DialogAction(l.actionCancel, null),
            for (final e in list.take(10)) DialogAction(e.name, e.name),
          ],
        );
        if (pick == null || !mounted) return;
        final overwrite = await showTgDialog<bool>(
          context,
          title: l.humanImportTitle,
          message: l.humanImportFooter,
          actions: [
            DialogAction(l.actionCancel, null),
            DialogAction(l.humanMerge, false),
            DialogAction(l.humanOverwrite, true, danger: true),
          ],
        );
        if (overwrite == null || !mounted) return;
        try {
          final report = await context.store.restoreFromRemote(pick, overwrite: overwrite);
          if (!mounted) return;
          final touched = report.chats + report.messages + report.personas + report.stickers + report.memories + report.settings;
          showBulletin(context, touched == 0 && !report.ai ? l.dataBackupNothing : l.dataBackupRestored(report.chats, report.messages));
        } on FormatException catch (e) {
          if (mounted) showBulletin(context, e.message);
        } catch (_) {
          if (mounted) showBulletin(context, l.humanInvalidFile);
        }
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final kindLabel = _kind == RemoteKind.s3 ? l.remoteBackupKindS3 : l.remoteBackupKindWebdav;
    return TgSettingsPage(
      title: l.remoteBackupTitle,
      builder: (context, _) => ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          TgSection(
            footer: l.remoteBackupSub,
            children: [
              TgTextCell(title: l.remoteBackupKind, value: kindLabel, icon: Ic.storage, onTap: _pickKind),
            ],
          ),
          if (_kind == RemoteKind.webdav)
            TgSection(children: [
              TgEditCell(controller: _url, label: l.remoteBackupUrl, hint: 'https://example.com/remote.php/dav/files/me/paradise'),
              TgEditCell(controller: _user, label: l.remoteBackupUser, hint: l.remoteBackupUser, divider: true),
              TgEditCell(controller: _pass, label: l.remoteBackupPass, hint: l.remoteBackupPass, obscure: true),
            ])
          else
            TgSection(children: [
              TgEditCell(controller: _endpoint, label: l.remoteBackupEndpoint, hint: 'https://s3.us-east-1.amazonaws.com'),
              TgEditCell(controller: _region, label: l.remoteBackupRegion, hint: 'us-east-1', divider: true),
              TgEditCell(controller: _bucket, label: l.remoteBackupBucket, hint: l.remoteBackupBucket, divider: true),
              TgEditCell(controller: _accessKey, label: l.remoteBackupAccessKey, hint: l.remoteBackupAccessKey, divider: true),
              TgEditCell(controller: _secretKey, label: l.remoteBackupSecretKey, hint: l.remoteBackupSecretKey, divider: true, obscure: true),
              TgEditCell(controller: _prefix, label: l.remoteBackupPrefix, hint: 'paradise/'),
            ]),
          TgSection(children: [
            TgCheckCell(title: l.remoteBackupEnable, subtitle: l.remoteBackupSub, value: _enabled, onChanged: (v) => setState(() => _enabled = v), divider: _kind == RemoteKind.s3),
            if (_kind == RemoteKind.s3)
              TgCheckCell(title: l.remoteBackupPathStyle, value: _pathStyle, onChanged: (v) => setState(() => _pathStyle = v)),
          ]),
          TgSection(children: [
            TgActionRow(label: l.actionSave, onTap: _busy ? null : _save, divider: true),
            TgActionRow(label: l.remoteBackupTest, onTap: _busy ? null : _test, divider: true),
            TgActionRow(label: l.remoteBackupUpload, onTap: _busy ? null : _upload, divider: true),
            TgActionRow(label: l.remoteBackupRestore, onTap: _busy ? null : _restore),
          ]),
        ],
      ),
    );
  }
}
