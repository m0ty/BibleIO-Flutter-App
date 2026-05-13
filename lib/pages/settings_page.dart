import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _kAppName = 'BibleIO Viewer';
const _kAppLicense = 'GNU Affero General Public License v3.0';
const _kAppMaker = 'Moty Fainer';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.selectedBiblePath,
    required this.onBiblePathChanged,
    required this.bibleTextSize,
    required this.onBibleTextSizeChanged,
    required this.showVersesInline,
    required this.onShowVersesInlineChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String selectedBiblePath;
  final ValueChanged<String> onBiblePathChanged;
  final double bibleTextSize;
  final ValueChanged<double> onBibleTextSizeChanged;
  final bool showVersesInline;
  final ValueChanged<bool> onShowVersesInlineChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late double _bibleTextSize;
  late bool _showVersesInline;
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _bibleTextSize = widget.bibleTextSize;
    _showVersesInline = widget.showVersesInline;
    _packageInfo = PackageInfo.fromPlatform();
  }

  Future<List<String>> _loadBibleFiles() async {
    try {
      final manifestJson = await rootBundle.loadString(
        'bible_io_json/bible_list.json',
      );
      final files = (json.decode(manifestJson) as List<dynamic>)
          .cast<String>()
          .where((path) => path.toLowerCase().endsWith('.json'))
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
    final parts = path.split('/');
    if (parts.length >= 3) {
      return '${parts[1]} / ${parts[2]}';
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tabColor = colorScheme.onPrimary;
    final unselectedTabColor = colorScheme.onPrimary.withValues(alpha: 0.72);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: TabBar(
            labelColor: tabColor,
            unselectedLabelColor: unselectedTabColor,
            indicatorColor: tabColor,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Theme',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          RadioGroup<ThemeMode>(
            groupValue: widget.themeMode,
            onChanged: (value) {
              if (value != null) {
                widget.onThemeModeChanged(value);
              }
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text('Light'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text('Dark'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bible Source',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text('Current: ${_labelForPath(widget.selectedBiblePath)}'),
          const SizedBox(height: 12),
          FutureBuilder<List<String>>(
            future: _loadBibleFiles(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final bibleFiles = snapshot.data ?? [];
              if (bibleFiles.isEmpty) {
                return const Center(child: Text('No bible files found.'));
              }
              return DropdownButtonFormField<String>(
                initialValue: widget.selectedBiblePath,
                decoration: const InputDecoration(
                  labelText: 'Select Bible file',
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
                  if (path != null && path != widget.selectedBiblePath) {
                    widget.onBiblePathChanged(path);
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDisplaySettings(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              widget.onBibleTextSizeChanged(value);
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            key: const Key('show_verses_inline_switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Continuous verses'),
            subtitle: const Text('Show verses one after another'),
            value: _showVersesInline,
            onChanged: (value) {
              setState(() {
                _showVersesInline = value;
              });
              widget.onShowVersesInlineChanged(value);
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: _bibleTextSize,
                    height: 1.45,
                  ),
                  children: _previewTextSpans(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _previewTextSpans(BuildContext context) {
    final verseNumberStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: const Text('Read License'),
            onPressed: () => _showLicenseFile(context),
          ),
        ],
      ),
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
