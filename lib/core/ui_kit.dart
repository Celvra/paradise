import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show materialTextSelectionControls;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'anim.dart';
import 'glyphs.dart';
import 'theme.dart';

// frosted pill used by the glass ui in chat and main tabs
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 22, this.width, this.height});
  final Widget child;
  final double radius;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final r = BorderRadius.circular(radius);
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(color: p.glassFill, borderRadius: r, border: Border.all(color: p.glassStroke, width: 0.6)),
            child: child,
          ),
        ),
      ),
    );
  }
}

enum Ic { back, more, search, close, pencil, send, stop, ai, pin, pinTilt, mute, unmute, down, reply, copy, regen, trash, chats, gear, moon, key, globe, textSize, corner, check, attach, smile, keyboard, sticker, image, file, pinLoc, music, poll, user, calendar, up, chevron, info, share, camera, link, unread, readAll, storage, palette, bell, plus, drag, list, backspace, check2, video, at, lock, crown, hongbao, wallet }

// every glyph is stroked on a 24 grid
class TgIcon extends StatelessWidget {
  const TgIcon(this.ic, {super.key, required this.color, this.size = 24, this.stroke = 2});
  final Ic ic;
  final Color color;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _IconPainter(ic, color, stroke));
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.ic, this.color, this.stroke);
  final Ic ic;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final sp = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fp = Paint()..color = color;
    final p = Path();
    switch (ic) {
      case Ic.back:
        p
          ..moveTo(20, 12)
          ..lineTo(5, 12)
          ..moveTo(11, 6)
          ..lineTo(5, 12)
          ..lineTo(11, 18);
        canvas.drawPath(p, sp);
      case Ic.more:
        for (final y in [5.0, 12.0, 19.0]) {
          canvas.drawCircle(Offset(12, y), 1.9, fp);
        }
      case Ic.search:
        canvas.drawCircle(const Offset(10.5, 10.5), 6.5, sp);
        canvas.drawLine(const Offset(15.4, 15.4), const Offset(20, 20), sp);
      case Ic.close:
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), sp);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), sp);
      case Ic.pencil:
        p
          ..moveTo(4.5, 19.5)
          ..lineTo(5.6, 15)
          ..lineTo(16.2, 4.4)
          ..lineTo(19.6, 7.8)
          ..lineTo(9, 18.4)
          ..close()
          ..moveTo(14, 6.6)
          ..lineTo(17.4, 10);
        canvas.drawPath(p, sp);
      case Ic.send:
        p
          ..moveTo(12, 19)
          ..lineTo(12, 5)
          ..moveTo(5.5, 11.5)
          ..lineTo(12, 5)
          ..lineTo(18.5, 11.5);
        canvas.drawPath(p, sp..strokeWidth = stroke + .4);
      case Ic.stop:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(7, 7, 10, 10), const Radius.circular(2.4)), fp);
      case Ic.ai:
        final star = Path()
          ..moveTo(11, 3)
          ..cubicTo(11.7, 8, 14, 10.3, 19, 11)
          ..cubicTo(14, 11.7, 11.7, 14, 11, 19)
          ..cubicTo(10.3, 14, 8, 11.7, 3, 11)
          ..cubicTo(8, 10.3, 10.3, 8, 11, 3)
          ..close();
        canvas.drawPath(star, sp..strokeWidth = stroke * .8);
        final small = Path()
          ..moveTo(18.2, 15)
          ..cubicTo(18.4, 16.6, 19, 17.2, 20.6, 17.4)
          ..cubicTo(19, 17.6, 18.4, 18.2, 18.2, 19.8)
          ..cubicTo(18, 18.2, 17.4, 17.6, 15.8, 17.4)
          ..cubicTo(17.4, 17.2, 18, 16.6, 18.2, 15)
          ..close();
        canvas.drawPath(small, fp);
      case Ic.pin:
        p
          ..moveTo(8, 3.5)
          ..lineTo(16, 3.5)
          ..lineTo(15, 9.5)
          ..lineTo(18, 13)
          ..lineTo(6, 13)
          ..lineTo(9, 9.5)
          ..close();
        canvas.drawPath(p, fp);
        canvas.drawLine(const Offset(12, 13), const Offset(12, 21), sp..strokeWidth = 2);
      // same pin turned 0.6rad and rescaled so its ink fills the whole 24 grid,
      // that lets the dialog row align it by its right edge with the date
      case Ic.pinTilt:
        p
          ..moveTo(12.3, 0)
          ..lineTo(21.78, 6.48)
          ..lineTo(15.73, 12.79)
          ..lineTo(16.45, 19.38)
          ..lineTo(2.21, 9.65)
          ..lineTo(8.62, 7.92)
          ..close();
        canvas.drawPath(p, fp);
        canvas.drawLine(const Offset(9.34, 14.52), const Offset(2.84, 24), sp..strokeWidth = 1.8);
      case Ic.mute:
      case Ic.unmute:
        p
          ..moveTo(3, 9.5)
          ..lineTo(7, 9.5)
          ..lineTo(12, 5)
          ..lineTo(12, 19)
          ..lineTo(7, 14.5)
          ..lineTo(3, 14.5)
          ..close();
        canvas.drawPath(p, ic == Ic.mute ? fp : sp);
        if (ic == Ic.mute) {
          canvas.drawLine(const Offset(15.5, 9.5), const Offset(20.5, 14.5), sp..strokeWidth = 1.8);
          canvas.drawLine(const Offset(20.5, 9.5), const Offset(15.5, 14.5), sp);
        } else {
          final w = Path()
            ..moveTo(15.5, 9)
            ..quadraticBezierTo(18, 12, 15.5, 15)
            ..moveTo(18, 6.5)
            ..quadraticBezierTo(22.5, 12, 18, 17.5);
          canvas.drawPath(w, sp..strokeWidth = 1.8);
        }
      case Ic.down:
        p
          ..moveTo(6, 9)
          ..lineTo(12, 15)
          ..lineTo(18, 9);
        canvas.drawPath(p, sp);
      case Ic.reply:
        p
          ..moveTo(9.5, 6.5)
          ..lineTo(4, 12)
          ..lineTo(9.5, 17.5)
          ..moveTo(4.5, 12)
          ..lineTo(14, 12)
          ..arcToPoint(const Offset(20, 18), radius: const Radius.circular(6), clockwise: true)
          ..lineTo(20, 19);
        canvas.drawPath(p, sp);
      case Ic.copy:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8.5, 8.5, 11, 11), const Radius.circular(2.5)), sp);
        p
          ..moveTo(15.5, 5.5)
          ..lineTo(15.5, 5.5)
          ..lineTo(6.5, 5.5)
          ..arcToPoint(const Offset(4.5, 7.5), radius: const Radius.circular(2), clockwise: false)
          ..lineTo(4.5, 15.5)
          ..arcToPoint(const Offset(6.5, 17.5), radius: const Radius.circular(2), clockwise: false);
        canvas.drawPath(p, sp);
      case Ic.regen:
        canvas.drawArc(const Rect.fromLTWH(4.5, 4.5, 15, 15), -0.5, 5.2, false, sp);
        p
          ..moveTo(15.2, 3.4)
          ..lineTo(18.6, 5.8)
          ..lineTo(15.6, 8.6);
        canvas.drawPath(p, sp);
      case Ic.trash:
        p
          ..moveTo(4.5, 7)
          ..lineTo(19.5, 7)
          ..moveTo(9.5, 7)
          ..lineTo(9.5, 4.5)
          ..lineTo(14.5, 4.5)
          ..lineTo(14.5, 7)
          ..moveTo(6.6, 7)
          ..lineTo(7.6, 19.5)
          ..lineTo(16.4, 19.5)
          ..lineTo(17.4, 7)
          ..moveTo(10.2, 11)
          ..lineTo(10.2, 16)
          ..moveTo(13.8, 11)
          ..lineTo(13.8, 16);
        canvas.drawPath(p, sp..strokeWidth = stroke * .85);
      case Ic.chats:
        p
          ..moveTo(12, 3.8)
          ..cubicTo(7, 3.8, 3, 7.2, 3, 11.4)
          ..cubicTo(3, 13.8, 4.3, 15.9, 6.3, 17.3)
          ..lineTo(5.4, 20.6)
          ..lineTo(9.3, 18.6)
          ..cubicTo(10.1, 18.8, 11, 19, 12, 19)
          ..cubicTo(17, 19, 21, 15.6, 21, 11.4)
          ..cubicTo(21, 7.2, 17, 3.8, 12, 3.8)
          ..close();
        canvas.drawPath(p, sp);
      case Ic.gear:
        const n = 8;
        for (var i = 0; i < n; i++) {
          final b = i * 2 * math.pi / n;
          for (final e in [(7.2, -.3), (9.6, -.17), (9.6, .17), (7.2, .3)]) {
            final a = b + e.$2;
            final pt = Offset(12 + e.$1 * math.cos(a), 12 + e.$1 * math.sin(a));
            if (i == 0 && e.$2 == -.3) {
              p.moveTo(pt.dx, pt.dy);
            } else {
              p.lineTo(pt.dx, pt.dy);
            }
          }
        }
        p.close();
        canvas.drawPath(p, sp..strokeWidth = stroke * .85);
        canvas.drawCircle(const Offset(12, 12), 3, sp);
      case Ic.moon:
        p
          ..moveTo(20, 14.6)
          ..arcToPoint(const Offset(9.4, 4), radius: const Radius.circular(8.6), clockwise: true, largeArc: true)
          ..arcToPoint(const Offset(20, 14.6), radius: const Radius.circular(7), clockwise: false);
        canvas.drawPath(p, sp);
      case Ic.key:
        canvas.drawCircle(const Offset(8, 15.5), 4, sp);
        canvas.drawLine(const Offset(10.9, 12.6), const Offset(20, 3.6), sp);
        canvas.drawLine(const Offset(16.8, 6.8), const Offset(19.4, 9.4), sp);
      case Ic.globe:
        canvas.drawCircle(const Offset(12, 12), 9, sp);
        canvas.drawOval(const Rect.fromLTWH(7.6, 3, 8.8, 18), sp);
        canvas.drawLine(const Offset(3, 12), const Offset(21, 12), sp);
      case Ic.textSize:
        p
          ..moveTo(3.5, 19)
          ..lineTo(8.5, 5.5)
          ..lineTo(13.5, 19)
          ..moveTo(5.2, 14.5)
          ..lineTo(11.8, 14.5)
          ..moveTo(15.5, 19)
          ..lineTo(18.5, 11)
          ..lineTo(21.5, 19)
          ..moveTo(16.5, 16.5)
          ..lineTo(20.5, 16.5);
        canvas.drawPath(p, sp..strokeWidth = stroke * .9);
      case Ic.corner:
        p
          ..moveTo(4.5, 19.5)
          ..lineTo(4.5, 12)
          ..arcToPoint(const Offset(12, 4.5), radius: const Radius.circular(7.5))
          ..lineTo(19.5, 4.5);
        canvas.drawPath(p, sp);
      case Ic.check:
        p
          ..moveTo(5, 12.5)
          ..lineTo(10, 17.5)
          ..lineTo(19, 7);
        canvas.drawPath(p, sp);
      default:
        paintGlyph(canvas, ic, sp, fp);
    }
  }

  @override
  bool shouldRepaint(_IconPainter o) => o.ic != ic || o.color != color || o.stroke != stroke;
}

// gradient circle avatar like dialog cells, a photo path wins over the initial
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, required this.color, this.size = 52, this.path = ''});
  final String name;
  final int color;
  final double size;
  final String path;

  @override
  Widget build(BuildContext context) {
    final g = avatarColors[color % avatarColors.length];
    final ch = name.trim().isEmpty ? '?' : String.fromCharCodes(name.trim().runes.take(1)).toUpperCase();
    if (path.isNotEmpty) {
      return ClipOval(
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: g)),
            child: Text(ch, style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: size * .42, fontWeight: FontWeight.w500, height: 1.1)),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: g)),
      child: Text(ch, style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: size * .42, fontWeight: FontWeight.w500, height: 1.1)),
    );
  }
}

// TypingDotsDrawable port three dots staggered by 150ms
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, required this.color});
  final Color color;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(18, 14), painter: _DotsPainter(_c, widget.color));
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.c, this.color) : super(repaint: c);
  final AnimationController c;
  final Color color;

  double _d(double x) => 1 - (1 - x) * (1 - x);

  @override
  void paint(Canvas canvas, Size size) {
    final ms = c.value * 800;
    final paint = Paint()..color = color;
    for (var i = 0; i < 3; i++) {
      final ph = ((ms - 150 * i) % 800 + 800) % 800;
      final s = ph < 320 ? 1.33 + _d(ph / 320) : (ph < 640 ? 1.33 + (1 - _d((ph - 320) / 320)) : 1.33);
      canvas.drawCircle(Offset(3.0 + 6 * i, 10), s, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter o) => o.color != color;
}

class TgSwitch extends StatelessWidget {
  const TgSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 200),
        curve: TgCurves.easeOut,
        builder: (_, t, __) => SizedBox(
          width: 44,
          height: 26,
          child: Stack(children: [
            Container(decoration: BoxDecoration(color: Color.lerp(p.unreadMuted, p.accent, t), borderRadius: BorderRadius.circular(13))),
            Positioned(left: 3 + 18 * t, top: 3, child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Color(0xFFFFFFFF), shape: BoxShape.circle))),
          ]),
        ),
      ),
    );
  }
}

// seekbar with a thumb that grows while dragging
class TgSlider extends StatefulWidget {
  const TgSlider({super.key, required this.value, required this.min, required this.max, required this.onChanged, this.step = 1});
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// Granularity of the value. The default 1 suits the integer sliders, but a
  /// 0 to 1 probability has to move in hundredths or the thumb only ever lands
  /// on the two ends and every setting in between is unreachable.
  final double step;

  @override
  State<TgSlider> createState() => _TgSliderState();
}

class _TgSliderState extends State<TgSlider> {
  bool _drag = false;

  void _at(double dx, double w) {
    final t = ((dx - 14) / (w - 28)).clamp(0.0, 1.0);
    // snapped to the step and never past either end, a 0 to 0.6 slider snapped
    // to whole numbers could only ever say 0 or 1
    final raw = widget.min + (widget.max - widget.min) * t;
    final snapped = (raw / widget.step).roundToDouble() * widget.step;
    widget.onChanged(snapped.clamp(widget.min, widget.max));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          setState(() => _drag = true);
          _at(d.localPosition.dx, w);
        },
        onTapUp: (_) => setState(() => _drag = false),
        onTapCancel: () => setState(() => _drag = false),
        onHorizontalDragStart: (_) => setState(() => _drag = true),
        onHorizontalDragUpdate: (d) => _at(d.localPosition.dx, w),
        onHorizontalDragEnd: (_) => setState(() => _drag = false),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _drag ? 9.0 : 6.0),
          duration: const Duration(milliseconds: 150),
          builder: (_, r, __) => CustomPaint(
            size: Size(w, 40),
            painter: _SliderPainter((widget.value - widget.min) / (widget.max - widget.min), r, p.accent, p.divider),
          ),
        ),
      );
    });
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter(this.t, this.r, this.active, this.inactive);
  final double t;
  final double r;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const x0 = 14.0;
    final x1 = size.width - 14;
    final x = x0 + (x1 - x0) * t;
    final line = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x0, y), Offset(x1, y), line..color = inactive);
    canvas.drawLine(Offset(x0, y), Offset(x, y), line..color = active);
    canvas.drawCircle(Offset(x, y), r, Paint()..color = active);
  }

  @override
  bool shouldRepaint(_SliderPainter o) => o.t != t || o.r != r || o.active != active;
}

// bare EditableText with tap and long press wired up by hand
class TgEdit extends StatefulWidget {
  const TgEdit({
    super.key,
    required this.controller,
    this.hint = '',
    this.style,
    this.hintStyle,
    this.maxLines = 1,
    this.obscure = false,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
    this.cursor,
    this.focusNode,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String hint;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final int? maxLines;
  final bool obscure;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Color? cursor;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;

  @override
  State<TgEdit> createState() => _TgEditState();
}

class _TgEditState extends State<TgEdit> {
  final GlobalKey<EditableTextState> _key = GlobalKey();
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final style = widget.style ?? TextStyle(color: p.title, fontSize: 17);
    final hintStyle = widget.hintStyle ?? style.copyWith(color: p.hint);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final s = _key.currentState;
        if (s == null) return;
        s.renderEditable.selectPositionAt(from: d.globalPosition, cause: SelectionChangedCause.tap);
        s.requestKeyboard();
      },
      onLongPressStart: (d) {
        final s = _key.currentState;
        if (s == null) return;
        s.requestKeyboard();
        s.renderEditable.selectWordsInRange(from: d.globalPosition, cause: SelectionChangedCause.longPress);
        s.showToolbar();
      },
      child: Stack(alignment: Alignment.centerLeft, children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (_, v, __) => v.text.isEmpty ? IgnorePointer(child: Text(widget.hint, style: hintStyle, maxLines: 1)) : const SizedBox.shrink(),
        ),
        EditableText(
          key: _key,
          controller: widget.controller,
          focusNode: _focus,
          style: style,
          cursorColor: widget.cursor ?? p.accent,
          backgroundCursorColor: p.divider,
          selectionColor: p.accent.withAlpha(70),
          selectionControls: materialTextSelectionControls,
          cursorWidth: 2,
          cursorRadius: const Radius.circular(1),
          maxLines: widget.maxLines,
          minLines: 1,
          obscureText: widget.obscure,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType ?? (widget.maxLines == 1 ? TextInputType.text : TextInputType.multiline),
          textInputAction: widget.maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          rendererIgnoresPointer: true,
        ),
      ]),
    );
  }
}

// underlined field like EditTextBoldCursor used in dialogs
class TgField extends StatefulWidget {
  const TgField({super.key, required this.controller, required this.hint, this.maxLines = 1, this.obscure = false, this.autofocus = false});
  final TextEditingController controller;
  final String hint;
  final int? maxLines;
  final bool obscure;
  final bool autofocus;

  @override
  State<TgField> createState() => _TgFieldState();
}

class _TgFieldState extends State<TgField> {
  final FocusNode _f = FocusNode();

  @override
  void initState() {
    super.initState();
    _f.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: TgEdit(controller: widget.controller, hint: widget.hint, maxLines: widget.maxLines, obscure: widget.obscure, autofocus: widget.autofocus, focusNode: _f, style: TextStyle(color: p.title, fontSize: 17)),
      ),
      AnimatedContainer(duration: const Duration(milliseconds: 200), height: _f.hasFocus ? 2 : 1, color: _f.hasFocus ? p.accent : p.divider),
    ]);
  }
}

// text button used at the bottom of sheets
class TgButton extends StatelessWidget {
  const TgButton({super.key, required this.label, required this.onTap, this.enabled = true});
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : .5,
      child: Tap(
        scale: .98,
        onTap: enabled ? onTap : null,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(10)),
          child: Text(label, style: TextStyle(color: p.dark ? const Color(0xFF0F1A24) : const Color(0xFFFFFFFF), fontSize: 15, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
