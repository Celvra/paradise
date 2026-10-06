import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'dialogs_page.dart';

/// The strip labels, in the order [SearchPageState._filter] indexes them.
List<String> searchFilters(AppLocalizations l) => [l.searchFilterAll, l.tabChats, l.dataMessages, l.profileTabMedia, l.profileTabLinks, l.profileTabFiles];

// text with every hit painted
Widget hlText(String text, String q, TextStyle style, Color bg, {int maxLines = 1}) {
  final t = q.trim().toLowerCase();
  if (t.isEmpty) return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style);
  final low = text.toLowerCase();
  final spans = <TextSpan>[];
  var at = 0;
  // keep the first hit in view for long previews
  var start = 0;
  final first = low.indexOf(t);
  if (first > 24) start = first - 24;
  final body = start > 0 ? '…${text.substring(start)}' : text;
  final lowBody = body.toLowerCase();
  while (true) {
    final i = lowBody.indexOf(t, at);
    if (i < 0) break;
    if (i > at) spans.add(TextSpan(text: body.substring(at, i)));
    spans.add(TextSpan(text: body.substring(i, i + t.length), style: TextStyle(color: style.color, fontWeight: FontWeight.w600, backgroundColor: bg)));
    at = i + t.length;
  }
  if (at < body.length) spans.add(TextSpan(text: body.substring(at)));
  return Text.rich(TextSpan(style: style, children: spans), maxLines: maxLines, overflow: TextOverflow.ellipsis);
}

// global search chats messages media links files
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open(Chat c, {Msg? m}) {
    Store.read(context).addRecentSearch(_ctl.text);
    openChat(context, c, jumpTo: m?.id, query: _ctl.text.trim());
  }

  bool _match(Msg m) {
    switch (_filter) {
      case 3:
        return m.kind == MsgKind.photo || m.kind == MsgKind.video;
      case 4:
        return m.hasLink;
      case 5:
        return m.kind == MsgKind.file || m.kind == MsgKind.music;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final st = context.store;
    final mq = MediaQuery.of(context);
    final q = _ctl.text.trim();
    final labels = searchFilters(l);
    return SwipeBack(
      child: ColoredBox(
        color: p.bg,
        child: Column(children: [
          Container(
            color: p.bar,
            padding: EdgeInsets.only(top: mq.padding.top),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 56,
                child: Row(children: [
                  Tap(scale: .88, onTap: () => Navigator.of(context).maybePop(), child: SizedBox(width: 52, height: 56, child: Center(child: TgIcon(Ic.back, color: p.icon, size: 24)))),
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.only(left: 14),
                      decoration: BoxDecoration(color: p.title.withAlpha(p.dark ? 18 : 13), borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        Expanded(child: TgEdit(controller: _ctl, focusNode: _focus, hint: l.chatsSearchHint, style: TextStyle(color: p.title, fontSize: 15), onSubmitted: (v) => st.addRecentSearch(v))),
                        // clear button scales in with the quint curve
                        TweenAnimationBuilder<double>(
                          tween: Tween(end: q.isEmpty ? 0.0 : 1.0),
                          duration: const Duration(milliseconds: 380),
                          curve: TgCurves.easeOutQuint,
                          builder: (_, t, __) => IgnorePointer(
                            ignoring: t < .5,
                            child: Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.scale(scale: .5 + .5 * t, child: Tap(scale: .85, onTap: _ctl.clear, child: SizedBox(width: 40, height: 40, child: Center(child: TgIcon(Ic.close, color: p.hint, size: 18)))))),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                ]),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  itemCount: labels.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Tap(
                    scale: .95,
                    onTap: () => setState(() => _filter = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: TgCurves.easeOut,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _filter == i ? p.accent : p.gray, borderRadius: BorderRadius.circular(16)),
                      child: Text(labels[i], style: TextStyle(color: _filter == i ? (p.dark ? const Color(0xFF0F1A24) : const Color(0xFFFFFFFF)) : p.title, fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(key: ValueKey('$q|$_filter'), child: q.isEmpty && _filter <= 2 ? _idle(p, st) : _results(p, st, q)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _idle(Pal p, Store st) {
    return ListView(padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20), children: [
      if (st.recentSearch.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
          child: Row(children: [
            Expanded(child: Text(context.l.searchRecent, style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none))),
            Tap(onTap: st.clearRecentSearch, child: Padding(padding: const EdgeInsets.all(8), child: Text(context.l.actionClear, style: TextStyle(color: p.accent, fontSize: 14, decoration: TextDecoration.none, fontWeight: FontWeight.w400)))),
          ]),
        ),
        for (final r in st.recentSearch)
          Tap(
            highlight: true,
            onTap: () => _ctl.value = TextEditingValue(text: r, selection: TextSelection.collapsed(offset: r.length)),
            child: SizedBox(
              height: 48,
              child: Row(children: [
                const SizedBox(width: 20),
                TgIcon(Ic.search, color: p.subtitle, size: 20),
                const SizedBox(width: 18),
                Expanded(child: Text(r, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w400))),
                Tap(scale: .85, onTap: () => st.removeRecentSearch(r), child: SizedBox(width: 48, height: 48, child: Center(child: TgIcon(Ic.close, color: p.subtitle, size: 18)))),
              ]),
            ),
          ),
      ],
      Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 8), child: Text(context.l.searchPeople, style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none))),
      SizedBox(
        height: 92,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: st.sorted.length,
          itemBuilder: (_, i) {
            final c = st.sorted[i];
            return Tap(
              scale: .93,
              onTap: () => openChat(context, c),
              child: SizedBox(
                width: 78,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Avatar(name: c.persona.emoji.isEmpty ? c.persona.name : c.persona.emoji, color: c.persona.color, size: 58, path: c.persona.avatarPath),
                  const SizedBox(height: 6),
                  Text(c.persona.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 12.5, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _results(Pal p, Store st, String q) {
    final low = q.toLowerCase();
    final chats = _filter <= 1 && q.isNotEmpty ? st.sorted.where((c) => c.persona.name.toLowerCase().contains(low) || c.persona.bio.toLowerCase().contains(low)).toList() : <Chat>[];
    final msgs = (_filter == 1 || (_filter == 0 && false)) ? <(Chat, Msg)>[] : st.searchAll(q, where: _match);
    if (chats.isEmpty && msgs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .4, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: TgCurves.easeOutBack,
              builder: (_, s, c) => Transform.scale(scale: s, child: c),
              child: TgIcon(Ic.search, color: p.subtitle.withAlpha(150), size: 64),
            ),
            const SizedBox(height: 12),
            Text(context.l.searchNoResultsTitle, style: TextStyle(color: p.title, fontSize: 19, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
            const SizedBox(height: 6),
            Text(q.isEmpty ? context.l.searchEmptyBody : context.l.searchNoResultsBody(q), textAlign: TextAlign.center, style: TextStyle(color: p.subtitle, fontSize: 15, height: 1.3, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
          ]),
        ),
      );
    }
    final hlBg = const Color(0x55FFC107);
    return ListView(padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20), children: [
      if (chats.isNotEmpty) ...[
        _head(p, context.l.tabChats),
        for (final c in chats)
          Tap(
            highlight: true,
            onTap: () => _open(c),
            child: SizedBox(
              height: 64,
              child: Row(children: [
                const SizedBox(width: 10),
                Avatar(name: c.persona.emoji.isEmpty ? c.persona.name : c.persona.emoji, color: c.persona.color, size: 48, path: c.persona.avatarPath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    hlText(c.persona.name, q, TextStyle(color: p.name, fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.none), hlBg),
                    const SizedBox(height: 2),
                    Text(c.persona.bio.isEmpty ? context.l.chatStatusBot : c.persona.bio, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 14, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                  ]),
                ),
              ]),
            ),
          ),
      ],
      if (msgs.isNotEmpty) ...[
        _head(p, _filter >= 3 ? searchFilters(context.l)[_filter] : context.l.dataMessages),
        for (final r in msgs.take(120))
          Tap(
            highlight: true,
            onTap: () => _open(r.$1, m: r.$2),
            child: SizedBox(
              height: 72,
              child: Row(children: [
                const SizedBox(width: 10),
                Avatar(name: r.$1.persona.emoji.isEmpty ? r.$1.persona.name : r.$1.persona.emoji, color: r.$1.persona.color, size: 52, path: r.$1.persona.avatarPath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text(r.$1.persona.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.name, fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.none))),
                      Text(dialogDate(r.$2.time), style: TextStyle(color: p.date, fontSize: 13, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                      const SizedBox(width: 14),
                    ]),
                    const SizedBox(height: 3),
                    Padding(padding: const EdgeInsets.only(right: 14), child: hlText('${r.$2.out ? context.l.chatsRowYou : ''}${r.$2.preview}', q, TextStyle(color: p.msg, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400), hlBg, maxLines: 2)),
                  ]),
                ),
              ]),
            ),
          ),
      ],
    ]);
  }

  Widget _head(Pal p, String t) => Container(
        color: p.gray,
        height: 32,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: Text(t, style: TextStyle(color: p.accent, fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
      );
}
