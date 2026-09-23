import 'dart:async';

import 'package:bible_io/bible_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bible_color_preset.dart';
import '../services/bible_loader.dart';
import '../services/reading_location_store.dart';
import '../widgets/bible_source_picker.dart';
import '../widgets/reference_dialog.dart';
import 'search_page.dart';
import 'settings_page.dart';

const _kBibleFilePathKey = 'bible_file_path';
const _kBibleTextSizeKey = 'bible_text_size';
const _kShowVersesInlineKey = 'show_verses_inline';
const _kDefaultBiblePath = 'bible_io_json/English/eng-kjv-1769.json';
const double _kDefaultBibleTextSize = 17;
const double _kCompactBreakpoint = 760;

class BibleHomePage extends StatefulWidget {
  const BibleHomePage({
    super.key,
    required this.colorPresets,
    required this.selectedColorPreset,
    required this.onColorPresetChanged,
    required this.onCustomColorPresetSaved,
    required this.onCustomColorPresetDeleted,
  });

  final List<BibleColorPreset> colorPresets;
  final BibleColorPreset selectedColorPreset;
  final ValueChanged<BibleColorPreset> onColorPresetChanged;
  final ValueChanged<BibleColorPreset> onCustomColorPresetSaved;
  final ValueChanged<BibleColorPreset> onCustomColorPresetDeleted;

  @override
  State<BibleHomePage> createState() => _BibleHomePageState();
}

class _BibleHomePageState extends State<BibleHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _focusedVerseKey = GlobalKey();
  final ScrollController _readerScrollController = ScrollController();

  SharedPreferences? _preferences;
  ReadingLocationStore? _readingLocationStore;
  BibleCatalog? _catalog;
  BibleSource? _selectedSource;
  Bible? _bible;
  BibleLocation? _location;
  BibleLoadProgress? _loadProgress;
  Object? _error;
  int _loadGeneration = 0;
  String? _focusedVerseLabel;
  double _bibleTextSize = _kDefaultBibleTextSize;
  bool _showVersesInline = false;
  bool _loading = true;
  bool _isSidebarVisible = true;
  String _bookFilter = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _readerScrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final catalog = await loadBibleCatalog();
      if (!mounted) return;

      _preferences = preferences;
      _catalog = catalog;
      _bibleTextSize =
          preferences.getDouble(_kBibleTextSizeKey) ?? _kDefaultBibleTextSize;
      _showVersesInline = preferences.getBool(_kShowVersesInlineKey) ?? false;
      _readingLocationStore = ReadingLocationStore(preferences);

      final savedPath =
          preferences.getString(_kBibleFilePathKey) ?? _kDefaultBiblePath;
      final source =
          _sourceForPath(savedPath) ??
          _sourceForPath(_kDefaultBiblePath) ??
          catalog.sources.first;
      final loaded = await _loadBibleSource(
        source,
        persistSource: false,
        allowLegacyPosition: true,
      );
      if (!loaded && savedPath != _kDefaultBiblePath) {
        final fallback = _sourceForPath(_kDefaultBiblePath);
        if (fallback != null) {
          await _loadBibleSource(
            fallback,
            persistSource: true,
            allowLegacyPosition: true,
          );
        }
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  BibleSource? _sourceForPath(String path) {
    final catalog = _catalog;
    return catalog == null ? null : bibleSourceForAsset(catalog, path);
  }

  Future<bool> _loadBibleSource(
    BibleSource source, {
    required bool persistSource,
    bool allowLegacyPosition = false,
  }) async {
    final generation = ++_loadGeneration;
    final hadBible = _bible != null;
    setState(() {
      _loading = true;
      _loadProgress = null;
      _error = null;
    });

    try {
      final bible = await loadBibleAsset(
        source.assetPath,
        source: source,
        onLoadProgress: (progress) {
          if (!mounted || generation != _loadGeneration) return;
          setState(() => _loadProgress = progress);
        },
      );
      if (!mounted || generation != _loadGeneration) return false;

      final location = _readingLocationStore!.restore(
        bible,
        source,
        allowLegacyPosition: allowLegacyPosition,
      );
      setState(() {
        _bible = bible;
        _selectedSource = source;
        _location = location;
        _focusedVerseLabel = null;
        _loading = false;
        _loadProgress = null;
        _error = null;
        _bookFilter = '';
      });

      if (persistSource) {
        await _preferences?.setString(_kBibleFilePathKey, source.assetPath);
      }
      if (location != null) unawaited(_saveReadingLocation(location));
      unawaited(bible.prewarmSearchIndexAsync());
      return true;
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return false;
      setState(() {
        _loading = false;
        _loadProgress = null;
        _error = hadBible ? null : error;
      });
      if (hadBible) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open ${source.translationName}.'),
            action: SnackBarAction(
              label: 'Details',
              onPressed: () => _showErrorDetails(error),
            ),
          ),
        );
      }
      return false;
    }
  }

  String? get _editionId {
    final bible = _bible;
    final source = _selectedSource;
    if (bible == null || source == null) return null;
    return bible.id ?? source.id;
  }

  Future<void> _saveReadingLocation(BibleLocation location) async {
    final editionId = _editionId;
    final store = _readingLocationStore;
    if (editionId == null || store == null) return;
    await store.save(editionId, location);
  }

  Book? get _selectedBook {
    final bible = _bible;
    final location = _location;
    if (bible == null || location == null) return null;
    try {
      return bible.getBook(location.book);
    } on BibleError {
      return null;
    }
  }

  Chapter? get _selectedChapter {
    final bible = _bible;
    final location = _location;
    if (bible == null || location == null) return null;
    try {
      return bible.getChapterAt(location);
    } on BibleError {
      return null;
    }
  }

  void _navigateToLocation(BibleLocation target) {
    final bible = _bible;
    if (bible == null) return;
    final chapterLocation = target.copyWith(verse: null);
    if (!bible.containsReference(chapterLocation)) return;

    setState(() {
      _location = chapterLocation;
      _focusedVerseLabel = target.verseLabel;
    });
    unawaited(_saveReadingLocation(chapterLocation));
    _revealFocusedVerse();
  }

  void _revealFocusedVerse() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final verseContext = _focusedVerseKey.currentContext;
      if (verseContext != null) {
        Scrollable.ensureVisible(
          verseContext,
          alignment: 0.16,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      } else if (_readerScrollController.hasClients) {
        _readerScrollController.jumpTo(0);
      }
    });
  }

  void _selectChapter(Book book, int chapterNumber) {
    _navigateToLocation(
      BibleLocation(book: book.bookEnum, chapter: chapterNumber),
    );
  }

  void _previousChapter() {
    final bible = _bible;
    final location = _location;
    if (bible == null || location == null) return;
    final previous = bible.previousChapter(location);
    if (previous != null) _navigateToLocation(previous);
  }

  void _nextChapter() {
    final bible = _bible;
    final location = _location;
    if (bible == null || location == null) return;
    final next = bible.nextChapter(location);
    if (next != null) _navigateToLocation(next);
  }

  Future<void> _setBibleTextSize(double textSize) async {
    setState(() => _bibleTextSize = textSize);
    await _preferences?.setDouble(_kBibleTextSizeKey, textSize);
  }

  Future<void> _setShowVersesInline(bool showInline) async {
    setState(() => _showVersesInline = showInline);
    await _preferences?.setBool(_kShowVersesInlineKey, showInline);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _kCompactBreakpoint;
        return Scaffold(
          key: _scaffoldKey,
          drawer: compact
              ? Drawer(
                  width: (constraints.maxWidth * 0.88)
                      .clamp(280.0, 360.0)
                      .toDouble(),
                  child: SafeArea(
                    child: _buildNavigationPanel(closeOnSelection: true),
                  ),
                )
              : null,
          appBar: AppBar(
            leading: compact
                ? null
                : IconButton(
                    icon: Icon(
                      _isSidebarVisible
                          ? Icons.menu_open_rounded
                          : Icons.menu_rounded,
                    ),
                    tooltip: _isSidebarVisible
                        ? 'Hide navigation'
                        : 'Show navigation',
                    onPressed: () =>
                        setState(() => _isSidebarVisible = !_isSidebarVisible),
                  ),
            title: constraints.maxWidth < 360
                ? const Icon(Icons.auto_stories_rounded, size: 24)
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories_rounded, size: 24),
                      SizedBox(width: 10),
                      Flexible(child: Text('BibleIO Reader')),
                    ],
                  ),
            actions: [
              IconButton(
                icon: const Icon(Icons.short_text_rounded),
                tooltip: 'Go to a Bible reference',
                onPressed: _bible == null ? null : _openReferenceDialog,
              ),
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Search verses',
                onPressed: _bible == null ? null : _openSearch,
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Reader settings',
                onPressed: _openSettings,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                  _openSearch,
              const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                  _openSearch,
              const SingleActivator(LogicalKeyboardKey.keyG, control: true):
                  _openReferenceDialog,
              const SingleActivator(LogicalKeyboardKey.keyG, meta: true):
                  _openReferenceDialog,
              const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
                  _previousChapter,
              const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
                  _nextChapter,
            },
            child: Focus(
              autofocus: true,
              child: Row(
                children: [
                  if (!compact && _isSidebarVisible)
                    SizedBox(
                      width: constraints.maxWidth >= 1200 ? 320 : 286,
                      child: _buildNavigationPanel(),
                    ),
                  if (!compact && _isSidebarVisible)
                    const VerticalDivider(width: 1),
                  Expanded(child: _buildMainContent()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationPanel({bool closeOnSelection = false}) {
    final theme = Theme.of(context);
    final bible = _bible;
    final selectedBook = _selectedBook;
    final query = _bookFilter.trim().toLowerCase();
    final books =
        bible?.books
            .where(
              (book) =>
                  query.isEmpty || book.name.toLowerCase().contains(query),
            )
            .toList(growable: false) ??
        const <Book>[];

    void closeDrawer() {
      if (closeOnSelection) Navigator.maybePop(context);
    }

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _catalog == null ? null : _openSourcePicker,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor: theme.colorScheme.onSecondaryContainer,
                        child: const Icon(Icons.translate_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _translationName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              bible?.languageName ??
                                  _selectedSource?.languageName ??
                                  'Choose translation',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.unfold_more_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Find a book',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _bookFilter = value),
            ),
          ),
          Expanded(
            child: _loading && bible == null
                ? const Center(child: CircularProgressIndicator())
                : books.isEmpty
                ? const Center(child: Text('No books found'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      final isSelected =
                          selectedBook?.bookEnum == book.bookEnum;
                      return _BookNavigationTile(
                        book: book,
                        selectedChapter: isSelected ? _location?.chapter : null,
                        onChapterSelected: (chapter) {
                          _selectChapter(book, chapter);
                          closeDrawer();
                        },
                      );
                    },
                  ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Reader settings'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              closeDrawer();
              _openSettings();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_loading) return _buildLoadingView();
    if (_error != null) return _buildErrorView(_error!);
    if (_bible == null || _location == null || _selectedChapter == null) {
      return const _ReaderMessage(
        icon: Icons.menu_book_outlined,
        title: 'No readable content',
        message: 'Choose another Bible translation to continue.',
      );
    }

    final preset = widget.selectedColorPreset;
    return ColoredBox(
      color: preset.backgroundColor,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            children: [
              _buildReaderHeader(),
              Expanded(child: _buildVersesView()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    final theme = Theme.of(context);
    final progress = _loadProgress;
    final phaseText = switch (progress?.phase) {
      BibleLoadPhase.reading => 'Reading translation…',
      BibleLoadPhase.processing => 'Preparing chapters…',
      BibleLoadPhase.complete => 'Almost ready…',
      null => 'Opening your Bible…',
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_stories_rounded,
                size: 54,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                phaseText,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _selectedSource?.translationName ?? 'BibleIO Reader',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(value: progress?.fraction),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(Object error) {
    return _ReaderMessage(
      icon: Icons.error_outline_rounded,
      title: 'This translation could not be opened',
      message: _friendlyError(error),
      actions: [
        FilledButton.icon(
          onPressed: _selectedSource == null
              ? _initialize
              : () => _loadBibleSource(_selectedSource!, persistSource: false),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
        if (_catalog != null)
          OutlinedButton.icon(
            onPressed: _openSourcePicker,
            icon: const Icon(Icons.translate_rounded),
            label: const Text('Choose translation'),
          ),
      ],
    );
  }

  String _friendlyError(Object error) {
    if (error is BibleDataFormatError) {
      return '${error.message}\nContent location: ${error.path}';
    }
    if (error is BibleError) return error.message;
    return 'The Bible data could not be read. Check the bundled file and try again.';
  }

  void _showErrorDetails(Object error) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Translation details'),
        content: SingleChildScrollView(child: SelectableText('$error')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderHeader() {
    final preset = widget.selectedColorPreset;
    final book = _selectedBook!;
    final location = _location!;
    final bible = _bible!;
    final previous = bible.hasPreviousChapter(location);
    final next = bible.hasNextChapter(location);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      decoration: BoxDecoration(
        color: preset.backgroundColor,
        border: Border(
          bottom: BorderSide(color: preset.textColor.withValues(alpha: 0.14)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _translationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: preset.verseNumberColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${book.name} ${location.chapter}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: preset.textColor,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous chapter',
            onPressed: previous ? _previousChapter : null,
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next chapter',
            onPressed: next ? _nextChapter : null,
          ),
        ],
      ),
    );
  }

  Widget _buildVersesView() {
    final chapter = _selectedChapter!;
    final preset = widget.selectedColorPreset;
    final direction = _readerTextDirection;
    if (chapter.verses.isEmpty) {
      return _ReaderMessage(
        icon: Icons.warning_amber_rounded,
        title: 'Chapter text unavailable',
        message:
            'This bundled edition does not contain verses for this chapter. You can continue to the next chapter or choose another translation.',
        actions: [
          if (_bible!.hasNextChapter(_location!))
            FilledButton(
              onPressed: _nextChapter,
              child: const Text('Next chapter'),
            ),
        ],
      );
    }

    final labelStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      inherit: false,
      color: preset.verseNumberColor,
      fontSize: (_bibleTextSize * 0.7).clamp(11, 16),
      fontWeight: FontWeight.w800,
      height: 1.55,
    );
    // Measure the full source labels at the current accessibility text scale.
    // A shared gutter keeps text aligned even for labels such as 123a-124b.
    final labelPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    );
    var labelWidth = 34.0;
    for (final verse in chapter.verses) {
      labelPainter.text = TextSpan(text: verse.verseLabel, style: labelStyle);
      labelPainter.layout();
      if (labelPainter.width > labelWidth) labelWidth = labelPainter.width;
    }
    labelPainter.dispose();

    return Directionality(
      textDirection: direction,
      child: SelectionArea(
        child: Scrollbar(
          controller: _readerScrollController,
          child: SingleChildScrollView(
            key: ValueKey(
              '${_editionId}_${_location!.book.name}_${_location!.chapter}',
            ),
            controller: _readerScrollController,
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
              14,
              MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
              36,
            ),
            child: Column(
              children: [
                for (final verse in chapter.verses)
                  _buildVerse(
                    verse,
                    preset,
                    compact: _showVersesInline,
                    direction: direction,
                    labelStyle: labelStyle,
                    labelWidth: labelWidth.ceilToDouble(),
                  ),
                const SizedBox(height: 18),
                _buildBottomNavigation(preset),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerse(
    Verse verse,
    BibleColorPreset preset, {
    required bool compact,
    required TextDirection direction,
    required TextStyle labelStyle,
    required double labelWidth,
  }) {
    final focused = verse.verseLabel == _focusedVerseLabel;
    return Semantics(
      key: focused ? _focusedVerseKey : null,
      container: true,
      label: 'Verse ${verse.verseLabel}',
      selected: focused,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        margin: EdgeInsets.only(bottom: compact ? 2 : 8),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: focused
              ? preset.verseNumberColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: focused
              ? Border.all(
                  color: preset.verseNumberColor.withValues(alpha: 0.55),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          textDirection: direction,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                verse.verseLabel,
                // Keep numeric ranges in source order beside RTL scripture.
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                softWrap: false,
                style: labelStyle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                verse.text,
                textDirection: direction,
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: preset.textColor,
                  fontSize: _bibleTextSize,
                  height: compact ? 1.5 : 1.62,
                  letterSpacing: 0.05,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BibleColorPreset preset) {
    final previous = _bible!.hasPreviousChapter(_location!);
    final next = _bible!.hasNextChapter(_location!);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: previous ? _previousChapter : null,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Previous'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: next ? _nextChapter : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Next'),
          ),
        ),
      ],
    );
  }

  TextDirection get _readerTextDirection {
    return _bible?.textDirection == TextDirectionHint.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  String get _translationName {
    return _bible?.translationName ??
        _selectedSource?.translationName ??
        'Bible translation';
  }

  void _openSearch() {
    final bible = _bible;
    if (bible == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            SearchPage(bible: bible, onResultSelected: _navigateToLocation),
      ),
    );
  }

  Future<void> _openReferenceDialog() async {
    final bible = _bible;
    if (bible == null) return;
    final location = await showDialog<BibleLocation>(
      context: context,
      builder: (context) => ReferenceDialog(bible: bible),
    );
    if (location != null) _navigateToLocation(location);
  }

  Future<void> _openSourcePicker() async {
    final catalog = _catalog;
    if (catalog == null) return;
    final source = await showModalBottomSheet<BibleSource>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => BibleSourcePicker(
        catalog: catalog,
        selectedPath: _selectedSource?.assetPath,
      ),
    );
    if (source == null || source.assetPath == _selectedSource?.assetPath) {
      return;
    }
    await _loadBibleSource(source, persistSource: true);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsPage(
          colorPresets: widget.colorPresets,
          selectedColorPreset: widget.selectedColorPreset,
          onColorPresetChanged: widget.onColorPresetChanged,
          onCustomColorPresetSaved: widget.onCustomColorPresetSaved,
          onCustomColorPresetDeleted: widget.onCustomColorPresetDeleted,
          selectedBiblePath: _selectedSource?.assetPath ?? _kDefaultBiblePath,
          onBiblePathChanged: (path) {
            final source = _sourceForPath(path);
            if (source != null) {
              unawaited(_loadBibleSource(source, persistSource: true));
            }
          },
          bibleTextSize: _bibleTextSize,
          onBibleTextSizeChanged: _setBibleTextSize,
          showVersesInline: _showVersesInline,
          onShowVersesInlineChanged: _setShowVersesInline,
          bible: _bible,
          bibleCatalog: _catalog,
        ),
      ),
    );
  }
}

class _BookNavigationTile extends StatelessWidget {
  const _BookNavigationTile({
    required this.book,
    required this.selectedChapter,
    required this.onChapterSelected,
  });

  final Book book;
  final int? selectedChapter;
  final ValueChanged<int> onChapterSelected;

  @override
  Widget build(BuildContext context) {
    final selected = selectedChapter != null;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colors.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ExpansionTile(
            key: ValueKey('${book.bookEnum.name}_$selected'),
            initiallyExpanded: selected,
            maintainState: false,
            shape: const RoundedRectangleBorder(),
            collapsedShape: const RoundedRectangleBorder(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            leading: Icon(
              selected ? Icons.book_rounded : Icons.book_outlined,
              size: 21,
            ),
            title: Text(
              book.name,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 64,
                  mainAxisExtent: 48,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: book.chapters.length,
                itemBuilder: (context, index) {
                  final number = book.chapters[index].chapterNumber;
                  final isSelected = number == selectedChapter;
                  return Semantics(
                    selected: isSelected,
                    button: true,
                    label: '${book.name} chapter $number',
                    child: isSelected
                        ? FilledButton(
                            onPressed: () => onChapterSelected(number),
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            child: Text('$number'),
                          )
                        : FilledButton.tonal(
                            onPressed: () => onChapterSelected(number),
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            child: Text('$number'),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

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
              Icon(icon, size: 58, color: theme.colorScheme.primary),
              const SizedBox(height: 18),
              Text(
                title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
