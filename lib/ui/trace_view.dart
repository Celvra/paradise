import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../data/workspace/workspace_metadata.dart';
import '../data/workspace/workspace_paths.dart';
import '../l10n/x.dart';
import 'bubble.dart' show mdBlocks;
import 'workspace/file_preview_page.dart';
import 'workspace/ws_trace_body.dart';

// One step of the model's work, drawn in the chat stream where it happened: a
// stretch of reasoning, or a tool call with what it got back. The shape follows
// Kelivo, which keeps both as collapsible timeline steps rather than burying
// them in a debug panel, but the skin is Telegram: a soft rounded card, a
// hairline rail that ties consecutive steps together, a white glyph node and
// the same chevron the settings rows use.
//
// Every piece of chrome on the row, rail, glyph, title, clock and chevron, is
// painted the same white in both palettes. The theme only reaches the card the
// step opens into, since that is a surface with text on it rather than a mark.
//
// Collapsed it is one line. While the step is still running it opens by itself
// and follows the tail, so thinking is watchable without a single tap. The
// chase yields to the reader: scroll up inside a running preview and it stops
// chasing until the tail is reached again, so a long output can be read.

/// How tall the running preview is, roughly six lines of small text.
const _previewH = 108.0;

/// The rail, the glyph node, the step title, the clock and the chevron ignore
/// the palette and stay white in both. Those are the timeline itself: the marks
/// that say a run of steps belongs together and which step you are looking at.
/// A themed divider on the day palette is too faint to read as a rail, so one
/// constant paints white wherever it lands. The card a step opens into is left
/// on the theme, it is a surface with text on it rather than a mark.
const _white = Color(0xFFFFFFFF);

class TraceView extends StatefulWidget {
  const TraceView({super.key, required this.msg, this.linkedAbove = false, this.linkedBelow = false, this.titleKey, this.panelKey});

  final Msg msg;

  /// the rail is drawn on both sides of a run of consecutive steps
  final bool linkedAbove;
  final bool linkedBelow;

  /// the layout test measures the title against a bubble, and the open body
  /// against the row, with these two
  final Key? titleKey;
  final Key? panelKey;

  @override
  State<TraceView> createState() => _TraceViewState();
}

class _TraceViewState extends State<TraceView> {
  /// null means the row follows the step: a preview while it runs, folded away
  /// once it is done. A tap pins it the other way and it stays that way.
  bool? _pinned;
  String? _seen;
  Timer? _tick;
  final ScrollController _win = ScrollController();
  final ValueNotifier<int> _pulse = ValueNotifier<int>(0);

  /// Whether the running preview should keep chasing its tail. It starts on, a
  /// hand that scrolls away from the tail parks it, and landing back on the
  /// tail turns it on again. A plain field on purpose: it paints nothing, so
  /// flipping it never needs a rebuild.
  bool _stick = true;

  bool get _running => widget.msg.data['state'] == 'run';
  bool get _tool => widget.msg.data['type'] == 'tool';
  bool get _bad => widget.msg.data['state'] == 'err';

  /// The chat list hands the very same Msg instance back on every rebuild, so
  /// comparing the old widget against the new one would always read as
  /// unchanged. What this row last acted on is kept here instead.
  String get _state => '${widget.msg.data['state']}';

  bool get _open => (_pinned ?? _running) && _body.isNotEmpty;

  /// How long the step took, or how long it has been running. A row that never
  /// finished (an abort mid think) reports the time it did take.
  int get _ms {
    final done = widget.msg.data['ms'] as int?;
    if (done != null) return done;
    final t0 = widget.msg.data['t0'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch - t0;
  }

  String get _args {
    final raw = widget.msg.data['args'];
    if (raw is! Map || raw.isEmpty) return '';
    return const JsonEncoder.withIndent('  ').convert(raw);
  }

  String get _result => '${widget.msg.data['result'] ?? ''}';

  String get _think => '${widget.msg.data['body'] ?? ''}';

  /// The workspace half of a step row, or null for every other tool. Parsed
  /// from the row rather than passed in, because the row is persisted and a
  /// conversation opened tomorrow must render the same way it did today.
  WorkspaceToolMeta? get _ws {
    if (!_tool) return null;
    final raw = widget.msg.data['ws'];
    return raw is Map ? WorkspaceToolMeta.fromJson(Map<String, dynamic>.from(raw)) : null;
  }

  /// What the expanded card would show. A step with nothing in it does not get
  /// a chevron, tapping it would open an empty box.
  String get _body => _tool ? (_ws == null ? '$_args$_result' : (_ws!.path + _ws!.diff + _ws!.count.toString())) : _think;

  @override
  void initState() {
    super.initState();
    _seen = _state;
    _sync();
  }

  @override
  void didUpdateWidget(covariant TraceView old) {
    super.didUpdateWidget(old);
    if (_seen == _state) {
      _follow();
      return;
    }
    _seen = _state;
    _sync();
    // a step that just finished folds itself away, unless the user pinned it
    // open because they wanted to read the whole thing
    if (!_running) setState(() => _pinned = null);
  }

  /// The clock only ticks while the step runs, a finished row needs no timer.
  void _sync() {
    _tick?.cancel();
    _tick = null;
    if (_running) {
      // a fresh run starts on the tail; the reader takes over from there
      _stick = true;
      _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        _pulse.value++;
        _follow();
      });
    }
  }

  /// Keeps the tail of a running step in view, the same way a streaming bubble
  /// keeps its own tail at the bottom — until the reader takes over. A hand
  /// that scrolls off the tail parks the chase, so a long output can be read
  /// while the step is still running instead of being dragged back down every
  /// tick. Landing on the tail again hands control straight back.
  void _follow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_win.hasClients) return;
      if (_stick) _win.jumpTo(_win.position.maxScrollExtent);
    });
  }

  /// The handoff between the tail chase and the reader. Only gestures count:
  /// a drag carries its pointer details, a fling ends with the position where
  /// the finger left it. Content growing under a pinned position corrects
  /// silently during layout and dispatches nothing, so streaming never reads
  /// as a scroll and the chase keeps its place at the tail.
  bool _onPreviewScroll(ScrollNotification n) {
    if (n.depth != 0) return false; // the diff view scrolls inside the card
    final hand = (n is ScrollUpdateNotification && n.dragDetails != null) || n is ScrollEndNotification;
    if (hand) _stick = (n.metrics.maxScrollExtent - n.metrics.pixels) <= 8;
    return false;
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    _win.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final body = _body;
    final open = _open;
    final meta = Row(mainAxisSize: MainAxisSize.min, children: [
      if (_running) TypingDots(color: _white) else TgIcon(_bad ? Ic.info : Ic.check2, color: _white, size: 15, stroke: 2),
      // the clock ticks in place, so the row never reflows while it thinks
      ValueListenableBuilder<int>(
        valueListenable: _pulse,
        builder: (_, __, ___) => Text(_meta(), style: TextStyle(color: _white, fontSize: 12.5, height: 1.2, decoration: TextDecoration.none)),
      ),
    ]);

    return Padding(
      padding: EdgeInsets.only(top: widget.linkedAbove ? 1 : 5, left: 12, right: 12, bottom: widget.linkedBelow ? 1 : 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // the rail: a glyph node with a hairline reaching the steps above
            // and below, so a run of them reads as one timeline
            SizedBox(
              width: 26,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (widget.linkedAbove) Container(width: 1, height: 5, color: _white),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _white.withAlpha(_running ? 46 : 26), borderRadius: BorderRadius.circular(8)),
                  child: TgIcon(_ws != null ? _wsIcon(_ws!) : (_tool ? (_bad ? Ic.info : Ic.gear) : Ic.ai), color: _white, size: 15, stroke: 1.9),
                ),
                if (widget.linkedBelow) Container(width: 1, height: 5, color: _white),
              ]),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Tap(
                onTap: body.isEmpty
                    ? null
                    : () {
                        setState(() => _pinned = !_open);
                        // an opened preview starts on the tail, the same
                        // auto-chase a step that opens by itself gets
                        _stick = true;
                        _follow();
                      },
                child: Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 3),
                  child: Row(children: [
                    Expanded(
                      child: Text(_title(), key: widget.titleKey, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _white, fontSize: 14.5, height: 1.25, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                    ),
                    const SizedBox(width: 8),
                    meta,
                    if (body.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 220),
                        curve: TgCurves.easeOut,
                        turns: open ? .5 : 0,
                        child: TgIcon(Ic.chevron, color: _white, size: 16, stroke: 2),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ]),
          // the body sits outside the rail column on purpose: once the step is
          // open the reason or the result wants the whole width, indenting it
          // past the icon only wastes the line the user is here to read
          AnimatedSize(            duration: const Duration(milliseconds: 240),
            curve: TgCurves.easeOut,
            alignment: Alignment.topLeft,
            child: !open
                ? const SizedBox.shrink()
                : Padding(
                    key: widget.panelKey,
                    padding: const EdgeInsets.only(top: 4, bottom: 3),
                    child: _panel(p),
                  ),
          ),
        ],
      ),
    );
  }

  /// The card under the header. While the step runs it is a clipped window onto
  /// the tail, so a long think never pushes the answer off screen.
  Widget _panel(Pal p) {
    final mono = _args.isNotEmpty;
    final style = TextStyle(color: p.msg, fontSize: mono ? 12 : 12.8, height: 1.4, fontFamily: mono ? 'monospace' : null, decoration: TextDecoration.none);
    // reasoning and results are model text, so they read through the same
    // markdown lens the bubbles use; the code blocks a shell run prints belong
    // in fences, not in backtick soup
    Widget body(String text) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: mdBlocks(context, text, style, p.codeIn, p.accent, 0),
        );
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(color: p.glassFill.withAlpha(p.dark ? 150 : 205), borderRadius: BorderRadius.circular(11), border: Border.all(color: p.divider, width: .5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (_ws != null)
          WsTraceBody(meta: _ws!, result: _result, running: _running, onOpenFile: _openWsFile)
        else if (_tool) ...[
          if (_args.isNotEmpty) ...[
            _tag(p, L10n.current.traceArguments),
            Text(_args, style: style.copyWith(color: p.subtitle)),
            const SizedBox(height: 9),
          ],
          if (_result.isNotEmpty || _running) ...[
            _tag(p, L10n.current.traceResult),
            body(_result.isEmpty ? '…' : _result),
          ],
        ] else
          body(_think.isEmpty ? '…' : _think),
      ]),
    );

    if (!_running) return card;
    // the running preview is a plain clipped window: the scroll view crops the
    // card at its own edge with no fade, so streaming text lands at the tail
    // fully opaque instead of dissolving in at the bottom of the mask
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _previewH),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onPreviewScroll,
        child: SingleChildScrollView(controller: _win, physics: const ClampingScrollPhysics(), child: card),
      ),
    );
  }

  Widget _tag(Pal p, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: TextStyle(color: p.accent, fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
      );

  /// 'Thinking…' while it runs, 'Thought for 2.4s' once it is done, and the tool
  /// name with its server for a call. An MCP row names the server because that is
  /// the only place the user can tell which of them was asked.
  String _title() {
    final l = L10n.current;
    if (!_tool) return _running ? l.traceThinkingNow : l.traceThoughtFor(traceSeconds(_ms));
    final ws = _ws;
    if (ws != null) return WsTraceBody.titleFor(ws, '${widget.msg.data['tool'] ?? ''}');
    final name = '${widget.msg.data['tool'] ?? ''}';
    final server = '${widget.msg.data['mcp'] ?? ''}';
    return server.isEmpty ? name : '$name · $server';
  }

  /// Turns a model path from the metadata into a file and opens the preview.
  ///
  /// The row only stores the model path, because that is what belongs in a
  /// persisted chat: a host path would break the moment the app's documents
  /// directory moved, which it does on restore.
  Future<void> _openWsFile(String modelPath) async {
    final store = Store.read(context);
    final chatId = '${widget.msg.data['chatId'] ?? ''}';
    final chat = store.chats.where((c) => c.id == chatId).firstOrNull ?? _nearestBoundChat(store);
    final ctx = chat == null ? null : await store.wsContext(chat);
    if (ctx == null) {
      if (context.mounted) showBulletin(context, L10n.current.wsPreviewMissing);
      return;
    }
    if (!context.mounted) return;
    try {
      final resolved = await ctx.paths.resolveReal(modelPath);
      await showFilePreview(context, File(resolved.hostPath), title: modelPath.split('/').last);
    } on PathResolutionException {
      if (context.mounted) showBulletin(context, L10n.current.wsPreviewMissing);
    }
  }

  /// A row rendered from history has no chat of its own, so fall back to the
  /// only workspace that matters for opening a file: the first bound one.
  Chat? _nearestBoundChat(Store store) {
    for (final c in store.chats) {
      if (c.ws.isBound) return c;
    }
    return null;
  }

  /// A read and a search look different from a write, because the whole point of
  /// the row is whether something on the device changed.
  Ic _wsIcon(WorkspaceToolMeta m) {
    if (_bad || m.status == 'denied') return Ic.info;
    return switch (m.tool) {
      'write_file' || 'edit_file' => Ic.pencil,
      'list_dir' => Ic.folder,
      'glob' || 'grep' => Ic.search,
      _ => Ic.file,
    };
  }

  /// A finished think already carries its duration in the title, so it gets
  /// nothing here. A tool keeps it on the right, next to the state glyph.
  String _meta() {
    if (_bad) return ' ${L10n.current.traceFailed}';
    if (_running) return ' ${traceSeconds(_ms)}';
    return _tool ? ' ${traceSeconds(_ms)}' : '';
  }
}
