import 'package:bible_io/bible_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/bible_color_preset.dart';

const _kAppName = 'BibleIO Reader';
const _kAppLicense = 'GNU Affero General Public License v3.0';
const _kAppMaker = 'Moty Fainer';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.colorPresets,
    required this.selectedColorPreset,
    required this.onColorPresetChanged,
    required this.onCustomColorPresetSaved,
    required this.onCustomColorPresetDeleted,
    required this.selectedBiblePath,
    required this.onBiblePathChanged,
    required this.bibleTextSize,
    required this.onBibleTextSizeChanged,
    required this.showVersesInline,
    required this.onShowVersesInlineChanged,
    this.bible,
    this.bibleCatalog,
  });

  final List<BibleColorPreset> colorPresets;
  final BibleColorPreset selectedColorPreset;
  final ValueChanged<BibleColorPreset> onColorPresetChanged;
  final ValueChanged<BibleColorPreset> onCustomColorPresetSaved;
  final ValueChanged<BibleColorPreset> onCustomColorPresetDeleted;
  final String selectedBiblePath;
  final ValueChanged<String> onBiblePathChanged;
  final double bibleTextSize;
  final ValueChanged<double> onBibleTextSizeChanged;
  final bool showVersesInline;
  final ValueChanged<bool> onShowVersesInlineChanged;
  final Bible? bible;
  final BibleCatalog? bibleCatalog;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late double _bibleTextSize;
  late bool _showVersesInline;
  late List<BibleColorPreset> _colorPresets;
  late BibleColorPreset _selectedColorPreset;
  late Color _editingBackgroundColor;
  late Color _editingTextColor;
  late final Future<PackageInfo> _packageInfo;
  late final Future<List<String>> _bibleFiles;
  late String _selectedBiblePath;

  @override
  void initState() {
    super.initState();
    _bibleTextSize = widget.bibleTextSize;
    _showVersesInline = widget.showVersesInline;
    _colorPresets = widget.colorPresets;
    _selectedColorPreset = widget.selectedColorPreset;
    _editingBackgroundColor = _selectedColorPreset.backgroundColor;
    _editingTextColor = _selectedColorPreset.textColor;
    _packageInfo = PackageInfo.fromPlatform();
    _selectedBiblePath = widget.selectedBiblePath;
    _bibleFiles = _loadBibleFiles();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedColorPreset.id != widget.selectedColorPreset.id) {
      _selectedColorPreset = widget.selectedColorPreset;
      _editingBackgroundColor = _selectedColorPreset.backgroundColor;
      _editingTextColor = _selectedColorPreset.textColor;
    }
    if (oldWidget.colorPresets != widget.colorPresets) {
      _colorPresets = widget.colorPresets;
    }
  }

  Future<List<String>> _loadBibleFiles() async {
    final catalog = widget.bibleCatalog;
    if (catalog != null) {
      return catalog.sources
          .map((source) => source.assetPath)
          .toList(growable: false);
    }
    try {
      final loadedCatalog = await BibleCatalog.loadAsset(
        rootBundle,
        'bible_io_json/bible_list.json',
      );
      final files = loadedCatalog.sources
          .map((source) => source.assetPath)
          .toList();
      files.sort();
      if (files.isNotEmpty) {
        return files;
      }
    } catch (_) {
      // If the generated list is unavailable, fall back to the current selected bible only.
    }

    return [widget.selectedBiblePath];
  }

  String _labelForPath(String path) {
    final catalog = widget.bibleCatalog;
    if (catalog != null) {
      for (final source in catalog.sources) {
        if (source.assetPath == path) {
          final partial = source.additional['contentStatus'] == 'partial'
              ? ' · partial content'
              : '';
          return '${source.languageName} · ${source.translationName}$partial';
        }
      }
    }
    final parts = path.split('/');
    if (parts.length >= 3) {
      return '${parts[1]} / ${parts[2]}';
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tabColor = colorScheme.primary;
    final unselectedTabColor = colorScheme.onSurfaceVariant;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: tabColor,
            unselectedLabelColor: unselectedTabColor,
            indicatorColor: colorScheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.tune), text: 'General'),
              Tab(icon: Icon(Icons.format_size), text: 'Display'),
              Tab(icon: Icon(Icons.info_outline), text: 'About'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGeneralSettings(context),
            _buildDisplaySettings(context),
            _buildAboutSettings(context),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettings(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: _settingsPane([
        const Text(
          'Bible Translation',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (widget.bible != null) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_stories_rounded, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.bible!.translationName ??
                              widget.bible!.metadata.id ??
                              'Current translation',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.bible!.languageName ?? widget.bible!.language.name} · '
                          '${widget.bible!.stats.bookCount} books · '
                          '${widget.bible!.stats.chapterCount} chapters',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (widget.bible!.description
                            case final description?) ...[
                          const SizedBox(height: 8),
                          Text(description),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('Current: ${_labelForPath(_selectedBiblePath)}'),
        const SizedBox(height: 12),
        FutureBuilder<List<String>>(
          future: _bibleFiles,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final bibleFiles = snapshot.data ?? [];
            if (bibleFiles.isEmpty) {
              return const Center(child: Text('No bible files found.'));
            }
            return DropdownButtonFormField<String>(
              initialValue: _selectedBiblePath,
              decoration: const InputDecoration(
                labelText: 'Translation',
                border: OutlineInputBorder(),
              ),
              items: bibleFiles
                  .map(
                    (path) => DropdownMenuItem(
                      value: path,
                      child: Text(_labelForPath(path)),
                    ),
                  )
                  .toList(),
              onChanged: (path) {
                if (path != null && path != _selectedBiblePath) {
                  setState(() => _selectedBiblePath = path);
                  widget.onBiblePathChanged(path);
                }
              },
            );
          },
        ),
      ]),
    );
  }

  Widget _buildDisplaySettings(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: _settingsPane([
        const Text(
          'Bible Text',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Text size'),
            Text('${_bibleTextSize.round()} pt'),
          ],
        ),
        Slider(
          key: const Key('bible_text_size_slider'),
          value: _bibleTextSize,
          min: 12,
          max: 28,
          divisions: 16,
          label: '${_bibleTextSize.round()} pt',
          onChanged: (value) {
            setState(() {
              _bibleTextSize = value;
            });
          },
          onChangeEnd: widget.onBibleTextSizeChanged,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          key: const Key('show_verses_inline_switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Compact verse spacing'),
          subtitle: const Text('Fit more text on screen while reading'),
          value: _showVersesInline,
          onChanged: (value) {
            setState(() {
              _showVersesInline = value;
            });
            widget.onShowVersesInlineChanged(value);
          },
        ),
        const SizedBox(height: 24),
        _buildColorPresetControls(context),
        const SizedBox(height: 24),
        Text('Preview', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _editingBackgroundColor,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: _editingTextColor,
                  fontSize: _bibleTextSize,
                  height: 1.45,
                ),
                children: _previewTextSpans(context),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _settingsPane(List<Widget> children) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildColorPresetControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Color Preset',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  'bible_color_preset_dropdown_${_selectedColorPreset.id}',
                ),
                isExpanded: true,
                initialValue: _selectedColorPreset.id,
                decoration: const InputDecoration(
                  labelText: 'Preset',
                  border: OutlineInputBorder(),
                ),
                items: _colorPresets
                    .map(
                      (preset) => DropdownMenuItem(
                        value: preset.id,
                        child: Row(
                          children: [
                            _ColorSwatchPair(preset: preset),
                            const SizedBox(width: 12),
                            Expanded(child: Text(preset.name)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (presetId) {
                  final preset = _colorPresets.firstWhere(
                    (preset) => preset.id == presetId,
                    orElse: () => _selectedColorPreset,
                  );
                  setState(() {
                    _selectedColorPreset = preset;
                    _editingBackgroundColor = preset.backgroundColor;
                    _editingTextColor = preset.textColor;
                  });
                  widget.onColorPresetChanged(preset);
                },
              ),
            ),
            if (!_selectedColorPreset.isBuiltIn) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const Key('delete_custom_color_preset_button'),
                tooltip: 'Delete custom preset',
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleteSelectedCustomColorPreset,
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        _buildColorEditor(
          context,
          label: 'Background',
          color: _editingBackgroundColor,
          onChanged: (color) {
            setState(() {
              _editingBackgroundColor = color;
            });
          },
        ),
        const SizedBox(height: 12),
        _buildColorEditor(
          context,
          label: 'Text',
          color: _editingTextColor,
          onChanged: (color) {
            setState(() {
              _editingTextColor = color;
            });
          },
        ),
        const SizedBox(height: 12),
        _ContrastStatus(
          backgroundColor: _editingBackgroundColor,
          textColor: _editingTextColor,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Save preset'),
            onPressed: _saveCurrentColorPreset,
          ),
        ),
      ],
    );
  }

  void _deleteSelectedCustomColorPreset() {
    if (_selectedColorPreset.isBuiltIn) {
      return;
    }

    final deletedPreset = _selectedColorPreset;
    final fallbackPreset = builtInBibleColorPresets.first;
    setState(() {
      _colorPresets = _colorPresets
          .where((preset) => preset.id != deletedPreset.id)
          .toList();
      _selectedColorPreset = fallbackPreset;
      _editingBackgroundColor = fallbackPreset.backgroundColor;
      _editingTextColor = fallbackPreset.textColor;
    });
    widget.onCustomColorPresetDeleted(deletedPreset);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted “${deletedPreset.name}”'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              setState(() {
                _colorPresets = [..._colorPresets, deletedPreset];
                _selectedColorPreset = deletedPreset;
                _editingBackgroundColor = deletedPreset.backgroundColor;
                _editingTextColor = deletedPreset.textColor;
              });
              widget.onCustomColorPresetSaved(deletedPreset);
            },
          ),
        ),
      );
  }

  Widget _buildColorEditor(
    BuildContext context, {
    required String label,
    required Color color,
    required ValueChanged<Color> onChanged,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _ColorSwatch(color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    _formatColor(color),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.palette_outlined),
              label: const Text('Edit'),
              onPressed: () async {
                final selected = await showDialog<Color>(
                  context: context,
                  builder: (context) =>
                      _ColorPickerDialog(title: label, initialColor: color),
                );
                if (selected != null) {
                  onChanged(selected);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCurrentColorPreset() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _SaveColorPresetDialog(
        initialName: '${_selectedColorPreset.name} Custom',
      ),
    );
    if (!mounted) {
      return;
    }

    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      return;
    }

    final preset = BibleColorPreset(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmedName,
      backgroundColor: _editingBackgroundColor,
      textColor: _editingTextColor,
    );
    setState(() {
      _colorPresets = [..._colorPresets, preset];
      _selectedColorPreset = preset;
    });
    widget.onCustomColorPresetSaved(preset);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved “${preset.name}”')));
  }

  String _formatColor(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  List<TextSpan> _previewTextSpans(BuildContext context) {
    final verseNumberStyle = TextStyle(
      color: BibleColorPreset(
        id: 'preview',
        name: 'Preview',
        backgroundColor: _editingBackgroundColor,
        textColor: _editingTextColor,
      ).verseNumberColor,
      fontWeight: FontWeight.bold,
    );

    if (_showVersesInline) {
      return [
        TextSpan(text: '1: ', style: verseNumberStyle),
        const TextSpan(
          text: 'In the beginning God created the heaven and the earth. ',
        ),
        TextSpan(text: '2: ', style: verseNumberStyle),
        const TextSpan(
          text:
              'And the earth was without form, and void; and darkness was upon the face of the deep.',
        ),
      ];
    }

    return [
      TextSpan(text: '1: ', style: verseNumberStyle),
      const TextSpan(
        text: 'In the beginning God created the heaven and the earth.\n\n',
      ),
      TextSpan(text: '2: ', style: verseNumberStyle),
      const TextSpan(
        text:
            'And the earth was without form, and void; and darkness was upon the face of the deep.',
      ),
    ];
  }

  Widget _buildAboutSettings(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: _settingsPane([
        Row(
          children: [
            Icon(
              Icons.menu_book,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FutureBuilder<PackageInfo>(
                future: _packageInfo,
                builder: (context, snapshot) {
                  final versionText = snapshot.hasData
                      ? 'Version ${_formatVersion(snapshot.data!)}'
                      : 'Version loading...';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _kAppName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        versionText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildAboutRow(context, 'Made by', _kAppMaker),
        _buildAboutRow(context, 'License', _kAppLicense),
        _buildAboutRow(
          context,
          'Bible data',
          'Bundled Bible JSON files from the BibleIO project',
        ),
        if (widget.bible?.copyright case final copyright?)
          _buildAboutRow(context, 'Translation copyright', copyright),
        if (widget.bible?.license case final license?)
          _buildAboutRow(context, 'Translation license', license),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.description_outlined),
          label: const Text('Read License'),
          onPressed: () => _showLicenseFile(context),
        ),
      ]),
    );
  }

  String _formatVersion(PackageInfo packageInfo) {
    if (packageInfo.buildNumber.isEmpty) {
      return packageInfo.version;
    }
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  Widget _buildAboutRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Future<void> _showLicenseFile(BuildContext context) async {
    final licenseText = await rootBundle.loadString('LICENSE');
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('License')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText(
              licenseText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveColorPresetDialog extends StatefulWidget {
  const _SaveColorPresetDialog({required this.initialName});

  final String initialName;

  @override
  State<_SaveColorPresetDialog> createState() => _SaveColorPresetDialogState();
}

class _SaveColorPresetDialogState extends State<_SaveColorPresetDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Color Preset'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Preset name',
          border: OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.title, required this.initialColor});

  final String title;
  final Color initialColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsvColor;
  late TextEditingController _hexController;

  static const _quickColors = [
    Color(0xFFFFFFFF),
    Color(0xFFFDF6E3),
    Color(0xFFF4ECD8),
    Color(0xFF1E1E1E),
    Color(0xFF272822),
    Color(0xFF282A36),
    Color(0xFF002B36),
    Color(0xFF000000),
    Color(0xFFD4D4D4),
    Color(0xFFF8F8F2),
    Color(0xFF839496),
    Color(0xFF1F2937),
  ];

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(
      text: _formatColor(_hsvColor.toColor()),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _setColor(Color color) {
    setState(() {
      _hsvColor = HSVColor.fromColor(color);
      _hexController.text = _formatColor(color);
      _hexController.selection = TextSelection.collapsed(
        offset: _hexController.text.length,
      );
    });
  }

  void _setHsvColor(HSVColor color) {
    setState(() {
      _hsvColor = color;
      _hexController.text = _formatColor(color.toColor());
      _hexController.selection = TextSelection.collapsed(
        offset: _hexController.text.length,
      );
    });
  }

  void _updateFromHex(String value) {
    final color = _tryParseColor(value);
    if (color == null) {
      return;
    }
    setState(() {
      _hsvColor = HSVColor.fromColor(color);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsvColor.toColor();
    return AlertDialog(
      title: Text('${widget.title} Color'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ColorSwatch(color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      decoration: const InputDecoration(
                        labelText: 'Hex',
                        border: OutlineInputBorder(),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[#0-9a-fA-F]'),
                        ),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      onChanged: _updateFromHex,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 190,
                child: _SaturationValuePicker(
                  color: _hsvColor,
                  onChanged: _setHsvColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(width: 36, child: Text('Hue')),
                  Expanded(
                    child: Slider(
                      value: _hsvColor.hue,
                      min: 0,
                      max: 360,
                      activeColor: HSVColor.fromAHSV(
                        1,
                        _hsvColor.hue,
                        1,
                        1,
                      ).toColor(),
                      label: _hsvColor.hue.round().toString(),
                      onChanged: (hue) {
                        _setHsvColor(_hsvColor.withHue(hue));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final quickColor in _quickColors)
                    Semantics(
                      button: true,
                      selected: quickColor.toARGB32() == color.toARGB32(),
                      label: 'Use ${_formatColor(quickColor)}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _setColor(quickColor),
                        child: SizedBox.square(
                          dimension: 48,
                          child: Center(child: _ColorSwatch(color: quickColor)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, color),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  String _formatColor(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Color? _tryParseColor(String value) {
    final normalized = value.replaceFirst('#', '').trim();
    if (normalized.length != 6) {
      return null;
    }

    final rgb = int.tryParse(normalized, radix: 16);
    if (rgb == null) {
      return null;
    }
    return Color(0xFF000000 | rgb);
  }
}

class _SaturationValuePicker extends StatelessWidget {
  const _SaturationValuePicker({required this.color, required this.onChanged});

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Semantics(
          label: 'Saturation and brightness',
          value:
              '${(color.saturation * 100).round()}% saturation, '
              '${(color.value * 100).round()}% brightness',
          onIncrease: () =>
              onChanged(color.withValue((color.value + 0.05).clamp(0.0, 1.0))),
          onDecrease: () =>
              onChanged(color.withValue((color.value - 0.05).clamp(0.0, 1.0))),
          child: GestureDetector(
            onTapDown: (details) =>
                _handlePosition(details.localPosition, size),
            onPanUpdate: (details) =>
                _handlePosition(details.localPosition, size),
            child: CustomPaint(
              painter: _SaturationValuePainter(color),
              size: size,
            ),
          ),
        );
      },
    );
  }

  void _handlePosition(Offset position, Size size) {
    final saturation = (position.dx / size.width).clamp(0.0, 1.0);
    final value = (1 - position.dy / size.height).clamp(0.0, 1.0);
    onChanged(color.withSaturation(saturation).withValue(value));
  }
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter(this.color);

  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, color.hue, 1, 1).toColor();

    canvas.drawRect(rect, Paint()..color = hueColor);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Colors.transparent],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );

    final handle = Offset(
      color.saturation * size.width,
      (1 - color.value) * size.height,
    );
    canvas.drawCircle(handle, 8, Paint()..color = Colors.white);
    canvas.drawCircle(
      handle,
      8,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ColorSwatchPair extends StatelessWidget {
  const _ColorSwatchPair({required this.preset});

  final BibleColorPreset preset;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 56,
        height: 36,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: preset.backgroundColor,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              'Aa',
              style: TextStyle(
                color: preset.textColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContrastStatus extends StatelessWidget {
  const _ContrastStatus({
    required this.backgroundColor,
    required this.textColor,
  });

  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final backgroundLuminance = backgroundColor.computeLuminance();
    final textLuminance = textColor.computeLuminance();
    final lighter = backgroundLuminance > textLuminance
        ? backgroundLuminance
        : textLuminance;
    final darker = backgroundLuminance > textLuminance
        ? textLuminance
        : backgroundLuminance;
    final ratio = (lighter + 0.05) / (darker + 0.05);
    final passes = ratio >= 4.5;
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label:
          'Text contrast ${ratio.toStringAsFixed(1)} to 1. '
          '${passes ? 'Passes' : 'Does not pass'} accessible text contrast.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: passes ? colors.primaryContainer : colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                passes
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                color: passes
                    ? colors.onPrimaryContainer
                    : colors.onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Contrast ${ratio.toStringAsFixed(1)}:1 · '
                  '${passes ? 'comfortable for body text' : 'increase the contrast for easier reading'}',
                  style: TextStyle(
                    color: passes
                        ? colors.onPrimaryContainer
                        : colors.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
