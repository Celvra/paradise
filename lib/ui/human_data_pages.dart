import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' as ip;
import 'package:path_provider/path_provider.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/human/hub.dart';
import '../data/human/human_models.dart';
import '../data/human/mcp_client.dart';
import '../data/human/memory.dart';
import '../data/human/sticker_lib.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'human_pages.dart';
import 'shop_page.dart';
import 'tool_descriptions.dart';
import 'tg_cells.dart';

/// Navigator of the whole app, used to raise the tool permission dialog from
/// the engine, which has no widget context of its own.
final GlobalKey<NavigatorState> appNav = GlobalKey<NavigatorState>();

/// Called by the engine when a tool is set to "ask".
Future<bool> askToolPermission(String tool, Map<String, dynamic> args) async {
  final ctx = appNav.currentState?.overlay?.context;
  if (ctx == null) return false;
  final l = ctx.l;
  final text = const JsonEncoder.withIndent('  ').convert(args);
  final r = await showTgDialog<bool>(
    ctx,
    title: l.toolPermTitle,
    message:
        '$tool\n${text.length > 600 ? '${text.substring(0, 600)}…' : text}',
    actions: [
      DialogAction(l.toolPermDeny, false, danger: true),
      DialogAction(l.toolPermAllow, true)
    ],
  );
  return r == true;
}

// ---------------------------------------------------------------- stickers

/// One sticker drawn at any size, shared by the settings page and the panel.
/// A library thumb wins over the full file so a grid of a hundred stickers
/// never decodes a hundred full size originals.
Widget stickerView(UserSticker s, double size) {
  if (s.kind == StickerKind.emoji) {
    return SizedBox(
        width: size,
        height: size,
        child: Center(
            child: Text(s.value,
                style: TextStyle(
                    fontSize: size * .62,
                    height: 1.1,
                    decoration: TextDecoration.none))));
  }
  final cache = (size * 2).round();
  final local = s.thumb.isNotEmpty && File(s.thumb).existsSync() ? s.thumb : s.value;
  final img = s.isRemote
      ? Image.network(s.value,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: cache,
          errorBuilder: (_, __, ___) => SizedBox(width: size, height: size))
      : (File(local).existsSync()
          ? Image.file(File(local),
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: cache)
          : SizedBox(width: size, height: size));
  return ClipRRect(borderRadius: BorderRadius.circular(8), child: img);
}

Future<String?> _copyIn(String dir, String path) async {
  try {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/$dir');
    if (!d.existsSync()) d.createSync(recursive: true);
    final f = File(
        '${d.path}/${DateTime.now().millisecondsSinceEpoch}_${path.split('/').last}');
    await File(path).copy(f.path);
    return f.path;
  } catch (_) {
    return path;
  }
}

/// Still preview of a freshly imported sticker. Empty string when the codec
/// cannot read the file, the sticker then simply renders from its full copy.
Future<String> _thumbIn(String copiedPath) async {
  try {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/stickers_thumbs');
    if (!d.existsSync()) d.createSync(recursive: true);
    final f = File(
        '${d.path}/${DateTime.now().millisecondsSinceEpoch}_thumb.png');
    return await makeStickerThumb(copiedPath, f.path) ?? '';
  } catch (_) {
    return '';
  }
}

/// Add flow shared with the sticker tab and this page: a picked file or an url
/// becomes a sticker, and a file or link that ends in .gif lands as a GIF.
Future<void> addStickerFlow(BuildContext c) async {
  final l = c.l;
  final h = Store.read(c).human!;
  // Only the two file sources. A plain emoji is one tap away in the panel, and
  // the three long labels used to wrap in a 320pt dialog and stretch it tall.
  final how = await showTgDialog<String>(c, title: l.stickerAddTitle, actions: [
    DialogAction(l.actionCancel, null),
    DialogAction(l.stickerAddGallery, 'gallery'),
    DialogAction(l.stickerAddUrl, 'url'),
  ]);
  if (how == null || !c.mounted) return;
  late String value;
  var kind = StickerKind.image;
  var thumb = '';
  if (how == 'gallery') {
    final x = await ip.ImagePicker().pickImage(source: ip.ImageSource.gallery);
    if (x == null) return;
    value = await _copyIn('stickers', x.path) ?? '';
    kind = x.path.toLowerCase().endsWith('.gif')
        ? StickerKind.gif
        : StickerKind.image;
    if (value.isNotEmpty) thumb = await _thumbIn(value);
  } else {
    value = (await hAsk(c, l.stickerLink, 'https://…'))?.trim() ?? '';
    kind = value.toLowerCase().contains('.gif')
        ? StickerKind.gif
        : StickerKind.image;
  }
  if (value.isEmpty || !c.mounted) return;
  final emotion =
      await hAsk(c, l.stickerEmotionOptional, l.stickerEmotionExample);
  h.stickers.add(
      kind: kind,
      value: value,
      emotion: (emotion ?? '').trim(),
      tags: [if ((emotion ?? '').trim().isNotEmpty) emotion!.trim()],
      thumb: thumb);
  h.changed();
}

Future<void> editStickerFlow(BuildContext c, UserSticker s) async {
  final l = c.l;
  final h = Store.read(c).human!;
  final name = TextEditingController(text: s.name);
  final emo = TextEditingController(text: s.emotion);
  final tags = TextEditingController(text: s.tags.join(', '));
  final cat = TextEditingController(text: s.category);
  final r = await showTgDialog<String>(
    c,
    title: s.label,
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      stickerView(s, 72),
      const SizedBox(height: 8),
      TgField(controller: name, hint: l.stickerFieldName),
      const SizedBox(height: 6),
      TgField(controller: emo, hint: l.stickerFieldEmotion),
      const SizedBox(height: 6),
      TgField(controller: tags, hint: l.stickerFieldTags),
      const SizedBox(height: 6),
      TgField(controller: cat, hint: l.stickerFieldCategory),
    ]),
    actions: [
      DialogAction(l.actionDelete, 'del', danger: true),
      DialogAction(s.favorite ? l.stickerUnfavorite : l.stickerFavorite, 'fav'),
      DialogAction(l.actionSave, 'save')
    ],
  );
  if (r == 'del') {
    h.stickers.remove(s.id);
  } else if (r == 'fav') {
    s.favorite = !s.favorite;
  } else if (r == 'save') {
    s.name = name.text.trim();
    s.emotion = emo.text.trim();
    s.tags = tags.text
        .split(RegExp(r'[,，、]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    s.category = cat.text.trim().isEmpty ? 'General' : cat.text.trim();
  }
  for (final x in [name, emo, tags, cat]) {
    x.dispose();
  }
  if (r != null) h.changed();
}

class StickerSettingsPage extends StatefulWidget {
  const StickerSettingsPage({super.key});
  @override
  State<StickerSettingsPage> createState() => _StickerSettingsState();
}

class _StickerSettingsState extends State<StickerSettingsPage> {
  final _q = TextEditingController();
  String? _cat;
  var _favs = false;
  var _recent = false;

  /// ids picked for a batch action, empty means the grid is in browse mode
  final Set<String> _sel = {};

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool get _picking => _sel.isNotEmpty;

  /// Tapping a cell in batch mode adds or removes it, otherwise it opens the
  /// editor. A long press starts the batch mode on the pressed sticker.
  void _tapCell(UserSticker s) {
    if (_picking) {
      setState(() => _sel.contains(s.id) ? _sel.remove(s.id) : _sel.add(s.id));
      return;
    }
    editStickerFlow(context, s);
  }

  void _holdCell(UserSticker s) {
    if (_picking) return;
    setState(() => _sel.add(s.id));
    HapticFeedback.mediumImpact();
  }

  Future<void> _batch() async {
    if (_sel.isEmpty) return;
    final l = context.l;
    final lib = Store.read(context).human!.stickers;
    final ids = [..._sel];
    final all = ids.map((id) => lib.byId(id)).whereType<UserSticker>().toList();
    if (all.isEmpty) {
      setState(_sel.clear);
      return;
    }
    final what = await showTgDialog<String>(
      context,
      title: l.stickerCountSelected(all.length),
      actions: [
        DialogAction(l.actionCancel, null),
        DialogAction(l.stickerFavorite, 'fav'),
        DialogAction(l.stickerUnfavorite, 'unfav'),
        DialogAction(l.stickerBatchMove, 'move'),
        DialogAction(l.actionDelete, 'del', danger: true),
      ],
    );
    if (what == null || !mounted) return;
    if (what == 'del') {
      final ok = await showTgDialog<bool>(context,
          title: l.stickerBatchDeleteTitle(all.length),
          message: l.stickerBatchUndo,
          actions: [
            DialogAction(l.actionCancel, false),
            DialogAction(l.actionDelete, true, danger: true)
          ]);
      if (ok != true) return;
      lib.removeAll(ids);
    } else if (what == 'fav') {
      lib.setFavorite(ids, true);
    } else if (what == 'unfav') {
      lib.setFavorite(ids, false);
    } else if (what == 'move') {
      final name = await hAsk(context, l.stickerFieldCategory,
          l.stickerBatchNow(all.first.category));
      if (name == null) return;
      lib.moveTo(ids, name);
    }
    if (!mounted) return;
    setState(_sel.clear);
    Store.read(context).human!.changed();
  }

  /// Picks everything the current filter shows, so a whole category can be
  /// cleared or moved in one go.
  void _selectVisible(List<UserSticker> list) {
    setState(() {
      for (final s in list) {
        _sel.add(s.id);
      }
    });
  }

  Widget _chip(Pal p, String label, bool on, VoidCallback tap) => Tap(
        scale: .94,
        onTap: tap,
        child: Container(
          margin: const EdgeInsets.only(right: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: on ? p.accent : p.gray,
              borderRadius: BorderRadius.circular(16)),
          child: Text(label,
              style: hStyle(p,
                  size: 14,
                  color: on ? const Color(0xFFFFFFFF) : p.title,
                  weight: FontWeight.w500)),
        ),
      );

  Widget _cell(Pal p, UserSticker s, double size) {
    final on = _sel.contains(s.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapCell(s),
      onLongPress: () => _holdCell(s),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: p.gray,
            borderRadius: BorderRadius.circular(10),
            border: on ? Border.all(color: p.accent, width: 2) : null),
        child: Stack(children: [
          Center(child: stickerView(s, size - 16)),
          if (s.favorite)
            Positioned(
                top: 3,
                right: 5,
                child: Text('★',
                    style:
                        hStyle(p, size: 12, color: const Color(0xFFF5A623)))),
          if (s.source == 'ai')
            Positioned(
                bottom: 2,
                left: 5,
                child: Text(L10n.current.stickerAiBadge,
                    style: hStyle(p,
                        size: 10, color: p.accent, weight: FontWeight.w600))),
          if (s.emotion.isNotEmpty)
            Positioned(
                bottom: 2,
                right: 5,
                child: Text(s.emotion,
                    style: hStyle(p, size: 10, color: p.subtitle))),
          if (_picking)
            Positioned(
              top: 2,
              left: 4,
              child: on
                  ? TgIcon(Ic.check2, color: p.accent, size: 18, stroke: 2)
                  : Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: p.hint, width: 1.5)),
                    ),
            ),
        ]),
      ),
    );
  }

  /// the batch bar rides on top of the grid so a long library can still be
  /// scrolled while something is picked
  Widget _batchBar(Pal p) {
    final l = context.l;
    return Container(
      decoration: BoxDecoration(
          color: p.bar,
          border: Border(top: BorderSide(color: p.divider, width: .5))),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(children: [
        Expanded(
            child: Text(l.stickerCountSelected(_sel.length),
                style: hStyle(p, size: 15, weight: FontWeight.w600))),
        Tap(
            scale: .94,
            onTap: () => setState(_sel.clear),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(l.actionCancel,
                    style: hStyle(p, size: 15, color: p.subtitle)))),
        Tap(
          scale: .94,
          onTap: _batch,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
                color: p.accent, borderRadius: BorderRadius.circular(20)),
            child: Text(l.stickerBatchActions,
                style: hStyle(p,
                    size: 15,
                    color: const Color(0xFFFFFFFF),
                    weight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return TgSettingsPage(
      title: l.stickerSettingsTitle,
      actions: [
        if (_picking)
          Tap(
              scale: .88,
              onTap: () => setState(_sel.clear),
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TgIcon(Ic.check2, color: context.p.accent, size: 22)))
        else
          Tap(
              scale: .88,
              onTap: () => addStickerFlow(context),
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TgIcon(Ic.plus, color: context.p.title, size: 24))),
      ],
      builder: (c, _) => HLive(builder: (c, h, p) {
        final lib = h.stickers;
        var list = _recent
            ? lib.recent(limit: 60)
            : lib.search(_q.text, category: _cat, favorites: _favs);
        if (_recent && _q.text.isNotEmpty)
          list = list.where((s) => s.matches(_q.text)).toList();
        const cell = 78.0;
        return Stack(children: [
          ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: _picking ? 76 : 40),
            children: [
              Container(
                color: p.bg,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TgField(controller: _q, hint: l.stickerSearchHint),
                      const SizedBox(height: 10),
                      Wrap(children: [
                        _chip(
                            p,
                            l.searchFilterAll,
                            _cat == null && !_favs && !_recent,
                            () => setState(() {
                                  _cat = null;
                                  _favs = false;
                                  _recent = false;
                                })),
                        _chip(
                            p,
                            '★ ${l.stickerFavorites}',
                            _favs,
                            () => setState(() {
                                  _favs = !_favs;
                                  _recent = false;
                                })),
                        _chip(
                            p,
                            l.stickerRecent,
                            _recent,
                            () => setState(() {
                                  _recent = !_recent;
                                  _favs = false;
                                })),
                        for (final cat in lib.categories)
                          _chip(
                              p,
                              cat,
                              _cat == cat,
                              () => setState(
                                  () => _cat = _cat == cat ? null : cat)),
                        if (list.isNotEmpty)
                          _chip(p, l.stickerSelectAll, false,
                              () => _selectVisible(list)),
                      ]),
                    ]),
              ),
              Container(
                color: p.bg,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                            child: Text(l.stickerEmptyLibrary,
                                textAlign: TextAlign.center,
                                style: hStyle(p, color: p.subtitle))))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final s in list) _cell(p, s, cell)]),
              ),
              TgInfoCell(l.stickerLibraryFooter),
            ],
          ),
          if (_picking)
            Positioned(left: 0, right: 0, bottom: 0, child: _batchBar(p)),
        ]);
      }),
    );
  }
}

// ------------------------------------------------------------------ memory

class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return HPage(
      title: l.memoryTitle,
      actions: [
        Tap(
          scale: .88,
          onTap: () async {
            final h = Store.read(context).human!;
            final text =
                await hAsk(context, l.memoryNew, l.memoryNewWhat, lines: 3);
            if (text == null || text.trim().isEmpty || !context.mounted) return;
            final t = await showTgDialog<String>(context,
                title: l.memoryNewType,
                actions: [
                  DialogAction(l.actionCancel, null),
                  for (final k in MemType.values) DialogAction(k.name, k.name),
                ]);
            if (t == null) return;
            h.memory.write(memTypeOf(t), text, weight: 2);
            h.changed();
          },
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: TgIcon(Ic.plus, color: context.p.title, size: 24)),
        ),
      ],
      body: (c, h, p) {
        final items = [...h.memory.items]
          ..sort((a, b) => b.weight.compareTo(a.weight));
        final now = DateTime.now().millisecondsSinceEpoch;
        return [
          TgSection(footer: l.memoryFooter, children: [
            if (items.isEmpty) TgTextCell(title: l.memoryEmpty, divider: false),
            for (final m in items)
              TgTextCell(
                title: m.content,
                subtitle:
                    '${m.type.name} · w ${m.weight.toStringAsFixed(2)}${m.done ? ' · done' : ''}${m.forgotten ? ' · ${l.memoryForgotten}' : ''}${m.dueAt > 0 ? ' · ${l.memoryDue} ${DateTime.fromMillisecondsSinceEpoch(m.dueAt).toIso8601String().substring(0, 16)}${m.dueAt <= now ? '' : ''}' : ''}',
                subtitleColor: m.forgotten || m.done ? p.hint : null,
                onTap: () async {
                  final r = await showTgDialog<String>(c,
                      title: m.type.name,
                      message: m.content,
                      actions: [
                        DialogAction(l.actionDelete, 'del', danger: true),
                        if (m.sticky) DialogAction(l.memoryNotNeeded, 'done'),
                        if (m.forgotten)
                          DialogAction(l.memoryRestore, 'restore'),
                        DialogAction(l.memoryClose, null),
                      ]);
                  if (r == 'del') h.memory.remove(m.id);
                  if (r == 'done') h.memory.complete(m.id);
                  if (r == 'restore') {
                    m.forgotten = false;
                    m.weight = 1;
                    m.lastAccess = now;
                    m.decayedAt = now;
                  }
                  if (r != null) h.changed();
                },
              ),
          ]),
        ];
      },
    );
  }
}

// ------------------------------------------------------------------- tools

/// The tools this build offers, in the order the page shows them.
///
/// The six file tools come last and only when the feature is on: they are a
/// different kind of thing from the rest, which are all things it can do inside
/// a conversation. Descriptions live in tool_descriptions.dart, and a test there
/// fails if a name here has none.
const kBuiltinTools = [
  'get_time',
  'schedule_message',
  'cancel_scheduled',
  'modify_scheduled',
  'list_scheduled',
  'set_status',
  'adjust_feeling',
  'write_memory',
  'read_memory',
  'complete_todo', //
  'set_life_schedule', 'pin_message', 'edit_message', 'quote_message',
  'update_character_card', 'adjust_rating', 'send_sticker', 'save_sticker', //
  'recall_message', 'send_typo', 'send_image', 'send_file', 'send_svg',
  'send_html', 'send_latex', 'send_cetz',
  'send_transfer', //
  'ask',
  'read_file', 'write_file', 'edit_file', 'list_dir', 'glob', 'grep', 'shell',
  'view_image', 'read_skill',
];

/// The ones that only exist once a chat is bound to a workspace. shell and
/// view_image also need an installed Linux environment, which is a separate
/// condition and is handled where the runtime is.
const kWorkspaceTools = {
  'read_file',
  'write_file',
  'edit_file',
  'list_dir',
  'glob',
  'grep',
  'shell',
  'view_image'
};

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});
  @override
  State<ToolsPage> createState() => _ToolsState();
}

class _ToolsState extends State<ToolsPage> {
  var _busy = false;

  String _label(ToolPerm p) {
    final l = context.l;
    return switch (p) {
      ToolPerm.allow => l.toolPermAllow,
      ToolPerm.ask => l.toolPermAsk,
      ToolPerm.deny => l.toolPermDeny
    };
  }

  Future<void> _refresh(HumanHubRef h) async {
    setState(() => _busy = true);
    await h.hub.mcp.refresh(h.hub.mcpServers);
    h.hub.changed();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit(BuildContext c, HumanHubRef h, McpServerConfig? s) async {
    final l = c.l;
    final name = TextEditingController(text: s?.name ?? '');
    final url = TextEditingController(text: s?.url ?? '');
    final hdr = TextEditingController(
        text: s == null || s.headers.isEmpty ? '' : jsonEncode(s.headers));
    final r = await showTgDialog<String>(
      c,
      title: s == null ? l.toolAddServer : s.name,
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TgField(controller: name, hint: l.stickerFieldName),
        const SizedBox(height: 6),
        TgField(controller: url, hint: l.toolUrlHint),
        const SizedBox(height: 6),
        TgField(controller: hdr, hint: l.toolHeadersJson),
      ]),
      actions: [
        if (s != null) DialogAction(l.actionDelete, 'del', danger: true),
        DialogAction(l.actionCancel, null),
        DialogAction(l.actionSave, 'save')
      ],
    );
    final nameT = name.text.trim(),
        urlT = url.text.trim(),
        hdrT = hdr.text.trim();
    for (final x in [name, url, hdr]) {
      x.dispose();
    }
    if (r == null) return;
    final list = h.hub.settings.mcp;
    if (r == 'del' && s != null) {
      list.removeWhere((e) => e['id'] == s.id);
    } else if (r == 'save' && urlT.isNotEmpty) {
      Map<String, String> headers = {};
      try {
        if (hdrT.isNotEmpty)
          headers = {
            for (final e in (jsonDecode(hdrT) as Map).entries)
              '${e.key}': '${e.value}'
          };
      } catch (_) {}
      final cfg = McpServerConfig(
          id: s?.id ??
              's${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
          name: nameT.isEmpty ? Uri.tryParse(urlT)?.host ?? 'MCP' : nameT,
          url: urlT,
          headers: headers,
          enabled: s?.enabled ?? true);
      list.removeWhere((e) => e['id'] == cfg.id);
      list.add(cfg.toJson());
    }
    h.hub.changed();
    await _refresh(h);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return HPage(
      title: l.toolsTitle,
      actions: [
        Tap(
            scale: .88,
            onTap: () =>
                _edit(context, HumanHubRef(Store.read(context).human!), null),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: TgIcon(Ic.plus, color: context.p.title, size: 24)))
      ],
      body: (c, h, p) {
        final ref = HumanHubRef(h);
        final on = Store.read(c).workspace.toolsEnabled;
        // a tool with no description falls back to its own name rather than to an
        // empty subtitle, which rendered as a blank line under the row
        Widget permCell(String name, String? sub,
            {required bool external, bool last = false}) {
          final perm = h.permFor(name, external: external);
          return TgTextCell(
            title: name,
            subtitle: (sub == null || sub.isEmpty) ? name : sub,
            value: _label(perm),
            divider: !last,
            color: perm == ToolPerm.deny ? p.danger : null,
            onTap: () => h.setPerm(name, ToolPerm.values[(perm.index + 1) % 3]),
          );
        }

        return [
          TgSection(
              header: l.toolServersHeader,
              footer: l.toolServersFooter,
              children: [
                for (final s in h.mcpServers)
                  TgTextCell(
                    title: s.name,
                    subtitle: h.mcp.errors[s.id] ??
                        mcpServerDescription(
                            s.url,
                            h.mcp.tools.where((t) => t.serverId == s.id).length,
                            l),
                    subtitleColor: h.mcp.errors[s.id] != null ? p.danger : null,
                    trailing: TgSwitch(
                        value: s.enabled,
                        onChanged: (v) {
                          final i =
                              h.settings.mcp.indexWhere((e) => e['id'] == s.id);
                          if (i >= 0) h.settings.mcp[i]['enabled'] = v;
                          h.changed();
                          _refresh(ref);
                        }),
                    onTap: () => _edit(c, ref, s),
                  ),
                TgTextCell(
                    title: _busy ? l.toolConnecting : l.toolRefresh,
                    icon: Ic.regen,
                    divider: false,
                    onTap: _busy ? null : () => _refresh(ref)),
              ]),
          if (h.mcp.tools.isNotEmpty)
            TgSection(header: l.toolMcpHeader, children: [
              for (var i = 0; i < h.mcp.tools.length; i++)
                permCell(h.mcp.tools[i].key,
                    '${h.mcp.tools[i].serverName} · ${mcpToolDescription(h.mcp.tools[i].name, h.mcp.tools[i].description)}',
                    external: true, last: i == h.mcp.tools.length - 1),
            ]),
          TgSection(
              header: l.toolBuiltinHeader,
              footer: on ? null : l.toolBuiltinFooter,
              children: [
                for (final t in kBuiltinTools
                    .where((e) => on || !kWorkspaceTools.contains(e)))
                  permCell(t, toolDescription(l, t), external: false),
              ]),
        ];
      },
    );
  }
}

/// tiny holder so helper methods can take the hub without importing it twice
class HumanHubRef {
  HumanHubRef(this.hub);
  final HumanHub hub;
}

// ------------------------------------------------------------------ wallet

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return HPage(
      title: l.humanWalletRow,
      body: (c, h, p) {
        final w = h.wallet;
        return [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                    colors: [Color(0xFF2AABEE), Color(0xFF229ED9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.walletBalance,
                  style: hStyle(p, size: 14, color: const Color(0xCCFFFFFF))),
              const SizedBox(height: 6),
              Text('¥ ${w.balance.toStringAsFixed(2)}',
                  style: hStyle(p,
                      size: 34,
                      color: const Color(0xFFFFFFFF),
                      weight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(l.walletPretendNote,
                  style: hStyle(p, size: 12.5, color: const Color(0xB3FFFFFF))),
            ]),
          ),
          TgSection(children: [
            TgTextCell(
                icon: Ic.crown,
                title: l.shopEntry,
                subtitle: l.shopEntrySub,
                divider: false,
                onTap: () => Navigator.of(c)
                    .push(TgRoute(builder: (_) => const ShopPage()))),
          ]),
          TgSection(header: l.walletRecords, children: [
            if (w.txs.isEmpty) TgTextCell(title: l.walletEmpty, divider: false),
            for (final t in w.txs)
              TgTextCell(
                icon: t.kind == 'shop'
                    ? Ic.crown
                    : (t.kind == 'redpacket' ? Ic.hongbao : Ic.wallet),
                color: t.kind == 'redpacket'
                    ? const Color(0xFFE14A3E)
                    : (t.kind == 'shop' ? p.accent : null),
                title: t.title.isEmpty
                    ? (t.kind == 'redpacket'
                        ? l.walletRedPacket
                        : l.walletTransfer)
                    : t.title,
                subtitle:
                    '${DateTime.fromMillisecondsSinceEpoch(t.at).toIso8601String().substring(0, 16).replaceFirst('T', ' ')} · ${t.status}',
                value:
                    '${t.amount >= 0 ? '+' : '−'}${t.amount.abs().toStringAsFixed(2)}',
              ),
          ]),
          TgSection(children: [
            TgTextCell(
                title: l.walletReset,
                color: p.danger,
                divider: false,
                onTap: () async {
                  final ok = await showTgDialog<bool>(c,
                      title: l.walletResetTitle,
                      actions: [
                        DialogAction(l.actionCancel, false),
                        DialogAction(l.walletResetAction, true, danger: true)
                      ]);
                  if (ok == true) {
                    w.txs.clear();
                    w.balance = 1000;
                    h.changed();
                  }
                }),
          ]),
        ];
      },
    );
  }
}
