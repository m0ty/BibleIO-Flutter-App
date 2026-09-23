import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bible/models/bible_color_preset.dart';
import 'package:flutter_bible/services/color_preset_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ColorPresetStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return ColorPresetStore(await SharedPreferences.getInstance());
  }

  const customPreset = BibleColorPreset(
    id: 'custom_test',
    name: 'Reader Custom',
    backgroundColor: Color(0xFF123456),
    textColor: Color(0xFFFEDCBA),
  );

  test('empty preferences use the default preset', () async {
    final settings = (await storeWith({})).load();
    expect(settings.customPresets, isEmpty);
    expect(settings.selectedPreset, builtInBibleColorPresets.first);
  });

  test('legacy theme migrates only when no preset is selected', () async {
    final legacy = await storeWith({'theme_mode': 'dark'});
    expect(legacy.load().selectedPreset.id, 'dark');

    final selected = await storeWith({
      'theme_mode': 'dark',
      'selected_bible_color_preset_id': 'sepia',
    });
    expect(selected.load().selectedPreset.id, 'sepia');
  });

  test(
    'invalid custom data and missing selected IDs fall back safely',
    () async {
      for (final encoded in ['not json', '{}', '[{"id":"broken"}]']) {
        final store = await storeWith({
          'custom_bible_color_presets': encoded,
          'selected_bible_color_preset_id': 'missing',
        });
        final settings = store.load();
        expect(settings.customPresets, isEmpty);
        expect(settings.selectedPreset, builtInBibleColorPresets.first);
      }
    },
  );

  test('existing custom preset JSON restores colors and selection', () async {
    final store = await storeWith({
      'custom_bible_color_presets': json.encode([customPreset.toJson()]),
      'selected_bible_color_preset_id': customPreset.id,
    });
    final settings = store.load();
    expect(settings.customPresets.single.toJson(), customPreset.toJson());
    expect(settings.selectedPreset.id, customPreset.id);
    expect(settings.selectedPreset.isBuiltIn, isFalse);
  });

  test('saving and deleting custom presets survive a fresh store', () async {
    final store = await storeWith({});
    await store.saveCustomPresets([customPreset], selectedPreset: customPreset);

    final preferences = await SharedPreferences.getInstance();
    final restored = ColorPresetStore(preferences).load();
    expect(restored.customPresets.single.toJson(), customPreset.toJson());
    expect(restored.selectedPreset.id, customPreset.id);

    await store.saveCustomPresets(
      [],
      selectedPreset: builtInBibleColorPresets.first,
    );
    final deleted = ColorPresetStore(preferences).load();
    expect(deleted.customPresets, isEmpty);
    expect(deleted.selectedPreset, builtInBibleColorPresets.first);
    expect(preferences.getString('custom_bible_color_presets'), '[]');
  });

  test('changing selection preserves saved custom presets', () async {
    final store = await storeWith({});
    await store.saveCustomPresets([customPreset], selectedPreset: customPreset);
    await store.saveSelection(builtInBibleColorPresets.first);

    expect(store.load().selectedPreset, builtInBibleColorPresets.first);
    expect(store.load().customPresets.single.id, customPreset.id);
  });
}
