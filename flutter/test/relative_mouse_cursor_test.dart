import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/widgets/relative_mouse_cursor.dart';
import 'package:flutter_hbb/desktop/widgets/standard_cursor.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/utils/image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class _FFI extends Fake implements FFI {}

class _Canvas extends ChangeNotifier implements CanvasModel {
  @override
  double get x => 20;
  @override
  double get y => 30;
  @override
  double get scale => 0.5;
  @override
  ViewStyle get viewStyle => ViewStyle(
      style: kRemoteViewStyleAdaptive,
      width: 400,
      height: 300,
      displayWidth: 800,
      displayHeight: 600);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cursor extends CursorModel {
  _Cursor(FFI ffi, this.image) : super(WeakReference(ffi));
  @override
  final ui.Image image;
}

void main() {
  testWidgets('relative cursor follows remote coordinates at the canvas scale',
      (tester) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 4, 4),
        ui.Paint()..color = const Color(0xFFFF0000));
    final image =
        await tester.runAsync(() => recorder.endRecording().toImage(4, 4));
    final ffi = _FFI();
    final cursor = _Cursor(ffi, image!);
    final canvas = _Canvas();
    addTearDown(image.dispose);
    addTearDown(cursor.disposeImages);
    addTearDown(canvas.dispose);
    cursor.updateRelativeCursorPosition({'x': '100', 'y': '80'});
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<CursorModel>.value(value: cursor),
        ChangeNotifierProvider<CanvasModel>.value(value: canvas),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 300,
          child: RelativeMouseCursor(id: 'test', zoomCursor: false.obs),
        ),
      ),
    ));
    ImagePainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<ImagePainter>()
        .single;
    expect((painter().x, painter().y), (70, 70));
    expect(painter().image, same(image));
    cursor.updateRelativeCursorPosition({'x': '600', 'y': '400'});
    await tester.pump();
    expect((painter().x, painter().y), (320, 230));
    cursor.standardKind = 'text';
    cursor.useStandardCursors = true;
    await tester.pump();
    final standard = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<StandardCursorPainter>()
        .single;
    expect(standard.kind, 'text');
    expect(standard.position, const Offset(320, 230));
    cursor.useStandardCursors = false;
    await tester.pump();
    expect(painter().image, same(image));
  });
}
