import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/bible_color_preset.dart';
import 'pages/bible_home_page.dart';
import 'services/color_preset_store.dart';
import 'theme/app_theme.dart';

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
    late final ColorPresetSettings settings;
    try {
      settings = (await _getColorPresetStore()).load();
    } on Object {
      if (mounted) setState(() => _initialized = true);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _customColorPresets = settings.customPresets;
      _selectedColorPreset = settings.selectedPreset;
      _initialized = true;
    });
  }

  Future<ColorPresetStore> _getColorPresetStore() async {
    final preferences =
        widget.initialPreferences ?? await SharedPreferences.getInstance();
    return ColorPresetStore(preferences);
  }

  Future<void> _setColorPreset(BibleColorPreset colorPreset) async {
    setState(() {
      _selectedColorPreset = colorPreset;
    });
    final store = await _getColorPresetStore();
    await store.saveSelection(colorPreset);
  }

  Future<void> _saveCustomColorPreset(BibleColorPreset colorPreset) async {
    final customColorPresets = [..._customColorPresets, colorPreset];
    setState(() {
      _customColorPresets = customColorPresets;
      _selectedColorPreset = colorPreset;
    });
    final store = await _getColorPresetStore();
    await store.saveCustomPresets(
      customColorPresets,
      selectedPreset: colorPreset,
    );
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

    final store = await _getColorPresetStore();
    await store.saveCustomPresets(
      customColorPresets,
      selectedPreset: selectedColorPreset,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        title: 'BibleIO Reader',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(builtInBibleColorPresets.first),
        home: const _AppStartupView(),
      );
    }

    final theme = buildAppTheme(_selectedColorPreset);

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
