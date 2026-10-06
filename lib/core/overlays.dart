import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'anim.dart';
import 'theme.dart';
import 'ui_kit.dart';
import '../l10n/x.dart';

// fragment push from ActionBarLayout fade plus 48dp slide over 150ms
class TgRoute<T> extends PageRoute<T> {
  TgRoute({required this.builder});
  final WidgetBuilder builder;

  @override
  bool get opaque => false;
  @override
  bool get maintainState => true;
  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => builder(context);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, c) {
        final v = const Decel(1.5).transform(animation.value.clamp(0.0, 1.0));
        return Opacity(opacity: v, child: Transform.translate(offset: Offset(48 * (1 - v), 0), child: c));
      },
    );
  }

  // swipe back already moved the page off screen so pop must not replay
  void popSilently() {
    controller?.reverseDuration = Duration.zero;
  }
}

// drag the page with the finger and reveal the one below
class SwipeBack extends StatefulWidget {
  const SwipeBack({super.key, required this.child, this.confirm});
  final Widget child;

  /// Ask before a swipe that crossed the threshold actually pops the route.
  /// Returning false slides the page back in. Editors with unsaved text use
  /// this so a fast right-swipe cannot throw edits away.
  final Future<bool> Function()? confirm;

  @override
  State<SwipeBack> createState() => _SwipeBackState();
}

class _SwipeBackState extends State<SwipeBack> with SingleTickerProviderStateMixin {
  double _dx = 0;
  bool _drag = false;
  late final AnimationController _c = AnimationController(vsync: this);
  double _from = 0;
  double _to = 0;
  bool _pop = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_drag) setState(() => _dx = _from + (_to - _from) * TgCurves.easeOutQuint.transform(_c.value));
    });
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && _pop && mounted) {
        final r = ModalRoute.of(context);
        if (r is TgRoute) r.popSilently();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _animate(double to, double w, {bool pop = false}) {
    _from = _dx;
    _to = to;
    _pop = pop;
    final ms = math.max(200 / w * (to - _dx).abs(), 120).round();
    _c.duration = Duration(milliseconds: ms);
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final t = (_dx / w).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _c.stop();
        _drag = true;
        FocusManager.instance.primaryFocus?.unfocus();
      },
      onHorizontalDragUpdate: (d) => setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, w)),
      onHorizontalDragEnd: (d) {
        _drag = false;
        final v = d.velocity.pixelsPerSecond.dx;
        if (_dx > w / 3 || v > 900) {
          final ask = widget.confirm;
          if (ask == null) {
            _animate(w, w, pop: true);
          } else {
            // the confirm dialog opens over the dragged page; a yes animates
            // out and pops, a no slides back where the finger left it
            ask().then((ok) {
              if (!mounted) return;
              if (ok) {
                _animate(w, w, pop: true);
              } else {
                _animate(0, w);
              }
            });
          }
        } else {
          _animate(0, w);
        }
      },
      child: Stack(children: [
        Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Color.fromRGBO(0, 0, 0, .18 * (1 - t))))),
        Transform.translate(
          offset: Offset(_dx, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, .25 * (1 - t)), blurRadius: 12)]),
            child: widget.child,
          ),
        ),
      ]),
    );
  }
}

class _PopupRoute<T> extends PopupRoute<T> {
  _PopupRoute({required this.builder, this.dim = const Color(0x00000000), this.dismissible = true, this.enter = 250, this.exit = 180, this.transition});
  final WidgetBuilder builder;
  final Color dim;
  final bool dismissible;
  final int enter;
  final int exit;
  final Widget Function(BuildContext, Animation<double>, Widget)? transition;

  @override
  Color? get barrierColor => dim;
  @override
  bool get barrierDismissible => dismissible;
  @override
  String? get barrierLabel => 'dismiss';
  @override
  Duration get transitionDuration => Duration(milliseconds: enter);
  @override
  Duration get reverseTransitionDuration => Duration(milliseconds: exit);

  @override
  Widget buildPage(BuildContext context, Animation<double> a, Animation<double> s) => builder(context);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> a, Animation<double> s, Widget child) => transition == null ? child : transition!(context, a, child);
}

// bottom sheet
Future<T?> showTgSheet<T>(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context, rootNavigator: true).push(_PopupRoute<T>(
    builder: (c) => Align(alignment: Alignment.bottomCenter, child: builder(c)),
    dim: const Color(0x80000000),
    enter: 320,
    exit: 200,
    transition: (c, a, child) => AnimatedBuilder(
      animation: a,
      child: child,
      builder: (_, ch) {
        final v = a.status == AnimationStatus.reverse ? Curves.easeIn.transform(a.value) : TgCurves.easeOutQuint.transform(a.value);
        return FractionalTranslation(translation: Offset(0, 1 - v), child: ch);
      },
    ),
  ));
}

class TgSheet extends StatefulWidget {
  const TgSheet({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  State<TgSheet> createState() => _TgSheetState();
}

class _TgSheetState extends State<TgSheet> {
  double _dy = 0;
  bool _drag = false;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    return AnimatedContainer(
      duration: Duration(milliseconds: _drag ? 0 : 220),
      curve: TgCurves.easeOutQuint,
      transform: Matrix4.translationValues(0, _dy, 0),
      padding: EdgeInsets.only(bottom: math.max(mq.viewInsets.bottom, mq.padding.bottom)),
      decoration: BoxDecoration(color: widget.color ?? p.sheet, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) => setState(() => _drag = true),
          onVerticalDragUpdate: (d) => setState(() => _dy = math.max(0, _dy + d.delta.dy)),
          onVerticalDragEnd: (d) {
            final close = _dy > 110 || d.velocity.pixelsPerSecond.dy > 800;
            setState(() {
              _drag = false;
              if (!close) _dy = 0;
            });
            if (close) Navigator.of(context).pop();
          },
          child: SizedBox(
            height: 22,
            child: Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: p.divider, borderRadius: BorderRadius.circular(2)))),
          ),
        ),
        Flexible(child: widget.child),
      ]),
    );
  }
}

void _noop() {}

class MenuItem {
  const MenuItem(this.label, this.icon, this.onTap, {this.danger = false, this.value, this.checked = false, this.sub, this.gap = false});
  const MenuItem.gap()
      : label = '',
        icon = Ic.check,
        onTap = _noop,
        danger = false,
        value = null,
        checked = false,
        sub = null,
        gap = true;
  final String label;
  final Ic icon;
  final VoidCallback onTap;
  final bool danger;
  final String? value;
  final bool checked;
  // optional second line under the label
  final String? sub;
  final bool gap;
}

// ItemOptions port popup grows from the anchor corner over 150ms plus 16ms per row
// rows fade in one after another and the scrimmed view floats above a blurred dim
Future<void> showTgMenu(BuildContext context, {required Rect anchor, required List<MenuItem> items, Widget? ghost, bool blur = false}) {
  final n = items.where((e) => !e.gap).length;
  final enter = 150 + 16 * n;
  return Navigator.of(context, rootNavigator: true).push(_PopupRoute<void>(
    builder: (c) => _MenuPage(anchor: anchor, items: items, ghost: ghost, blur: blur, enterMs: enter),
    enter: enter,
    exit: 130,
    transition: (c, a, child) => child,
  ));
}

class _MenuPage extends StatelessWidget {
  const _MenuPage({required this.anchor, required this.items, required this.ghost, required this.blur, required this.enterMs});
  final Rect anchor;
  final List<MenuItem> items;
  final Widget? ghost;
  final bool blur;
  final int enterMs;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    final screen = mq.size;
    const mw = 224.0;
    final mh = items.fold<double>(0, (s, e) => s + (e.gap ? 8 : 48)) + 12;
    final below = anchor.bottom + 8 + mh <= screen.height - mq.padding.bottom - 8;
    final top = below ? anchor.bottom + 8 : math.max(mq.padding.top + 8, anchor.top - 8 - mh);
    final rightSide = anchor.center.dx > screen.width / 2;
    final left = (rightSide ? anchor.right - mw : anchor.left).clamp(12.0, screen.width - mw - 12);
    final a = ModalRoute.of(context)!.animation!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedBuilder(
        animation: a,
        builder: (_, __) {
          final t = a.value.clamp(0.0, 1.0);
          final grow = TgCurves.standard.transform(t);
          var idx = 0;
          return Stack(children: [
            if (blur)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
                  child: ColoredBox(color: Color.fromRGBO(0, 0, 0, .22 * t)),
                ),
              ),
            if (ghost != null) Positioned(left: anchor.left, top: anchor.top, width: anchor.width, height: anchor.height, child: IgnorePointer(child: OverflowBox(alignment: Alignment.topLeft, minWidth: 0, maxWidth: anchor.width, minHeight: 0, maxHeight: anchor.height, child: ghost!))),
            Positioned(
              left: left,
              top: top,
              width: mw,
              child: DecoratedBox(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, .2 * t), blurRadius: 22, offset: const Offset(0, 6))]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Align(
                    alignment: Alignment(rightSide ? 1 : -1, below ? -1 : 1),
                    widthFactor: math.max(grow, .001),
                    heightFactor: math.max(grow, .001),
                    child: Container(
                      width: mw,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: p.sheet,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final it in items)
                          if (it.gap)
                            Container(height: 8, color: p.title.withAlpha(15))
                          else
                            _row(context, p, it, ((t * enterMs - 16 * idx++) / 150).clamp(0.0, 1.0)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _row(BuildContext context, Pal p, MenuItem it, double alpha) {
    final color = it.danger ? p.danger : p.title;
    return Opacity(
      opacity: alpha,
      child: Tap(
        highlight: true,
        radius: 8,
        onTap: () {
          Navigator.of(context).pop();
          it.onTap();
        },
        child: SizedBox(
          height: it.sub != null ? 58 : 48,
          child: Row(children: [
            const SizedBox(width: 18),
            TgIcon(it.icon, color: it.danger ? p.danger : p.icon.withAlpha(190), size: 24, stroke: 1.8),
            const SizedBox(width: 19),
            Expanded(
              child: it.sub != null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 16)),
                      Text(it.sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                    ])
                  : Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 16)),
            ),
            if (it.value != null) Text(it.value!, style: TextStyle(color: p.subtitle, fontSize: 14)),
            if (it.checked) TgIcon(Ic.check, color: p.accent, size: 20),
            const SizedBox(width: 18),
          ]),
        ),
      ),
    );
  }
}

class DialogAction {
  const DialogAction(this.label, this.value, {this.danger = false, this.enabled});
  final String label;
  final Object? value;
  final bool danger;

  /// Checked when the body rebuilds, so a typed confirm keeps its button
  /// dead until the field says the word.
  final bool Function()? enabled;
}

Future<T?> showTgDialog<T>(BuildContext context, {required String title, String? message, Widget? content, required List<DialogAction> actions, Listenable? listenable}) {
  return Navigator.of(context, rootNavigator: true).push(_PopupRoute<T>(
    dim: const Color(0x73000000),
    enter: 220,
    exit: 150,
    // the listenable rebuilds the body so an enabled action can flip from
    // dead to live while the user types
    builder: (c) => ListenableBuilder(
      listenable: listenable ?? ValueNotifier<int>(0),
      child: _DialogBody(title: title, message: message, content: content, actions: actions),
      builder: (_, body) => body!,
    ),
    transition: (c, a, child) => AnimatedBuilder(
      animation: a,
      child: child,
      builder: (_, ch) {
        final v = TgCurves.easeOutQuint.transform(a.value.clamp(0.0, 1.0));
        return Opacity(opacity: a.value.clamp(0.0, 1.0), child: Transform.scale(scale: .9 + .1 * v, child: ch));
      },
    ),
  ));
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({required this.title, required this.message, required this.content, required this.actions});
  final String title;
  final String? message;
  final Widget? content;
  final List<DialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Container(
          width: math.min(mq.size.width - 56, 320),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
          decoration: BoxDecoration(color: p.sheet, borderRadius: BorderRadius.circular(18)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: p.title, fontSize: 20, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
            if (message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message!, style: TextStyle(color: p.title, fontSize: 16, height: 1.25, decoration: TextDecoration.none, fontWeight: FontWeight.w400))),
            if (content != null) Padding(padding: const EdgeInsets.only(top: 8), child: content),
            const SizedBox(height: 14),
            // a Wrap so a dialog with four or five actions does not run off the
            // edge of the sheet, with fewer actions it lays out as a Row did.
            // The SizedBox is load bearing: the Column above is
            // crossAxisAlignment.start, so the Wrap would shrink to its own
            // content and sit on the left, leaving WrapAlignment.end with
            // nothing to align.
            SizedBox(
              width: double.infinity,
              child: Wrap(alignment: WrapAlignment.end, runAlignment: WrapAlignment.end, children: [
                for (final a in actions)
                  Tap(
                    scale: .96,
                    onTap: a.enabled?.call() ?? true ? () => Navigator.of(context).pop(a.value) : null,
                    child: Opacity(
                      opacity: a.enabled?.call() ?? true ? 1 : .35,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Text(a.label, style: TextStyle(color: a.danger ? p.danger : p.accent, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

Future<String?> showTgInput(BuildContext context, {required String title, required String initial, required String hint, bool obscure = false, int maxLines = 1}) {
  final ctl = TextEditingController(text: initial);
  return showTgDialog<String>(
    context,
    title: title,
    content: TgField(controller: ctl, hint: hint, obscure: obscure, autofocus: true, maxLines: maxLines),
    actions: [
      DialogAction(context.l.actionCancel, null),
      DialogAction(context.l.actionOk, '__ok__')
    ],
  ).then((v) {
    final r = v == '__ok__' ? ctl.text : null;
    ctl.dispose();
    return r;
  });
}

// bottom toast like Bulletin
void showBulletin(BuildContext context, String text) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Bulletin(text: text, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _Bulletin extends StatefulWidget {
  const _Bulletin({required this.text, required this.onDone});
  final String text;
  final VoidCallback onDone;

  @override
  State<_Bulletin> createState() => _BulletinState();
}

class _BulletinState extends State<_Bulletin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 300), reverseDuration: const Duration(milliseconds: 200));

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // the pill takes the wallpaper colour once there is one, and stays the stock
    // dark slab until then. White text is the only ink on either, because both
    // surfaces are solved or fixed at a luminance it reads on
    final bg = context.p.toastBg;
    return Positioned(
      left: 16,
      right: 16,
      bottom: mq.padding.bottom + 96,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final v = TgCurves.easeOutQuint.transform(_c.value);
            return Opacity(
              opacity: _c.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - v)),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                    child: Text(widget.text, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
