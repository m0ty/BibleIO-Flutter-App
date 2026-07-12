import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/bible_color_preset.dart';
import 'pages/bible_home_page.dart';

const _kThemeModePrefKey = 'theme_mode';
const _kSelectedBibleColorPresetIdPrefKey = 'selected_bible_color_preset_id';
const _kCustomBibleColorPresetsPrefKey = 'custom_bible_color_presets';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } on Object {
    // The app can still start with defaults if preference storage is unavailable.
  }
  runApp(BibleReaderApp(initialPreferences: preferences));
}

class BibleReaderApp extends StatefulWidget {
  const BibleReaderApp({super.key, this.initialPreferences});

  final SharedPreferences? initialPreferences;

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
    late final SharedPreferences prefs;
    try {
      prefs =
          widget.initialPreferences ?? await SharedPreferences.getInstance();
    } on Object {
      if (mounted) setState(() => _initialized = true);
      return;
    }
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
    if (!mounted) {
      return;
    }
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
      return MaterialApp(
        title: 'BibleIO Reader',
        debugShowCheckedModeBanner: false,
        theme: _buildAppTheme(builtInBibleColorPresets.first),
        home: const _AppStartupView(),
      );
    }

    final theme = _buildAppTheme(_selectedColorPreset);

    return MaterialApp(
      title: 'BibleIO Reader',
      debugShowCheckedModeBanner: false,
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
      seedColor: const Color(0xFF355F78),
      brightness: colorPreset.brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        surfaceTintColor: colorScheme.surfaceTint,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.secondaryContainer,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: colorScheme.primary,
      ),
    );
  }
}

class _AppStartupView extends StatelessWidget {
  const _AppStartupView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Starting BibleIO Reader',
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_rounded, size: 52),
              SizedBox(height: 20),
              SizedBox(width: 180, child: LinearProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
