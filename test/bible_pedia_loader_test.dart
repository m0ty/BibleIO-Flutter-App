import 'dart:async';
import 'dart:convert';

import 'package:bible_io/bible_io.dart';
import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bible/services/bible_pedia_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetBiblePediaArtifactCache);

  test('loads the app artifact with its manifest and logical root', () async {
    final assetBundle = _TestAssetBundle({
      biblePediaBundleAssetKey: _validBundleJson,
      biblePediaManifestAssetKey: _manifestJsonFor(_validBundleJson),
    });

    final artifact = await loadBiblePediaArtifact(assetBundle: assetBundle);
    final dataset = artifact.dataset;

    expect(assetBundle.requestedKeys, [
      biblePediaBundleAssetKey,
      biblePediaManifestAssetKey,
    ]);
    expect(dataset.schemaVersion, 1);
    expect(dataset.languageCode, 'en');
    expect(dataset.contentVersion, 'test-1');
    expect(dataset.entries, isEmpty);
    expect(artifact.manifest.datasetId, dataset.datasetId);
    expect(artifact.resourceRoot, biblePediaResourceRoot);
  });

  test('bundled runtime asset contains the reviewed package snapshot', () async {
    final artifact = await loadBiblePediaArtifact();
    final dataset = artifact.dataset;

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
    expect(artifact.manifest.files, isNotEmpty);
    expect(artifact.manifest.fileByPath('encyclopedia.bundle.json'), isNotNull);
  });

  test('does not cache loads from an injected asset bundle', () async {
    final assetBundle = _TestAssetBundle({
      biblePediaBundleAssetKey: _validBundleJson,
      biblePediaManifestAssetKey: _manifestJsonFor(_validBundleJson),
    });

    await loadBiblePediaArtifact(assetBundle: assetBundle);
    await loadBiblePediaArtifact(assetBundle: assetBundle);

    expect(assetBundle.requestedKeys, [
      biblePediaBundleAssetKey,
      biblePediaManifestAssetKey,
      biblePediaBundleAssetKey,
      biblePediaManifestAssetKey,
    ]);
  });

  test(
    'observes concurrent failures when both artifact assets are missing',
    () {
      final assetBundle = _TestAssetBundle(const {});

      expect(
        loadBiblePediaArtifact(assetBundle: assetBundle),
        throwsA(isA<ParallelWaitError>()),
      );
    },
  );

  test('rejects a malformed UTF-8 manifest as invalid content', () async {
    final assetBundle = _TestAssetBundle({
      biblePediaBundleAssetKey: _validBundleJson,
      biblePediaManifestAssetKey: Uint8List.fromList([0xc3, 0x28]),
    });

    await expectLater(
      loadBiblePediaArtifact(assetBundle: assetBundle),
      throwsA(
        isA<InvalidEncyclopediaContentException>().having(
          (error) => error.cause,
          'cause',
          isA<FormatException>(),
        ),
      ),
    );
  });

  test('propagates bundle validation errors', () async {
    final invalidBundle = jsonEncode({
      'schemaVersion': 2,
      'languageCode': 'en',
      'contentVersion': 'test-1',
      'entries': <Object?>[],
    });
    final assetBundle = _TestAssetBundle({
      biblePediaBundleAssetKey: invalidBundle,
      biblePediaManifestAssetKey: _manifestJsonFor(invalidBundle),
    });

    await expectLater(
      loadBiblePediaArtifact(assetBundle: assetBundle),
      throwsA(
        isA<UnsupportedEncyclopediaSchemaException>().having(
          (error) => error.message,
          'message',
          contains('unsupported bundle "schemaVersion" 2'),
        ),
      ),
    );
  });

  test('rejects a bundle whose bytes do not match the manifest', () async {
    final tamperedBundle = _validBundleJson.replaceFirst('test-1', 'test-2');
    final assetBundle = _TestAssetBundle({
      biblePediaBundleAssetKey: tamperedBundle,
      biblePediaManifestAssetKey: _manifestJsonFor(_validBundleJson),
    });

    await expectLater(
      loadBiblePediaArtifact(assetBundle: assetBundle),
      throwsA(
        isA<InvalidEncyclopediaContentException>().having(
          (error) => error.message,
          'message',
          contains('failed SHA-256 verification'),
        ),
      ),
    );
  });

  test('rejects a manifest without a bundle record', () async {
    final assetBundle = _TestAssetBundle({
      biblePediaBundleAssetKey: _validBundleJson,
      biblePediaManifestAssetKey: _manifestJsonFor(
        _validBundleJson,
        includeBundle: false,
      ),
    });

    await expectLater(
      loadBiblePediaArtifact(assetBundle: assetBundle),
      throwsA(
        isA<InvalidEncyclopediaContentException>().having(
          (error) => error.message,
          'message',
          contains('does not declare file "encyclopedia.bundle.json"'),
        ),
      ),
    );
  });

  test('rejects a future manifest schema', () async {
    final assetBundle = _TestAssetBundle({
      biblePediaBundleAssetKey: _validBundleJson,
      biblePediaManifestAssetKey: _manifestJsonFor(
        _validBundleJson,
        schemaVersion: 2,
      ),
    });

    await expectLater(
      loadBiblePediaArtifact(assetBundle: assetBundle),
      throwsA(
        isA<InvalidEncyclopediaContentException>().having(
          (error) => error.message,
          'message',
          contains('unsupported artifact manifest schema version'),
        ),
      ),
    );
  });

  test('rejects a manifest for a different dataset release', () async {
    final mismatchedManifest =
        jsonDecode(_manifestJsonFor(_validBundleJson)) as Map
          ..['contentVersion'] = 'different';
    final assetBundle = _TestAssetBundle({
      biblePediaBundleAssetKey: _validBundleJson,
      biblePediaManifestAssetKey: jsonEncode(mismatchedManifest),
    });

    await expectLater(
      loadBiblePediaArtifact(assetBundle: assetBundle),
      throwsA(isA<InvalidEncyclopediaContentException>()),
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

String _manifestJsonFor(
  String bundleJson, {
  bool includeBundle = true,
  int schemaVersion = 1,
}) {
  final bytes = utf8.encode(bundleJson);
  return jsonEncode({
    'schemaVersion': schemaVersion,
    'datasetId': 'bible-pedia',
    'languageCode': 'en',
    'contentVersion': 'test-1',
    'coverage': {'defaultStatus': 'notCovered', 'books': <Object?>[]},
    'provenance': {
      'generatorName': 'bible_pedia_dart',
      'generatorVersion': 'unspecified',
    },
    'rights': {
      'license': 'NOASSERTION',
      'attribution': 'Attribution not supplied',
    },
    'files': [
      if (includeBundle)
        {
          'path': 'encyclopedia.bundle.json',
          'sha256': sha256.convert(bytes).toString(),
          'bytes': bytes.length,
        },
    ],
  });
}

final class _TestAssetBundle extends AssetBundle {
  _TestAssetBundle(this.sources);

  final Map<String, Object> sources;
  final List<String> requestedKeys = [];

  @override
  Future<ByteData> load(String key) async {
    requestedKeys.add(key);
    final source = sources[key];
    if (source == null) throw StateError('Missing test asset $key');
    final bytes = Uint8List.fromList(switch (source) {
      String value => utf8.encode(value),
      List<int> value => value,
      _ => throw StateError('Unsupported test asset value for $key'),
    });
    return ByteData.sublistView(bytes);
  }
}
