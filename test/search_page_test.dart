import 'package:bible_io/bible_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bible/pages/search_page.dart';
import 'package:flutter_bible/services/bible_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pageSize = 50;
  late Bible bible;

  SearchResults searchPage(
    String query, {
    SearchMode mode = SearchMode.exact,
    bool caseSensitive = false,
    bool wholeWords = false,
    bool ignoreDiacritics = false,
    BibleBookEnum? book,
    int offset = 0,
  }) {
    return bible.searchWithOptions(
      query,
      SearchOptions(
        mode: mode,
        caseSensitive: caseSensitive,
        wholeWords: wholeWords,
        ignoreDiacritics: ignoreDiacritics,
        book: book,
        maxResults: pageSize,
        offset: offset,
      ),
    );
  }

  String resultSummary(
    SearchResults page,
    String query, {
    String? book,
    int? displayedCount,
  }) {
    final shown = displayedCount ?? page.count;
    final countText = page.totalCount == null && page.hasMore
        ? '$shown+'
        : '${page.totalCount ?? shown}';
    final singular = page.totalCount == 1 && !page.hasMore;
    return '$countText result${singular ? '' : 's'} for "$query"'
        '${book == null ? '' : ' in $book'}';
  }

  Future<void> pumpSearchPage(
    WidgetTester tester, {
    Bible? source,
    ValueChanged<BibleLocation>? onResultSelected,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: SearchPage(
          bible: source ?? bible,
          onResultSelected: onResultSelected ?? (_) {},
        ),
      ),
    );
  }

  Future<void> runSearch(WidgetTester tester, String query) async {
    await tester.enterText(find.byKey(const Key('search_query_field')), query);
    await tester.tap(find.byKey(const Key('search_button')));
    await tester.pumpAndSettle();
  }

  setUpAll(() async {
    bible = await loadBibleAsset('bible_io_json/English/eng-kjv-1769.json');
  });

  test('asset loader preserves UTF-8 Bible text for search', () async {
    final arabicBible = await loadBibleAsset(
      'bible_io_json/Arabic/arb-svd-1865.json',
    );
    final firstVerse = arabicBible.getVerse(BibleBookEnum.genesis, 1, 1);
    final arabicGod = String.fromCharCodes([1575, 1604, 1604, 1607]);
    final mojibakeMarker = String.fromCharCode(0x00c3);

    expect(firstVerse.text, contains(arabicGod));
    expect(firstVerse.text, isNot(contains(mojibakeMarker)));
    expect(
      arabicBible.searchWithOptions(arabicGod, const SearchOptions()).count,
      greaterThan(0),
    );
  });

  testWidgets('book filter scopes search results to the selected book', (
    WidgetTester tester,
  ) async {
    await pumpSearchPage(tester);
    await runSearch(tester, 'jesus');

    expect(find.textContaining('for "jesus"'), findsOneWidget);
    expect(find.text('No verses matched your search.'), findsNothing);

    await tester.ensureVisible(find.text('All books'));
    await tester.tap(find.text('All books'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Genesis').last);
    await tester.pumpAndSettle();

    final genesisPage = searchPage('jesus', book: BibleBookEnum.genesis);
    expect(
      find.text(resultSummary(genesisPage, 'jesus', book: 'Genesis')),
      findsOneWidget,
    );
    expect(find.text('No verses matched your search.'), findsOneWidget);
  });

  testWidgets('case sensitive toggle updates search results', (
    WidgetTester tester,
  ) async {
    const query = 'jesus';
    final defaultPage = searchPage(query);
    final caseSensitivePage = searchPage(query, caseSensitive: true);

    expect(defaultPage.count, pageSize);
    expect(caseSensitivePage.count, lessThan(defaultPage.count));

    await pumpSearchPage(tester);
    await runSearch(tester, query);

    expect(find.text(resultSummary(defaultPage, query)), findsOneWidget);

    final toggle = find.byKey(const Key('search_case_sensitive_toggle'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text(resultSummary(caseSensitivePage, query)), findsOneWidget);
  });

  testWidgets('whole word toggle excludes partial matches', (
    WidgetTester tester,
  ) async {
    const query = 'loving';
    final defaultPage = searchPage(query);
    final wholeWordPage = searchPage(query, wholeWords: true);

    expect(defaultPage.count, isNot(wholeWordPage.count));

    await pumpSearchPage(tester);
    await runSearch(tester, query);

    expect(find.text(resultSummary(defaultPage, query)), findsOneWidget);

    final toggle = find.byKey(const Key('search_whole_word_toggle'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text(resultSummary(wholeWordPage, query)), findsOneWidget);
  });

  testWidgets('search mode selects phrase or all-word matching', (
    WidgetTester tester,
  ) async {
    const query = 'God earth';
    final phrasePage = searchPage(query);
    final allWordsPage = searchPage(query, mode: SearchMode.all);

    expect(phrasePage.count, 0);
    expect(allWordsPage.count, greaterThan(phrasePage.count));

    await pumpSearchPage(tester);
    await runSearch(tester, query);

    expect(find.text(resultSummary(phrasePage, query)), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('search_mode_filter')));
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text(resultSummary(allWordsPage, query)), findsOneWidget);
  });

  testWidgets('result snippets highlight matches and return exact location', (
    WidgetTester tester,
  ) async {
    BibleLocation? selectedLocation;
    await pumpSearchPage(
      tester,
      onResultSelected: (location) => selectedLocation = location,
    );
    await runSearch(tester, 'beginning');

    final snippetFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'search_result_snippet_',
          ),
    );
    expect(snippetFinder, findsWidgets);

    final snippet = tester.widget<Text>(snippetFinder.first);
    final snippetSpan = snippet.textSpan! as TextSpan;
    final highlightedSpans = snippetSpan.children!.whereType<TextSpan>().where(
      (span) => span.style?.backgroundColor != null,
    );
    expect(
      highlightedSpans.any(
        (span) => span.text!.toLowerCase().contains('beginning'),
      ),
      isTrue,
    );

    final resultFinder = find.byWidgetPredicate(
      (widget) =>
          widget is ListTile &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('search_result_'),
    );
    await tester.tap(resultFinder.first);
    await tester.pumpAndSettle();

    expect(
      selectedLocation,
      const BibleLocation(book: BibleBookEnum.genesis, chapter: 1, verse: 1),
    );
  });

  testWidgets('search pages broad results and can load the next page', (
    WidgetTester tester,
  ) async {
    const query = 'the';
    final firstPage = searchPage(query);
    expect(firstPage.count, pageSize);
    expect(firstPage.hasMore, isTrue);

    await pumpSearchPage(tester);
    await runSearch(tester, query);

    expect(find.text(resultSummary(firstPage, query)), findsOneWidget);

    final loadMore = find.byKey(const Key('search_load_more_button'));
    await tester.scrollUntilVisible(
      loadMore,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(loadMore);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 10000));
    await tester.pumpAndSettle();

    final secondPage = searchPage(query, offset: firstPage.count);
    expect(
      tester.widget<Text>(find.byKey(const Key('search_result_summary'))).data,
      resultSummary(
        secondPage,
        query,
        displayedCount: firstPage.count + secondPage.count,
      ),
    );
  });

  testWidgets('ignore diacritics option finds equivalent unmarked text', (
    WidgetTester tester,
  ) async {
    final accentedBible = Bible.fromJson('''
      {
        "language": "English",
        "books": {
          "gn": {
            "chapters": {
              "1": {"1": "A café welcomes everyone."}
            }
          }
        }
      }
    ''');

    await pumpSearchPage(tester, source: accentedBible);
    await runSearch(tester, 'cafe');
    expect(find.text('No verses matched your search.'), findsOneWidget);

    final toggle = find.byKey(const Key('search_ignore_diacritics_toggle'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('Genesis 1:1'), findsOneWidget);
    expect(find.text('No verses matched your search.'), findsNothing);
  });

  testWidgets('query and filter clear affordances reset the search form', (
    WidgetTester tester,
  ) async {
    await pumpSearchPage(tester);
    await tester.enterText(
      find.byKey(const Key('search_query_field')),
      'earth',
    );

    final caseToggle = find.byKey(const Key('search_case_sensitive_toggle'));
    await tester.ensureVisible(caseToggle);
    await tester.tap(caseToggle);
    await tester.pumpAndSettle();

    final clearFilters = find.byKey(const Key('search_clear_filters_button'));
    await tester.ensureVisible(clearFilters);
    await tester.tap(clearFilters);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(caseToggle).value, isFalse);

    final clearQuery = find.byKey(const Key('search_clear_query_button'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(clearQuery);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('search_query_field')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.byIcon(Icons.manage_search), findsOneWidget);
  });

  testWidgets('search layout scrolls on a small screen with large text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpSearchPage(tester, textScale: 2);
    await runSearch(tester, 'light');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomScrollView), findsOneWidget);
  });
}
