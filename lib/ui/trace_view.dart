import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../l10n/x.dart';

// One step of the model's work, drawn in the chat stream where it happened: a
// stretch of reasoning, or a tool call with what it got back. The shape follows
// Kelivo, which keeps both as collapsible timeline steps rather than burying
// them in a debug panel, but the skin is Telegram: a soft rounded card, an
// accent tinted glyph, a hairline rail that ties consecutive steps together and
// the same chevron the settings rows use.
//
// Collapsed it is one line. While the step is still running it opens by itself
// and follows the tail, so thinking is watchable without a single tap.

/// How tall the running preview is, roughly six lines of small text.
const _previewH = 108.0;

/// dstIn masks for the running preview: flat while the text fits, faded at the
/// bottom once there is more of it below the fold. A gradient needs two colours
/// even when it is meant to be flat, one colour asserts during paint.
const _flat = LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)]);
const _fade = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
  stops: [0, .7, 1],
);

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
  bool _over = false;
  Timer? _tick;
  final ScrollController _win = ScrollController();
  final ValueNotifier<int> _pulse = ValueNotifier<int>(0);

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

  /// What the expanded card would show. A step with nothing in it does not get
  /// a chevron, tapping it would open an empty box.
  String get _body => _tool ? '$_args$_result' : _think;

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
      _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        _pulse.value++;
        _follow();
      });
    }
  }

  /// Keeps the tail of a running step in view, the same way a streaming bubble
  /// keeps its own tail at the bottom.
  void _follow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_win.hasClients) return;
      _win.jumpTo(_win.position.maxScrollExtent);
      final over = _win.position.maxScrollExtent > .5;
      if (over != _over) setState(() => _over = over);
    });
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
    final accent = _bad ? p.danger : p.accent;

    final meta = Row(mainAxisSize: MainAxisSize.min, children: [
      if (_running) TypingDots(color: accent) else TgIcon(_bad ? Ic.info : Ic.check2, color: _bad ? p.danger : p.subtitle, size: 15, stroke: 2),
      // the clock ticks in place, so the row never reflows while it thinks
      ValueListenableBuilder<int>(
        valueListenable: _pulse,
        builder: (_, __, ___) => Text(_meta(), style: TextStyle(color: p.subtitle, fontSize: 12.5, height: 1.2, decoration: TextDecoration.none)),
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
                if (widget.linkedAbove) Container(width: 1, height: 5, color: p.divider),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: accent.withAlpha(_running ? 46 : 26), borderRadius: BorderRadius.circular(8)),
                  child: TgIcon(_tool ? (_bad ? Ic.info : Ic.gear) : Ic.ai, color: accent, size: 15, stroke: 1.9),
                ),
                if (widget.linkedBelow) Container(width: 1, height: 5, color: p.divider),
              ]),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Tap(
                onTap: body.isEmpty
                    ? null
                    : () {
                        setState(() => _pinned = !_open);
                        _follow();
                      },
                child: Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 3),
                  child: Row(children: [
                    Expanded(
                      child: Text(_title(), key: widget.titleKey, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 14.5, height: 1.25, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                    ),
                    const SizedBox(width: 8),
                    meta,
                    if (body.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 220),
                        curve: TgCurves.easeOut,
                        turns: open ? .5 : 0,
                        child: TgIcon(Ic.chevron, color: p.subtitle, size: 16, stroke: 2),
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
  /// the tail with a fade, so a long think never pushes the answer off screen.
  Widget _panel(Pal p) {
    final mono = _args.isNotEmpty;
    final style = TextStyle(color: p.msg, fontSize: mono ? 12 : 12.8, height: 1.4, fontFamily: mono ? 'monospace' : null, decoration: TextDecoration.none);
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(color: p.glassFill.withAlpha(p.dark ? 150 : 205), borderRadius: BorderRadius.circular(11), border: Border.all(color: p.divider, width: .5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (_tool) ...[
          if (_args.isNotEmpty) ...[
            _tag(p, L10n.current.traceArguments),
            Text(_args, style: style.copyWith(color: p.subtitle)),
            const SizedBox(height: 9),
          ],
          if (_result.isNotEmpty || _running) ...[
            _tag(p, L10n.current.traceResult),
            Text(_result.isEmpty ? '…' : _result, style: style),
          ],
        ] else
          Text(_think.isEmpty ? '…' : _think, style: style),
      ]),
    );

    if (!_running) return card;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _previewH),
      child: ShaderMask(
        // the fade is only painted when there is more to read, otherwise the
        // last visible line would look cut for no reason. A gradient needs two
        // colours even when it is meant to be flat.
        shaderCallback: _over ? _fade.createShader : _flat.createShader,
        blendMode: BlendMode.dstIn,
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
    final name = '${widget.msg.data['tool'] ?? ''}';
    final server = '${widget.msg.data['mcp'] ?? ''}';
    return server.isEmpty ? name : '$name · $server';
  }

  /// A finished think already carries its duration in the title, so it gets
  /// nothing here. A tool keeps it on the right, next to the state glyph.
  String _meta() {
    if (_bad) return ' ${L10n.current.traceFailed}';
    if (_running) return ' ${traceSeconds(_ms)}';
    return _tool ? ' ${traceSeconds(_ms)}' : '';
  }
}
