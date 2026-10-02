import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

// curves copied from CubicBezierInterpolator and ChatListItemAnimator
class TgCurves {
  static const easeOutQuint = Cubic(.23, 1, .32, 1);
  static const easeOut = Cubic(0, 0, .58, 1);
  static const easeBoth = Cubic(.42, 0, .58, 1);
  static const standard = Cubic(.25, .1, .25, 1);
  static const easeOutBack = Cubic(.34, 1.56, .64, 1);
  static const chatItem = Cubic(0.19919472913616398, 0.010644531250000006, 0.27920937042459737, 0.91025390625);
}

// android DecelerateInterpolator with factor
class Decel extends Curve {
  const Decel(this.factor);
  final double factor;
  @override
  double transformInternal(double t) => 1 - math.pow(1 - t, 2 * factor).toDouble();
}

// press feedback: list highlight or button scale
class Tap extends StatefulWidget {
  const Tap({super.key, required this.child, this.onTap, this.onLongPress, this.highlight = false, this.scale = 1.0, this.radius = 0});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool highlight;
  final double scale;
  final double radius;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;
  Timer? _t;

  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  void _press() {
    _t?.cancel();
    if (widget.highlight) {
      _t = Timer(const Duration(milliseconds: 45), () => _set(true));
    } else {
      _set(true);
    }
  }

  void _release() {
    _t?.cancel();
    _set(false);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget c = widget.child;
    if (widget.highlight) {
      c = AnimatedContainer(
        duration: Duration(milliseconds: _down ? 0 : 240),
        decoration: BoxDecoration(color: _down ? context.p.selector : const Color(0x00000000), borderRadius: BorderRadius.circular(widget.radius)),
        child: c,
      );
    }
    if (widget.scale != 1.0) {
      c = AnimatedScale(scale: _down ? widget.scale : 1.0, duration: const Duration(milliseconds: 150), curve: TgCurves.easeOut, child: c);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: c,
    );
  }
}

// one shot enter animation for new list items
class Enter extends StatefulWidget {
  const Enter({super.key, required this.child, this.fly = false, this.enabled = true});
  final Widget child;
  final bool fly;
  final bool enabled;

  @override
  State<Enter> createState() => _EnterState();
}

class _EnterState extends State<Enter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.fly ? 460 : 250));

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_c.isCompleted) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final size = TgCurves.chatItem.transform(math.min(1.0, _c.value * (widget.fly ? 1.84 : 1.0)));
        final e = widget.fly ? TgCurves.easeOutQuint.transform(_c.value) : TgCurves.chatItem.transform(_c.value);
        final dy = (widget.fly ? 60.0 : 14.0) * (1 - e);
        final dx = widget.fly ? 18.0 * (1 - e) : 0.0;
        final s = widget.fly ? 0.72 + 0.28 * e : 0.96 + 0.04 * e;
        return Align(
          alignment: Alignment.bottomCenter,
          heightFactor: size,
          child: Opacity(
            opacity: math.min(1.0, e * (widget.fly ? 3 : 1.4)).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.scale(scale: s, alignment: widget.fly ? Alignment.bottomRight : Alignment.bottomLeft, child: child),
            ),
          ),
        );
      },
    );
  }
}
