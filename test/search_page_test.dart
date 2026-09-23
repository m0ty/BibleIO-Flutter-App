import 'dart:convert';
import 'dart:ui' show SemanticsAction, SemanticsActionEvent;

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

  Bible filterBible({String? genesisName}) {
    return Bible.fromJson(
      jsonEncode({
        'language': 'English',
        'books': {
          if (genesisName != null)
            'gn': {
              'name': genesisName,
              'chapters': {
                '1': {'1': 'God created the earth.'},
              },
            },
          'ex': {
            'chapters': {
              '1': {'1': 'God leads his people.'},
            },
          },
        },
      }),
    );
  }

  Bible labeledBible({
    Map<String, String> verses = const {
      '1–2': 'The light shines over the waters.',
      '3a': 'The first light appears.',
      '3b': 'The second light follows.',
      '4': 'The light is good.',
    },
    bool rtl = false,
  }) {
    return Bible.fromJson(
      jsonEncode({
        'language': rtl ? 'Hebrew' : 'English',
        'metadata': {'direction': rtl ? 'rtl' : 'ltr'},
        'books': {
          'gn': {
            if (rtl) 'name': 'בראשית',
            'chapters': {'1': verses},
          },
        },
      }),
    );
  }

  Finder resultTile(String label) =>
      find.byKey(ValueKey('search_result_genesis_1_$label'));

  Finder resultSnippet(String label) =>
      find.byKey(ValueKey('search_result_snippet_genesis_1_$label'));

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

  testWidgets('book filter follows the selected book in a replacement Bible', (
    WidgetTester tester,
  ) async {
    await pumpSearchPage(tester, source: filterBible(genesisName: 'Genesis'));
    await tester.tap(find.text('All books'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Genesis').last);
    await tester.pumpAndSettle();
    await runSearch(tester, 'God');
    expect(find.text('1 result for "God" in Genesis'), findsOneWidget);

    await pumpSearchPage(
      tester,
      source: filterBible(genesisName: 'Beginnings'),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Beginnings'), findsOneWidget);
    expect(find.text('Genesis'), findsNothing);
    expect(find.byKey(const Key('search_result_summary')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('search_query_field')))
          .controller!
          .text,
      'God',
    );

    await tester.tap(find.byKey(const Key('search_button')));
    await tester.pumpAndSettle();
    expect(find.text('1 result for "God" in Beginnings'), findsOneWidget);
  });

  testWidgets('book filter clears when a replacement Bible omits the book', (
    WidgetTester tester,
  ) async {
    await pumpSearchPage(tester, source: filterBible(genesisName: 'Genesis'));
    await tester.tap(find.text('All books'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Genesis').last);
    await tester.pumpAndSettle();
    await runSearch(tester, 'God');

    await pumpSearchPage(tester, source: filterBible());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('All books'), findsOneWidget);
    expect(find.text('Genesis'), findsNothing);
    expect(find.byKey(const Key('search_result_summary')), findsNothing);

    await tester.tap(find.byKey(const Key('search_button')));
    await tester.pumpAndSettle();
    expect(find.text('1 result for "God"'), findsOneWidget);
    expect(find.text('Exodus 1:1'), findsOneWidget);
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

  testWidgets(
    'range and subverse results have distinct labels and highlights',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpSearchPage(tester, source: labeledBible());
      await runSearch(tester, 'light');

      expect(find.text('4 results for "light"'), findsOneWidget);
      for (final label in ['1–2', '3a', '3b', '4']) {
        expect(find.text('Genesis 1:$label'), findsOneWidget);
        expect(resultTile(label), findsOneWidget);
        final snippet = tester.widget<Text>(resultSnippet(label));
        final spans = (snippet.textSpan! as TextSpan).children!
            .cast<TextSpan>();
        expect(
          spans
              .where((span) => span.style?.backgroundColor != null)
              .map((span) => span.text),
          ['light'],
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final label in ['1–2', '3a', '3b']) {
    testWidgets('selecting result $label retains its exact source location', (
      WidgetTester tester,
    ) async {
      BibleLocation? selectedLocation;
      await pumpSearchPage(
        tester,
        source: labeledBible(),
        onResultSelected: (location) => selectedLocation = location,
      );
      await runSearch(tester, 'light');
      await tester.scrollUntilVisible(
        resultTile(label),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(resultTile(label));
      await tester.pumpAndSettle();
      await tester.tap(resultTile(label));
      await tester.pumpAndSettle();

      expect(
        selectedLocation,
        BibleLocation(
          book: BibleBookEnum.genesis,
          chapter: 1,
          verse: label == '1–2' ? 1 : 3,
          verseLabel: label,
        ),
      );
    });
  }

  testWidgets('screen-reader activation opens the exact subverse', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      BibleLocation? selectedLocation;
      await pumpSearchPage(
        tester,
        source: labeledBible(),
        onResultSelected: (location) => selectedLocation = location,
      );
      await runSearch(tester, 'light');
      await tester.scrollUntilVisible(
        resultTile('3b'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(resultTile('3b'));
      await tester.pumpAndSettle();

      final node = tester.getSemantics(
        find.bySemanticsLabel('Genesis 1:3b. The second light follows.'),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.tap,
          viewId: tester.view.viewId,
          nodeId: node.id,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        selectedLocation,
        labeledBible().getVerseByLabel(BibleBookEnum.genesis, 1, '3b').location,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('pagination retains both subverses across a page boundary', (
    WidgetTester tester,
  ) async {
    final source = labeledBible(
      verses: {
        for (var number = 1; number < pageSize; number++)
          '$number': 'The light shines.',
        '${pageSize}a': 'The first light appears.',
        '${pageSize}b': 'The second light follows.',
        '${pageSize + 1}-${pageSize + 2}': 'The light remains.',
      },
    );
    await pumpSearchPage(tester, source: source);
    await runSearch(tester, 'light');

    final loadMore = find.byKey(const Key('search_load_more_button'));
    await tester.scrollUntilVisible(
      loadMore,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(resultTile('${pageSize}a'), findsOneWidget);
    expect(resultTile('${pageSize}b'), findsNothing);
    await tester.tap(loadMore);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('End of results'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(resultTile('${pageSize}a'), findsOneWidget);
    expect(resultTile('${pageSize}b'), findsOneWidget);
    expect(resultTile('${pageSize + 1}-${pageSize + 2}'), findsOneWidget);
    expect(loadMore, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL range and subverse results retain Scripture direction', (
    WidgetTester tester,
  ) async {
    final source = labeledBible(
      rtl: true,
      verses: {'1–2': 'אור ראשון', '3a': 'אור שני', '3b': 'אור שלישי'},
    );
    await pumpSearchPage(tester, source: source);
    await runSearch(tester, 'אור');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    for (final label in ['1–2', '3a', '3b']) {
      final title = tester.widget<Text>(
        find.text('בראשית \u20661:$label\u2069'),
      );
      final snippet = tester.widget<Text>(resultSnippet(label));
      expect(title.textDirection, TextDirection.rtl);
      expect(snippet.textDirection, TextDirection.rtl);
      if (label == '1–2') {
        final painter = TextPainter(
          text: TextSpan(text: title.data, style: title.style),
          textDirection: title.textDirection!,
        )..layout();
        addTearDown(painter.dispose);
        final numberOffset = title.data!.indexOf('1:1–2');
        double leftAt(int offset) => painter
            .getBoxesForSelection(
              TextSelection(baseOffset: offset, extentOffset: offset + 1),
            )
            .single
            .left;
        // Check visual positions: chapter, first verse, then range endpoint.
        expect(leftAt(numberOffset), lessThan(leftAt(numberOffset + 2)));
        expect(leftAt(numberOffset + 2), lessThan(leftAt(numberOffset + 4)));
      }
      final spans = (snippet.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(
        spans
            .where((span) => span.style?.backgroundColor != null)
            .map((span) => span.text),
        ['אור'],
      );
    }
    expect(tester.takeException(), isNull);
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
