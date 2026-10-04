import 'package:flutter/widgets.dart';

import 'ui_kit.dart';

// glyphs for attach emoji search and profile screens stroked on the same 24 grid
void paintGlyph(Canvas canvas, Ic ic, Paint sp, Paint fp) {
  final p = Path();
  switch (ic) {
    case Ic.attach:
      p
        ..moveTo(21.44, 11.05)
        ..lineTo(12.25, 20.24)
        ..arcToPoint(const Offset(3.76, 11.75),
            radius: const Radius.circular(6), clockwise: true)
        ..lineTo(12.95, 2.56)
        ..arcToPoint(const Offset(18.61, 8.22),
            radius: const Radius.circular(4), clockwise: true)
        ..lineTo(9.41, 17.41)
        ..arcToPoint(const Offset(6.58, 14.58),
            radius: const Radius.circular(2), clockwise: true)
        ..lineTo(15.07, 6.10);
      canvas.drawPath(p, sp);
    case Ic.smile:
      canvas.drawCircle(const Offset(12, 12), 9, sp);
      canvas.drawCircle(const Offset(9, 10), 1.05, fp);
      canvas.drawCircle(const Offset(15, 10), 1.05, fp);
      p
        ..moveTo(8, 14.4)
        ..quadraticBezierTo(12, 18.6, 16, 14.4);
      canvas.drawPath(p, sp);
    case Ic.keyboard:
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(
                2.5,
                6,
                19,
                12,
              ),
              const Radius.circular(3)),
          sp);
      for (final x in [6.5, 10.2, 13.8, 17.5]) {
        canvas.drawCircle(Offset(x, 10), 0.9, fp);
      }
      canvas.drawLine(const Offset(8, 14.2), const Offset(16, 14.2), sp);
    case Ic.sticker:
      p
        ..moveTo(20.5, 12)
        ..lineTo(20.5, 8)
        ..arcToPoint(const Offset(16, 3.5),
            radius: const Radius.circular(4.5), clockwise: false)
        ..lineTo(8, 3.5)
        ..arcToPoint(const Offset(3.5, 8),
            radius: const Radius.circular(4.5), clockwise: false)
        ..lineTo(3.5, 16)
        ..arcToPoint(const Offset(8, 20.5),
            radius: const Radius.circular(4.5), clockwise: false)
        ..lineTo(12, 20.5)
        ..arcToPoint(const Offset(20.5, 12),
            radius: const Radius.circular(8.5), clockwise: false);
      canvas.drawPath(p, sp);
      canvas.drawCircle(const Offset(9, 10.2), 1, fp);
      canvas.drawCircle(const Offset(14.6, 10.2), 1, fp);
      p
        ..reset()
        ..moveTo(8.6, 13.6)
        ..quadraticBezierTo(11.8, 16.2, 15, 13.6);
      canvas.drawPath(p, sp);
    case Ic.image:
      canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(3.5, 4.5, 17, 15),
              const Radius.circular(3.2)),
          sp);
      canvas.drawCircle(const Offset(9, 10), 1.6, sp);
      p
        ..moveTo(4.2, 17.4)
        ..lineTo(9.6, 12.8)
        ..lineTo(13, 15.8)
        ..lineTo(15.6, 13.4)
        ..lineTo(19.8, 17.2);
      canvas.drawPath(p, sp);
    case Ic.file:
      p
        ..moveTo(14, 3.5)
        ..lineTo(8, 3.5)
        ..arcToPoint(const Offset(5.5, 6),
            radius: const Radius.circular(2.5), clockwise: false)
        ..lineTo(5.5, 18)
        ..arcToPoint(const Offset(8, 20.5),
            radius: const Radius.circular(2.5), clockwise: false)
        ..lineTo(16, 20.5)
        ..arcToPoint(const Offset(18.5, 18),
            radius: const Radius.circular(2.5), clockwise: false)
        ..lineTo(18.5, 8)
        ..close()
        ..moveTo(14, 3.5)
        ..lineTo(14, 8)
        ..lineTo(18.5, 8)
        ..moveTo(9, 12.8)
        ..lineTo(15, 12.8)
        ..moveTo(9, 16.2)
        ..lineTo(13, 16.2);
      canvas.drawPath(p, sp);
    case Ic.pinLoc:
      p
        ..moveTo(12, 21)
        ..cubicTo(12, 21, 5, 14.8, 5, 9.6)
        ..arcToPoint(const Offset(19, 9.6),
            radius: const Radius.circular(7), clockwise: true)
        ..cubicTo(19, 14.8, 12, 21, 12, 21)
        ..close();
      canvas.drawPath(p, sp);
      canvas.drawCircle(const Offset(12, 9.6), 2.4, sp);
    case Ic.music:
      p
        ..moveTo(9, 17.5)
        ..lineTo(9, 6.4)
        ..lineTo(19, 4.2)
        ..lineTo(19, 15.4)
        ..moveTo(9, 9.6)
        ..lineTo(19, 7.4);
      canvas.drawPath(p, sp);
      canvas.drawCircle(const Offset(6.6, 17.6), 2.4, sp);
      canvas.drawCircle(const Offset(16.6, 15.6), 2.4, sp);
    case Ic.poll:
      p
        ..moveTo(4.5, 6.5)
        ..lineTo(19.5, 6.5)
        ..moveTo(4.5, 12)
        ..lineTo(14.5, 12)
        ..moveTo(4.5, 17.5)
        ..lineTo(10.5, 17.5);
      canvas.drawPath(p, sp..strokeWidth = sp.strokeWidth + 1.2);
    case Ic.user:
      canvas.drawCircle(const Offset(12, 8.2), 3.9, sp);
      p
        ..moveTo(4.5, 20)
        ..arcToPoint(const Offset(19.5, 20),
            radius: const Radius.elliptical(7.5, 6.6), clockwise: true);
      canvas.drawPath(p, sp);
    case Ic.calendar:
      canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(3.5, 5, 17, 15.5),
              const Radius.circular(3.2)),
          sp);
      p
        ..moveTo(3.5, 10.2)
        ..lineTo(20.5, 10.2)
        ..moveTo(8, 3)
        ..lineTo(8, 6.6)
        ..moveTo(16, 3)
        ..lineTo(16, 6.6);
      canvas.drawPath(p, sp);
    case Ic.up:
      p
        ..moveTo(6, 15)
        ..lineTo(12, 9)
        ..lineTo(18, 15);
      canvas.drawPath(p, sp);
    case Ic.chevron:
      p
        ..moveTo(9.5, 6)
        ..lineTo(15.5, 12)
        ..lineTo(9.5, 18);
      canvas.drawPath(p, sp);
    case Ic.info:
      canvas.drawCircle(const Offset(12, 12), 9, sp);
      canvas.drawLine(const Offset(12, 11), const Offset(12, 16.4), sp);
      canvas.drawCircle(const Offset(12, 7.9), 1.05, fp);
    case Ic.share:
      p
        ..moveTo(12, 15)
        ..lineTo(12, 3.8)
        ..moveTo(8, 7.6)
        ..lineTo(12, 3.6)
        ..lineTo(16, 7.6)
        ..moveTo(7.6, 10)
        ..lineTo(6.5, 10)
        ..arcToPoint(const Offset(4.5, 12),
            radius: const Radius.circular(2), clockwise: false)
        ..lineTo(4.5, 18)
        ..arcToPoint(const Offset(6.5, 20),
            radius: const Radius.circular(2), clockwise: false)
        ..lineTo(17.5, 20)
        ..arcToPoint(const Offset(19.5, 18),
            radius: const Radius.circular(2), clockwise: false)
        ..lineTo(19.5, 12)
        ..arcToPoint(const Offset(17.5, 10),
            radius: const Radius.circular(2), clockwise: false)
        ..lineTo(16.4, 10);
      canvas.drawPath(p, sp);
    case Ic.camera:
      canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(3, 7.2, 18, 12.3),
              const Radius.circular(3.2)),
          sp);
      canvas.drawCircle(const Offset(12, 13.3), 3.6, sp);
      p
        ..moveTo(8.6, 7.2)
        ..lineTo(9.8, 4.8)
        ..lineTo(14.2, 4.8)
        ..lineTo(15.4, 7.2);
      canvas.drawPath(p, sp);
    case Ic.link:
      p
        ..moveTo(10, 13)
        ..arcToPoint(const Offset(17.54, 13.54),
            radius: const Radius.circular(5), clockwise: false)
        ..lineTo(20.54, 10.54)
        ..arcToPoint(const Offset(13.47, 3.47),
            radius: const Radius.circular(5), clockwise: false)
        ..lineTo(11.75, 5.18)
        ..moveTo(14, 11)
        ..arcToPoint(const Offset(6.46, 10.46),
            radius: const Radius.circular(5), clockwise: false)
        ..lineTo(3.46, 13.46)
        ..arcToPoint(const Offset(10.53, 20.53),
            radius: const Radius.circular(5), clockwise: false)
        ..lineTo(12.24, 18.82);
      canvas.drawPath(p, sp);
    case Ic.unread:
      canvas.drawCircle(const Offset(12, 12), 8.5, sp);
      canvas.drawCircle(const Offset(12, 12), 4.2, fp);
    case Ic.readAll:
      p
        ..moveTo(2.5, 13)
        ..lineTo(6.5, 17)
        ..lineTo(14.2, 8.4)
        ..moveTo(10.6, 15.6)
        ..lineTo(12, 17)
        ..lineTo(21, 7.2);
      canvas.drawPath(p, sp);
    case Ic.storage:
      canvas.drawOval(const Rect.fromLTWH(4.5, 3.6, 15, 6), sp);
      p
        ..moveTo(4.5, 6.6)
        ..lineTo(4.5, 17.4)
        ..arcToPoint(const Offset(19.5, 17.4),
            radius: const Radius.elliptical(7.5, 3), clockwise: false)
        ..lineTo(19.5, 6.6)
        ..moveTo(4.5, 12)
        ..arcToPoint(const Offset(19.5, 12),
            radius: const Radius.elliptical(7.5, 3), clockwise: false);
      canvas.drawPath(p, sp);
    case Ic.palette:
      p
        ..moveTo(12, 3.5)
        ..arcToPoint(const Offset(12, 20.5),
            radius: const Radius.circular(8.5),
            clockwise: false,
            largeArc: true)
        ..cubicTo(13.6, 20.5, 14.2, 19.3, 13.7, 18.1)
        ..cubicTo(13.1, 16.8, 14, 15.5, 15.5, 15.5)
        ..lineTo(17.5, 15.5)
        ..arcToPoint(const Offset(20.5, 12.5),
            radius: const Radius.circular(3), clockwise: false)
        ..cubicTo(20.5, 7, 16.7, 3.5, 12, 3.5)
        ..close();
      canvas.drawPath(p, sp);
      for (final o in const [
        Offset(7.6, 11),
        Offset(10, 7.6),
        Offset(14.5, 7.6),
        Offset(16.8, 11)
      ]) {
        canvas.drawCircle(o, 1, fp);
      }
    case Ic.bell:
      p
        ..moveTo(6, 16.5)
        ..lineTo(6, 11)
        ..arcToPoint(const Offset(18, 11),
            radius: const Radius.circular(6), clockwise: true)
        ..lineTo(18, 16.5)
        ..lineTo(19.6, 18.4)
        ..lineTo(4.4, 18.4)
        ..close()
        ..moveTo(10, 21)
        ..arcToPoint(const Offset(14, 21),
            radius: const Radius.circular(2), clockwise: false);
      canvas.drawPath(p, sp);
    case Ic.plus:
      p
        ..moveTo(12, 5)
        ..lineTo(12, 19)
        ..moveTo(5, 12)
        ..lineTo(19, 12);
      canvas.drawPath(p, sp);
    case Ic.minus:
      canvas.drawLine(const Offset(5, 12), const Offset(19, 12), sp);
    case Ic.drag:
      p
        ..moveTo(5, 8)
        ..lineTo(19, 8)
        ..moveTo(5, 12)
        ..lineTo(19, 12)
        ..moveTo(5, 16)
        ..lineTo(19, 16);
      canvas.drawPath(p, sp..strokeWidth = sp.strokeWidth * .8);
    case Ic.list:
      for (final y in [7.0, 12.0, 17.0]) {
        canvas.drawCircle(Offset(5, y), 1.1, fp);
        canvas.drawLine(Offset(9, y), Offset(20, y), sp);
      }
    case Ic.backspace:
      p
        ..moveTo(9, 5.5)
        ..lineTo(19.5, 5.5)
        ..arcToPoint(const Offset(21, 7),
            radius: const Radius.circular(1.5), clockwise: true)
        ..lineTo(21, 17)
        ..arcToPoint(const Offset(19.5, 18.5),
            radius: const Radius.circular(1.5), clockwise: true)
        ..lineTo(9, 18.5)
        ..lineTo(3, 12)
        ..close()
        ..moveTo(12.6, 9.4)
        ..lineTo(17.4, 14.6)
        ..moveTo(17.4, 9.4)
        ..lineTo(12.6, 14.6);
      canvas.drawPath(p, sp);
    case Ic.check2:
      p
        ..moveTo(2.5, 12.8)
        ..lineTo(6.5, 16.8)
        ..lineTo(13.5, 8)
        ..moveTo(10.5, 15.4)
        ..lineTo(11.6, 16.5)
        ..lineTo(20.5, 6.4);
      canvas.drawPath(p, sp);
    case Ic.video:
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(3.5, 6.5, 12, 11), const Radius.circular(3)),
          sp);
      p
        ..moveTo(15.5, 11)
        ..lineTo(20.5, 7.8)
        ..lineTo(20.5, 16.2)
        ..lineTo(15.5, 13)
        ..close();
      canvas.drawCircle(const Offset(8.2, 10.6), 1.2, fp);
      canvas.drawCircle(const Offset(12, 7.6), 1.2, fp);
      canvas.drawCircle(const Offset(16, 9.6), 1.2, fp);
    case Ic.at:
      canvas.drawCircle(const Offset(12, 12), 4.2, sp);
      p
        ..moveTo(16.2, 7.8)
        ..arcToPoint(const Offset(16.2, 16.2),
            radius: const Radius.circular(6.6), clockwise: true)
        ..lineTo(16.2, 14.4)
        ..arcToPoint(const Offset(19.6, 12),
            radius: const Radius.circular(4.4), clockwise: true)
        ..lineTo(14.4, 12);
      canvas.drawPath(p, sp);
    case Ic.lock:
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(4.5, 10, 15, 10), const Radius.circular(3)),
          sp);
      p
        ..moveTo(7.8, 10)
        ..lineTo(7.8, 7.6)
        ..arcToPoint(const Offset(16.2, 7.6),
            radius: const Radius.circular(4.2), clockwise: true)
        ..lineTo(16.2, 10);
      canvas.drawPath(p, sp);
    case Ic.crown:
      p
        ..moveTo(3, 17.5)
        ..lineTo(5, 6.5)
        ..lineTo(9.4, 12)
        ..lineTo(12, 4.5)
        ..lineTo(14.6, 12)
        ..lineTo(19, 6.5)
        ..lineTo(21, 17.5)
        ..close();
      canvas.drawPath(p, sp);
      canvas.drawLine(const Offset(4.6, 20.2), const Offset(19.4, 20.2), sp);
    // hongbao envelope, the flap line plus the coin disc the real one carries
    case Ic.hongbao:
      p
        ..moveTo(5, 4.6)
        ..quadraticBezierTo(5, 3, 6.6, 3)
        ..lineTo(17.4, 3)
        ..quadraticBezierTo(19, 3, 19, 4.6)
        ..lineTo(19, 19.4)
        ..quadraticBezierTo(19, 21, 17.4, 21)
        ..lineTo(6.6, 21)
        ..quadraticBezierTo(5, 21, 5, 19.4)
        ..close();
      canvas.drawPath(p, sp);
      p
        ..moveTo(5.4, 5.2)
        ..lineTo(12, 11.4)
        ..lineTo(18.6, 5.2);
      canvas.drawPath(p, sp);
      canvas.drawCircle(const Offset(12, 16.2), 2.1, sp);
    // wallet with the clasp tab breaking the right edge
    case Ic.wallet:
      p
        ..moveTo(3.4, 8.2)
        ..quadraticBezierTo(3.4, 5.6, 6, 5.6)
        ..lineTo(15.4, 5.6)
        ..lineTo(19, 5.6)
        ..quadraticBezierTo(20.6, 5.6, 20.6, 7.2)
        ..lineTo(20.6, 16.8)
        ..quadraticBezierTo(20.6, 18.4, 19, 18.4)
        ..lineTo(6, 18.4)
        ..quadraticBezierTo(3.4, 18.4, 3.4, 16.8)
        ..close();
      canvas.drawPath(p, sp);
      // the clasp, a short bar and the dot that reads as the button
      canvas.drawLine(const Offset(3.4, 11.2), const Offset(20.6, 11.2), sp);
      canvas.drawCircle(const Offset(16.4, 14.8), 1.15, fp);
    case Ic.folder:
      p
        ..moveTo(3.5, 6.5)
        ..quadraticBezierTo(3.5, 5, 5, 5)
        ..lineTo(9.6, 5)
        ..lineTo(11.4, 7.2)
        ..lineTo(19, 7.2)
        ..quadraticBezierTo(20.5, 7.2, 20.5, 8.7)
        ..lineTo(20.5, 17.3)
        ..quadraticBezierTo(20.5, 18.8, 19, 18.8)
        ..lineTo(5, 18.8)
        ..quadraticBezierTo(3.5, 18.8, 3.5, 17.3)
        ..close();
      canvas.drawPath(p, sp);
    case Ic.folderOpen:
      // the tab, then the body swung open and tipped forward
      p
        ..moveTo(3.5, 7.4)
        ..quadraticBezierTo(3.5, 5.4, 5.5, 5.4)
        ..lineTo(9.8, 5.4)
        ..lineTo(11.6, 7.6)
        ..lineTo(18.5, 7.6);
      canvas.drawPath(p, sp);
      p
        ..moveTo(3.5, 10)
        ..lineTo(20.5, 10)
        ..lineTo(17.9, 18.6)
        ..quadraticBezierTo(17.7, 19.3, 17, 19.3)
        ..lineTo(5.6, 19.3)
        ..quadraticBezierTo(4.9, 19.3, 4.7, 18.6)
        ..close();
      canvas.drawPath(p, sp);
    case Ic.fileCode:
      p
        ..moveTo(6, 3.5)
        ..lineTo(13.5, 3.5)
        ..lineTo(19, 9)
        ..lineTo(19, 20.5)
        ..lineTo(6, 20.5)
        ..close()
        ..moveTo(13.4, 3.6)
        ..lineTo(13.4, 9.1)
        ..lineTo(18.9, 9.1)
        ..moveTo(10.4, 12.6)
        ..lineTo(8.4, 15.6)
        ..lineTo(10.4, 18.4)
        ..moveTo(14.6, 12.6)
        ..lineTo(16.6, 15.6)
        ..lineTo(14.6, 18.4);
      canvas.drawPath(p, sp);
    case Ic.terminal:
      p
        ..moveTo(3.4, 6)
        ..quadraticBezierTo(3.4, 4.6, 4.9, 4.6)
        ..lineTo(19.1, 4.6)
        ..quadraticBezierTo(20.6, 4.6, 20.6, 6)
        ..lineTo(20.6, 18)
        ..quadraticBezierTo(20.6, 19.4, 19.1, 19.4)
        ..lineTo(4.9, 19.4)
        ..quadraticBezierTo(3.4, 19.4, 3.4, 18)
        ..close();
      canvas.drawPath(p, sp);
      p
        ..moveTo(7.2, 9.2)
        ..lineTo(10, 12)
        ..lineTo(7.2, 14.8)
        ..moveTo(11.6, 15)
        ..lineTo(16.4, 15);
      canvas.drawPath(p, sp);
    case Ic.eye:
      p
        ..moveTo(2.6, 12)
        ..cubicTo(5.6, 6.8, 8.6, 4.4, 12, 4.4)
        ..cubicTo(15.4, 4.4, 18.4, 6.8, 21.4, 12)
        ..cubicTo(18.4, 17.2, 15.4, 19.6, 12, 19.6)
        ..cubicTo(8.6, 19.6, 5.6, 17.2, 2.6, 12)
        ..close();
      canvas.drawPath(p, sp);
      canvas.drawCircle(const Offset(12, 12), 3.2, sp);
    case Ic.download:
      p
        ..moveTo(12, 4)
        ..lineTo(12, 14.4)
        ..moveTo(7.6, 10.2)
        ..lineTo(12, 14.6)
        ..lineTo(16.4, 10.2);
      canvas.drawPath(p, sp);
      p
        ..moveTo(4.6, 16.4)
        ..lineTo(4.6, 18.6)
        ..quadraticBezierTo(4.6, 20, 6, 20)
        ..lineTo(18, 20)
        ..quadraticBezierTo(19.4, 20, 19.4, 18.6)
        ..lineTo(19.4, 16.4);
      canvas.drawPath(p, sp);
    case Ic.wrap:
      p
        ..moveTo(4, 6.6)
        ..lineTo(20, 6.6)
        ..quadraticBezierTo(20, 10.4, 16.6, 10.4)
        ..lineTo(7.4, 10.4)
        ..quadraticBezierTo(4, 10.4, 4, 13.4)
        ..quadraticBezierTo(4, 16.4, 7.4, 16.4)
        ..lineTo(18.6, 16.4)
        ..moveTo(15.2, 13.6)
        ..lineTo(18.6, 16.4)
        ..lineTo(15.2, 19.2);
      canvas.drawPath(p, sp);
    case Ic.hidden:
      // a struck-through eye, which reads as hidden without needing a label
      p
        ..moveTo(3.6, 7.4)
        ..quadraticBezierTo(7, 4.8, 12, 4.8)
        ..quadraticBezierTo(17, 4.8, 20.4, 7.4)
        ..moveTo(6.4, 10.4)
        ..quadraticBezierTo(6, 11.2, 5.6, 12)
        ..quadraticBezierTo(8, 15.4, 12, 15.4)
        ..quadraticBezierTo(16, 15.4, 18.4, 12)
        ..quadraticBezierTo(18, 11.2, 17.6, 10.4)
        ..moveTo(4.4, 4.4)
        ..lineTo(19.6, 19.6);
      canvas.drawPath(p, sp);
    default:
      break;
  }
}
