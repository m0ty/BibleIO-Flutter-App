import 'package:bible_io/bible_io.dart';
import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.bible,
    required this.onResultSelected,
  });

  final Bible bible;
  final void Function(Book book, int chapterNumber) onResultSelected;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _queryController = TextEditingController();
  bool _isSearching = false;
  bool _hasSearched = false;
  SearchMode _searchMode = SearchMode.exact;
  bool _isCaseSensitive = false;
  bool _isWholeWordsOnly = false;
  String _lastQuery = '';
  String? _lastBookFilterName;
  Book? _selectedBookFilter;
  List<_SearchResult> _results = const [];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _hasSearched = false;
        _isSearching = false;
        _lastQuery = '';
        _lastBookFilterName = null;
        _results = const [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    await Future<void>.delayed(Duration.zero);
    final results = _searchBible(query);

    if (!mounted) {
      return;
    }

    setState(() {
      _hasSearched = true;
      _isSearching = false;
      _lastQuery = query;
      _lastBookFilterName = _selectedBookFilter?.name;
      _results = results;
    });
  }

  List<_SearchResult> _searchBible(String query) {
    final results = widget.bible.searchWithOptions(
      query,
      SearchOptions(
        mode: _searchMode,
        book: _selectedBookFilter?.bookEnum,
        caseSensitive: _isCaseSensitive,
        wholeWords: _isWholeWordsOnly,
      ),
    );

    return results.verses
        .map(
          (verse) => _SearchResult(
            book: widget.bible.getBook(verse.book),
            chapterNumber: verse.chapterNumber,
            verseNumber: verse.verseNumber,
            verseText: verse.text,
          ),
        )
        .toList();
  }

  void _updateBookFilter(Book? book) {
    setState(() {
      _selectedBookFilter = book;
    });

    if (_queryController.text.trim().isNotEmpty) {
      _runSearch();
    }
  }

  void _updateSearchOptions({
    SearchMode? searchMode,
    bool? isCaseSensitive,
    bool? isWholeWordsOnly,
  }) {
    setState(() {
      if (searchMode != null) {
        _searchMode = searchMode;
      }
      if (isCaseSensitive != null) {
        _isCaseSensitive = isCaseSensitive;
      }
      if (isWholeWordsOnly != null) {
        _isWholeWordsOnly = isWholeWordsOnly;
      }
    });

    if (_queryController.text.trim().isNotEmpty) {
      _runSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resultSummary =
        '${_results.length} result${_results.length == 1 ? '' : 's'} for "$_lastQuery"'
        '${_lastBookFilterName == null ? '' : ' in $_lastBookFilterName'}';

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('search_query_field'),
              controller: _queryController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by word or phrase',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const Key('search_button'),
                  icon: const Icon(Icons.search),
                  tooltip: 'Search',
                  onPressed: _runSearch,
                ),
              ),
              onSubmitted: (_) => _runSearch(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Book?>(
              key: const Key('search_book_filter'),
              initialValue: _selectedBookFilter,
              isExpanded: true,
              menuMaxHeight: 360,
              decoration: const InputDecoration(
                labelText: 'Book',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<Book?>(
                  value: null,
                  child: Text('All books'),
                ),
                ...widget.bible.books.map(
                  (book) => DropdownMenuItem<Book?>(
                    value: book,
                    child: Text(book.name),
                  ),
                ),
              ],
              onChanged: _updateBookFilter,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Match', style: theme.textTheme.labelLarge),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<SearchMode>(
                    key: const Key('search_mode_filter'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<SearchMode>(
                        value: SearchMode.exact,
                        label: Text('Phrase'),
                      ),
                      ButtonSegment<SearchMode>(
                        value: SearchMode.all,
                        label: Text('All'),
                      ),
                      ButtonSegment<SearchMode>(
                        value: SearchMode.any,
                        label: Text('Any'),
                      ),
                    ],
                    selected: {_searchMode},
                    onSelectionChanged: (selection) {
                      _updateSearchOptions(searchMode: selection.single);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const Key('search_case_sensitive_toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Case sensitive'),
              subtitle: const Text(
                'Treat uppercase and lowercase as different',
              ),
              value: _isCaseSensitive,
              onChanged: (value) =>
                  _updateSearchOptions(isCaseSensitive: value),
            ),
            SwitchListTile(
              key: const Key('search_whole_word_toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Whole words only'),
              subtitle: const Text(
                'Match complete words instead of partial text',
              ),
              value: _isWholeWordsOnly,
              onChanged: (value) =>
                  _updateSearchOptions(isWholeWordsOnly: value),
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (!_hasSearched)
              Expanded(
                child: Center(
                  child: Text(
                    'Enter a word or phrase, optionally choose a book or search options, then search.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(resultSummary, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _results.isEmpty
                          ? const Center(
                              child: Text('No verses matched your search.'),
                            )
                          : ListView.separated(
                              itemCount: _results.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final result = _results[index];
                                return ListTile(
                                  title: Text(
                                    '${result.book.name} ${result.chapterNumber}:${result.verseNumber}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(result.verseText),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    widget.onResultSelected(
                                      result.book,
                                      result.chapterNumber,
                                    );
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchResult {
  const _SearchResult({
    required this.book,
    required this.chapterNumber,
    required this.verseNumber,
    required this.verseText,
  });

  final Book book;
  final int chapterNumber;
  final int verseNumber;
  final String verseText;
}
