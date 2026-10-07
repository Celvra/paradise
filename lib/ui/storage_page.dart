import 'package:flutter/widgets.dart';

import '../core/overlays.dart';
import '../data/models.dart';
import '../data/storage_report.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'tg_cells.dart';

/// What the app is using on this device, split by kind, with a way to drop the
/// cache.
///
/// The sizes are read once when the page opens and again after a clear, so the
/// list a user is looking at always matches the device. Attachment bytes are
/// counted where the files sit (under media), while each assistant row counts
/// only its own text, so the two never describe the same bytes twice.
class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  StorageReport? _report;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_report == null) _load();
  }

  Future<void> _load() async {
    final r = await buildStorageReport(context.store);
    if (mounted) setState(() => _report = r);
  }

  static String _label(StorageKind k, AppLocalizations l) => switch (k) {
        StorageKind.chat => l.storageChats,
        StorageKind.media => l.storageMedia,
        StorageKind.stickers => l.storageStickers,
        StorageKind.wallpaper => l.storageWallpaper,
        StorageKind.backup => l.storageBackups,
        StorageKind.workspace => l.storageWorkspace,
        StorageKind.database => l.storageDatabase,
        StorageKind.cache => l.storageCache,
        StorageKind.other => l.storageOther,
      };

  static String _percent(int part, int whole) => whole <= 0 ? '0%' : '${(part * 100 / whole).round()}%';

  Future<void> _clear() async {
    final l = context.l;
    final ok = await showTgDialog<bool>(
      context,
      title: l.storageClearTitle,
      message: l.storageClearMessage,
      actions: [
        DialogAction(l.actionCancel, false),
        DialogAction(l.actionClear, true, danger: true),
      ],
    );
    if (ok != true || !mounted) return;
    await clearCache();
    await _load();
    if (mounted) showBulletin(context, l.storageClearDone);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final r = _report;
    return TgSettingsPage(
      title: l.storageTitle,
      builder: (context, _) => ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
        physics: const ClampingScrollPhysics(),
        children: r == null
            ? [
                TgSection(header: l.storageUsage, children: [
                  TgTextCell(title: l.storageTotal, value: '…'),
                ]),
              ]
            : _body(context, r),
      ),
    );
  }

  List<Widget> _body(BuildContext context, StorageReport r) {
    final l = context.l;
    // The chat aggregate first, then every group that holds something. The total
    // is their sum, so the percentages under each row add up to the whole.
    final rows = <(String, int)>[
      (l.storageChats, r.bytesOf(StorageKind.chat)),
      for (final e in r.groups) (_label(e.kind, l), e.bytes),
    ];
    return [
      TgSection(
        header: l.storageUsage,
        children: [
          TgTextCell(title: l.storageTotal, value: fileSize(r.total), divider: true),
          for (var i = 0; i < rows.length; i++)
            TgTextCell(
              title: rows[i].$1,
              subtitle: _percent(rows[i].$2, r.total),
              value: fileSize(rows[i].$2),
              divider: i != rows.length - 1,
            ),
        ],
      ),
      if (r.chats.isNotEmpty)
        TgSection(
          header: l.storagePerAgent,
          children: [
            for (var i = 0; i < r.chats.length; i++)
              TgTextCell(
                title: r.chats[i].name.isEmpty ? l.storageChats : r.chats[i].name,
                value: fileSize(r.chats[i].bytes),
                divider: i != r.chats.length - 1,
              ),
          ],
        ),
      TgSection(
        header: l.storageCache,
        children: [
          TgActionRow(label: l.storageClear, danger: true, onTap: _clear),
          TgInfoCell(l.storageClearMessage, center: false),
        ],
      ),
    ];
  }
}
