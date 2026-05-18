// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter_bible/main.dart';
import 'package:flutter_bible/models/bible_color_preset.dart';
import 'package:flutter_bible/pages/settings_page.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'BibleIO Viewer',
      packageName: 'flutter_bible',
      version: '1.0.0',
      buildNumber: '',
      buildSignature: '',
    );
  });

  testWidgets('Bible reader app loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BibleReaderApp());

    // Verify that the app loads without error (loading indicator should be present initially)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('display settings color preset dropdown lays out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          colorPresets: builtInBibleColorPresets,
          selectedColorPreset: builtInBibleColorPresets.first,
          onColorPresetChanged: (_) {},
          onCustomColorPresetSaved: (_) {},
          onCustomColorPresetDeleted: (_) {},
          selectedBiblePath: 'bible_io_json/English/eng-kjv-1769.json',
          onBiblePathChanged: (_) {},
          bibleTextSize: 16,
          onBibleTextSizeChanged: (_) {},
          showVersesInline: false,
          onShowVersesInlineChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Display'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('bible_color_preset_dropdown_light')),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('Monokai'), findsWidgets);
  });

  testWidgets('saving custom color preset closes dialog cleanly', (
    WidgetTester tester,
  ) async {
    var presets = List<BibleColorPreset>.from(builtInBibleColorPresets);
    var selectedPreset = builtInBibleColorPresets.first;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return SettingsPage(
              colorPresets: presets,
              selectedColorPreset: selectedPreset,
              onColorPresetChanged: (preset) {
                setState(() {
                  selectedPreset = preset;
                });
              },
              onCustomColorPresetSaved: (preset) {
                setState(() {
                  presets = [...presets, preset];
                  selectedPreset = preset;
                });
              },
              onCustomColorPresetDeleted: (preset) {
                setState(() {
                  presets = presets
                      .where((existingPreset) => existingPreset.id != preset.id)
                      .toList();
                  selectedPreset = builtInBibleColorPresets.first;
                });
              },
              selectedBiblePath: 'bible_io_json/English/eng-kjv-1769.json',
              onBiblePathChanged: (_) {},
              bibleTextSize: 16,
              onBibleTextSizeChanged: (_) {},
              showVersesInline: false,
              onShowVersesInlineChanged: (_) {},
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Display'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save preset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save preset'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Reader Custom');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(selectedPreset.name, 'Reader Custom');
    expect(find.text('Reader Custom'), findsOneWidget);
  });

  testWidgets('custom color preset can be deleted', (
    WidgetTester tester,
  ) async {
    final customPreset = BibleColorPreset(
      id: 'custom_test',
      name: 'Reader Custom',
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );
    var presets = [...builtInBibleColorPresets, customPreset];
    var selectedPreset = customPreset;
    BibleColorPreset? deletedPreset;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return SettingsPage(
              colorPresets: presets,
              selectedColorPreset: selectedPreset,
              onColorPresetChanged: (preset) {
                setState(() {
                  selectedPreset = preset;
                });
              },
              onCustomColorPresetSaved: (_) {},
              onCustomColorPresetDeleted: (preset) {
                setState(() {
                  deletedPreset = preset;
                  presets = presets
                      .where((existingPreset) => existingPreset.id != preset.id)
                      .toList();
                  selectedPreset = builtInBibleColorPresets.first;
                });
              },
              selectedBiblePath: 'bible_io_json/English/eng-kjv-1769.json',
              onBiblePathChanged: (_) {},
              bibleTextSize: 16,
              onBibleTextSizeChanged: (_) {},
              showVersesInline: false,
              onShowVersesInlineChanged: (_) {},
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Display'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('delete_custom_color_preset_button')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(deletedPreset?.id, customPreset.id);
    expect(selectedPreset.id, builtInBibleColorPresets.first.id);
    expect(presets.any((preset) => preset.id == customPreset.id), isFalse);
    expect(
      find.byKey(const Key('delete_custom_color_preset_button')),
      findsNothing,
    );
  });
}
