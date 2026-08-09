import 'package:bible_io/bible_io.dart';
import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bible/pages/bible_pedia_page.dart';
import 'package:flutter_bible/services/bible_pedia_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleEncyclopediaBundle bundle;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bundle = _buildBundle();
  });

  testWidgets('browses categories, searches aliases, and opens entry details', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pumpPediaPage(tester, bundle: bundle, preferences: preferences);

    expect(
      find.byKey(const ValueKey('bible_pedia_category_person')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bible_pedia_category_location')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bible_pedia_category_event')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bible_pedia_category_concept')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('bible_pedia_category_concept')),
    );
    await tester.pump();
    expect(_resultCount(tester), '1');

    await tester.tap(
      find.byKey(const ValueKey('bible_pedia_category_concept')),
    );
    await tester.enterText(
      find.byKey(const Key('bible_pedia_search_field')),
      'Saul of Tarsus',
    );
    await tester.pump();

    expect(_resultCount(tester), '1');
    await _openVisibleEntry(tester, 'person/paul');

    expect(find.byKey(const Key('bible_pedia_entry_page')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('bible_pedia_entry_title')))
          .data,
      'Paul',
    );
    expect(
      find.byKey(const Key('bible_pedia_entry_description')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('bible_pedia_entry_references_section')),
      findsOneWidget,
    );
  });

  testWidgets('uses data-defined categories and content attribution', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final customBundle = BibleEncyclopediaBundle(
      languageCode: 'en',
      contentVersion: 'custom-category-test',
      entries: [
        _entry(
          id: 'person/paul',
          title: 'Paul',
          type: EntryType.person,
          categoryId: 'apostle',
          description: 'An apostle to the nations.',
        ),
      ],
      categories: [
        CategoryDescriptor(
          id: 'apostle',
          label: 'Apostles',
          entryType: EntryType.person,
        ),
      ],
      rights: ContentRights(
        license: 'TEST-1.0',
        attribution: 'Test contributors',
      ),
    );

    await _pumpPediaPage(
      tester,
      bundle: customBundle,
      preferences: preferences,
    );

    expect(
      find.byKey(const ValueKey('bible_pedia_category_apostle')),
      findsOneWidget,
    );
    expect(find.text('Apostles'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bible_pedia_category_person')),
      findsNothing,
    );
    expect(find.text('Test contributors (TEST-1.0)'), findsOneWidget);
  });

  testWidgets('keeps ranked search results in relevance order', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final rankedBundle = BibleEncyclopediaBundle(
      languageCode: 'en',
      contentVersion: 'ranked-search-test',
      entries: [
        _entry(
          id: 'person/aaron',
          title: 'Aaron',
          type: EntryType.person,
          description: 'Aaron witnessed the covenant.',
        ),
        _entry(
          id: 'concept/covenant',
          title: 'Covenant',
          type: EntryType.concept,
          description: 'A binding promise.',
        ),
      ],
    );

    await _pumpPediaPage(
      tester,
      bundle: rankedBundle,
      preferences: preferences,
    );
    await tester.enterText(
      find.byKey(const Key('bible_pedia_search_field')),
      'covenant',
    );
    await tester.pump();
    expect(_resultCount(tester), '2');

    final exactTitle = find.byKey(
      const ValueKey('bible_pedia_entry_concept/covenant'),
    );
    final descriptionMatch = find.byKey(
      const ValueKey('bible_pedia_entry_person/aaron'),
    );
    expect(exactTitle, findsOneWidget);
    expect(descriptionMatch, findsNothing);
  });

  testWidgets('groups Moses references by book and expands independently', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final mosesBundle = BibleEncyclopediaBundle(
      languageCode: 'en',
      contentVersion: 'moses-groups-test',
      entries: [
        _entry(
          id: 'person/moses',
          title: 'Moses',
          type: EntryType.person,
          description: 'Moses appears throughout all four Gospels.',
          references: [
            for (var verse = 1; verse <= 9; verse++)
              BibleCitation.parse('Mark 1:$verse'),
            for (var verse = 1; verse <= 10; verse++)
              BibleCitation.parse('John 1:$verse'),
            for (var verse = 1; verse <= 7; verse++)
              BibleCitation.parse('Matthew 1:$verse'),
            for (var verse = 1; verse <= 10; verse++)
              BibleCitation.parse('Luke 1:$verse'),
          ],
        ),
      ],
    );
    await _pumpPediaPage(tester, bundle: mosesBundle, preferences: preferences);

    await _searchFor(tester, 'Moses');
    await _openVisibleEntry(tester, 'person/moses');

    final matthewGroup = find.byKey(
      const ValueKey('bible_pedia_reference_book_matthew'),
    );
    final markGroup = find.byKey(
      const ValueKey('bible_pedia_reference_book_mark'),
    );
    final lukeGroup = find.byKey(
      const ValueKey('bible_pedia_reference_book_luke'),
    );
    final johnGroup = find.byKey(
      const ValueKey('bible_pedia_reference_book_john'),
    );

    expect(matthewGroup, findsOneWidget);
    expect(markGroup, findsOneWidget);
    expect(lukeGroup, findsOneWidget);
    expect(johnGroup, findsOneWidget);
    expect(
      find.descendant(
        of: matthewGroup,
        matching: find.text('7 Bible references'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: markGroup, matching: find.text('9 Bible references')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: lukeGroup,
        matching: find.text('10 Bible references'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: johnGroup,
        matching: find.text('10 Bible references'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(matthewGroup).dy,
      lessThan(tester.getTopLeft(markGroup).dy),
    );
    expect(
      tester.getTopLeft(markGroup).dy,
      lessThan(tester.getTopLeft(lukeGroup).dy),
    );
    expect(
      tester.getTopLeft(lukeGroup).dy,
      lessThan(tester.getTopLeft(johnGroup).dy),
    );
    expect(_visibleCitationCount(), 0);

    await tester.tap(matthewGroup);
    await tester.pumpAndSettle();
    expect(_visibleCitationCount(), 7);
    expect(
      find.byKey(const ValueKey('bible_pedia_citation_matthew_6')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bible_pedia_citation_mark_0')),
      findsNothing,
    );

    await tester.ensureVisible(markGroup);
    await tester.tap(markGroup);
    await tester.pumpAndSettle();
    expect(_visibleCitationCount(), 16);
    expect(
      find.byKey(const ValueKey('bible_pedia_citation_mark_8')),
      findsOneWidget,
    );
  });

  testWidgets('cross-book ranges appear in every spanned book group', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final rangeBundle = BibleEncyclopediaBundle(
      languageCode: 'en',
      contentVersion: 'cross-book-groups-test',
      entries: [
        _entry(
          id: 'event/gospel-range',
          title: 'Gospel range',
          type: EntryType.event,
          description: 'A synthetic cross-book range.',
          references: [BibleCitation.parse('Matthew 28:20-John 1:1')],
        ),
      ],
    );
    await _pumpPediaPage(tester, bundle: rangeBundle, preferences: preferences);

    await _searchFor(tester, 'Gospel range');
    await _openVisibleEntry(tester, 'event/gospel-range');

    for (final book in ['matthew', 'mark', 'luke', 'john']) {
      final group = find.byKey(ValueKey('bible_pedia_reference_book_$book'));
      expect(group, findsOneWidget);
      expect(
        find.descendant(of: group, matching: find.text('1 Bible reference')),
        findsOneWidget,
      );
    }
  });

  testWidgets('entry references reveal 30 citations at a time', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final manyReferencesBundle = BibleEncyclopediaBundle(
      languageCode: 'en',
      contentVersion: 'many-references-test',
      entries: [
        _entry(
          id: 'other/many-references',
          title: 'Many references',
          type: EntryType.other,
          description: 'An entry used to verify incremental reference loading.',
          references: List.generate(65, (_) => BibleCitation.parse('John 1:1')),
        ),
      ],
    );
    await _pumpPediaPage(
      tester,
      bundle: manyReferencesBundle,
      preferences: preferences,
    );

    await _searchFor(tester, 'Many references');
    await _openVisibleEntry(tester, 'other/many-references');

    final johnGroup = find.byKey(
      const ValueKey('bible_pedia_reference_book_john'),
    );
    expect(johnGroup, findsOneWidget);
    expect(_visibleCitationCount(), 0);
    await tester.tap(johnGroup);
    await tester.pumpAndSettle();

    expect(_visibleCitationCount(), 30);
    expect(
      find.byKey(const ValueKey('bible_pedia_citation_john_29')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bible_pedia_citation_john_30')),
      findsNothing,
    );

    final moreReferences = find.byKey(
      const ValueKey('bible_pedia_more_references_john'),
    );
    expect(find.text('Show 30 more (35 remaining)'), findsOneWidget);
    await tester.ensureVisible(moreReferences);
    await tester.tap(moreReferences);
    await tester.pumpAndSettle();

    expect(_visibleCitationCount(), 60);
    expect(
      find.byKey(const ValueKey('bible_pedia_citation_john_59')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bible_pedia_citation_john_60')),
      findsNothing,
    );
    expect(find.text('Show 5 more (5 remaining)'), findsOneWidget);

    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();
    expect(_visibleCitationCount(), 60);

    await tester.ensureVisible(moreReferences);
    await tester.tap(moreReferences);
    await tester.pumpAndSettle();

    expect(_visibleCitationCount(), 65);
    expect(
      find.byKey(const ValueKey('bible_pedia_citation_john_64')),
      findsOneWidget,
    );
    expect(moreReferences, findsNothing);
  });

  testWidgets('This chapter shows exact matches and an empty state', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pumpPediaPage(
      tester,
      bundle: bundle,
      preferences: preferences,
      currentLocation: BibleLocation(book: BibleBookEnum.acts, chapter: 9),
      currentChapterLabel: 'Acts 9',
      pageKey: const ValueKey('matching_chapter_page'),
    );

    await _selectTab(tester, 'bible_pedia_chapter_tab');
    final chapterList = find.byKey(
      const PageStorageKey('bible_pedia_chapter_list'),
    );
    expect(
      find.descendant(
        of: chapterList,
        matching: find.byKey(const ValueKey('bible_pedia_entry_person/paul')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: chapterList,
        matching: find.byKey(
          const ValueKey('bible_pedia_entry_event/paul-conversion'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: chapterList,
        matching: find.byKey(const ValueKey('bible_pedia_entry_concept/grace')),
      ),
      findsNothing,
    );
    expect(find.text('Acts 9'), findsOneWidget);

    await _pumpPediaPage(
      tester,
      bundle: bundle,
      preferences: preferences,
      currentLocation: BibleLocation(book: BibleBookEnum.genesis, chapter: 1),
      currentChapterLabel: 'Genesis 1',
      pageKey: const ValueKey('empty_chapter_page'),
    );
    await _selectTab(tester, 'bible_pedia_chapter_tab');

    expect(find.byKey(const Key('bible_pedia_chapter_empty')), findsOneWidget);
    expect(find.text('Genesis 1'), findsOneWidget);
    expect(find.text('Chapter not covered yet'), findsOneWidget);
    expect(
      find.text('This chapter has not been reviewed for Bible Pedia yet.'),
      findsOneWidget,
    );
  });

  testWidgets('can open directly on the current chapter section', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pumpPediaPage(
      tester,
      bundle: bundle,
      preferences: preferences,
      currentLocation: BibleLocation(book: BibleBookEnum.acts, chapter: 9),
      currentChapterLabel: 'Acts 9',
      initialSection: BiblePediaSection.currentChapter,
    );

    final currentChapterHeader = find.byKey(
      const Key('bible_pedia_current_chapter_header'),
    );
    expect(currentChapterHeader.hitTestable(), findsOneWidget);
    expect(
      find.descendant(of: currentChapterHeader, matching: find.text('Acts 9')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('bible_pedia_search_field')).hitTestable(),
      findsNothing,
    );
  });

  testWidgets('opening an entry persists and deduplicates Recent', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pumpPediaPage(tester, bundle: bundle, preferences: preferences);

    await _searchFor(tester, 'Saul of Tarsus');
    await _openVisibleEntry(tester, 'person/paul');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _openVisibleEntry(tester, 'person/paul');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(preferences.getStringList(BiblePediaHistory.preferenceKey), [
      'person/paul',
    ]);

    await _selectTab(tester, 'bible_pedia_recent_tab');
    final recentList = find.byKey(
      const PageStorageKey('bible_pedia_recent_list'),
    );
    expect(
      find.descendant(
        of: recentList,
        matching: find.byKey(const ValueKey('bible_pedia_entry_person/paul')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('restored Recent history skips IDs missing from the bundle', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      BiblePediaHistory.preferenceKey: [
        'missing/entry',
        'concept/grace',
        'person/paul',
      ],
    });
    final preferences = await SharedPreferences.getInstance();
    await _pumpPediaPage(tester, bundle: bundle, preferences: preferences);

    await _selectTab(tester, 'bible_pedia_recent_tab');
    final recentList = find.byKey(
      const PageStorageKey('bible_pedia_recent_list'),
    );
    expect(
      find.descendant(
        of: recentList,
        matching: find.byKey(const ValueKey('bible_pedia_entry_concept/grace')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: recentList,
        matching: find.byKey(const ValueKey('bible_pedia_entry_person/paul')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: recentList,
        matching: find.byKey(const ValueKey('bible_pedia_entry_missing/entry')),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('bible_pedia_recent_empty')), findsNothing);
  });

  testWidgets('Recent resolves legacy IDs without duplicate entries', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      BiblePediaHistory.preferenceKey: ['person/saul', 'person/paul'],
    });
    final preferences = await SharedPreferences.getInstance();
    await _pumpPediaPage(tester, bundle: bundle, preferences: preferences);

    await _selectTab(tester, 'bible_pedia_recent_tab');

    final recentList = find.byKey(
      const PageStorageKey('bible_pedia_recent_list'),
    );
    expect(
      find.descendant(
        of: recentList,
        matching: find.byKey(const ValueKey('bible_pedia_entry_person/paul')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting a citation returns its first Bible location', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    BibleLocation? selectedLocation;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open_bible_pedia_test_button'),
                onPressed: () async {
                  selectedLocation = await Navigator.of(context)
                      .push<BibleLocation>(
                        MaterialPageRoute<BibleLocation>(
                          builder: (context) => BiblePediaPage(
                            currentLocation: BibleLocation(
                              book: BibleBookEnum.acts,
                              chapter: 9,
                            ),
                            preferences: preferences,
                            bundleLoader: () async => bundle,
                          ),
                        ),
                      );
                },
                child: const Text('Open Bible Pedia'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_bible_pedia_test_button')));
    await tester.pumpAndSettle();
    await _searchFor(tester, 'Saul of Tarsus');
    await _openVisibleEntry(tester, 'person/paul');

    final actsGroup = find.byKey(
      const ValueKey('bible_pedia_reference_book_acts'),
    );
    await tester.tap(actsGroup);
    await tester.pumpAndSettle();
    final citation = find.byKey(const ValueKey('bible_pedia_citation_acts_0'));
    await tester.ensureVisible(citation);
    await tester.tap(citation);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('open_bible_pedia_test_button')),
      findsOneWidget,
    );
    expect(selectedLocation?.book, BibleBookEnum.acts);
    expect(selectedLocation?.chapter, 9);
    expect(selectedLocation?.verse, 1);
  });

  testWidgets('nested related-entry citation closes Pedia with its location', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    BibleLocation? selectedLocation;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open_nested_pedia_test_button'),
                onPressed: () async {
                  selectedLocation = await Navigator.of(context)
                      .push<BibleLocation>(
                        MaterialPageRoute<BibleLocation>(
                          builder: (context) => BiblePediaPage(
                            currentLocation: BibleLocation(
                              book: BibleBookEnum.acts,
                              chapter: 9,
                            ),
                            preferences: preferences,
                            bundleLoader: () async => bundle,
                          ),
                        ),
                      );
                },
                child: const Text('Open nested Bible Pedia'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_nested_pedia_test_button')));
    await tester.pumpAndSettle();
    await _searchFor(tester, 'Saul of Tarsus');
    await _openVisibleEntry(tester, 'person/paul');

    final damascusLink = find.byKey(
      const ValueKey('bible_pedia_related_location/damascus_0'),
    );
    await tester.ensureVisible(damascusLink);
    await tester.tap(damascusLink);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('bible_pedia_entry_title')))
          .data,
      'Damascus',
    );

    final actsGroup = find.byKey(
      const ValueKey('bible_pedia_reference_book_acts'),
    );
    await tester.tap(actsGroup);
    await tester.pumpAndSettle();
    final citation = find.byKey(const ValueKey('bible_pedia_citation_acts_0'));
    await tester.ensureVisible(citation);
    await tester.tap(citation);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('open_nested_pedia_test_button')),
      findsOneWidget,
    );
    expect(selectedLocation?.book, BibleBookEnum.acts);
    expect(selectedLocation?.chapter, 9);
    expect(selectedLocation?.verse, 2);
  });

  testWidgets('loading error can retry successfully', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    var attempts = 0;

    Future<BibleEncyclopediaBundle> loader() {
      attempts++;
      if (attempts == 1) {
        return Future<BibleEncyclopediaBundle>.error(
          StateError('test load failure'),
        );
      }
      return Future.value(bundle);
    }

    await tester.pumpWidget(
      _pediaTestApp(preferences: preferences, bundleLoader: loader),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bible_pedia_error')), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.byKey(const Key('bible_pedia_retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bible_pedia_error')), findsNothing);
    expect(find.byKey(const Key('bible_pedia_search_field')), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('invalid bundle errors are not presented as retryable', (
    WidgetTester tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    Future<BibleEncyclopediaBundle> loader() =>
        Future<BibleEncyclopediaBundle>.error(
          InvalidEncyclopediaContentException(
            'invalid test bundle',
            artifact: 'bundle',
          ),
        );

    await tester.pumpWidget(
      _pediaTestApp(preferences: preferences, bundleLoader: loader),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bible_pedia_error')), findsOneWidget);
    expect(
      find.text(
        'The bundled encyclopedia data is invalid or incompatible with this app.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bible_pedia_retry_button')), findsNothing);
  });

  testWidgets('layout remains scrollable at 320x480 with text scale 2', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final preferences = await SharedPreferences.getInstance();
    await _pumpPediaPage(
      tester,
      bundle: bundle,
      preferences: preferences,
      currentLocation: BibleLocation(book: BibleBookEnum.acts, chapter: 9),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const PageStorageKey('bible_pedia_browse_list')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _selectTab(tester, 'bible_pedia_chapter_tab');
    expect(tester.takeException(), isNull);
    await _selectTab(tester, 'bible_pedia_recent_tab');
    expect(tester.takeException(), isNull);
  });

  testWidgets('long entry detail fits 320x480 at text scale 2', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final preferences = await SharedPreferences.getInstance();
    const longTitle =
        'The Remarkably Long and Carefully Explained Test Entry About Faith '
        'Across Many Generations';
    const longAlias =
        'An exceptionally long alternate name that must wrap safely on a '
        'compact screen with enlarged text';
    final longContentBundle = BibleEncyclopediaBundle(
      languageCode: 'en',
      contentVersion: 'long-content-test',
      entries: [
        _entry(
          id: 'other/long-entry',
          title: longTitle,
          type: EntryType.other,
          description:
              'This deliberately long entry verifies that detail content '
              'remains readable and scrollable.',
          aliases: const [longAlias],
          references: [BibleCitation.parse('Psalm 119:105')],
        ),
      ],
    );
    await _pumpPediaPage(
      tester,
      bundle: longContentBundle,
      preferences: preferences,
      textScale: 2,
    );

    await _searchFor(tester, 'Remarkably Long');
    await _openVisibleEntry(tester, 'other/long-entry');

    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('bible_pedia_entry_title')))
          .data,
      longTitle,
    );
    expect(
      tester
          .widget<Chip>(find.byKey(const ValueKey('bible_pedia_alias_0')))
          .label,
      isA<Text>().having((text) => text.data, 'text', longAlias),
    );

    final psalmsGroup = find.byKey(
      const ValueKey('bible_pedia_reference_book_psalms'),
    );
    await tester.ensureVisible(psalmsGroup);
    await tester.tap(psalmsGroup);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('bible_pedia_citation_psalms_0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const Key('bible_pedia_entry_scroll_view')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPediaPage(
  WidgetTester tester, {
  required BibleEncyclopediaBundle bundle,
  required SharedPreferences preferences,
  BibleLocation? currentLocation,
  String? currentChapterLabel,
  BiblePediaSection initialSection = BiblePediaSection.browse,
  Key? pageKey,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    _pediaTestApp(
      preferences: preferences,
      bundleLoader: () async => bundle,
      currentLocation: currentLocation,
      currentChapterLabel: currentChapterLabel,
      initialSection: initialSection,
      pageKey: pageKey,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
}

Widget _pediaTestApp({
  required SharedPreferences preferences,
  required BiblePediaBundleLoader bundleLoader,
  BibleLocation? currentLocation,
  String? currentChapterLabel,
  BiblePediaSection initialSection = BiblePediaSection.browse,
  Key? pageKey,
  double textScale = 1,
}) {
  return MaterialApp(
    builder: (context, child) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
    },
    home: BiblePediaPage(
      key: pageKey,
      currentLocation: currentLocation,
      currentChapterLabel: currentChapterLabel,
      initialSection: initialSection,
      preferences: preferences,
      bundleLoader: bundleLoader,
    ),
  );
}

Future<void> _selectTab(WidgetTester tester, String key) async {
  final tab = find.byKey(ValueKey(key));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

String? _resultCount(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('bible_pedia_result_count'))).data;

int _visibleCitationCount() {
  return find
      .byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('bible_pedia_citation_');
      })
      .evaluate()
      .length;
}

Future<void> _searchFor(WidgetTester tester, String query) async {
  await tester.enterText(
    find.byKey(const Key('bible_pedia_search_field')),
    query,
  );
  await tester.pump();
  expect(_resultCount(tester), '1');
}

Future<void> _openVisibleEntry(WidgetTester tester, String entryId) async {
  final entry = find.byKey(ValueKey('bible_pedia_entry_$entryId'));
  final browseList = find.byKey(
    const PageStorageKey('bible_pedia_browse_list'),
  );
  final scrollable = find.descendant(
    of: browseList,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
  for (
    var attempt = 0;
    attempt < 12 && entry.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    await tester.drag(scrollable.first, const Offset(0, -220));
    await tester.pumpAndSettle();
  }
  await tester.tap(entry.hitTestable());
  await tester.pumpAndSettle();
}

BibleEncyclopediaBundle _buildBundle() {
  return BibleEncyclopediaBundle(
    languageCode: 'en',
    contentVersion: 'test-1',
    coverage: EditorialCoverage(
      books: [
        BookCoverage(book: BibleBookEnum.acts, status: CoverageStatus.covered),
      ],
    ),
    entries: [
      _entry(
        id: 'person/paul',
        legacyIds: const ['person/saul'],
        title: 'Paul',
        type: EntryType.person,
        description: '# Paul\nPaul was an apostle to the nations.',
        aliases: const ['Saul', 'Saul of Tarsus'],
        references: [BibleCitation.parse('Acts 9:1-9')],
        relatedEntries: [
          EntryLink(
            target: 'Damascus',
            label: 'Damascus',
            entryId: 'location/damascus',
          ),
        ],
        tags: const ['apostle'],
      ),
      _entry(
        id: 'location/damascus',
        title: 'Damascus',
        type: EntryType.location,
        description: 'The city Paul approached during his conversion.',
        references: [BibleCitation.parse('Acts 9:2')],
      ),
      _entry(
        id: 'event/paul-conversion',
        title: "Paul's conversion",
        type: EntryType.event,
        description: 'The risen Jesus appeared to Saul.',
        references: [BibleCitation.parse('Acts 9:1-19')],
      ),
      _entry(
        id: 'concept/grace',
        title: 'Grace',
        type: EntryType.concept,
        description: 'God gives favor freely.',
        references: [BibleCitation.parse('Romans 5:1')],
      ),
      _entry(
        id: 'person/moses',
        title: 'Moses',
        type: EntryType.person,
        description: 'God called Moses from the burning bush.',
        references: [BibleCitation.parse('Exodus 3:1')],
      ),
    ],
  );
}

EncyclopediaEntry _entry({
  required String id,
  Iterable<String> legacyIds = const [],
  required String title,
  required EntryType type,
  String? categoryId,
  required String description,
  Iterable<String> aliases = const [],
  Iterable<BibleCitation> references = const [],
  Iterable<EntryLink> relatedEntries = const [],
  Iterable<String> tags = const [],
}) {
  return EncyclopediaEntry(
    id: id,
    legacyIds: legacyIds,
    title: title,
    type: type,
    categoryId: categoryId,
    descriptionMarkdown: description,
    aliases: aliases,
    bibleReferences: references,
    relatedEntries: relatedEntries,
    tags: tags,
    sourcePath: '$id.md',
  );
}
