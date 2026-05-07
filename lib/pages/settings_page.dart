import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.selectedBiblePath,
    required this.onBiblePathChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String selectedBiblePath;
  final ValueChanged<String> onBiblePathChanged;

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

    return [selectedBiblePath];
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
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
              groupValue: themeMode,
              onChanged: (value) {
                if (value != null) {
                  onThemeModeChanged(value);
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
            Text('Current: ${_labelForPath(selectedBiblePath)}'),
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
                  initialValue: selectedBiblePath,
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
                    if (path != null && path != selectedBiblePath) {
                      onBiblePathChanged(path);
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
