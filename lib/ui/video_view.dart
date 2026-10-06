import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../core/anim.dart';
import '../core/ui_kit.dart';
import '../l10n/x.dart';

/// Fullscreen player for video messages. Pushed (not a sheet) so the aspect
/// ratio owns the whole screen; a tap toggles playback, a tap on the close
/// glyph or a back gesture pops.
Future<void> showVideoView(BuildContext context, String path) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: const Color(0xE6000000),
      pageBuilder: (_, __, ___) => _VideoView(path: path),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _VideoView extends StatefulWidget {
  const _VideoView({required this.path});
  final String path;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final VideoPlayerController _ctl = VideoPlayerController.file(File(widget.path));
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ctl.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _ctl.play();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
    _ctl.addListener(_onTick);
  }

  void _onTick() {
    if (mounted && !_ctl.value.isPlaying && _ctl.value.position >= _ctl.value.duration && _ctl.value.duration > Duration.zero) {
      // hold the last frame instead of snapping back to the poster
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ctl.removeListener(_onTick);
    _ctl.dispose();
    super.dispose();
  }

  String _clock(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!_ready) return;
        setState(() {
          _ctl.value.isPlaying ? _ctl.pause() : _ctl.play();
        });
      },
      child: ColoredBox(
        color: const Color(0xE6000000),
        child: Stack(fit: StackFit.expand, children: [
          if (_ready)
            Center(
              child: AspectRatio(
                aspectRatio: _ctl.value.aspectRatio,
                child: VideoPlayer(_ctl),
              ),
            )
          else
            Center(
              child: _failed
                  ? Text(context.l.attachVideoFailed, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 16, decoration: TextDecoration.none))
                  : const SizedBox(width: 36, height: 36, child: _Spinner()),
            ),
          if (_ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(14)),
                  child: Text('${_clock(_ctl.value.position)} / ${_clock(_ctl.value.duration)}', style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13, decoration: TextDecoration.none, fontFeatures: [])),
                ),
              ),
            ),
          if (_ready && !_ctl.value.isPlaying)
            const Center(child: _PlayGlyph()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Tap(
              scale: .88,
              onTap: () => Navigator.of(context, rootNavigator: true).pop(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Container(
                  decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                  child: Center(child: TgIcon(Ic.close, color: const Color(0xFFFFFFFF), size: 20)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(color: const Color(0x99000000), shape: BoxShape.circle, border: Border.all(color: const Color(0xCCFFFFFF), width: 1.6)),
      child: const Center(child: TgIcon(Ic.video, color: Color(0xFFFFFFFF), size: 34)),
    );
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        painter: _RingPainter(t: _c.value),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    final r = math.min(s.width, s.height) / 2 - 2;
    final bg = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fg = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    canvas.drawCircle(center, r, bg);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2 + t * 2 * math.pi, math.pi * 1.2, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}
