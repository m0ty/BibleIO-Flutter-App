import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/bible_color_preset.dart';
import 'pages/bible_home_page.dart';

const _kThemeModePrefKey = 'theme_mode';
const _kSelectedBibleColorPresetIdPrefKey = 'selected_bible_color_preset_id';
const _kCustomBibleColorPresetsPrefKey = 'custom_bible_color_presets';

void main() {
  runApp(const BibleReaderApp());
}

class BibleReaderApp extends StatefulWidget {
  const BibleReaderApp({super.key});

  @override
  State<BibleReaderApp> createState() => _BibleReaderAppState();
}

class _BibleReaderAppState extends State<BibleReaderApp> {
  List<BibleColorPreset> _customColorPresets = [];
  BibleColorPreset _selectedColorPreset = builtInBibleColorPresets.first;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadColorPresetSettings();
  }

  Future<void> _loadColorPresetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final customPresets = _decodeCustomColorPresets(
      prefs.getString(_kCustomBibleColorPresetsPrefKey),
    );
    final presets = [...builtInBibleColorPresets, ...customPresets];
    final selectedId =
        prefs.getString(_kSelectedBibleColorPresetIdPrefKey) ??
        _migratedPresetIdFromThemeMode(prefs.getString(_kThemeModePrefKey));
    final selectedPreset = presets.firstWhere(
      (preset) => preset.id == selectedId,
      orElse: () => builtInBibleColorPresets.first,
    );
    setState(() {
      _customColorPresets = customPresets;
      _selectedColorPreset = selectedPreset;
      _initialized = true;
    });
  }

  List<BibleColorPreset> _decodeCustomColorPresets(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return [];
    }

    try {
      final decoded = json.decode(encoded) as List<dynamic>;
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (preset) =>
                BibleColorPreset.fromJson(Map<String, Object?>.from(preset)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _migratedPresetIdFromThemeMode(String? themeMode) {
    return themeMode == 'dark' ? 'dark' : 'light';
  }

  Future<void> _setColorPreset(BibleColorPreset colorPreset) async {
    setState(() {
      _selectedColorPreset = colorPreset;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedBibleColorPresetIdPrefKey, colorPreset.id);
  }

  Future<void> _saveCustomColorPreset(BibleColorPreset colorPreset) async {
    final customColorPresets = [..._customColorPresets, colorPreset];
    setState(() {
      _customColorPresets = customColorPresets;
      _selectedColorPreset = colorPreset;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCustomBibleColorPresetsPrefKey,
      json.encode(customColorPresets.map((preset) => preset.toJson()).toList()),
    );
    await prefs.setString(_kSelectedBibleColorPresetIdPrefKey, colorPreset.id);
  }

  Future<void> _deleteCustomColorPreset(BibleColorPreset colorPreset) async {
    if (colorPreset.isBuiltIn) {
      return;
    }

    final customColorPresets = _customColorPresets
        .where((preset) => preset.id != colorPreset.id)
        .toList();
    final selectedColorPreset = _selectedColorPreset.id == colorPreset.id
        ? builtInBibleColorPresets.first
        : _selectedColorPreset;
    setState(() {
      _customColorPresets = customColorPresets;
      _selectedColorPreset = selectedColorPreset;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCustomBibleColorPresetsPrefKey,
      json.encode(customColorPresets.map((preset) => preset.toJson()).toList()),
    );
    await prefs.setString(
      _kSelectedBibleColorPresetIdPrefKey,
      selectedColorPreset.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final theme = _buildAppTheme(_selectedColorPreset);

    return MaterialApp(
      title: 'BibleIO Viewer',
      theme: theme,
      home: BibleHomePage(
        colorPresets: [...builtInBibleColorPresets, ..._customColorPresets],
        selectedColorPreset: _selectedColorPreset,
        onColorPresetChanged: _setColorPreset,
        onCustomColorPresetSaved: _saveCustomColorPreset,
        onCustomColorPresetDeleted: _deleteCustomColorPreset,
      ),
    );
  }

  ThemeData _buildAppTheme(BibleColorPreset colorPreset) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: colorPreset.verseNumberColor,
      brightness: colorPreset.brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
      ),
    );
  }
}
