import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../pages/remote_page.dart' show CursorPaint;

class RelativeMouseCursor extends StatelessWidget {
  final String id;
  final RxBool zoomCursor;

  const RelativeMouseCursor(
      {super.key, required this.id, required this.zoomCursor});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CursorPaint(id: id, zoomCursor: zoomCursor),
      );
}
