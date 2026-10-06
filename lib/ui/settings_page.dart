import 'dart:async' show unawaited;
import 'dart:convert' show utf8;
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../app_info.dart' show appVersion;
import '../data/models.dart';
import '../data/speech_config.dart';
import '../data/ai/provider_model.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'bubble.dart';
import 'account_page.dart';
import 'update_sheet.dart';
import 'wallpaper.dart';
import 'wallpaper_page.dart';
import 'workspace/workspace_pages.dart';
import 'skills_page.dart';
import 'ai_model_picker.dart';
import 'ai_reply_page.dart';
import 'ai_settings_page.dart';
import 'speech_page.dart';
import 'human_pages.dart';

// IconBackgroundColors pairs top and bottom
const _blue = [Color(0xFF1CA5ED), Color(0xFF1488E1)];
const _orange = [Color(0xFFF09F1B), Color(0xFFE18A11)];
const _green = [Color(0xFF55CA47), Color(0xFF27B434)];
const _red = [Color(0xFFF45255), Color(0xFFDF3955)];
const _blueDeep = [Color(0xFF4F85F6), Color(0xFF3568E8)];
const _purple = [Color(0xFFC46EF4), Color(0xFF9F55DF)];
const _cyan = [Color(0xFF32C0CE), Color(0xFF1D9CC6)];
const _teal = [Color(0xFF34B3A0), Color(0xFF1E9184)];
const _gray = [Color(0xFF8699AA), Color(0xFF6E8397)];

// settings tab like SettingsActivity big avatar then gradient icon rows
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  void _open(BuildContext c, String title, List<Widget> Function(BuildContext) kids) {
    Navigator.of(c).push(TgRoute(builder: (_) => _SubPage(title: title, body: kids)));
  }

  void _openAi(BuildContext c) {
    Navigator.of(c).push(TgRoute(builder: (_) => const AiSettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final st = context.store;
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    return ColoredBox(
      color: p.gray,
      child: Stack(children: [
        Positioned.fill(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(top: top + 56 + 12, bottom: mq.padding.bottom + 56 + 8 + 24),
            children: [
              // the profile already has its own tab, so nothing here repeats it
              _Group(children: [
                _Cell(icon: Ic.user, colors: _blue, title: l.settingsAccount, sub: l.settingsAccountSub, onTap: () => openAccount(context)),
                _Cell(
                  icon: Ic.ai,
                  colors: _purple,
                  title: l.settingsAi,
                  sub: AiScope.of(context).ready ? aiProviderSummary(AiScope.of(context), l) : l.settingsAiSubNone,
                  onTap: () => _openAi(context),
                ),
                _Cell(icon: Ic.smile, colors: _cyan, title: l.humanTitle, sub: l.humanSubtitle, onTap: () => openHumanSettings(context)),
                _Cell(icon: Ic.chats, colors: _teal, title: l.aiReplyTitle, sub: aiReplySummary(st), onTap: () => openAiReplySettings(context)),
                _Cell(icon: Ic.unmute, colors: _cyan, title: l.speechTitle, sub: speechSummary(context, l), onTap: () => openSpeechSettings(context)),
                _Cell(icon: Ic.folder, colors: _gray, title: l.wsTitle, sub: st.workspace.all.isEmpty ? l.wsSub : wsSettingsSummary(st), onTap: () => openWorkspaceSettings(context)),
                ListenableBuilder(
                  listenable: st.skills,
                  builder: (_, __) => _Cell(icon: Ic.fileCode, colors: _purple, title: l.skillTitle, sub: skillSettingsSummary(st, l), onTap: () => openSkillsSettings(context)),
                ),
                _Cell(icon: Ic.palette, colors: _orange, title: l.settingsAppearance, sub: l.settingsAppearanceSub, onTap: () => _open(context, l.settingsAppearance, _appearance)),
                _Cell(icon: Ic.bell, colors: _red, title: l.settingsNotifications, sub: st.haptics ? l.settingsVibrationOn : l.settingsVibrationOff, onTap: () => _open(context, l.settingsNotifications, _notifications)),
                _Cell(icon: Ic.globe, colors: _green, title: l.settingsLanguage, sub: languageLabel(st.localeTag, l), onTap: () => _openLanguage(context)),
                _Cell(icon: Ic.storage, colors: _blueDeep, title: l.settingsData, sub: l.settingsDataSub(st.chats.length, fileSize(st.attachBytes)), last: true, onTap: () => _open(context, l.settingsData, _data)),
              ]),
              const SizedBox(height: 12),
              _Group(children: [
                _Cell(
                  icon: Ic.download,
                  colors: _green,
                  title: l.updateCheckTitle,
                  sub: l.updateCheckSub(appVersion),
                  onTap: () => checkAndShowUpdate(context, manual: true),
                ),
                _Cell(
                  icon: Ic.info,
                  colors: _gray,
                  title: l.settingsAbout,
                  sub: l.settingsAboutSub,
                  last: true,
                  onTap: () => showTgDialog<void>(
                    context,
                    title: l.settingsAboutSub,
                    content: _AboutBody(sections: [
                      l.settingsAboutLicense,
                      l.settingsAboutRepo,
                      l.settingsAboutThanks,
                      l.settingsAboutQqGroup + ' ' + l.settingsAboutQqGroupUrl,
                      l.settingsAboutCommunity + ' ' + l.settingsAboutCommunityUrl,
                      l.settingsAboutDeps,
                    ]),
                    actions: [DialogAction(l.actionOk, null)],
                  ),
                ),
              ]),
              Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Center(child: Text(l.settingsFooter, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none, fontWeight: FontWeight.w400)))),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            color: p.bar,
            padding: EdgeInsets.only(top: top),
            child: SizedBox(
              height: 56,
              child: Row(children: [
                const SizedBox(width: 20),
                Expanded(child: Text(l.settingsTitle, style: TextStyle(color: p.title, fontSize: 22, fontWeight: FontWeight.w600, decoration: TextDecoration.none))),
                const SizedBox(width: 20),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _appearance(BuildContext context) {
    final st = context.store;
    final l = context.l;
    final p = context.p;
    return [
      _Head(l.appearanceTheme),
      _Group(children: [
        _Cell(icon: Ic.moon, colors: _cyan, title: l.appearanceNightMode, last: true, trailing: TgSwitch(value: st.dark, onChanged: st.setDark), onTap: () => st.setDark(!st.dark)),
      ]),
      _Head(l.appearancePreview),
      const _Preview(),
      _Head(l.wallpaperHeader),
      _Group(children: [
        _Cell(
          icon: Ic.image,
          colors: _blue,
          title: l.wallpaperRow,
          sub: st.wallpaperPath.isEmpty ? l.wallpaperNone : wallpaperFileName(st.wallpaperPath),
          onTap: () => openWallpaperSheet(context),
        ),
        // the blur switch only means something once there is a picture behind
        // it, and an always-on row that does nothing is worse than a hidden one
        if (st.wallpaperPath.isNotEmpty)
          _Cell(
            icon: Ic.image,
            colors: _gray,
            title: l.wallpaperBlur,
            sub: l.wallpaperBlurSub,
            trailing: TgSwitch(value: st.wallpaperBlur, onChanged: st.setWallpaperBlur),
            last: true,
            onTap: () => st.setWallpaperBlur(!st.wallpaperBlur),
          )
        else
          const SizedBox.shrink(),
      ]),
      if (st.wallpaperPath.isNotEmpty) ...[
        _Head(l.wallpaperColorHeader),
        _Group(children: [
          WallpaperSwatches(path: st.wallpaperPath),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(l.wallpaperColorFooter, style: TextStyle(color: p.subtitle, fontSize: 13, height: 1.35, decoration: TextDecoration.none)),
          ),
          // Only once a seed has recoloured the bubble does it gradient at all,
          // so putting this above the swatches would offer a control that cannot
          // do anything yet.
          if (st.wallpaperColor != null) ...[
            Container(height: .5, color: p.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.wallpaperBubbleGrad, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none)),
                const SizedBox(height: 10),
                TgSegmented(
                  labels: [l.wallpaperBubbleGradSubtle, l.wallpaperBubbleGradMedium, l.wallpaperBubbleGradStrong],
                  index: st.wallpaperBubbleGrad,
                  onChanged: st.setWallpaperBubbleGrad,
                ),
                const SizedBox(height: 10),
                Text(l.wallpaperBubbleGradSub, style: TextStyle(color: p.subtitle, fontSize: 13, height: 1.35, decoration: TextDecoration.none)),
              ]),
            ),
          ],
        ]),
      ],
      _Head(l.appearanceTextSize),
      _Group(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Row(children: [Expanded(child: Text(l.appearanceSize, style: TextStyle(color: context.p.title, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400))), Text(L10n.number('#,##0').format(st.textSize.round()), style: TextStyle(color: context.p.accent, fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.none))])),
        Padding(padding: const EdgeInsets.fromLTRB(2, 0, 2, 6), child: TgSlider(value: st.textSize, min: 12, max: 30, onChanged: st.setTextSize)),
      ]),
      _Head(l.appearanceCorners),
      _Group(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Row(children: [Expanded(child: Text(l.appearanceRadius, style: TextStyle(color: context.p.title, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400))), Text(L10n.number('#,##0').format(st.bubbleRadius.round()), style: TextStyle(color: context.p.accent, fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.none))])),
        Padding(padding: const EdgeInsets.fromLTRB(2, 0, 2, 6), child: TgSlider(value: st.bubbleRadius, min: 0, max: 17, onChanged: st.setRadius)),
      ]),
      const SizedBox(height: 12),
      _Group(children: [
        _Cell(
          icon: Ic.regen,
          colors: _gray,
          title: l.appearanceReset,
          last: true,
          onTap: () {
            st.setTextSize(16);
            st.setRadius(17);
          },
        ),
      ]),
    ];
  }

  List<Widget> _notifications(BuildContext context) {
    final st = context.store;
    final l = context.l;
    return [
      _Head(l.notifAlerts),
      _Group(children: [
        _Cell(icon: Ic.bell, colors: _red, title: l.notifVibrate, sub: l.notifVibrateSub, trailing: TgSwitch(value: st.haptics, onChanged: st.setHaptics), onTap: () => st.setHaptics(!st.haptics)),
        _Cell(icon: Ic.mute, colors: _orange, title: l.notifCountMuted, sub: l.notifCountMutedSub, last: true, trailing: TgSwitch(value: st.countMuted, onChanged: st.setCountMuted), onTap: () => st.setCountMuted(!st.countMuted)),
      ]),
      Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child: Text(l.notifFooter, style: TextStyle(color: context.p.subtitle, fontSize: 13, height: 1.3, decoration: TextDecoration.none, fontWeight: FontWeight.w400))),
    ];
  }

  List<Widget> _data(BuildContext context) {
    final st = context.store;
    final l = context.l;
    final msgs = st.chats.fold<int>(0, (a, c) => a + c.msgs.length);
    final media = st.chats.fold<int>(0, (a, c) => a + c.msgs.where((m) => m.kind == MsgKind.photo || m.kind == MsgKind.file || m.kind == MsgKind.music).length);
    Future<void> ask(String title, String msg, String action, VoidCallback run) async {
      final r = await showTgDialog<bool>(context, title: title, message: msg, actions: [DialogAction(l.actionCancel, false), DialogAction(action, true, danger: true)]);
      if (r == true) run();
    }

    return [
      _Head(l.dataUsage),
      _Group(children: [
        _Cell(icon: Ic.chats, colors: _blue, title: l.dataChats, value: L10n.number('#,##0').format(st.chats.length), noTap: true),
        _Cell(icon: Ic.send, colors: _green, title: l.dataMessages, value: L10n.number('#,##0').format(msgs), noTap: true),
        _Cell(icon: Ic.image, colors: _orange, title: l.dataMedia, value: '${L10n.number('#,##0').format(media)} · ${fileSize(st.attachBytes)}', noTap: true, last: true),
      ]),
      _Head(l.dataClear),
      _Group(children: [
        _Cell(icon: Ic.search, colors: _gray, title: l.dataClearSearch, last: false, onTap: st.clearRecentSearch),
        _Cell(icon: Ic.file, colors: _orange, title: l.dataClearMedia, onTap: () => ask(l.dataClearMediaTitle, l.dataClearMediaMessage, l.actionClear, st.clearMedia)),
        _Cell(icon: Ic.trash, colors: _red, title: l.dataClearAll, last: true, danger: true, onTap: () => ask(l.dataClearAllTitle, l.dataClearAllMessage, l.actionClear, st.clearAll)),
      ]),
      _Head(l.dataBackup),
      _Group(children: [
        _Cell(icon: Ic.share, colors: _blue, title: l.humanExport, sub: l.dataBackupExportSub, onTap: () => _exportBackup(context)),
        _Cell(icon: Ic.file, colors: _green, title: l.humanImportFile, sub: l.dataBackupImportSub, last: true, onTap: () => _importBackup(context)),
      ]),
    ];
  }

  /// Hands the whole account to the system save dialog.
  ///
  /// Not the app's own exports directory: that is private storage, so a backup
  /// written there is a file the user cannot reach, cannot attach to a message
  /// and cannot put in a cloud drive. The save dialog puts it wherever they
  /// choose, which is the only place a backup is actually a backup.
  ///
  /// The clipboard is only the fallback for when that dialog cannot be used at
  /// all. It is not the primary route: a large history will not fit in a
  /// clipboard, and the string has to be in memory twice to get there.
  Future<void> _exportBackup(BuildContext context) async {
    final st = context.store;
    final l = context.l;
    String json;
    try {
      json = st.exportBackupString();
    } catch (_) {
      if (context.mounted) showBulletin(context, l.dataBackupSaveFailed);
      return;
    }

    try {
      final saved = await FilePicker.saveFile(
        fileName: 'paradise-${_stamp()}.json',
        bytes: utf8.encode(json),
        mimeType: 'application/json',
        allowedExtensions: const ['json'],
        dialogTitle: l.humanExport,
      );
      // null means the user backed out of the dialog, which is not a failure
      if (saved == null) return;
      if (context.mounted) showBulletin(context, l.dataBackupSaved);
    } catch (_) {
      try {
        unawaited(Clipboard.setData(ClipboardData(text: json)));
        if (context.mounted) showBulletin(context, l.humanCopiedClipboard);
      } catch (_) {
        if (context.mounted) showBulletin(context, l.dataBackupSaveFailed);
      }
    }
  }

  /// A filename a human can sort by, instead of a millisecond count.
  static String _stamp() {
    String p(int v) => v.toString().padLeft(2, '0');
    final n = DateTime.now();
    return '${n.year}${p(n.month)}${p(n.day)}-${p(n.hour)}${p(n.minute)}';
  }

  Future<void> _importBackup(BuildContext context) async {
    final st = context.store;
    final l = context.l;
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    final path = picked.firstOrNull?.path;
    if (path == null || !context.mounted) return;

    // asked before anything is read, because merge and replace are not
    // recoverable once they have run
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
    if (overwrite == null || !context.mounted) return;

    try {
      final report = st.importBackupString(await File(path).readAsString(), overwrite: overwrite);
      if (!context.mounted) return;
      // a file that parsed but held nothing this build can use is its own case,
      // distinct from a failure and from a restore that did something
      final touched = report.chats + report.messages + report.personas + report.stickers + report.memories + report.settings;
      showBulletin(context, touched == 0 && !report.ai ? l.dataBackupNothing : l.dataBackupRestored(report.chats, report.messages));
    } on FormatException catch (e) {
      // the message says which file or which version, which is the useful part
      if (context.mounted) showBulletin(context, e.message);
    } catch (_) {
      if (context.mounted) showBulletin(context, l.humanInvalidFile);
    }
  }

  // language picker, the same mark on every card but the globe reads as settings
  void _openLanguage(BuildContext context) {
    final st = context.store;
    showTgSheet<void>(context, (_) => _LanguageSheet(current: st.localeTag));
  }
}

/// Every entry names itself in its own language, so the list is readable
/// whichever one the reader already knows.
/// One line for the voice row: which engine is live, and whether the
/// endpoint it needs has been filled in.
String speechSummary(BuildContext context, AppLocalizations l) {
  final cfg = SpeechScope.of(context);
  if (cfg.engine == TtsEngine.system) return l.speechSummarySystem;
  if (!cfg.apiReady) return l.speechNotReady;
  return '${l.speechEngineApi} · ${cfg.model} · ${cfg.voice}';
}

String languageLabel(String? tag, AppLocalizations l) => switch (tag) {
      'en' => l.languageEnglish,
      'zh' => l.languageChineseSimplified,
      'zh_Hant' => l.languageChineseTraditional,
      _ => l.settingsLanguageSystem,
    };

const _languageTags = <String?>[null, 'en', 'zh', 'zh_Hant'];

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.current});
  final String? current;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    return TgSheet(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Text(l.settingsLanguage, style: TextStyle(color: p.title, fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
        ),
        for (final tag in _languageTags)
          Tap(
            scale: .99,
            onTap: () {
              context.store.setLocale(tag);
              Navigator.of(context).pop();
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: current == tag ? p.accent.withAlpha(28) : p.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: current == tag ? p.accent : const Color(0x00000000), width: .6)),
              child: Row(children: [
                Expanded(child: Text(languageLabel(tag, l), style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none))),
                if (current == tag) TgIcon(Ic.check, color: p.accent, size: 20, stroke: 2.2),
              ]),
            ),
          ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// pushed settings sub page with a flat bar and back arrow
class _SubPage extends StatelessWidget {
  const _SubPage({required this.title, required this.body});
  final String title;
  final List<Widget> Function(BuildContext) body;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    context.store;
    return SwipeBack(
      child: ColoredBox(
        color: p.gray,
        child: Column(children: [
          Container(
            color: p.bar,
            padding: EdgeInsets.only(top: mq.padding.top),
            height: mq.padding.top + 56,
            child: Row(children: [
              Tap(scale: .88, onTap: () => Navigator.of(context).maybePop(), child: SizedBox(width: 56, height: 56, child: Center(child: TgIcon(Ic.back, color: p.icon, size: 24)))),
              Text(title, style: TextStyle(color: p.title, fontSize: 20, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
            ]),
          ),
          Expanded(child: ListView(padding: EdgeInsets.only(bottom: mq.padding.bottom + 24), physics: const ClampingScrollPhysics(), children: body(context))),
        ]),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(text, style: TextStyle(color: context.p.accent, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(color: context.p.bg, child: Column(children: children));
}

// SettingCell gradient square icon title and optional two line subtitle
class _Cell extends StatelessWidget {
  const _Cell({required this.icon, this.colors = _blue, required this.title, this.sub, this.value, this.trailing, this.onTap, this.last = false, this.danger = false, this.noTap = false});
  final Ic icon;
  final List<Color> colors;
  final String title;
  final String? sub;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;
  final bool danger;
  final bool noTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final row = SizedBox(
      height: sub == null ? 52 : 60,
      child: Row(children: [
        const SizedBox(width: 16),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: p.iconTile(colors))),
          child: Center(child: TgIcon(icon, color: const Color(0xFFFFFFFF), size: 19, stroke: 1.7)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.divider, width: .5))),
            child: Row(children: [
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: danger ? p.danger : p.title, fontSize: 16, height: 1.2, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                  if (sub != null) Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 13, height: 1.3, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                ]),
              ),
              if (value != null) Text(value!, style: TextStyle(color: p.subtitle, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
              if (trailing != null) trailing!,
              const SizedBox(width: 16),
            ]),
          ),
        ),
      ]),
    );
    if (noTap) return row;
    return Tap(highlight: true, onTap: onTap, child: row);
  }
}

// live preview of text size and corner radius on the chat wallpaper
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final now = DateTime.now().millisecondsSinceEpoch;
    final l = context.l;
    final st = context.store;
    final a = Msg(id: 'pa', out: false, text: l.previewSampleIncoming, time: now, read: true);
    final b = Msg(id: 'pb', out: true, text: l.previewSampleOutgoing, time: now, read: true);
    // bubbles sit inside one unconstrained column that gets scaled down as a whole,
    // so the outgoing one still lands hard against the right edge of the frame
    return SizedBox(
      height: 172,
      child: LayoutBuilder(builder: (context, box) {
        return Stack(fit: StackFit.expand, children: [
          // the preview has to show the wallpaper too, otherwise setting one
          // means picking blind and only seeing the result after backing out
          ChatWallpaper(path: st.wallpaperPath, blur: st.wallpaperBlur, colors: p.wall, accent: p.accent, phase: 0),
          ClipRect(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: box.maxWidth - 8,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Align(alignment: Alignment.centerLeft, child: BubbleView(msg: a, tail: true, topNear: false, maxWidth: box.maxWidth - 8)),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerRight, child: BubbleView(msg: b, tail: true, topNear: false, maxWidth: box.maxWidth - 8)),
                  ]),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

/// One line under the workspace settings row: how many there are and whether
/// the tools are on, so the row says something before it is opened.
String wsSettingsSummary(Store st) {
  final ws = st.workspace;
  final n = ws.all.length;
  return '${wsTitles(n)} · ${ws.toolsEnabled ? L10n.current.wsToolsOn : L10n.current.wsToolsOff}';
}

/// One line under the skills row: how many are installed, or the empty hint.
String skillSettingsSummary(Store st, AppLocalizations l) {
  final n = st.skills.skills.length;
  return n == 0 ? l.skillSubEmpty : l.skillSubCount(n);
}

String wsTitles(int n) => L10n.number('#,##0').format(n);

/// Body of the about dialog: the licence notice, then the repository link, the
/// projects this one was modelled on and the direct dependencies with their
/// licence.
///
/// Every URL in those blocks is tinted so it reads as a link, and each one
/// taps its own address.
class _AboutBody extends StatelessWidget {
  const _AboutBody({required this.sections});

  /// Each block carries its own label, so this stays dumb.
  final List<String> sections;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ConstrainedBox(
      // the dialog is a Column of mainAxisSize.min, a body this long needs a
      // ceiling or it runs off the top and bottom of the screen
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.62),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        children: [
          for (final s in sections) ...[
            _Block(text: s),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

/// One paragraph with the urls inside it tinted. Each url gets its own tap
/// target, so a block holding two addresses (like the thanks block with
/// Kelivo and SillyTavern) opens the one actually tapped.
class _Block extends StatefulWidget {
  const _Block({required this.text});

  final String text;

  static final _url = RegExp(r'https?://[^\s,;)\]]+');

  @override
  State<_Block> createState() => _BlockState();
}

class _BlockState extends State<_Block> {
  final _recs = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recs) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recs) {
      r.dispose();
    }
    _recs.clear();
    final p = context.p;
    final base = TextStyle(color: p.title, fontSize: 14.5, height: 1.55, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
    final spans = <TextSpan>[];
    var at = 0;
    for (final m in _Block._url.allMatches(widget.text)) {
      if (m.start > at) spans.add(TextSpan(text: widget.text.substring(at, m.start)));
      final url = m.group(0)!;
      final rec = TapGestureRecognizer()..onTap = () => _open(context, url);
      _recs.add(rec);
      spans.add(TextSpan(text: url, style: base.copyWith(color: p.accent, fontWeight: FontWeight.w500), recognizer: rec));
      at = m.end;
    }
    if (at < widget.text.length) spans.add(TextSpan(text: widget.text.substring(at)));
    if (spans.isEmpty) spans.add(TextSpan(text: widget.text));

    return Text.rich(TextSpan(children: spans), style: base);
  }

  Future<void> _open(BuildContext context, String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) showBulletin(context, L10n.current.aboutLinkFailed);
  }
}
