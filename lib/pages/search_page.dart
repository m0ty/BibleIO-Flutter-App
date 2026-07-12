import 'dart:async';

import 'package:bible_io/bible_io.dart';
import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.bible,
    required this.onResultSelected,
  });

  final Bible bible;
  final ValueChanged<BibleLocation> onResultSelected;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const int _pageSize = 50;
  static const double _maxContentWidth = 840;

  final TextEditingController _queryController = TextEditingController();

  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasSearched = false;
  SearchMode _searchMode = SearchMode.exact;
  bool _isCaseSensitive = false;
  bool _isWholeWordsOnly = false;
  bool _ignoreDiacritics = false;
  String _lastQuery = '';
  String? _lastBookFilterName;
  Book? _selectedBookFilter;
  List<SearchHit> _hits = const [];
  bool _hasMore = false;
  int? _totalCount;
  String? _searchError;
  int _searchGeneration = 0;

  bool get _hasActiveFilters =>
      _selectedBookFilter != null ||
      _searchMode != SearchMode.exact ||
      _isCaseSensitive ||
      _isWholeWordsOnly ||
      _ignoreDiacritics;

  TextDirection? get _scriptureTextDirection {
    return switch (widget.bible.textDirection) {
      TextDirectionHint.ltr => TextDirection.ltr,
      TextDirectionHint.rtl => TextDirection.rtl,
      TextDirectionHint.auto => null,
    };
  }

  @override
  void initState() {
    super.initState();
    unawaited(_prewarmSearchIndex());
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bible, widget.bible)) {
      _searchGeneration++;
      _resetSearchState();
      unawaited(_prewarmSearchIndex());
    }
  }

  Future<void> _prewarmSearchIndex() async {
    try {
      await widget.bible.prewarmSearchIndexAsync();
    } on Object {
      // A search can still fall back to scanning when index prewarming fails.
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch({bool loadMore = false}) async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      _searchGeneration++;
      setState(_resetSearchState);
      return;
    }

    if (loadMore && (!_hasMore || _isLoadingMore || _isSearching)) {
      return;
    }

    final generation = loadMore ? _searchGeneration : ++_searchGeneration;
    final offset = loadMore ? _hits.length : 0;
    final options = SearchOptions(
      mode: _searchMode,
      book: _selectedBookFilter?.bookEnum,
      caseSensitive: _isCaseSensitive,
      wholeWords: _isWholeWordsOnly,
      ignoreDiacritics: _ignoreDiacritics,
      maxResults: _pageSize,
      offset: offset,
    );
    final bookFilterName = _selectedBookFilter?.name;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isSearching = true;
        _isLoadingMore = false;
        _searchError = null;
      }
    });

    await Future<void>.delayed(Duration.zero);

    try {
      final page = widget.bible.searchWithOptions(query, options);
      if (!mounted || generation != _searchGeneration) {
        return;
      }

      setState(() {
        _hasSearched = true;
        _isSearching = false;
        _isLoadingMore = false;
        _lastQuery = query;
        _lastBookFilterName = bookFilterName;
        _hits = loadMore ? [..._hits, ...page.hits] : page.hits;
        _hasMore = page.hasMore;
        _totalCount = page.totalCount;
        _searchError = null;
      });
    } on Object {
      if (!mounted || generation != _searchGeneration) {
        return;
      }
      setState(() {
        _hasSearched = true;
        _isSearching = false;
        _isLoadingMore = false;
        _searchError = 'Search could not be completed. Please try again.';
      });
    }
  }

  void _resetSearchState() {
    _isSearching = false;
    _isLoadingMore = false;
    _hasSearched = false;
    _lastQuery = '';
    _lastBookFilterName = null;
    _hits = const [];
    _hasMore = false;
    _totalCount = null;
    _searchError = null;
  }

  void _handleQueryChanged(String value) {
    final query = value.trim();
    if (_isSearching ||
        _isLoadingMore ||
        (_hasSearched && query != _lastQuery)) {
      _searchGeneration++;
      setState(_resetSearchState);
      return;
    }
    setState(() {});
  }

  void _clearQuery() {
    _queryController.clear();
    _searchGeneration++;
    setState(_resetSearchState);
  }

  void _clearFilters() {
    if (!_hasActiveFilters) {
      return;
    }
    setState(() {
      _selectedBookFilter = null;
      _searchMode = SearchMode.exact;
      _isCaseSensitive = false;
      _isWholeWordsOnly = false;
      _ignoreDiacritics = false;
    });

    if (_queryController.text.trim().isNotEmpty) {
      _runSearch();
    }
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
    bool? ignoreDiacritics,
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
      if (ignoreDiacritics != null) {
        _ignoreDiacritics = ignoreDiacritics;
      }
    });

    if (_queryController.text.trim().isNotEmpty) {
      _runSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 900 ? 32.0 : 16.0;
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _CenteredContent(child: _buildSearchControls()),
                ),
              ),
              ..._buildResultSlivers(horizontalPadding),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchControls() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('search_query_field'),
          controller: _queryController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Search Scripture',
            hintText: 'Enter a word or phrase',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_queryController.text.isNotEmpty)
                  IconButton(
                    key: const Key('search_clear_query_button'),
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear search',
                    onPressed: _clearQuery,
                  ),
                IconButton(
                  key: const Key('search_button'),
                  icon: const Icon(Icons.search),
                  tooltip: 'Search',
                  onPressed: _isSearching ? null : _runSearch,
                ),
              ],
            ),
          ),
          onChanged: _handleQueryChanged,
          onSubmitted: (_) => _runSearch(),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final bookFilter = _buildBookFilter();
            final matchMode = _buildMatchMode(theme);
            if (constraints.maxWidth < 640) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [bookFilter, const SizedBox(height: 12), matchMode],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: bookFilter),
                const SizedBox(width: 16),
                Expanded(child: matchMode),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth >= 700
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: SwitchListTile(
                    key: const Key('search_case_sensitive_toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Case sensitive'),
                    subtitle: const Text('Distinguish uppercase and lowercase'),
                    value: _isCaseSensitive,
                    onChanged: (value) =>
                        _updateSearchOptions(isCaseSensitive: value),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: SwitchListTile(
                    key: const Key('search_whole_word_toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Whole words only'),
                    subtitle: const Text('Exclude partial-word matches'),
                    value: _isWholeWordsOnly,
                    onChanged: (value) =>
                        _updateSearchOptions(isWholeWordsOnly: value),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: SwitchListTile(
                    key: const Key('search_ignore_diacritics_toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ignore diacritics'),
                    subtitle: const Text('Match letters with or without marks'),
                    value: _ignoreDiacritics,
                    onChanged: (value) =>
                        _updateSearchOptions(ignoreDiacritics: value),
                  ),
                ),
              ],
            );
          },
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            key: const Key('search_clear_filters_button'),
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Reset filters'),
            onPressed: _hasActiveFilters ? _clearFilters : null,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildBookFilter() {
    return KeyedSubtree(
      key: const Key('search_book_filter'),
      child: DropdownButtonFormField<Book?>(
        key: ValueKey(_selectedBookFilter?.bookEnum),
        initialValue: _selectedBookFilter,
        isExpanded: true,
        menuMaxHeight: 360,
        decoration: const InputDecoration(
          labelText: 'Book',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<Book?>(value: null, child: Text('All books')),
          ...widget.bible.books.map(
            (book) => DropdownMenuItem<Book?>(
              value: book,
              child: Text(book.name, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: _updateBookFilter,
      ),
    );
  }

  Widget _buildMatchMode(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
          child: Text('Match', style: theme.textTheme.labelLarge),
        ),
        SegmentedButton<SearchMode>(
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
      ],
    );
  }

  List<Widget> _buildResultSlivers(double horizontalPadding) {
    if (_isSearching) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Searching Scripture',
            ),
          ),
        ),
      ];
    }

    if (_searchError != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _SearchMessage(
            icon: Icons.error_outline,
            message: _searchError!,
            action: FilledButton.icon(
              onPressed: _runSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ),
      ];
    }

    if (!_hasSearched) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _SearchMessage(
            icon: Icons.manage_search,
            message:
                'Enter a word or phrase, then refine the search by book or match options.',
          ),
        ),
      ];
    }

    if (_hits.isEmpty) {
      return [
        _buildResultSummarySliver(horizontalPadding),
        SliverFillRemaining(
          hasScrollBody: false,
          child: _SearchMessage(
            icon: Icons.search_off,
            message: 'No verses matched your search.',
            action: _hasActiveFilters
                ? OutlinedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Reset filters'),
                  )
                : null,
          ),
        ),
      ];
    }

    return [
      _buildResultSummarySliver(horizontalPadding),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        sliver: SliverList.separated(
          itemCount: _hits.length,
          separatorBuilder: (context, index) =>
              const _CenteredContent(child: Divider(height: 1)),
          itemBuilder: (context, index) {
            final hit = _hits[index];
            return _CenteredContent(child: _buildResultTile(hit));
          },
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          24,
        ),
        sliver: SliverToBoxAdapter(
          child: _CenteredContent(
            child: Center(
              child: _hasMore
                  ? FilledButton.tonalIcon(
                      key: const Key('search_load_more_button'),
                      onPressed: _isLoadingMore
                          ? null
                          : () => _runSearch(loadMore: true),
                      icon: _isLoadingMore
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more),
                      label: Text(
                        _isLoadingMore ? 'Loading more…' : 'Load more results',
                      ),
                    )
                  : Text(
                      'End of results',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildResultSummarySliver(double horizontalPadding) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 8),
      sliver: SliverToBoxAdapter(
        child: _CenteredContent(
          child: Semantics(
            liveRegion: true,
            child: Text(
              _resultSummary,
              key: const Key('search_result_summary'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }

  String get _resultSummary {
    final knownTotal = _totalCount;
    final countText = knownTotal == null && _hasMore
        ? '${_hits.length}+'
        : '${knownTotal ?? _hits.length}';
    final singular = knownTotal == 1 && !_hasMore;
    return '$countText result${singular ? '' : 's'} for "$_lastQuery"'
        '${_lastBookFilterName == null ? '' : ' in $_lastBookFilterName'}';
  }

  Widget _buildResultTile(SearchHit hit) {
    final location = BibleLocation.fromVerse(hit.verse);
    final resultKey =
        '${hit.verse.book.name}_${hit.verse.chapterNumber}_${hit.verse.verseNumber}';
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyMedium;
    final matchStyle = baseStyle?.copyWith(
      color: theme.colorScheme.onPrimaryContainer,
      backgroundColor: theme.colorScheme.primaryContainer,
      fontWeight: FontWeight.w700,
    );

    return Semantics(
      button: true,
      label: '${hit.reference}. ${hit.verse.text}',
      excludeSemantics: true,
      child: ListTile(
        key: ValueKey('search_result_$resultKey'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        title: Text(
          hit.reference,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text.rich(
            key: ValueKey('search_result_snippet_$resultKey'),
            TextSpan(
              style: baseStyle,
              children: _highlightedSnippetSpans(hit, matchStyle),
            ),
            textDirection: _scriptureTextDirection,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          widget.onResultSelected(location);
          Navigator.pop(context);
        },
      ),
    );
  }

  List<InlineSpan> _highlightedSnippetSpans(
    SearchHit hit,
    TextStyle? matchStyle,
  ) {
    final spans = <InlineSpan>[];
    if (hit.hasLeadingOmission) {
      spans.add(const TextSpan(text: '…'));
    }

    var cursor = 0;
    for (final range in hit.snippetMatchRanges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: hit.snippet.substring(cursor, range.start)));
      }
      spans.add(
        TextSpan(
          text: hit.snippet.substring(range.start, range.end),
          style: matchStyle,
        ),
      );
      cursor = range.end;
    }
    if (cursor < hit.snippet.length) {
      spans.add(TextSpan(text: hit.snippet.substring(cursor)));
    }
    if (hit.hasTrailingOmission) {
      spans.add(const TextSpan(text: '…'));
    }
    return spans;
  }
}

class _CenteredContent extends StatelessWidget {
  const _CenteredContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _SearchPageState._maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
