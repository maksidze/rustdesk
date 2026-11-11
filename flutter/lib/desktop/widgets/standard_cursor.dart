import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

SystemMouseCursor standardSystemCursor(String kind) {
  switch (kind) {
    case 'text':
      return SystemMouseCursors.text;
    case 'resizeLeftRight':
      return SystemMouseCursors.resizeLeftRight;
    case 'resizeUpDown':
      return SystemMouseCursors.resizeUpDown;
    case 'resizeUpLeftDownRight':
      return SystemMouseCursors.resizeUpLeftDownRight;
    case 'resizeUpRightDownLeft':
      return SystemMouseCursors.resizeUpRightDownLeft;
    case 'move':
      return SystemMouseCursors.move;
    default:
      return SystemMouseCursors.basic;
  }
}

class StandardCursorPainter extends CustomPainter {
  final String kind;
  final Offset position;
  final double scale;

  const StandardCursorPainter(
      {required this.kind, required this.position, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (!position.dx.isFinite ||
        !position.dy.isFinite ||
        !scale.isFinite ||
        scale <= 0) return;
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.scale(scale);
    final path = Path();
    if (kind == 'text') {
      path
        ..moveTo(-4, -10)
        ..lineTo(4, -10)
        ..moveTo(0, -10)
        ..lineTo(0, 10)
        ..moveTo(-4, 10)
        ..lineTo(4, 10);
    } else if (const [
      'resizeLeftRight',
      'resizeUpDown',
      'resizeUpLeftDownRight',
      'resizeUpRightDownLeft',
      'move'
    ].contains(kind)) {
      if (kind == 'resizeUpDown') canvas.rotate(math.pi / 2);
      if (kind == 'resizeUpLeftDownRight') canvas.rotate(math.pi / 4);
      if (kind == 'resizeUpRightDownLeft') canvas.rotate(-math.pi / 4);
      void arrow() {
        path
          ..moveTo(-11, 0)
          ..lineTo(11, 0)
          ..moveTo(-6, -5)
          ..lineTo(-11, 0)
          ..lineTo(-6, 5)
          ..moveTo(6, -5)
          ..lineTo(11, 0)
          ..lineTo(6, 5);
      }

      arrow();
      if (kind == 'move') {
        path.addPath(path.transform(Matrix4.rotationZ(math.pi / 2).storage),
            Offset.zero);
      }
    } else {
      path
        ..lineTo(0, 20)
        ..lineTo(5, 15)
        ..lineTo(9, 23)
        ..lineTo(13, 21)
        ..lineTo(9, 13)
        ..lineTo(16, 13)
        ..close();
      canvas.drawPath(path, Paint()..color = Colors.white);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StandardCursorPainter oldDelegate) =>
      kind != oldDelegate.kind ||
      position != oldDelegate.position ||
      scale != oldDelegate.scale;
}
