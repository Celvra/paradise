import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'bubble.dart';
import 'account_page.dart';
import 'wallpaper.dart';
import 'ai_model_picker.dart';
import 'ai_reply_page.dart';
import 'ai_settings_page.dart';
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
                _Cell(icon: Ic.palette, colors: _orange, title: l.settingsAppearance, sub: l.settingsAppearanceSub, onTap: () => _open(context, l.settingsAppearance, _appearance)),
                _Cell(icon: Ic.bell, colors: _red, title: l.settingsNotifications, sub: st.haptics ? l.settingsVibrationOn : l.settingsVibrationOff, onTap: () => _open(context, l.settingsNotifications, _notifications)),
                _Cell(icon: Ic.globe, colors: _green, title: l.settingsLanguage, sub: languageLabel(st.localeTag, l), onTap: () => _openLanguage(context)),
                _Cell(icon: Ic.storage, colors: _blueDeep, title: l.settingsData, sub: l.settingsDataSub(st.chats.length, fileSize(st.attachBytes)), last: true, onTap: () => _open(context, l.settingsData, _data)),
              ]),
              const SizedBox(height: 12),
              _Group(children: [
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
    return [
      _Head(l.appearanceTheme),
      _Group(children: [
        _Cell(icon: Ic.moon, colors: _cyan, title: l.appearanceNightMode, last: true, trailing: TgSwitch(value: st.dark, onChanged: st.setDark), onTap: () => st.setDark(!st.dark)),
      ]),
      _Head(l.appearancePreview),
      const _Preview(),
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
    ];
  }

  // language picker, the same mark on every card but the globe reads as settings
  void _openLanguage(BuildContext context) {
    final st = context.store;
    showTgSheet<void>(context, (_) => _LanguageSheet(current: st.localeTag));
  }
}

/// Every entry names itself in its own language, so the list is readable
/// whichever one the reader already knows.
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors)),
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
    final a = Msg(id: 'pa', out: false, text: l.previewSampleIncoming, time: now, read: true);
    final b = Msg(id: 'pb', out: true, text: l.previewSampleOutgoing, time: now, read: true);
    // bubbles sit inside one unconstrained column that gets scaled down as a whole,
// so the outgoing one still lands hard against the right edge of the frame
return SizedBox(
      height: 172,
      child: LayoutBuilder(builder: (context, box) {
        return Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: WallPainter(colors: p.wall, phase: 0)),
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

/// Body of the about dialog: the licence notice, then the repository link, the
/// projects this one was modelled on and the direct dependencies with their
/// licence.
///
/// Every URL in those blocks is tinted so it reads as a link. Tapping a block
/// opens the first url in it, which is what the eye expects from a list where
/// every entry ends in an address, and it avoids a recognizer per span.
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

/// One paragraph with the urls inside it tinted.
class _Block extends StatelessWidget {
  const _Block({required this.text});

  final String text;

  static final _url = RegExp(r'https?://[^\s,;)\]]+');

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final base = TextStyle(color: p.title, fontSize: 14.5, height: 1.55, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
    final spans = <TextSpan>[];
    var at = 0;
    for (final m in _url.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      spans.add(TextSpan(text: m.group(0), style: base.copyWith(color: p.accent, fontWeight: FontWeight.w500)));
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    if (spans.isEmpty) spans.add(TextSpan(text: text));

    final urls = _url.allMatches(text).map((e) => e.group(0)!).toList();
    return GestureDetector(
      onTap: urls.isEmpty ? null : () => _open(context, urls.first),
      child: Text.rich(TextSpan(children: spans), style: base),
    );
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
