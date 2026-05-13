import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_io/bible_io.dart';
import '../services/bible_loader.dart';
import 'search_page.dart';
import 'settings_page.dart';

const _kLastBookIndexKey = 'last_book_index';
const _kLastChapterKey = 'last_chapter';
const _kBibleFilePathKey = 'bible_file_path';
const _kBibleTextSizeKey = 'bible_text_size';
const _kShowVersesInlineKey = 'show_verses_inline';
const double _kDefaultBibleTextSize = 16.0;

class BibleHomePage extends StatefulWidget {
  const BibleHomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<BibleHomePage> createState() => _BibleHomePageState();
}

class _BibleHomePageState extends State<BibleHomePage> {
  Bible? _bible;
  bool _loading = true;
  String? _error;
  Book? _selectedBook;
  int _selectedChapter = 1;
  String _selectedBiblePath = 'bible_io_json/English/eng-kjv-1769.json';
  double _bibleTextSize = _kDefaultBibleTextSize;
  bool _showVersesInline = false;

  @override
  void initState() {
    super.initState();
    _loadBible();
  }

  Future<void> _loadBible([String? newBiblePath]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBiblePath =
          newBiblePath ??
          prefs.getString(_kBibleFilePathKey) ??
          _selectedBiblePath;
      _selectedBiblePath = savedBiblePath;
      _bibleTextSize =
          prefs.getDouble(_kBibleTextSizeKey) ?? _kDefaultBibleTextSize;
      _showVersesInline = prefs.getBool(_kShowVersesInlineKey) ?? false;
      _bible = await loadBibleAsset(savedBiblePath);
      final lastBookIndex = prefs.getInt(_kLastBookIndexKey) ?? 0;
      final lastChapter = prefs.getInt(_kLastChapterKey) ?? 1;
      setState(() {
        if (_bible != null && _bible!.books.isNotEmpty) {
          final safeBookIndex = (newBiblePath != null)
              ? 0
              : lastBookIndex.clamp(0, _bible!.books.length - 1);
          _selectedBook = _bible!.books[safeBookIndex];
          _selectedChapter = _selectedBook!.chapters.isNotEmpty
              ? lastChapter.clamp(1, _selectedBook!.chapters.length)
              : 1;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveReadingPosition(int bookIndex, int chapter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastBookIndexKey, bookIndex);
    await prefs.setInt(_kLastChapterKey, chapter);
  }

  Future<void> _setBiblePath(String biblePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBibleFilePathKey, biblePath);
    setState(() {
      _loading = true;
      _error = null;
    });
    await _loadBible(biblePath);
  }

  Future<void> _setBibleTextSize(double textSize) async {
    setState(() {
      _bibleTextSize = textSize;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kBibleTextSizeKey, textSize);
  }

  Future<void> _setShowVersesInline(bool showInline) async {
    setState(() {
      _showVersesInline = showInline;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowVersesInlineKey, showInline);
  }

  void _openSearchResult(Book book, int chapter) {
    if (_bible == null) {
      return;
    }

    final bookIndex = _bible!.books.indexOf(book);
    if (bookIndex < 0) {
      return;
    }

    setState(() {
      _selectedBook = _bible!.books[bookIndex];
      _selectedChapter = chapter;
    });
    _saveReadingPosition(bookIndex, chapter);
  }

  void _updateChapter(int chapter) {
    if (_selectedBook == null) return;
    setState(() {
      _selectedChapter = chapter;
    });
    final bookIndex = _bible!.books.indexOf(_selectedBook!);
    _saveReadingPosition(bookIndex, chapter);
  }

  bool get _hasPreviousChapter {
    if (_selectedBook == null) return false;
    if (_selectedChapter > 1) return true;
    final bookIndex = _bible!.books.indexOf(_selectedBook!);
    return bookIndex > 0;
  }

  bool get _hasNextChapter {
    if (_selectedBook == null) return false;
    if (_selectedChapter < _selectedBook!.chapters.length) return true;
    final bookIndex = _bible!.books.indexOf(_selectedBook!);
    return bookIndex < _bible!.books.length - 1;
  }

  void _previousChapter() {
    if (_selectedBook == null) return;

    final bookIndex = _bible!.books.indexOf(_selectedBook!);
    if (_selectedChapter > 1) {
      _updateChapter(_selectedChapter - 1);
      return;
    }

    if (bookIndex > 0) {
      final prevBook = _bible!.books[bookIndex - 1];
      final lastChapter = prevBook.chapters.length;
      setState(() {
        _selectedBook = prevBook;
        _selectedChapter = lastChapter;
      });
      _saveReadingPosition(bookIndex - 1, lastChapter);
    }
  }

  void _nextChapter() {
    if (_selectedBook == null) return;

    final bookIndex = _bible!.books.indexOf(_selectedBook!);
    if (_selectedChapter < _selectedBook!.chapters.length) {
      _updateChapter(_selectedChapter + 1);
      return;
    }

    if (bookIndex < _bible!.books.length - 1) {
      final nextBook = _bible!.books[bookIndex + 1];
      setState(() {
        _selectedBook = nextBook;
        _selectedChapter = 1;
      });
      _saveReadingPosition(bookIndex + 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BibleIO Viewer'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search verses',
            onPressed: _bible == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchPage(
                          bible: _bible!,
                          onResultSelected: _openSearchResult,
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.2,
            child: _buildSidebar(context),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: _buildMainContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Books',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: _bible == null
                ? const Center(child: Text('No Bible loaded'))
                : ListView.builder(
                    itemCount: _bible!.books.length,
                    itemBuilder: (context, index) {
                      final book = _bible!.books[index];
                      final isSelected =
                          _selectedBook?.bookEnum == book.bookEnum;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer
                                : Colors.transparent,
                            child: ListTile(
                              title: Text(
                                book.name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: Icon(
                                isSelected
                                    ? Icons.expand_less
                                    : Icons.chevron_right,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedBook = book;
                                  _selectedChapter = 1;
                                });
                                _saveReadingPosition(index, 1);
                              },
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              color: Theme.of(context).colorScheme.surface,
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 88,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 1.8,
                                    ),
                                itemCount: book.chapters.length,
                                itemBuilder: (context, chapterIndex) {
                                  final chapterNum = chapterIndex + 1;
                                  final isChapterSelected =
                                      _selectedChapter == chapterNum;
                                  return ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isChapterSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.secondaryContainer,
                                      foregroundColor: isChapterSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                          : Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer,
                                      minimumSize: const Size(48, 40),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 0,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedBook = book;
                                        _selectedChapter = chapterNum;
                                      });
                                      _saveReadingPosition(index, chapterNum);
                                    },
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '$chapterNum',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    themeMode: widget.themeMode,
                    onThemeModeChanged: widget.onThemeModeChanged,
                    selectedBiblePath: _selectedBiblePath,
                    onBiblePathChanged: (path) {
                      _setBiblePath(path);
                    },
                    bibleTextSize: _bibleTextSize,
                    onBibleTextSizeChanged: _setBibleTextSize,
                    showVersesInline: _showVersesInline,
                    onShowVersesInlineChanged: _setShowVersesInline,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorView(context);
    }
    if (_selectedBook == null) {
      return const Center(child: Text('Select a book'));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedBook!.name,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chapter $_selectedChapter',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium,
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed:
                        _hasPreviousChapter ? _previousChapter : null,
                    tooltip: 'Previous chapter',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _hasNextChapter ? _nextChapter : null,
                    tooltip: 'Next chapter',
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: _buildVersesView()),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Error loading Bible',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadBible();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersesView() {
    if (_selectedBook == null) {
      return const Center(child: Text('No book selected'));
    }

    final chapter = _bible![(_selectedBook!.bookEnum, _selectedChapter)];
    if (_showVersesInline) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: _bibleTextSize,
              height: 1.45,
            ),
            children: [
              for (var index = 0; index < chapter.verses.length; index++) ...[
                TextSpan(
                  text: '${index + 1}: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                TextSpan(
                  text: '${chapter.verses[index].text} ',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: _bibleTextSize,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: chapter.verses.length,
      itemBuilder: (context, index) {
        final verse = chapter.verses[index];
        final verseNum = index + 1;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: _bibleTextSize,
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: '$verseNum: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                TextSpan(
                  text: verse.text,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: _bibleTextSize,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
