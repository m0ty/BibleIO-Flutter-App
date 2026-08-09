import 'dart:async';

import 'package:bible_io/bible_io.dart';
import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/bible_pedia_history.dart';
import '../services/bible_pedia_loader.dart';
import 'bible_pedia_entry_page.dart';

typedef BiblePediaBundleLoader = Future<BibleEncyclopediaBundle> Function();

enum BiblePediaSection { browse, currentChapter, recent }

/// Browses Bible Pedia, chapter-relevant entries, and recently opened entries.
class BiblePediaPage extends StatefulWidget {
  const BiblePediaPage({
    super.key,
    this.currentLocation,
    this.currentChapterLabel,
    this.preferences,
    this.initialSection = BiblePediaSection.browse,
    this.bundleLoader = loadBiblePediaBundle,
  });

  final BibleLocation? currentLocation;
  final String? currentChapterLabel;
  final SharedPreferences? preferences;
  final BiblePediaSection initialSection;
  final BiblePediaBundleLoader bundleLoader;

  @override
  State<BiblePediaPage> createState() => _BiblePediaPageState();
}

class _BiblePediaPageState extends State<BiblePediaPage> {
  late Future<BibleEncyclopediaBundle> _bundleFuture;
  BiblePediaHistory? _history;
  List<String> _recentIds = const [];
  final List<String> _sessionRecentIds = [];
  Future<void> _historyWriteQueue = Future.value();
  bool _clearPending = false;

  @override
  void initState() {
    super.initState();
    _bundleFuture = widget.bundleLoader();
    final preferences = widget.preferences;
    if (preferences != null) {
      _history = BiblePediaHistory(preferences);
      _recentIds = _history!.read();
    } else {
      unawaited(_loadHistory());
    }
  }

  Future<void> _loadHistory() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final history = BiblePediaHistory(preferences);
      if (!mounted) return;

      final shouldClear = _clearPending;
      final sessionIds = List<String>.of(_sessionRecentIds);
      final storedIds = shouldClear ? const <String>[] : history.read();
      _clearPending = false;
      _history = history;
      setState(() {
        _recentIds = _mergeRecent(sessionIds, storedIds);
      });
      _queueHistoryWrite((history) async {
        if (shouldClear) await history.clear();
        for (final id in sessionIds.reversed) {
          await history.record(id);
        }
      });
    } on Object {
      // History is an enhancement; encyclopedia browsing remains available.
    }
  }

  void _queueHistoryWrite(
    Future<void> Function(BiblePediaHistory history) operation,
  ) {
    final history = _history;
    if (history == null) return;
    _historyWriteQueue = _historyWriteQueue
        .then((_) => operation(history))
        .catchError((Object _) {
          // Preference failures must not interrupt encyclopedia browsing.
        });
  }

  void _retryLoading() {
    setState(() {
      _bundleFuture = widget.bundleLoader();
    });
  }

  void _openEntry(EncyclopediaEntry entry, BibleEncyclopedia encyclopedia) {
    _recordEntry(entry);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/bible-pedia/entry/${entry.id}'),
        builder: (context) => BiblePediaEntryPage(
          entry: entry,
          encyclopedia: encyclopedia,
          onEntryOpened: _recordEntry,
          onCitationSelected: _openCitation,
        ),
      ),
    );
  }

  void _recordEntry(EncyclopediaEntry entry) {
    _sessionRecentIds
      ..remove(entry.id)
      ..insert(0, entry.id);
    if (_sessionRecentIds.length > BiblePediaHistory.maxEntries) {
      _sessionRecentIds.removeRange(
        BiblePediaHistory.maxEntries,
        _sessionRecentIds.length,
      );
    }
    if (mounted) {
      setState(() {
        _recentIds = _mergeRecent([entry.id], _recentIds);
      });
    }
    _queueHistoryWrite((history) => history.record(entry.id));
  }

  void _clearHistory() {
    _sessionRecentIds.clear();
    setState(() => _recentIds = const []);
    if (_history == null) {
      _clearPending = true;
    } else {
      _queueHistoryWrite((history) => history.clear());
    }
  }

  void _openCitation(BibleCitation citation) {
    if (citation.books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This reference cannot be opened.')),
      );
      return;
    }
    final location = BibleLocation.fromVerseRef(citation.firstReference);

    final navigator = Navigator.of(context);
    final pediaRoute = ModalRoute.of(context);
    if (pediaRoute != null) {
      navigator.popUntil((route) => route == pediaRoute);
    }
    navigator.pop(location);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialSection.index,
      child: Scaffold(
        key: const Key('bible_pedia_page'),
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_library_outlined, size: 24),
              SizedBox(width: 10),
              Flexible(child: Text('Bible Pedia')),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(key: Key('bible_pedia_browse_tab'), text: 'Browse'),
              Tab(key: Key('bible_pedia_chapter_tab'), text: 'This chapter'),
              Tab(key: Key('bible_pedia_recent_tab'), text: 'Recent'),
            ],
          ),
        ),
        body: FutureBuilder<BibleEncyclopediaBundle>(
          future: _bundleFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _PediaMessage(
                key: Key('bible_pedia_loading'),
                icon: Icons.local_library_outlined,
                title: 'Opening Bible Pedia',
                message: 'Preparing encyclopedia entries…',
                loading: true,
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              final error = snapshot.error;
              final canRetry =
                  error is! EncyclopediaLoadException || error.isRetryable;
              return _PediaMessage(
                key: const Key('bible_pedia_error'),
                icon: Icons.error_outline_rounded,
                title: 'Bible Pedia could not be opened',
                message: canRetry
                    ? 'Check that the encyclopedia bundle is available, then try again.'
                    : 'The bundled encyclopedia data is invalid or incompatible with this app.',
                action: canRetry
                    ? FilledButton.icon(
                        key: const Key('bible_pedia_retry_button'),
                        onPressed: _retryLoading,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      )
                    : null,
              );
            }

            final bundle = snapshot.data!;
            final encyclopedia = bundle.encyclopedia;
            return TabBarView(
              children: [
                _BrowsePediaTab(
                  bundle: bundle,
                  onEntrySelected: (entry) => _openEntry(entry, encyclopedia),
                ),
                _ChapterPediaTab(
                  bundle: bundle,
                  location: widget.currentLocation,
                  chapterLabel: widget.currentChapterLabel,
                  onEntrySelected: (entry) => _openEntry(entry, encyclopedia),
                ),
                _RecentPediaTab(
                  encyclopedia: encyclopedia,
                  recentIds: _recentIds,
                  onEntrySelected: (entry) => _openEntry(entry, encyclopedia),
                  onClear: _clearHistory,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BrowsePediaTab extends StatefulWidget {
  const _BrowsePediaTab({required this.bundle, required this.onEntrySelected});

  final BibleEncyclopediaBundle bundle;
  final ValueChanged<EncyclopediaEntry> onEntrySelected;

  @override
  State<_BrowsePediaTab> createState() => _BrowsePediaTabState();
}

class _BrowsePediaTabState extends State<_BrowsePediaTab> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoryId;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final encyclopedia = widget.bundle.encyclopedia;
    final selectedCategoryId = _selectedCategoryId;
    final hits = encyclopedia.searchHits(
      EncyclopediaQuery(
        text: _query,
        categoryIds: selectedCategoryId == null
            ? const []
            : [selectedCategoryId],
      ),
    );
    final entries = hits.map((hit) => hit.entry).toList(growable: false);
    if (_query.trim().isEmpty) {
      entries.sort(_compareEntries);
    }
    final snippetsById = <String, String>{
      for (final hit in hits) hit.entry.id: hit.snippet,
    };
    final categoryCounts = encyclopedia.categoryCounts;
    final selectedCategory = selectedCategoryId == null
        ? null
        : widget.bundle.categoryById(selectedCategoryId);
    final hasResults = entries.isNotEmpty;

    return ListView.builder(
      key: const PageStorageKey('bible_pedia_browse_list'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: hasResults ? entries.length + 1 : 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CenteredPediaContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BrowseHero(
                  entryCount: encyclopedia.length,
                  rights: widget.bundle.rights,
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('bible_pedia_search_field'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search people, places, events, and concepts',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 22),
                Semantics(
                  header: true,
                  child: Text(
                    'Explore by section',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final visibleCategories = widget.bundle.categories
                        .where(
                          (category) => (categoryCounts[category.id] ?? 0) > 0,
                        )
                        .toList(growable: false);
                    final columnCount = constraints.maxWidth >= 720
                        ? 4
                        : constraints.maxWidth >= 280
                        ? 2
                        : 1;
                    const spacing = 12.0;
                    final cardWidth =
                        (constraints.maxWidth - spacing * (columnCount - 1)) /
                        columnCount;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final category in visibleCategories)
                          SizedBox(
                            width: cardWidth,
                            child: _CategoryCard(
                              category: category,
                              count: categoryCounts[category.id]!,
                              selected: category.id == selectedCategoryId,
                              onTap: () => setState(() {
                                _selectedCategoryId =
                                    selectedCategoryId == category.id
                                    ? null
                                    : category.id;
                              }),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          selectedCategory?.label ?? 'All entries',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    Text(
                      '${entries.length}',
                      key: const Key('bible_pedia_result_count'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (selectedCategoryId != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Show every section',
                        onPressed: () =>
                            setState(() => _selectedCategoryId = null),
                        icon: const Icon(Icons.filter_alt_off_outlined),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }

        if (!hasResults) {
          return const _CenteredPediaContent(
            child: _InlineEmptyState(
              key: Key('bible_pedia_no_search_results'),
              icon: Icons.search_off_rounded,
              title: 'No entries found',
              message: 'Try another search or choose a different section.',
            ),
          );
        }

        final entry = entries[index - 1];
        return _CenteredPediaContent(
          child: _PediaEntryCard(
            entry: entry,
            supportingText: _query.trim().isEmpty
                ? _entrySupportingText(entry)
                : snippetsById[entry.id] ?? _entrySupportingText(entry),
            onTap: () => widget.onEntrySelected(entry),
          ),
        );
      },
    );
  }
}

class _ChapterPediaTab extends StatelessWidget {
  const _ChapterPediaTab({
    required this.bundle,
    required this.location,
    required this.chapterLabel,
    required this.onEntrySelected,
  });

  final BibleEncyclopediaBundle bundle;
  final BibleLocation? location;
  final String? chapterLabel;
  final ValueChanged<EncyclopediaEntry> onEntrySelected;

  @override
  Widget build(BuildContext context) {
    final currentLocation = location;
    if (currentLocation == null) {
      return const _InlineEmptyState(
        key: Key('bible_pedia_no_current_chapter'),
        icon: Icons.menu_book_outlined,
        title: 'No chapter is open',
        message:
            'Open a Bible chapter, then return here to see related entries.',
      );
    }

    final results = bundle.entriesForChapter(
      book: currentLocation.book,
      chapter: currentLocation.chapter,
    );
    final matches = results.matches.toList(growable: false)
      ..sort((left, right) => _compareEntries(left.entry, right.entry));
    final label = chapterLabel?.trim().isNotEmpty == true
        ? chapterLabel!.trim()
        : currentLocation.reference;

    return ListView.builder(
      key: const PageStorageKey('bible_pedia_chapter_list'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: matches.isEmpty ? 2 : matches.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CenteredPediaContent(
            child: _SectionHeaderCard(
              key: const Key('bible_pedia_current_chapter_header'),
              icon: Icons.auto_stories_rounded,
              eyebrow: 'CURRENT CHAPTER',
              title: label,
              message: _chapterHeaderMessage(
                matches.length,
                results.coverageStatus,
              ),
            ),
          );
        }
        if (matches.isEmpty) {
          return _CenteredPediaContent(
            child: _InlineEmptyState(
              key: const Key('bible_pedia_chapter_empty'),
              icon: Icons.travel_explore_rounded,
              title: _chapterEmptyTitle(results.coverageStatus),
              message: _chapterEmptyMessage(results.coverageStatus),
            ),
          );
        }

        final match = matches[index - 1];
        final citations = match.matchingCitations
            .map((citation) => citation.sourceText)
            .join(' • ');
        return _CenteredPediaContent(
          child: _PediaEntryCard(
            entry: match.entry,
            supportingText: 'Mentioned in $citations',
            onTap: () => onEntrySelected(match.entry),
          ),
        );
      },
    );
  }
}

class _RecentPediaTab extends StatelessWidget {
  const _RecentPediaTab({
    required this.encyclopedia,
    required this.recentIds,
    required this.onEntrySelected,
    required this.onClear,
  });

  final BibleEncyclopedia encyclopedia;
  final List<String> recentIds;
  final ValueChanged<EncyclopediaEntry> onEntrySelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final entries = _resolveRecentEntries(encyclopedia, recentIds);

    return ListView.builder(
      key: const PageStorageKey('bible_pedia_recent_list'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: entries.isEmpty ? 2 : entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CenteredPediaContent(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recently opened',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your latest Bible Pedia entries stay easy to find.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entries.isNotEmpty)
                  TextButton.icon(
                    key: const Key('bible_pedia_clear_recent'),
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          );
        }
        if (entries.isEmpty) {
          return const _CenteredPediaContent(
            child: _InlineEmptyState(
              key: Key('bible_pedia_recent_empty'),
              icon: Icons.history_rounded,
              title: 'No recent entries',
              message: 'Entries you open will appear here.',
            ),
          );
        }

        final entry = entries[index - 1];
        return _CenteredPediaContent(
          child: _PediaEntryCard(
            entry: entry,
            supportingText: _entrySupportingText(entry),
            onTap: () => onEntrySelected(entry),
          ),
        );
      },
    );
  }
}

class _BrowseHero extends StatelessWidget {
  const _BrowseHero({required this.entryCount, required this.rights});

  final int entryCount;
  final ContentRights rights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryContainer, colors.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colors.surface.withValues(alpha: 0.78),
              foregroundColor: colors.primary,
              child: const Icon(Icons.local_library_outlined, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover the world of the Bible',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$entryCount entries with people, places, events, and ideas.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  if (rights.license != 'NOASSERTION' ||
                      rights.attribution != 'Attribution not supplied') ...[
                    const SizedBox(height: 8),
                    Text(
                      '${rights.attribution} (${rights.license})',
                      key: const Key('bible_pedia_content_rights'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final CategoryDescriptor category;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${category.label}, $count entries',
      excludeSemantics: true,
      child: Card(
        key: ValueKey('bible_pedia_category_${category.id}'),
        margin: EdgeInsets.zero,
        color: selected
            ? colors.secondaryContainer
            : colors.surfaceContainerLow,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _categoryIcon(category.entryType),
                      color: selected
                          ? colors.onSecondaryContainer
                          : colors.primary,
                    ),
                    const Spacer(),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PediaEntryCard extends StatelessWidget {
  const _PediaEntryCard({
    required this.entry,
    required this.supportingText,
    required this.onTap,
  });

  final EncyclopediaEntry entry;
  final String supportingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('bible_pedia_entry_${entry.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label:
            '${entry.title}, ${_singularCategoryLabel(entry.type)}. '
            '$supportingText',
        excludeSemantics: true,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          leading: CircleAvatar(
            backgroundColor: colors.secondaryContainer,
            foregroundColor: colors.onSecondaryContainer,
            child: Icon(_categoryIcon(entry.type)),
          ),
          title: Text(
            entry.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              supportingText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _SectionHeaderCard extends StatelessWidget {
  const _SectionHeaderCard({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: colors.primaryContainer.withValues(alpha: 0.62),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 34, color: colors.onPrimaryContainer),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
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

class _CenteredPediaContent extends StatelessWidget {
  const _CenteredPediaContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 42),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PediaMessage extends StatelessWidget {
  const _PediaMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              if (loading) ...[
                const SizedBox(height: 18),
                const SizedBox(width: 200, child: LinearProgressIndicator()),
              ],
              const SizedBox(height: 18),
              Text(
                title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[const SizedBox(height: 22), action!],
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _mergeRecent(Iterable<String> first, Iterable<String> second) {
  final result = <String>[];
  final seen = <String>{};
  for (final id in [...first, ...second]) {
    if (id.trim().isEmpty || !seen.add(id)) continue;
    result.add(id);
    if (result.length == BiblePediaHistory.maxEntries) break;
  }
  return List.unmodifiable(result);
}

List<EncyclopediaEntry> _resolveRecentEntries(
  BibleEncyclopedia encyclopedia,
  Iterable<String> ids,
) {
  final entries = <EncyclopediaEntry>[];
  final canonicalIds = <String>{};
  for (final id in ids) {
    final entry = encyclopedia.entryById(id);
    if (entry != null && canonicalIds.add(entry.id)) {
      entries.add(entry);
    }
  }
  return List.unmodifiable(entries);
}

int _compareEntries(EncyclopediaEntry left, EncyclopediaEntry right) =>
    left.title.toLowerCase().compareTo(right.title.toLowerCase());

String _chapterHeaderMessage(int matchCount, CoverageStatus status) {
  if (matchCount == 0) {
    return switch (status) {
      CoverageStatus.covered =>
        'This chapter has been reviewed and has no linked entries.',
      CoverageStatus.partiallyCovered =>
        'Editorial coverage for this chapter is still in progress.',
      CoverageStatus.notCovered =>
        'Editorial review has not started for this chapter.',
    };
  }

  final summary =
      '$matchCount related ${matchCount == 1 ? 'entry' : 'entries'}';
  return switch (status) {
    CoverageStatus.covered => summary,
    CoverageStatus.partiallyCovered => '$summary; coverage is in progress.',
    CoverageStatus.notCovered => '$summary; editorial review is pending.',
  };
}

String _chapterEmptyTitle(CoverageStatus status) => switch (status) {
  CoverageStatus.covered => 'No linked entries',
  CoverageStatus.partiallyCovered => 'Coverage in progress',
  CoverageStatus.notCovered => 'Chapter not covered yet',
};

String _chapterEmptyMessage(CoverageStatus status) => switch (status) {
  CoverageStatus.covered =>
    'This reviewed chapter has no linked encyclopedia entries.',
  CoverageStatus.partiallyCovered =>
    'More entries may be added as this chapter is reviewed.',
  CoverageStatus.notCovered =>
    'This chapter has not been reviewed for Bible Pedia yet.',
};

String _entrySupportingText(EncyclopediaEntry entry) {
  final description = _plainText(entry.descriptionMarkdown);
  if (description.isNotEmpty) {
    return description.length <= 180
        ? description
        : '${description.substring(0, 179).trimRight()}…';
  }
  final references = entry.bibleReferences.length;
  return references == 0
      ? _singularCategoryLabel(entry.type)
      : '$references Bible ${references == 1 ? 'reference' : 'references'}';
}

String _plainText(String markdown) {
  var result = markdown.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
    (match) => match.group(1) ?? '',
  );
  result = result.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]*\)'),
    (match) => match.group(1)!,
  );
  result = result.replaceAll(RegExp(r'[#*_`>~-]+'), ' ');
  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}

IconData _categoryIcon(EntryType type) => switch (type) {
  EntryType.person => Icons.person_outline_rounded,
  EntryType.location => Icons.place_outlined,
  EntryType.event => Icons.event_outlined,
  EntryType.concept => Icons.lightbulb_outline_rounded,
  EntryType.other => Icons.category_outlined,
};

String _singularCategoryLabel(EntryType type) => switch (type) {
  EntryType.person => 'Person',
  EntryType.location => 'Place',
  EntryType.event => 'Event',
  EntryType.concept => 'Concept',
  EntryType.other => 'Other',
};
