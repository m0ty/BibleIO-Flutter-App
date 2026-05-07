// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_bible/main.dart';

void main() {
  testWidgets('Bible reader app loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BibleReaderApp());

    // Verify that the app loads without error (loading indicator should be present initially)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
