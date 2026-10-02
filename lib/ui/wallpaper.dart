import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui show ImageFilter;
import 'dart:ui' show Vertices, VertexMode;
import 'package:flutter/widgets.dart';

// four corner mesh like MotionBackgroundDrawable colors rotate when a message is sent

/// The chat backdrop: either the procedural gradient the app ships with, or a
/// picture the user picked, optionally blurred.
///
/// A scrim sits over a picture because a blur alone does not guarantee that
/// black text on a bright bubble still reads, and the scrim is never opaque
/// since the wallpaper is meant to be seen.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.path, required this.blur, required this.phase, required this.colors, this.accent});

  /// Empty draws the gradient.
  final String path;
  final bool blur;

  /// Drives the gradient's rotation when a message is sent. Unused by pictures.
  final double phase;

  /// The gradient's four corners, passed in rather than read here so this stays
  /// a dumb widget and the caller keeps its dependency on the palette.
  final List<Color> colors;

  /// Tint of the scrim, following the accent the user picked.
  final Color? accent;

  bool get _hasPicture => path.isNotEmpty && File(path).existsSync();

  @override
  Widget build(BuildContext context) {
    if (!_hasPicture) {
      return CustomPaint(painter: WallPainter(colors: colors, phase: phase));
    }
    Widget img = Image.file(
      File(path),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    if (blur) {
      // 18 is where a photo stops competing with the bubbles but still reads as
      // a photo rather than a wash
      img = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: img);
    }
    return Stack(fit: StackFit.expand, children: [
      img,
      // a blurred bright photo is still bright, so the blurred case takes the
      // heavier scrim
      ColoredBox(color: (accent ?? const Color(0xFF000000)).withAlpha(blur ? 58 : 38)),
    ]);
  }
}

// four corner mesh like MotionBackgroundDrawable colors rotate when a message is sent
class WallPainter extends CustomPainter {
  WallPainter({required this.colors, required this.phase});
  final List<Color> colors;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final k = phase.floor();
    final f = phase - k;
    Color at(int i) {
      final a = colors[((i + k) % 4 + 4) % 4];
      final b = colors[((i + k + 1) % 4 + 4) % 4];
      return Color.lerp(a, b, f)!;
    }

    final tl = at(0), tr = at(1), br = at(2), bl = at(3);
    const n = 12;
    final pos = <Offset>[];
    final col = <Color>[];
    for (var y = 0; y <= n; y++) {
      for (var x = 0; x <= n; x++) {
        final u = x / n, v = y / n;
        pos.add(Offset(u * size.width, v * size.height));
        col.add(Color.lerp(Color.lerp(tl, tr, u), Color.lerp(bl, br, u), v)!);
      }
    }
    final idx = <int>[];
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final a = y * (n + 1) + x;
        idx.addAll([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1]);
      }
    }
    canvas.drawVertices(Vertices(VertexMode.triangles, pos, colors: col, indices: idx), BlendMode.dst, Paint());
    _doodles(canvas, size);
  }

  // faint tiled doodles stand in for the pattern image
  void _doodles(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final p = Paint()
      ..color = const Color(0x14000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const cell = 64.0;
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final c = Offset(x + 12 + rnd.nextDouble() * 40, y + 12 + rnd.nextDouble() * 40);
        final s = 5 + rnd.nextDouble() * 4;
        switch (rnd.nextInt(4)) {
          case 0:
            canvas.drawCircle(c, s, p);
          case 1:
            canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s * 2, height: s * 2), const Radius.circular(3)), p);
          case 2:
            canvas.drawPath(
                Path()
                  ..moveTo(c.dx - s, c.dy + s * .7)
                  ..lineTo(c.dx, c.dy - s)
                  ..lineTo(c.dx + s, c.dy + s * .7)
                  ..close(),
                p);
          default:
            canvas.drawLine(Offset(c.dx - s, c.dy), Offset(c.dx + s, c.dy), p);
            canvas.drawLine(Offset(c.dx, c.dy - s), Offset(c.dx, c.dy + s), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(WallPainter o) => o.phase != phase || o.colors != colors;
}
