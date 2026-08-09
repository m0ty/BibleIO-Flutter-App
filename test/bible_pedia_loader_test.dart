import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bible/services/bible_pedia_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetBiblePediaBundleCache);

  test('loads the app asset and validates its bundle metadata', () async {
    final assetBundle = _TestAssetBundle(_validBundleJson);

    final bundle = await loadBiblePediaBundle(assetBundle: assetBundle);

    expect(assetBundle.requestedKeys, [biblePediaBundleAssetKey]);
    expect(bundle.schemaVersion, 1);
    expect(bundle.languageCode, 'en');
    expect(bundle.contentVersion, 'test-1');
    expect(bundle.entries, isEmpty);
  });

  test('does not cache loads from an injected asset bundle', () async {
    final assetBundle = _TestAssetBundle(_validBundleJson);

    await loadBiblePediaBundle(assetBundle: assetBundle);
    await loadBiblePediaBundle(assetBundle: assetBundle);

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
      loadBiblePediaBundle(assetBundle: assetBundle),
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
