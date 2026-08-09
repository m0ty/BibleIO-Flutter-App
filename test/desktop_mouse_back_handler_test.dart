import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bible/widgets/desktop_mouse_back_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mouse back pops routes on every native desktop platform', (
    tester,
  ) async {
    try {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_testApp(navigatorKey));

      for (final platform in <TargetPlatform>[
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        navigatorKey.currentState!.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Details')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Details'), findsOneWidget);

        await _sendMouseButton(tester, kBackMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Details'), findsNothing);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mouse back is ignored outside native desktop', (tester) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_testApp(navigatorKey));
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Details')),
        ),
      );
      await tester.pumpAndSettle();

      await _sendMouseButton(tester, kBackMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Details'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('primary mouse clicks do not pop routes', (tester) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_testApp(navigatorKey));
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Details')),
        ),
      );
      await tester.pumpAndSettle();

      await _sendMouseButton(tester, kPrimaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Details'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Widget _testApp(GlobalKey<NavigatorState> navigatorKey) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    builder: (context, child) => DesktopMouseBackHandler(
      navigatorKey: navigatorKey,
      child: child ?? const SizedBox.shrink(),
    ),
    home: const Scaffold(body: Text('Home')),
  );
}

Future<void> _sendMouseButton(WidgetTester tester, int buttons) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  const position = Offset(20, 20);
  await tester.sendEventToBinding(pointer.addPointer(location: position));
  await tester.sendEventToBinding(pointer.down(position, buttons: buttons));
  await tester.sendEventToBinding(pointer.up());
  await tester.sendEventToBinding(pointer.removePointer());
}
