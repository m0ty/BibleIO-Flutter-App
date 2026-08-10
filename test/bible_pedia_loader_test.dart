import 'dart:convert';

import 'package:bible_io/bible_io.dart';
import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bible/services/bible_pedia_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetBiblePediaDatasetCache);

  test('loads the app asset and validates its bundle metadata', () async {
    final assetBundle = _TestAssetBundle(_validBundleJson);

    final dataset = await loadBiblePediaDataset(assetBundle: assetBundle);

    expect(assetBundle.requestedKeys, [biblePediaBundleAssetKey]);
    expect(dataset.schemaVersion, 1);
    expect(dataset.languageCode, 'en');
    expect(dataset.contentVersion, 'test-1');
    expect(dataset.entries, isEmpty);
  });

  test('bundled runtime asset contains the reviewed package snapshot', () async {
    final dataset = await loadBiblePediaDataset();

    expect(dataset.datasetId, 'bible-pedia');
    expect(dataset.languageCode, 'en');
    expect(dataset.contentVersion, '1.0.0');
    expect(dataset.length, 328);
    expect(dataset.categories.map((category) => category.label), [
      'People',
      'Locations',
      'Events',
      'Concepts',
      'Other',
    ]);
    expect(dataset.categoryCounts, {
      'person': 197,
      'location': 63,
      'event': 8,
      'concept': 60,
    });
    expect(
      dataset.coverageStatus(BibleBookEnum.matthew, 1),
      CoverageStatus.covered,
    );
    expect(
      dataset.coverageStatus(BibleBookEnum.acts, 1),
      CoverageStatus.notCovered,
    );
    expect(dataset.provenance.generatorVersion, '0.1.0');
    expect(
      dataset.provenance.generatorRevision,
      'a29da7b7a7e834ed9a293805dbc21d6a1a87fd96',
    );
    expect(
      dataset.provenance.sourceRevision,
      'sha256-tree:4b33075f9cf67fdec1995434e93f660431cc8aa618d07f89ac14328b39df6cec',
    );
    expect(dataset.rights.license, 'AGPL-3.0-only');
    expect(dataset.rights.attribution, 'Bible Pedia Dart contributors');
    expect(
      dataset.resolveEntry('concept/crucifiction').entry?.title,
      'Crucifixion',
    );
  });

  test('does not cache loads from an injected asset bundle', () async {
    final assetBundle = _TestAssetBundle(_validBundleJson);

    await loadBiblePediaDataset(assetBundle: assetBundle);
    await loadBiblePediaDataset(assetBundle: assetBundle);

    expect(assetBundle.requestedKeys, [
      biblePediaBundleAssetKey,
      biblePediaBundleAssetKey,
    ]);
  });

  test('propagates bundle validation errors', () async {
    final assetBundle = _TestAssetBundle(
      jsonEncode({
        'schemaVersion': 2,
        'languageCode': 'en',
        'contentVersion': 'test-1',
        'entries': <Object?>[],
      }),
    );

    await expectLater(
      loadBiblePediaDataset(assetBundle: assetBundle),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('unsupported bundle "schemaVersion" 2'),
        ),
      ),
    );
  });
}

const _validBundleJson = '''
{
  "schemaVersion": 1,
  "languageCode": "en",
  "contentVersion": "test-1",
  "entries": []
}
''';

final class _TestAssetBundle extends AssetBundle {
  _TestAssetBundle(this.source);

  final String source;
  final List<String> requestedKeys = [];

  @override
  Future<ByteData> load(String key) async {
    requestedKeys.add(key);
    final bytes = Uint8List.fromList(utf8.encode(source));
    return ByteData.sublistView(bytes);
  }
}
