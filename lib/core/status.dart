import 'package:flutter/widgets.dart';

import '../data/models.dart';
import 'anim.dart';

// delivery mark port of drawStatusDrawable and MsgClockDrawable
// clock while sending one check when sent two checks when read red bang on failure
// sent to read slides the check 4dp and grows the half check in over 220ms
// every other change cross scales over 150ms
class MsgStatus extends StatefulWidget {
  const MsgStatus({super.key, required this.state, required this.color, this.list = false, this.danger = const Color(0xFFDB4A48)});
  final int state;
  final Color color;
  final bool list;
  final Color danger;

  static double widthOf(bool list) => list ? 19.5 : 17.0;

  @override
  State<MsgStatus> createState() => _MsgStatusState();
}

class _MsgStatusState extends State<MsgStatus> with TickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, value: 1);
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));
  late int _from = widget.state;
  late int _to = widget.state;

  @override
  void initState() {
    super.initState();
    _a.addStatusListener((s) {
      if (s == AnimationStatus.completed && _to != St.sending && _from != St.sending) _clock.stop();
    });
    if (widget.state == St.sending) _clock.repeat();
  }

  @override
  void didUpdateWidget(MsgStatus old) {
    super.didUpdateWidget(old);
    if (old.state == widget.state) return;
    _from = _to;
    _to = widget.state;
    final move = _from == St.sent && _to == St.read;
    _a.duration = Duration(milliseconds: move ? 220 : 150);
    _a.forward(from: 0);
    if ((_to == St.sending || _from == St.sending) && !_clock.isAnimating) _clock.repeat();
  }

  @override
  void dispose() {
    _a.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => CustomPaint(
        size: Size(MsgStatus.widthOf(widget.list), 12),
        painter: _StatusPainter(
          from: _from,
          to: _to,
          t: TgCurves.standard.transform(_a.value),
          clock: _clock,
          color: widget.color,
          danger: widget.danger,
          list: widget.list,
        ),
      ),
    );
  }
}

class _StatusPainter extends CustomPainter {
  _StatusPainter({required this.from, required this.to, required this.t, required this.clock, required this.color, required this.danger, required this.list}) : super(repaint: clock);
  final int from;
  final int to;
  final double t;
  final AnimationController clock;
  final Color color;
  final Color danger;
  final bool list;

  // centre lines measured from list_check msg_check_s and the half check bitmaps
  Path get _check => list
      ? (Path()
        ..moveTo(0.95, 6.3)
        ..lineTo(4.67, 10.0)
        ..lineTo(12.8, 1.8))
      : (Path()
        ..moveTo(0.55, 6.55)
        ..lineTo(3.6, 9.6)
        ..lineTo(10.8, 2.3));

  // half check keeps only a stub of the short arm so it never crosses the first check
  Path get _half => list
      ? (Path()
        ..moveTo(3.3, 8.9)
        ..lineTo(4.35, 10.0)
        ..lineTo(12.8, 1.8))
      : (Path()
        ..moveTo(3.3, 8.6)
        ..lineTo(4.0, 9.3)
        ..lineTo(11.3, 2.0));

  @override
  void paint(Canvas canvas, Size size) {
    final move = from == St.sent && to == St.read;
    if (t >= 1 || from == to) {
      _draw(canvas, to, 1, false);
    } else if (move) {
      _draw(canvas, to, t, true);
    } else {
      _draw(canvas, from, 1 - t, false);
      _draw(canvas, to, t, false);
    }
  }

  Color _c(Color c, double a) => c.withValues(alpha: c.a * a.clamp(0.0, 1.0));

  void _scaled(Canvas canvas, Offset center, double s, VoidCallback draw) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(s, s);
    canvas.translate(-center.dx, -center.dy);
    draw();
    canvas.restore();
  }

  void _draw(Canvas canvas, int st, double p, bool move) {
    final useScale = p != 1 && !move;
    final scale = 0.5 + 0.5 * p;
    final alpha = useScale ? p : 1.0;
    final w = MsgStatus.widthOf(list);
    final ox = list ? 0.0 : w - 16.5;
    final sentLeft = list ? 0.0 : ox + 4;
    final readLeft = ox;
    final halfLeft = list ? 5.5 : ox + 4.5;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    if (st == St.sending) {
      final left = sentLeft;
      final c = Offset(left + 6, 6);
      void clockDraw() {
        final s = stroke
          ..strokeWidth = 1
          ..color = _c(color, alpha);
        canvas.drawCircle(c, 5.5, s);
        final mAng = 2 * 3.141592653589793 * ((clock.value * 3) % 1);
        final hAng = 2 * 3.141592653589793 * clock.value;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(mAng);
        canvas.drawLine(Offset.zero, const Offset(0, -3), s);
        canvas.rotate(hAng - mAng);
        canvas.drawLine(Offset.zero, const Offset(2.3, 0), s);
        canvas.restore();
      }

      if (useScale) {
        _scaled(canvas, c, scale, clockDraw);
      } else {
        clockDraw();
      }
      return;
    }

    if (st == St.failed) {
      final c = Offset(sentLeft + 6, 6);
      void bang() {
        canvas.drawCircle(c, 6, Paint()..color = _c(danger, alpha));
        final s = stroke
          ..strokeWidth = 1.4
          ..color = _c(const Color(0xFFFFFFFF), alpha);
        canvas.drawLine(Offset(c.dx, c.dy - 2.8), Offset(c.dx, c.dy + 0.6), s);
        canvas.drawCircle(Offset(c.dx, c.dy + 2.7), 0.8, Paint()..color = _c(const Color(0xFFFFFFFF), alpha));
      }

      if (useScale) {
        _scaled(canvas, c, scale, bang);
      } else {
        bang();
      }
      return;
    }

    final read = st == St.read;
    stroke
      ..strokeWidth = 1.65
      ..color = _c(color, alpha);
    final left = read ? readLeft : sentLeft;
    final boxC = Offset(left + (list ? 7 : 6), 6);
    void main() {
      canvas.save();
      canvas.translate(left, 0);
      canvas.drawPath(_check, stroke);
      canvas.restore();
    }

    canvas.save();
    if (move && read) canvas.translate(4 * (1 - p), 0);
    if (useScale) {
      _scaled(canvas, boxC, scale, main);
    } else {
      main();
    }
    canvas.restore();

    if (read) {
      final hc = Offset(halfLeft + (list ? 7 : 6), 6);
      void half() {
        canvas.save();
        canvas.translate(halfLeft, 0);
        canvas.drawPath(_half, stroke);
        canvas.restore();
      }

      if (useScale || move) {
        _scaled(canvas, hc, scale, half);
      } else {
        half();
      }
    }
  }

  @override
  bool shouldRepaint(_StatusPainter o) => o.from != from || o.to != to || o.t != t || o.color != color || o.list != list;
}
