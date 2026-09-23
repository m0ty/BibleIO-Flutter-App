import 'dart:convert';

import 'package:bible_io/bible_io.dart';
import 'package:flutter_bible/services/reading_location_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _source = BibleSource(
  id: 'catalog-edition',
  assetPath: 'bible_io_json/test.json',
  languageName: 'English',
  languageCode: 'en',
  translationName: 'Test edition',
  abbreviation: 'TEST',
);
const _genesisOne = BibleLocation(book: BibleBookEnum.genesis, chapter: 1);
const _genesisTwo = BibleLocation(book: BibleBookEnum.genesis, chapter: 2);
const _johnThree = BibleLocation(book: BibleBookEnum.john, chapter: 3);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> preferencesWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test(
    'saved edition position takes precedence over legacy settings',
    () async {
      final preferences = await preferencesWith({
        'reading_locations_v2': json.encode({
          'edition': _genesisTwo.copyWith(verse: 1).toJson(),
        }),
        'last_book_index': 1,
        'last_chapter': 3,
      });
      final store = ReadingLocationStore(preferences);

      expect(
        store.restore(
          _bible(id: 'edition'),
          _source,
          allowLegacyPosition: true,
        ),
        _genesisTwo,
      );
    },
  );

  test(
    'saves chapter positions independently and keeps existing editions',
    () async {
      final preferences = await preferencesWith({
        'reading_locations_v2': json.encode({'existing': _genesisOne.toJson()}),
      });
      final store = ReadingLocationStore(preferences);

      await store.save('first', _genesisTwo.copyWith(verse: 1));
      await store.save('second', _johnThree.copyWith(verse: 1));

      final restored = ReadingLocationStore(preferences);
      expect(
        restored.restore(
          _bible(id: 'first'),
          _source,
          allowLegacyPosition: false,
        ),
        _genesisTwo,
      );
      expect(
        restored.restore(
          _bible(id: 'second'),
          _source,
          allowLegacyPosition: false,
        ),
        _johnThree,
      );
      expect(json.decode(preferences.getString('reading_locations_v2')!), {
        'existing': _genesisOne.toJson(),
        'first': _genesisTwo.toJson(),
        'second': _johnThree.toJson(),
      });
    },
  );

  test('uses the catalog ID when the Bible has no edition ID', () async {
    final preferences = await preferencesWith({});
    final store = ReadingLocationStore(preferences);
    await store.save(_source.id, _johnThree);

    expect(
      store.restore(_bible(), _source, allowLegacyPosition: false),
      _johnThree,
    );
  });

  test('legacy positions are only used when allowed', () async {
    final preferences = await preferencesWith({
      'last_book_index': 1,
      'last_chapter': 3,
    });
    final store = ReadingLocationStore(preferences);
    final bible = _bible();

    expect(
      store.restore(bible, _source, allowLegacyPosition: true),
      _johnThree,
    );
    expect(
      store.restore(bible, _source, allowLegacyPosition: false),
      _genesisOne,
    );
  });

  test('legacy book indexes are clamped to the edition', () async {
    final preferences = await preferencesWith({
      'last_book_index': 99,
      'last_chapter': 3,
    });
    final store = ReadingLocationStore(preferences);

    expect(
      store.restore(_bible(), _source, allowLegacyPosition: true),
      _johnThree,
    );

    await preferences.setInt('last_book_index', -1);
    await preferences.setInt('last_chapter', 2);
    expect(
      store.restore(_bible(), _source, allowLegacyPosition: true),
      _genesisTwo,
    );
  });

  test(
    'missing legacy chapters fall back to the first available chapter',
    () async {
      final preferences = await preferencesWith({
        'last_book_index': 1,
        'last_chapter': 99,
      });

      expect(
        ReadingLocationStore(
          preferences,
        ).restore(_bible(), _source, allowLegacyPosition: true),
        _genesisOne,
      );
    },
  );

  for (final encoded in [
    '',
    '{broken',
    '[]',
    json.encode({'edition': 'invalid'}),
    json.encode({
      'edition': {'book': 'unknown', 'chapter': 1},
    }),
    json.encode({
      'edition': const BibleLocation(
        book: BibleBookEnum.genesis,
        chapter: 99,
      ).toJson(),
    }),
  ]) {
    test('invalid saved positions fall back safely: $encoded', () async {
      final preferences = await preferencesWith({
        'reading_locations_v2': encoded,
        'last_book_index': 1,
        'last_chapter': 3,
      });
      final store = ReadingLocationStore(preferences);
      final bible = _bible(id: 'edition');

      expect(
        store.restore(bible, _source, allowLegacyPosition: true),
        _johnThree,
      );
      expect(
        store.restore(bible, _source, allowLegacyPosition: false),
        _genesisOne,
      );
    });
  }

  test('first chapter fallback skips books without chapters', () async {
    final preferences = await preferencesWith({});
    final bible = _bible();
    final sparseBible = bible.copyWith(
      books: [
        Book(BibleBookEnum.genesis, []),
        bible.getBook(BibleBookEnum.john),
      ],
    );

    expect(
      ReadingLocationStore(
        preferences,
      ).restore(sparseBible, _source, allowLegacyPosition: true),
      _johnThree,
    );
  });

  test('an edition without chapters has no reading position', () async {
    final preferences = await preferencesWith({});
    final store = ReadingLocationStore(preferences);

    expect(
      store.restore(
        _bible().copyWith(books: []),
        _source,
        allowLegacyPosition: true,
      ),
      isNull,
    );
  });
}

Bible _bible({String? id}) {
  return Bible.fromDecodedJson({
    'language': 'English',
    if (id != null) 'metadata': {'id': id},
    'books': {
      'gn': {
        'chapters': {
          '1': {'1': 'First chapter.'},
          '2': {'1': 'Second chapter.'},
        },
      },
      'jo': {
        'chapters': {
          '3': {'1': 'Another book.'},
        },
      },
    },
  });
}
