import 'package:bible_io/bible_io.dart';
import 'package:flutter/material.dart';

class BibleSourcePicker extends StatefulWidget {
  const BibleSourcePicker({
    super.key,
    required this.catalog,
    required this.selectedPath,
  });

  final BibleCatalog catalog;
  final String? selectedPath;

  @override
  State<BibleSourcePicker> createState() => _BibleSourcePickerState();
}

class _BibleSourcePickerState extends State<BibleSourcePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final groups = <String, List<BibleSource>>{};
    for (final source in widget.catalog.sources) {
      if (query.isNotEmpty &&
          !source.translationName.toLowerCase().contains(query) &&
          !source.languageName.toLowerCase().contains(query) &&
          !source.abbreviation.toLowerCase().contains(query)) {
        continue;
      }
      groups.putIfAbsent(source.languageName, () => []).add(source);
    }
    final languages = groups.keys.toList()..sort();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Choose a translation',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Search language or translation',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: languages.isEmpty
                  ? const Center(child: Text('No translations found'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      itemCount: languages.length,
                      itemBuilder: (context, index) {
                        final language = languages[index];
                        final sources = groups[language]!;
                        return ExpansionTile(
                          initiallyExpanded:
                              query.isNotEmpty || sources.length <= 2,
                          title: Text(language),
                          subtitle: Text(
                            '${sources.length} translation${sources.length == 1 ? '' : 's'}',
                          ),
                          children: [
                            for (final source in sources)
                              ListTile(
                                leading: source.assetPath == widget.selectedPath
                                    ? const Icon(Icons.check_circle_rounded)
                                    : const Icon(Icons.menu_book_outlined),
                                title: Text(source.translationName),
                                subtitle: Text(source.abbreviation),
                                onTap: () => Navigator.pop(context, source),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
