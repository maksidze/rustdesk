import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_hbb/desktop/widgets/standard_cursor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'standard cursors include text and resize forms and always paint visibly',
      () async {
    final expected = {
      'basic': SystemMouseCursors.basic,
      'text': SystemMouseCursors.text,
      'resizeLeftRight': SystemMouseCursors.resizeLeftRight,
      'resizeUpDown': SystemMouseCursors.resizeUpDown,
      'resizeUpLeftDownRight': SystemMouseCursors.resizeUpLeftDownRight,
      'resizeUpRightDownLeft': SystemMouseCursors.resizeUpRightDownLeft,
      'move': SystemMouseCursors.move,
      'transparent-custom': SystemMouseCursors.basic,
    };
    for (final entry in expected.entries) {
      expect(standardSystemCursor(entry.key), entry.value);
      final recorder = ui.PictureRecorder();
      StandardCursorPainter(
              kind: entry.key, position: const Offset(32, 32), scale: 1)
          .paint(Canvas(recorder), const Size(64, 64));
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 64);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(List.generate(64 * 64, (i) => pixels!.getUint8(i * 4 + 3)),
          contains(isNonZero),
          reason: entry.key);
      image.dispose();
      picture.dispose();
    }
  });
}
