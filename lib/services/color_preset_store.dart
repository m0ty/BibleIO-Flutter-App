import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bible_color_preset.dart';

const _themeModeKey = 'theme_mode';
const _selectedPresetIdKey = 'selected_bible_color_preset_id';
const _customPresetsKey = 'custom_bible_color_presets';

class ColorPresetSettings {
  ColorPresetSettings({
    required List<BibleColorPreset> customPresets,
    required this.selectedPreset,
  }) : customPresets = List.unmodifiable(customPresets);

  final List<BibleColorPreset> customPresets;
  final BibleColorPreset selectedPreset;
}

/// Owns the stored preset format and migration from the legacy theme setting.
class ColorPresetStore {
  const ColorPresetStore(this._preferences);

  final SharedPreferences _preferences;

  ColorPresetSettings load() {
    final customPresets = _decodeCustomPresets(
      _preferences.getString(_customPresetsKey),
    );
    final selectedId =
        _preferences.getString(_selectedPresetIdKey) ??
        (_preferences.getString(_themeModeKey) == 'dark' ? 'dark' : 'light');
    final selectedPreset = [...builtInBibleColorPresets, ...customPresets]
        .firstWhere(
          (preset) => preset.id == selectedId,
          orElse: () => builtInBibleColorPresets.first,
        );
    return ColorPresetSettings(
      customPresets: customPresets,
      selectedPreset: selectedPreset,
    );
  }

  Future<void> saveSelection(BibleColorPreset preset) async {
    await _preferences.setString(_selectedPresetIdKey, preset.id);
  }

  Future<void> saveCustomPresets(
    List<BibleColorPreset> customPresets, {
    required BibleColorPreset selectedPreset,
  }) async {
    await _preferences.setString(
      _customPresetsKey,
      json.encode(customPresets.map((preset) => preset.toJson()).toList()),
    );
    await saveSelection(selectedPreset);
  }

  List<BibleColorPreset> _decodeCustomPresets(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final decoded = json.decode(encoded) as List<dynamic>;
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (preset) =>
                BibleColorPreset.fromJson(Map<String, Object?>.from(preset)),
          )
          .toList();
    } on Object {
      // Invalid stored presets should not prevent startup.
      return [];
    }
  }
}
