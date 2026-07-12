import 'package:bible_io/bible_io.dart';
import 'package:flutter_bible/services/bible_loader.dart';
import 'package:flutter_test/flutter_test.dart';

const _kjvPath = 'bible_io_json/English/eng-kjv-1769.json';
const _chineseNcvPath = 'bible_io_json/Chinese/zho-ncv-trad-shen.json';
const _koreanKrvPath = 'bible_io_json/Korean/kor-krv-1938.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleCatalog catalog;

  setUpAll(() async {
    catalog = await loadBibleCatalog();
  });

  test('catalog exposes validated sources and supports source lookup', () {
    expect(catalog.sources, hasLength(19));

    final source = bibleSourceForAsset(catalog, _kjvPath);
    expect(source, isNotNull);
    expect(source!.assetPath, _kjvPath);
    expect(source.languageName, 'English');
    expect(source.languageCode, 'en');
    expect(catalog.findById(source.id), source);
    expect(catalog.forLanguage('en'), contains(source));

    expect(
      bibleSourceForAsset(
        catalog,
        r'.\bible_io_json\English\eng-kjv-1769.json',
      ),
      source,
    );
    expect(
      bibleSourceForAsset(catalog, 'bible_io_json/English/missing.json'),
      isNull,
    );
  });

  test(
    'asset loading reports progress and retains a lazy search index',
    () async {
      final progress = <BibleLoadProgress>[];
      final source = bibleSourceForAsset(catalog, _kjvPath);

      final bible = await loadBibleAsset(
        _kjvPath,
        source: source,
        onLoadProgress: progress.add,
      );

      expect(bible.id, 'eng-kjv-1769');
      expect(bible.source, source);
      expect(bible.searchIndexMode, SearchIndexMode.lazy);
      expect(bible.hasSearchIndex, isFalse);

      expect(progress.first.phase, BibleLoadPhase.reading);
      expect(progress.last.phase, BibleLoadPhase.complete);
      expect(
        progress.map((event) => event.phase),
        containsAllInOrder([
          BibleLoadPhase.reading,
          BibleLoadPhase.processing,
          BibleLoadPhase.complete,
        ]),
      );
      for (var index = 1; index < progress.length; index++) {
        expect(
          progress[index].fraction,
          greaterThanOrEqualTo(progress[index - 1].fraction),
        );
      }

      await bible.prewarmSearchIndexAsync();
      expect(bible.hasSearchIndex, isTrue);
    },
  );

  test('repaired Chinese NCV loads strictly and preserves UTF-8', () async {
    final bible = await loadBibleAsset(
      _chineseNcvPath,
      source: bibleSourceForAsset(catalog, _chineseNcvPath),
    );
    final firstVerse = bible.getVerse(BibleBookEnum.genesis, 1, 1);
    final songOfSolomon = bible.getBook(BibleBookEnum.songOfSolomon);

    expect(firstVerse.text, contains(String.fromCharCode(0x795e)));
    expect(firstVerse.text, isNot(contains(String.fromCharCode(0x00c3))));
    expect(songOfSolomon.chapters, hasLength(8));
    expect(
      songOfSolomon.chapters.every((chapter) => chapter.verses.isNotEmpty),
      isTrue,
    );
    expect(
      songOfSolomon.chapters.fold<int>(
        0,
        (count, chapter) => count + chapter.verses.length,
      ),
      117,
    );
    expect(bible.searchIndexMode, SearchIndexMode.lazy);
    expect(bible.hasSearchIndex, isFalse);
  });

  test(
    'repaired Korean KRV chapters load strictly with complete text',
    () async {
      final bible = await loadBibleAsset(
        _koreanKrvPath,
        source: bibleSourceForAsset(catalog, _koreanKrvPath),
      );

      expect(bible.getChapter(BibleBookEnum.job, 42).verses, hasLength(17));
      expect(
        bible.getChapter(BibleBookEnum.firstPeter, 5).verses,
        hasLength(14),
      );
      expect(
        bible.getVerse(BibleBookEnum.genesis, 1, 1).text,
        contains(String.fromCharCode(0xd558)),
      );
    },
  );
}
