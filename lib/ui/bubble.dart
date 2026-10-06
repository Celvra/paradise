import 'dart:math' as math;

import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/status.dart';
import '../core/text_utils.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'media_bubbles.dart';
import 'canvas_cards.dart';
import 'workspace/html_svg_view.dart';
import 'workspace/preview_kind.dart';

const _deg = math.pi / 180;

// MessageDrawable.generatePath ported for the tail bubble on the right
Path bubblePath(Size s, {required bool tail, required bool topNear, required double radius}) {
  const pad = 2.0;
  final w = s.width, h = s.height;
  final rad = math.min(radius, (h - pad) / 2);
  final near = math.min(6.0, radius);
  const small = 6.0;
  final rt = math.min(topNear ? near : rad, (h - pad) / 2);
  final path = Path();
  if (tail) {
    path.moveTo(w - 2.6, h - pad);
    path.lineTo(pad + rad, h - pad);
    path.arcTo(Rect.fromLTWH(pad, h - pad - rad * 2, rad * 2, rad * 2), 90 * _deg, 90 * _deg, false);
    path.lineTo(pad, pad + rad);
    path.arcTo(Rect.fromLTWH(pad, pad, rad * 2, rad * 2), 180 * _deg, 90 * _deg, false);
    path.lineTo(w - 8 - rt, pad);
    path.arcTo(Rect.fromLTWH(w - 8 - rt * 2, pad, rt * 2, rt * 2), 270 * _deg, 90 * _deg, false);
    path.lineTo(w - 8, h - pad - small - 3);
    path.arcTo(Rect.fromLTRB(w - 8, h - pad - small * 2 - 9, w - 7 + small * 2, h - pad - 1), 180 * _deg, -83 * _deg, false);
    path.close();
  } else {
    path.addRRect(RRect.fromLTRBAndCorners(pad, pad, w - 8, h - pad, topLeft: Radius.circular(rad), bottomLeft: Radius.circular(rad), topRight: Radius.circular(rt), bottomRight: Radius.circular(math.min(near, (h - pad) / 2))));
  }
  return path;
}

class BubblePainter extends CustomPainter {
  BubblePainter({required this.out, required this.tail, required this.topNear, required this.radius, required this.colors, required this.keyOf, required this.screenH, super.repaint});
  final bool out;
  final bool tail;
  final bool topNear;
  final double radius;
  final List<Color> colors;
  final GlobalKey keyOf;
  final double screenH;

  @override
  void paint(Canvas canvas, Size size) {
    final path = bubblePath(size, tail: tail, topNear: topNear, radius: radius);
    canvas.save();
    if (!out) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(path.shift(const Offset(0, 1)), Paint()..color = const Color(0x1F000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
    final paint = Paint()..isAntiAlias = true;
    final flat = colors.every((c) => c == colors.first);
    if (flat) {
      paint.color = colors.first;
    } else {
      final ro = keyOf.currentContext?.findRenderObject();
      var top = 0.0;
      if (ro is RenderBox && ro.hasSize && ro.attached) top = ro.localToGlobal(Offset.zero).dy;
      paint.shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: const [0, .35, .7, 1])
          .createShader(Rect.fromLTWH(0, -top, size.width, screenH));
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(BubblePainter o) => o.out != out || o.tail != tail || o.topNear != topNear || o.radius != radius || o.colors != colors;
}

// one message bubble text time ticks reply quote and markdown
class BubbleView extends StatefulWidget {
  const BubbleView({super.key, required this.msg, required this.tail, required this.topNear, required this.maxWidth, this.replyTo, this.replyName = '', this.senderName = '', this.scroll, this.onLongPress, this.query = '', this.onRetry, this.onVote, this.onPhoto, this.onAction, this.onFileLink, this.onAskVote, this.onAskSubmit, this.onAskSkip, this.onAskCustom});
  final Msg msg;
  final bool tail;
  final bool topNear;
  final double maxWidth;
  final Msg? replyTo;
  final String replyName;

  /// Who sent this message, used only by the recalled placeholder so it can
  /// read "X recalled a message" instead of a bare label.
  final String senderName;
  final Listenable? scroll;
  final void Function(Rect rect)? onLongPress;
  final String query;
  final VoidCallback? onRetry;
  final void Function(int)? onVote;

  /// ask card taps: vote (single closes at once, multi stages), submit,
  /// skip, and custom text edits. Null in previews, where an ask card
  /// renders inert.
  final void Function(int)? onAskVote;
  final VoidCallback? onAskSubmit;
  final VoidCallback? onAskSkip;
  final ValueChanged<String>? onAskCustom;
  final VoidCallback? onPhoto;

  /// tap on a transfer card
  final VoidCallback? onAction;

  /// Opens a workspace link the body cites, `paradise://…`. Null leaves the
  /// link as tinted text that only looks tappable, which is what the preview
  /// bubbles on the wallpaper page want.
  final void Function(String link)? onFileLink;

  @override
  State<BubbleView> createState() => _BubbleViewState();
}

class _BubbleViewState extends State<BubbleView> {
  final GlobalKey _gk = GlobalKey();

  Rect _rect() {
    final box = _gk.currentContext!.findRenderObject() as RenderBox;
    final o = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(o.dx, o.dy, box.size.width, box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final st = context.store;
    final m = widget.msg;
    final out = m.out;
    final base = TextStyle(color: out ? p.textOut : p.textIn, fontSize: st.textSize, height: 1.22, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
    // a transfer or a red packet repaints the whole bubble, so its clock and
    // ticks have to leave the normal bubble colours behind too
    final wallet = isFullBleed(m);
    final ink = wallet ? walletInk(p) : null;
    final timeStyle = TextStyle(color: wallet ? ink!.clock : (out ? p.timeOut : p.timeIn), fontSize: 12, height: 1, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
    Widget wrap(Widget child) => widget.onLongPress == null
        ? child
        : GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!(_rect());
            },
            child: child,
          );
    if (m.recalled) {
      // A recalled message never vanishes, it leaves a placeholder behind, and
      // the placeholder reads like the system line it is. Whether the reader
      // had already seen it is not announced: "already read" is a detail the
      // person being ignored does not need rubbed in.
      final l = L10n.current;
      // an unnamed persona would leave the stamp reading " recalled a message"
      final who = widget.senderName.trim();
      final label = who.isEmpty ? l.msgRecalledAnonymous : l.msgRecalled(who);
      return wrap(Container(
        key: _gk,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: p.service, borderRadius: BorderRadius.circular(14)),
        child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13, fontWeight: FontWeight.w500, height: 1.2, decoration: TextDecoration.none)),
      ));
    }
    if (m.isSticker) return wrap(SizedBox(key: _gk, child: StickerBubble(msg: m)));
    if (m.kind == MsgKind.html || m.kind == MsgKind.latex) {
      // a canvas message normally never reaches the bubble: the chat list draws
      // it flat through CanvasCard before the bubble branch runs. This is the
      // safety net for the few places that reuse the bubble outside the chat.
      final ih = (m.data['h'] as num?)?.toDouble();
      return wrap(SizedBox(
          key: _gk,
          width: double.infinity,
          child: CanvasCard(
            source: '${m.data['source'] ?? ''}',
            latex: m.kind == MsgKind.latex,
            cetz: m.data['cetz'] == true,
            align: parseCardAlign(m.data['align']),
            initialHeight: (ih != null && ih > 0 && ih <= 2000) ? ih : null,
            onHeight: (h) {
              final old = (m.data['h'] as num?)?.toDouble();
              if (old == null || (h - old).abs() > 1) m.data['h'] = h;
            },
          )));
    }
    final overlay = m.isMedia && m.text.isEmpty;
    Widget status(Color c) {
      final s = MsgStatus(state: m.state, color: c, danger: p.danger);
      return m.state == St.failed && widget.onRetry != null ? Tap(onTap: widget.onRetry, child: s) : s;
    }

    final stamp = '${m.edited ? '${L10n.current.msgEdited} ' : ''}${hm(m.time)}';
    // the pin mark is drawn, not an emoji: it has to take the clock colour and
    // read the same on every font the device may substitute for the codepoint
    final pinMark = m.pinned
        ? Padding(
            padding: const EdgeInsets.only(right: 3),
            child: TgIcon(Ic.pin, color: timeStyle.color!, size: 9, stroke: 3.2),
          )
        : null;
    final tp = TextPainter(text: TextSpan(text: stamp, style: timeStyle), textDirection: TextDirection.ltr)..layout();
    final spacer = tp.width + (pinMark != null ? 12 : 0) + (out ? 25 : 8);
    final time = Row(mainAxisSize: MainAxisSize.min, children: [
      if (pinMark != null) pinMark,
      Text(stamp, style: timeStyle),
      if (out) ...[const SizedBox(width: 4), status(wallet ? ink!.ink : p.checkOut)],
    ]);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: const Color(0x80000000), borderRadius: BorderRadius.circular(11)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(hm(m.time), style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12, height: 1, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
        if (out) ...[const SizedBox(width: 4), status(const Color(0xFFFFFFFF))],
      ]),
    );
    final hasText = (m.kind == MsgKind.text || m.text.isNotEmpty) && m.kind != MsgKind.transfer;
    final textBlocks = widget.query.isNotEmpty && m.kind == MsgKind.text
        ? <Widget>[
            Text.rich(TextSpan(children: [
              ...hlSpans(m.text, widget.query, base, p.accent, bg: p.accent.withAlpha(90)),
              WidgetSpan(alignment: PlaceholderAlignment.bottom, child: SizedBox(width: spacer, height: 14)),
            ]), textWidthBasis: TextWidthBasis.longestLine),
          ]
        : mdBlocks(context, m.text, base, out ? p.codeOut : p.codeIn, p.accent, spacer, onFileLink: widget.onFileLink);
    final media = m.kind == MsgKind.text ? null : mediaBody(context, m: m, p: p, width: math.min(widget.maxWidth - 28, 280), out: out, timePill: overlay ? pill : null, onPhoto: widget.onPhoto, onVote: widget.onVote, onAction: widget.onAction, onAskVote: widget.onAskVote, onAskSubmit: widget.onAskSubmit, onAskSkip: widget.onAskSkip, onAskCustom: widget.onAskCustom);
    final content = Stack(children: [
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.replyTo != null) _quote(p, out, base),
        if (media != null) Padding(padding: EdgeInsets.only(bottom: hasText ? 6 : 0), child: media),
        if (hasText) ...textBlocks else if (!overlay && m.kind != MsgKind.poll && m.kind != MsgKind.transfer) const SizedBox(height: 16),
      ]),
      if (!overlay) Positioned(right: 0, bottom: 0, child: time),
    ]);
    final body = Padding(
      // bubblePath draws the fill 2px in on the left and 6px in on the right, so
      // a wallet card needs 14 and 18 here to sit 14px off the colour on both
      // sides. The plain 11/17 pair below is the text bubble, whose tail side
      // already gives the clock its room.
      padding: wallet
          ? const EdgeInsets.fromLTRB(14, 12, 18, 10)
          : (overlay ? EdgeInsets.fromLTRB(out ? 3 : 9, 3, out ? 9 : 3, 3) : EdgeInsets.fromLTRB(out ? 11 : 17, 9, out ? 17 : 11, 8)),
      child: content,
    );
    final painted = CustomPaint(
      key: _gk,
      painter: BubblePainter(
        out: out,
        tail: widget.tail,
        topNear: widget.topNear,
        radius: st.bubbleRadius,
        // a transfer or a red packet repaints the entire bubble, tail and
        // corners included, so the card above only has to place ink on the fill
        colors: wallet
            ? walletFill(p, red: m.data['kind'] == 'redpacket', done: '${m.data['status'] ?? 'pending'}' != 'pending')
            : (out ? p.outGrad : [p.inBubble]),
        keyOf: _gk,
        screenH: MediaQuery.of(context).size.height,
        repaint: widget.scroll,
      ),
      child: body,
    );
    // AnimatedSize wraps every bubble, not just a streaming one: a code block
    // toggling wrap, a preview opening or an edited text reshape the bubble
    // after it has landed, and a jump between sizes reads as a glitch. The
    // streaming duration stays the snappier of the two.
    final sized = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth, minWidth: 64),
      child: AnimatedSize(
        duration: Duration(milliseconds: m.streaming ? 160 : 220),
        curve: TgCurves.easeOut,
        alignment: Alignment.topLeft,
        child: painted,
      ),
    );
    return wrap(sized);
  }

  Widget _quote(Pal p, bool out, TextStyle base) {
    final line = out ? p.lineOut : p.lineIn;
    final r = widget.replyTo!;
    final preview = r.preview;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 1),
      child: IntrinsicHeight(
        child: Container(
          decoration: BoxDecoration(color: line.withAlpha(34), borderRadius: BorderRadius.circular(5)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Container(width: 2.5, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(2))),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.replyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: out ? p.nameOut : p.nameIn, fontSize: 14, fontWeight: FontWeight.w500, height: 1.2, decoration: TextDecoration.none)),
                  Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: base.copyWith(fontSize: 14, height: 1.2)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Blk {
  _Blk(this.code, this.text, this.lang);
  final bool code;
  final String text;
  final String lang;
}

// tiny markdown fences bold italic inline code headings bullets and links, plus
// latex spans and syntax highlighted code blocks
List<Widget> mdBlocks(BuildContext context, String text, TextStyle base, Color codeBg, Color accent, double spacer, {void Function(String link)? onFileLink, void Function(String link)? onWebLink}) {
  final blocks = <_Blk>[];
  final buf = <String>[];
  var inCode = false;
  var lang = '';
  for (final line in text.split('\n')) {
    final t = line.trimLeft();
    if (t.startsWith('```')) {
      if (inCode) {
        blocks.add(_Blk(true, buf.join('\n'), lang));
        buf.clear();
        inCode = false;
      } else {
        if (buf.isNotEmpty) blocks.add(_Blk(false, buf.join('\n'), ''));
        buf.clear();
        inCode = true;
        lang = t.substring(3).trim();
      }
    } else {
      buf.add(line);
    }
  }
  if (buf.isNotEmpty || inCode) blocks.add(_Blk(inCode, buf.join('\n'), lang));
  while (blocks.isNotEmpty && !blocks.last.code && blocks.last.text.trim().isEmpty) {
    blocks.removeLast();
  }
  if (blocks.isEmpty) blocks.add(_Blk(false, '', ''));
  final mono = base.copyWith(fontFamily: 'monospace', fontSize: math.max(11, base.fontSize! - 2), height: 1.3);
  final out = <Widget>[];
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    final last = i == blocks.length - 1;
    if (b.code) {
      out.add(_CodeBlock(blk: b, base: base, mono: mono, codeBg: codeBg, accent: accent));
      if (last) out.add(const SizedBox(height: 14));
    } else {
      final spans = _inline(b.text, base, accent, codeBg, onFileLink, onWebLink);
      if (last) spans.add(WidgetSpan(alignment: PlaceholderAlignment.bottom, child: SizedBox(width: spacer, height: 14)));
      out.add(Text.rich(TextSpan(children: spans), textWidthBasis: TextWidthBasis.longestLine));
    }
  }
  return out;
}

/// One fenced code block in a bubble: header with the language, a wrap toggle,
/// a preview button for html and svg, and the code itself with syntax
/// highlighting over a horizontal scroll, so nothing is ever cut off.
class _CodeBlock extends StatefulWidget {
  const _CodeBlock({required this.blk, required this.base, required this.mono, required this.codeBg, required this.accent});
  final _Blk blk;
  final TextStyle base;
  final TextStyle mono;
  final Color codeBg;
  final Color accent;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  // the reader asked for wrapping; a fresh bubble starts unwrapped, an IDE
  // layout where every line keeps its own row and a long line scrolls
  bool _wrap = false;

  static const _previewable = {'html', 'htm', 'xml', 'svg'};

  bool get _canPreview {
    final lang = widget.blk.lang.toLowerCase();
    if (_previewable.contains(lang)) return true;
    // a fence with no language may still smell like html or svg
    final t = widget.blk.text.trimLeft();
    return widget.blk.lang.isEmpty && (t.startsWith('<!DOCTYPE html') || t.startsWith('<svg') || (t.startsWith('<') && t.contains('</html>')));
  }

  void _openPreview() {
    final l = L10n.current;
    final lang = widget.blk.lang.toLowerCase();
    final kind = lang.contains('svg') || widget.blk.text.trimLeft().startsWith('<svg') ? PreviewKind.image : PreviewKind.html;
    showSnippetPreview(context, widget.blk.text, kind: kind, title: lang.isEmpty ? l.codePreview : lang);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.blk;
    final p = context.p;
    final dark = p.dark;
    final theme = dark ? atomOneDarkTheme : githubTheme;
    final codeStyle = widget.mono.copyWith(color: dark ? const Color(0xFFABB2BF) : const Color(0xFF383A42));
    final spans = previewSpans(b.text, _langForHighlight(b.lang), theme, codeStyle);
    final accent = widget.accent;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(color: widget.codeBg, borderRadius: BorderRadius.circular(8)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(b.lang.isEmpty ? context.l.codeGeneric : b.lang, style: widget.base.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: accent)),
          const SizedBox(width: 18),
          Tap(
            onTap: () => setState(() => _wrap = !_wrap),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: TgIcon(Ic.wrap, color: _wrap ? accent : accent.withAlpha(140), size: 14, stroke: 2.2),
            ),
          ),
          if (_canPreview) ...[
            const SizedBox(width: 12),
            Tap(
              onTap: _openPreview,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: TgIcon(Ic.eye, color: accent.withAlpha(200), size: 14, stroke: 2),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Tap(
            onTap: () {
              Clipboard.setData(ClipboardData(text: b.text));
              showBulletin(context, context.l.toastCodeCopied);
            },
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(context.l.actionCopy, style: widget.base.copyWith(fontSize: 12, color: accent.withAlpha(200)))),
          ),
        ]),
        const SizedBox(height: 2),
        // Both modes size the block the same way: hug the longest line up to
        // the room the bubble has, scroll or wrap the rest. That keeps the
        // toggle a pure reshuffle of the same box, and the AnimatedSize is
        // what turns the reshuffle into a glide instead of a jump — the
        // bubble background above repaints at every intermediate size.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: TgCurves.easeOut,
          alignment: Alignment.topLeft,
          child: LayoutBuilder(builder: (context, constraints) {
            final scaler = MediaQuery.textScalerOf(context);
            final painter = TextPainter(
              text: TextSpan(children: spans, style: codeStyle),
              textDirection: TextDirection.ltr,
              textScaler: scaler,
            )..layout();
            final natural = painter.maxIntrinsicWidth;
            painter.dispose();
            final width = math.min(natural, constraints.maxWidth);
            return SizedBox(
              width: width,
              child: _wrap
                  ? _codeText(spans, codeStyle)
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _codeText(spans, codeStyle),
                    ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _codeText(List<InlineSpan> spans, TextStyle style) => Text.rich(
        TextSpan(children: spans),
        style: style,
        // soft wrap keeps a long line readable when wrap is on; the strut is
        // not needed here because the whole block is one paragraph
        softWrap: true,
      );
}

/// The highlight grammar for a fence label, or null to leave plain. The labels
/// models actually write are matched loosely: "py", "python3" and "Python" all
/// want the python grammar.
String? _langForHighlight(String lang) {
  final l = lang.trim().toLowerCase();
  if (l.isEmpty) return null;
  const aliases = {
    'py': 'python', 'python3': 'python', 'py3': 'python',
    'js': 'javascript', 'node': 'javascript', 'nodejs': 'javascript', 'jsx': 'javascript',
    'ts': 'typescript', 'tsx': 'typescript',
    'sh': 'bash', 'shell': 'bash', 'zsh': 'bash', 'console': 'bash', 'terminal': 'bash',
    'yml': 'yaml',
    'c++': 'cpp', 'cc': 'cpp', 'cxx': 'cpp', 'hpp': 'cpp',
    'cs': 'csharp', 'c#': 'csharp',
    'kt': 'kotlin',
    'rb': 'ruby',
    'golang': 'go',
    'rs': 'rust',
    'htm': 'xml', 'svg': 'xml', 'html': 'xml',
    'docker': 'dockerfile',
    'tex': 'latex', 'latex': 'latex',
    'md': 'markdown',
  };
  return aliases[l] ?? l;
}

// a cited file, `[label](paradise://zone/path)`; the whole thing is the tap
// target, the label is what the reader sees
final _mdLink = RegExp(r'\[([^\]\n]+)\]\((paradise://[^)\s]+)\)');

/// Splits a stretch of plain text on the file links it cites. A link with a
/// handler becomes the label underlined and tinted with its own tap target; a
/// bare `paradise://…` url is the same thing with the url as its label. The
/// recognizer is disposed by the span tree, a GestureRecognizer sink of one.
List<TextSpan> _withLinks(String text, TextStyle style, Color accent, void Function(String link)? onFileLink) {
  if (!text.contains('paradise://') || onFileLink == null) return [TextSpan(text: text, style: style)];
  final out = <TextSpan>[];
  var at = 0;
  for (final m in _mdLink.allMatches(text)) {
    if (m.start > at) out.add(TextSpan(text: text.substring(at, m.start), style: style));
    out.add(_linkSpan(m.group(1)!, m.group(2)!, style, accent, onFileLink));
    at = m.end;
  }
  // a bare link with no label: the url itself, up to whitespace
  final rest = text.substring(at);
  final bare = RegExp('paradise://[^\\s)]+');
  var b = 0;
  for (final m in bare.allMatches(rest)) {
    if (m.start > b) out.add(TextSpan(text: rest.substring(b, m.start), style: style));
    out.add(_linkSpan(m.group(0)!, m.group(0)!, style, accent, onFileLink));
    b = m.end;
  }
  if (b < rest.length) out.add(TextSpan(text: rest.substring(b), style: style));
  return out;
}

TextSpan _linkSpan(String label, String link, TextStyle style, Color accent, void Function(String) onFileLink) {
  final rec = TapGestureRecognizer()..onTap = () => onFileLink(link);
  return TextSpan(
    text: label,
    style: style.copyWith(color: accent, decoration: TextDecoration.underline, decorationColor: accent.withAlpha(120)),
    recognizer: rec,
  );
}

// markdown and bare web links, `[label](https://…)` and a `https://…` on its
// own. Opt-in per call site: bubbles leave them plain (see bubble_link_test),
// the update sheet tints and taps them.
final _mdWebLink = RegExp(r'\[([^\]\n]+)\]\((https?://[^)\s]+)\)');
final _bareWeb = RegExp(r'https?://[^\s)\]]+');

/// Second link pass over the spans [_withLinks] left alone. Only plain spans
/// with no recognizer are split, so file links and inline code are never
/// re-eaten. A null [onTap] keeps every byte as it was.
List<InlineSpan> _linkifyWeb(List<InlineSpan> spans, Color accent, void Function(String link)? onTap) {
  if (onTap == null) return spans;
  final out = <InlineSpan>[];
  for (final s in spans) {
    if (s is! TextSpan || s.text == null || s.recognizer != null || s.style?.fontFamily == 'monospace') {
      out.add(s);
      continue;
    }
    out.addAll(_splitWeb(s.text!, s.style, accent, onTap));
  }
  return out;
}

List<TextSpan> _splitWeb(String text, TextStyle? style, Color accent, void Function(String) onTap) {
  final out = <TextSpan>[];
  var at = 0;
  for (final m in _mdWebLink.allMatches(text)) {
    if (m.start > at) out.addAll(_bareSpans(text.substring(at, m.start), style, accent, onTap));
    out.add(_webSpan(m.group(1)!, m.group(2)!, style, accent, onTap));
    at = m.end;
  }
  if (at < text.length) out.addAll(_bareSpans(text.substring(at), style, accent, onTap));
  if (out.isEmpty) out.add(TextSpan(text: text, style: style));
  return out;
}

/// Bare urls in a stretch with no markdown link left. Trailing punctuation is
/// not part of the address: a `https://x/y.` at the end of a sentence links
/// without its full stop, and the same goes for the CJK `。` release notes in
/// Chinese end with.
List<TextSpan> _bareSpans(String text, TextStyle? style, Color accent, void Function(String) onTap) {
  final out = <TextSpan>[];
  var at = 0;
  for (final m in _bareWeb.allMatches(text)) {
    var url = m.group(0)!;
    var end = m.end;
    while (url.length > 1 && '.,;:!?。，；：！？）'.contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
      end--;
    }
    if (m.start > at) out.add(TextSpan(text: text.substring(at, m.start), style: style));
    out.add(_webSpan(url, url, style, accent, onTap));
    if (end < m.end) out.add(TextSpan(text: text.substring(end, m.end), style: style));
    at = m.end;
  }
  if (at < text.length) out.add(TextSpan(text: text.substring(at), style: style));
  if (out.isEmpty) out.add(TextSpan(text: text, style: style));
  return out;
}

TextSpan _webSpan(String label, String url, TextStyle? style, Color accent, void Function(String) onTap) {
  final rec = TapGestureRecognizer()..onTap = () => onTap(url);
  final base = style ?? const TextStyle();
  return TextSpan(
    text: label,
    style: base.copyWith(color: accent, decoration: TextDecoration.underline, decorationColor: accent.withAlpha(120)),
    recognizer: rec,
  );
}

// one latex span. $$..$$ display first so $$ is never eaten as two $..$ pairs,
// then \[..\] and \(..\), then the plain $..$ pair. The patterns never cross a
// line break inside a $..$ span: a price like "$5\nand" must not become math.
final _latex = RegExp(r'\$\$([^$]+?)\$\$|\\\[([\s\S]+?)\\\]|\\\((.+?)\\\)|\$(?!\s)([^$\n]+?)(?<!\s)\$');

List<InlineSpan> _inline(String text, TextStyle base, Color accent, Color codeBg, [void Function(String link)? onFileLink, void Function(String link)? onWebLink]) {
  final spans = <InlineSpan>[];
  final lines = text.split('\n');
  final re = RegExp(r'(\*\*[^*\n]+\*\*|`[^`\n]+`|\*[^*\n\s][^*\n]*\*)');
  for (var li = 0; li < lines.length; li++) {
    var line = lines[li];
    var style = base;
    final h = RegExp(r'^\s{0,3}#{1,6}\s+').firstMatch(line);
    if (h != null) {
      line = line.substring(h.end);
      style = base.copyWith(fontWeight: FontWeight.w600);
    }
    final b = RegExp(r'^(\s*)[-*]\s+').firstMatch(line);
    if (b != null) line = '${b.group(1)}\u2022 ${line.substring(b.end)}';
    var at = 0;
    for (final m in re.allMatches(line)) {
      if (m.start > at) spans.addAll(_withLinks(line.substring(at, m.start), style, accent, onFileLink));
      final s = m.group(0)!;
      if (s.startsWith('**')) {
        spans.addAll(_withLinks(s.substring(2, s.length - 2), style.copyWith(fontWeight: FontWeight.w600), accent, onFileLink));
      } else if (s.startsWith('`')) {
        spans.add(TextSpan(text: s.substring(1, s.length - 1), style: style.copyWith(fontFamily: 'monospace', fontSize: style.fontSize! - 1.5, backgroundColor: codeBg)));
      } else {
        spans.addAll(_withLinks(s.substring(1, s.length - 1), style.copyWith(fontStyle: FontStyle.italic), accent, onFileLink));
      }
      at = m.end;
    }
    if (at < line.length) spans.addAll(_withLinks(line.substring(at), style, accent, onFileLink));
    if (li < lines.length - 1) spans.add(TextSpan(text: '\n', style: style));
  }
  return _latexify(_linkifyWeb(spans, accent, onWebLink), base);
}

/// Second pass over the flat span list: any plain-text span is split again on
/// the latex delimiters, each formula becomes a Math widget span in the flow.
///
/// A formula the parser cannot read falls back to its raw text, an equation
/// must never blank out the sentence around it. Display math gets its own
/// centered line by splitting the hosting text span around it.
List<InlineSpan> _latexify(List<InlineSpan> spans, TextStyle base) {
  var hasDollar = false;
  for (final s in spans) {
    if (s is TextSpan && (s.text?.contains(r'$') == true || s.text?.contains(r'\(') == true || s.text?.contains(r'\[') == true)) {
      hasDollar = true;
      break;
    }
  }
  if (!hasDollar) return spans;
  final out = <InlineSpan>[];
  for (final s in spans) {
    if (s is TextSpan && s.text != null && s.style?.fontFamily != 'monospace') {
      out.addAll(_latexSpan(s, base));
    } else {
      out.add(s);
    }
  }
  return out;
}

List<InlineSpan> _latexSpan(TextSpan span, TextStyle base) {
  final text = span.text!;
  if (!_latex.hasMatch(text)) return [span];
  final style = span.style ?? base;
  final out = <InlineSpan>[];
  var at = 0;
  for (final m in _latex.allMatches(text)) {
    if (m.start > at) out.add(TextSpan(text: text.substring(at, m.start), style: style));
    final tex = m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4) ?? '';
    final display = m.group(1) != null || m.group(2) != null;
    final trimmed = tex.trim();
    out.add(WidgetSpan(
      alignment: display ? PlaceholderAlignment.middle : PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: _MathView(tex: trimmed, display: display, base: style, raw: m.group(0)!),
    ));
    at = m.end;
  }
  if (at < text.length) out.add(TextSpan(text: text.substring(at), style: style));
  return out;
}

/// One formula. [flutter_math_fork] throws on input it cannot parse, which in
/// a chat is usually a half written formula mid-stream, so every parse is
/// guarded and a failure shows the raw dollars text instead.
class _MathView extends StatelessWidget {
  const _MathView({required this.tex, required this.display, required this.base, required this.raw});
  final String tex;
  final bool display;
  final TextStyle base;
  final String raw;

  @override
  Widget build(BuildContext context) {
    try {
      final expr = Math.tex(
        tex,
        textStyle: base.copyWith(fontSize: (base.fontSize ?? 14) * 1.12, height: 1.25, fontFamily: null, decoration: TextDecoration.none),
      );
      return display
          ? Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: expr,
            )
          : expr;
    } catch (_) {
      // half written or unsupported syntax: keep the characters the author
      // wrote rather than a blank gap
      return Text(raw, style: base);
    }
  }
}
