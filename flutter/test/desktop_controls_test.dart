import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart' show MyTheme, SessionID;
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/relative_mouse_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class _Binding extends Fake implements RustdeskImpl {
  final mouse = <Map<String, dynamic>>[];

  @override
  int versionToNumber({required String v, dynamic hint}) =>
      v.split('.').fold(0, (number, part) => number * 1000 + int.parse(part));

  @override
  String translate(
          {required String name, required String locale, dynamic hint}) =>
      name;

  @override
  Future<void> sessionSendMouse(
      {required SessionID sessionId, required String msg, dynamic hint}) async {
    mouse.add(jsonDecode(msg) as Map<String, dynamic>);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.rustdesk.rustdesk/desktop_controls');
  late _Binding core;

  setUp(() {
    core = _Binding();
    platformFFI.setBindingForTesting(core);
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('pin button sets and clears always on top', (tester) async {
    var pinned = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isAlwaysOnTop') return pinned;
      if (call.method == 'setAlwaysOnTop') pinned = call.arguments as bool;
      return null;
    });
    await tester.pumpWidget(MaterialApp(
        theme: MyTheme.lightTheme,
        home: const Scaffold(body: Center(child: AlwaysOnTopButton()))));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    await tester.tap(find.byType(AlwaysOnTopButton));
    await tester.pumpAndSettle();
    expect(pinned, isTrue);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    await tester.tap(find.byType(AlwaysOnTopButton));
    await tester.pumpAndSettle();
    expect(pinned, isFalse);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
  });

  testWidgets('locked pointer forwards raw motion and releases on blur',
      (tester) async {
    var locked = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'enableRelativeMouse') {
        locked = true;
        return true;
      }
      if (call.method == 'disableRelativeMouse') locked = false;
      return null;
    });
    final enabled = false.obs;
    var inside = true;
    final model = RelativeMouseModel(
      sessionId: const Uuid().v4obj(),
      enabled: enabled,
      keyboardPerm: () => true,
      isViewCamera: () => false,
      peerVersion: () => '1.5.1',
      peerPlatform: () => 'Windows',
      modify: (msg) => msg,
      getPointerInsideImage: () => inside,
      setPointerInsideImage: (value) => inside = value,
    );
    addTearDown(model.dispose);
    model.updateImageWidgetSize(const Size(800, 600));
    expect(model.setRelativeMouseMode(true), isTrue);
    await tester.pump();
    expect(enabled.value, isTrue);
    expect(locked, isTrue);
    // The OS cursor never changes its Flutter position while it is clipped.
    model.handleRelativeMouseMove(const Offset(400, 300));
    for (var i = 0; i < 2; i++) {
      await binding.defaultBinaryMessenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
              const MethodCall('mouseDelta', {'dx': 1200, 'dy': -25})),
          (_) {});
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(core.mouse.where((m) => m['x'] == '1200' && m['y'] == '-25'),
        hasLength(2));
    model.onWindowBlur();
    await tester.pump();
    expect(enabled.value, isFalse);
    expect(locked, isFalse);
  }, skip: !Platform.isWindows);
}
