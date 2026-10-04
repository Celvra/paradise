import 'dart:math' as math;

import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/status.dart';
import '../core/text_utils.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'media_bubbles.dart';

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
  const BubbleView({super.key, required this.msg, required this.tail, required this.topNear, required this.maxWidth, this.replyTo, this.replyName = '', this.senderName = '', this.scroll, this.onLongPress, this.query = '', this.onRetry, this.onVote, this.onPhoto, this.onAction, this.onFileLink});
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
    final overlay = m.kind == MsgKind.photo && m.text.isEmpty;
    Widget status(Color c) {
      final s = MsgStatus(state: m.state, color: c, danger: p.danger);
      return m.state == St.failed && widget.onRetry != null ? Tap(onTap: widget.onRetry, child: s) : s;
    }

    final stamp = '${m.pinned ? '📌 ' : ''}${m.edited ? '${L10n.current.msgEdited} ' : ''}${hm(m.time)}';
    final tp = TextPainter(text: TextSpan(text: stamp, style: timeStyle), textDirection: TextDirection.ltr)..layout();
    final spacer = tp.width + (out ? 25 : 8);
    final time = Row(mainAxisSize: MainAxisSize.min, children: [
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
    final media = m.kind == MsgKind.text ? null : mediaBody(context, m: m, p: p, width: math.min(widget.maxWidth - 28, 280), out: out, timePill: overlay ? pill : null, onPhoto: widget.onPhoto, onVote: widget.onVote, onAction: widget.onAction);
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
    final sized = ConstrainedBox(constraints: BoxConstraints(maxWidth: widget.maxWidth, minWidth: 64), child: m.streaming ? AnimatedSize(duration: const Duration(milliseconds: 160), curve: TgCurves.easeOut, alignment: Alignment.topLeft, child: painted) : painted);
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

// tiny markdown fences bold italic inline code headings bullets and links
List<Widget> mdBlocks(BuildContext context, String text, TextStyle base, Color codeBg, Color accent, double spacer, {void Function(String link)? onFileLink}) {
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
      out.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        decoration: BoxDecoration(color: codeBg, borderRadius: BorderRadius.circular(8)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(b.lang.isEmpty ? context.l.codeGeneric : b.lang, style: base.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: accent)),
            const SizedBox(width: 18),
            Tap(
              onTap: () {
                Clipboard.setData(ClipboardData(text: b.text));
                showBulletin(context, context.l.toastCodeCopied);
              },
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(context.l.actionCopy, style: base.copyWith(fontSize: 12, color: accent.withAlpha(200)))),
            ),
          ]),
          const SizedBox(height: 2),
          Text(b.text, style: mono),
        ]),
      ));
      if (last) out.add(const SizedBox(height: 14));
    } else {
      final spans = _inline(b.text, base, accent, codeBg, onFileLink);
      if (last) spans.add(WidgetSpan(alignment: PlaceholderAlignment.bottom, child: SizedBox(width: spacer, height: 14)));
      out.add(Text.rich(TextSpan(children: spans), textWidthBasis: TextWidthBasis.longestLine));
    }
  }
  return out;
}

// a cited file, `[label](paradise://zone/path)`; the whole thing is the tap
// target, the label is what the reader sees
final _mdLink = RegExp(r'\[([^\]\n]+)\]\((paradise://[^)\s]+)\)');

List<InlineSpan> _inline(String text, TextStyle base, Color accent, Color codeBg, [void Function(String link)? onFileLink]) {
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
  return spans;
}

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

