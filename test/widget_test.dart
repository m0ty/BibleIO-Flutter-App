import 'package:flutter/material.dart';
import 'package:flutter_bible/main.dart';
import 'package:flutter_bible/models/bible_color_preset.dart';
import 'package:flutter_bible/pages/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _defaultBiblePath = 'bible_io_json/English/eng-kjv-1769.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'BibleIO Reader',
      packageName: 'flutter_bible',
      version: '1.0.0',
      buildNumber: '',
      buildSignature: '',
    );
  });

  testWidgets('startup presents branded progress feedback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BibleReaderApp());

    expect(find.bySemanticsLabel('Starting BibleIO Reader'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('reader supports compact, wide, and reference navigation', (
    WidgetTester tester,
  ) async {
    _setTestViewport(tester, const Size(390, 844));
    await tester.pumpWidget(const BibleReaderApp());
    await _pumpUntilFound(tester, find.text('Genesis 1'));

    expect(find.text('BibleIO Reader'), findsOneWidget);
    expect(find.byTooltip('Go to a Bible reference'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();

    expect(find.text('Find a book'), findsOneWidget);
    expect(find.text('Genesis 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Go to a Bible reference'));
    await tester.pumpAndSettle();
    expect(find.text('Go to a passage'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('reference_field')),
      'Juan 3:16',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Go'));
    await tester.pumpAndSettle();

    expect(find.text('John 3'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Verse 16')), findsOneWidget);
    expect(find.textContaining('For God so loved the world'), findsOneWidget);
    final readerScrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(readerScrollView.controller!.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('display settings color preset dropdown lays out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_settingsTestApp());

    await tester.tap(find.text('Display'));
    await tester.pumpAndSettle();
    expect(find.text('Compact verse spacing'), findsOneWidget);

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
            return _settingsPage(
              presets: presets,
              selectedPreset: selectedPreset,
              onColorPresetChanged: (preset) {
                setState(() => selectedPreset = preset);
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
                      .where((existing) => existing.id != preset.id)
                      .toList();
                  selectedPreset = builtInBibleColorPresets.first;
                });
              },
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
            return _settingsPage(
              presets: presets,
              selectedPreset: selectedPreset,
              onColorPresetChanged: (preset) {
                setState(() => selectedPreset = preset);
              },
              onCustomColorPresetDeleted: (preset) {
                setState(() {
                  deletedPreset = preset;
                  presets = presets
                      .where((existing) => existing.id != preset.id)
                      .toList();
                  selectedPreset = builtInBibleColorPresets.first;
                });
              },
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

Widget _settingsTestApp() {
  return MaterialApp(
    home: _settingsPage(
      presets: builtInBibleColorPresets,
      selectedPreset: builtInBibleColorPresets.first,
    ),
  );
}

SettingsPage _settingsPage({
  required List<BibleColorPreset> presets,
  required BibleColorPreset selectedPreset,
  ValueChanged<BibleColorPreset>? onColorPresetChanged,
  ValueChanged<BibleColorPreset>? onCustomColorPresetSaved,
  ValueChanged<BibleColorPreset>? onCustomColorPresetDeleted,
}) {
  return SettingsPage(
    colorPresets: presets,
    selectedColorPreset: selectedPreset,
    onColorPresetChanged: onColorPresetChanged ?? (_) {},
    onCustomColorPresetSaved: onCustomColorPresetSaved ?? (_) {},
    onCustomColorPresetDeleted: onCustomColorPresetDeleted ?? (_) {},
    selectedBiblePath: _defaultBiblePath,
    onBiblePathChanged: (_) {},
    bibleTextSize: 17,
    onBibleTextSizeChanged: (_) {},
    showVersesInline: false,
    onShowVersesInlineChanged: (_) {},
  );
}

void _setTestViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int attempts = 400,
}) async {
  for (
    var attempt = 0;
    attempt < attempts && finder.evaluate().isEmpty;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  expect(finder, findsWidgets);
}
