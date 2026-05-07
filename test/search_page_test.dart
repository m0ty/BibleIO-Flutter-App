import 'package:bible_io/bible_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bible/pages/search_page.dart';
import 'package:flutter_bible/services/bible_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Bible bible;

  String resultSummary(int count, String query, {String? book}) {
    return '$count result${count == 1 ? '' : 's'} for "$query"'
        '${book == null ? '' : ' in $book'}';
  }

  int searchCount(
    String query, {
    SearchMode mode = SearchMode.exact,
    bool caseSensitive = false,
    bool wholeWords = false,
  }) {
    return bible
        .searchWithOptions(
          query,
          SearchOptions(
            mode: mode,
            caseSensitive: caseSensitive,
            wholeWords: wholeWords,
          ),
        )
        .count;
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
    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(bible: bible, onResultSelected: (_, _) {}),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('search_query_field')),
      'jesus',
    );
    await tester.tap(find.byKey(const Key('search_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('for "jesus"'), findsOneWidget);
    expect(find.text('No verses matched your search.'), findsNothing);

    await tester.tap(find.text('All books'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Genesis').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('for "jesus" in Genesis'), findsOneWidget);
    expect(find.text('No verses matched your search.'), findsOneWidget);
  });

  testWidgets('case sensitive toggle updates search results', (
    WidgetTester tester,
  ) async {
    const query = 'god';
    final defaultCount = searchCount(query);
    final caseSensitiveCount = searchCount(query, caseSensitive: true);

    expect(defaultCount, isNot(caseSensitiveCount));

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(bible: bible, onResultSelected: (_, _) {}),
      ),
    );

    await tester.enterText(find.byKey(const Key('search_query_field')), query);
    await tester.tap(find.byKey(const Key('search_button')));
    await tester.pumpAndSettle();

    expect(find.text(resultSummary(defaultCount, query)), findsOneWidget);

    await tester.tap(find.byKey(const Key('search_case_sensitive_toggle')));
    await tester.pumpAndSettle();

    expect(find.text(resultSummary(caseSensitiveCount, query)), findsOneWidget);
  });

  testWidgets('whole word toggle excludes partial matches', (
    WidgetTester tester,
  ) async {
    const query = 'sin';
    final defaultCount = searchCount(query);
    final wholeWordCount = searchCount(query, wholeWords: true);

    expect(defaultCount, isNot(wholeWordCount));

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(bible: bible, onResultSelected: (_, _) {}),
      ),
    );

    await tester.enterText(find.byKey(const Key('search_query_field')), query);
    await tester.tap(find.byKey(const Key('search_button')));
    await tester.pumpAndSettle();

    expect(find.text(resultSummary(defaultCount, query)), findsOneWidget);

    await tester.tap(find.byKey(const Key('search_whole_word_toggle')));
    await tester.pumpAndSettle();

    expect(find.text(resultSummary(wholeWordCount, query)), findsOneWidget);
  });

  testWidgets('search mode selects phrase or all-word matching', (
    WidgetTester tester,
  ) async {
    const query = 'God earth';
    final phraseCount = searchCount(query);
    final allWordsCount = searchCount(query, mode: SearchMode.all);

    expect(phraseCount, 0);
    expect(allWordsCount, greaterThan(phraseCount));

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(bible: bible, onResultSelected: (_, _) {}),
      ),
    );

    await tester.enterText(find.byKey(const Key('search_query_field')), query);
    await tester.tap(find.byKey(const Key('search_button')));
    await tester.pumpAndSettle();

    expect(find.text(resultSummary(phraseCount, query)), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text(resultSummary(allWordsCount, query)), findsOneWidget);
  });
}
