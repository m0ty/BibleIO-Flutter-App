import 'dart:convert';

import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const biblePediaRuntimeAssetRoot = 'assets/bible_pedia';
const biblePediaBundleAssetKey =
    '$biblePediaRuntimeAssetRoot/encyclopedia.bundle.json';
const biblePediaManifestAssetKey =
    '$biblePediaRuntimeAssetRoot/runtime.manifest.json';

final biblePediaResourceRoot = BiblePediaResourceRoot.asset(
  biblePediaRuntimeAssetRoot,
);

Future<BiblePediaArtifact>? _defaultArtifactFuture;

/// Lazily loads the bundled dataset together with its resource manifest/root.
///
/// The default [rootBundle] load is cached for the lifetime of the application.
/// An injected [assetBundle] is never cached, keeping tests and callers with
/// independently managed bundles isolated from the application-wide cache.
Future<BiblePediaArtifact> loadBiblePediaArtifact({AssetBundle? assetBundle}) {
  if (assetBundle != null) return _loadBiblePediaArtifact(assetBundle);

  final cached = _defaultArtifactFuture;
  if (cached != null) return cached;

  late final Future<BiblePediaArtifact> future;
  future = _loadBiblePediaArtifact(rootBundle).onError((
    Object error,
    StackTrace stackTrace,
  ) {
    if (identical(_defaultArtifactFuture, future)) {
      _defaultArtifactFuture = null;
    }
    Error.throwWithStackTrace(error, stackTrace);
  });
  _defaultArtifactFuture = future;
  return future;
}

Future<BiblePediaArtifact> _loadBiblePediaArtifact(
  AssetBundle assetBundle,
) async {
  final (bundleData, manifestData) = await (
    assetBundle.load(biblePediaBundleAssetKey),
    assetBundle.load(biblePediaManifestAssetKey),
  ).wait;
  final bundleBytes = bundleData.buffer.asUint8List(
    bundleData.offsetInBytes,
    bundleData.lengthInBytes,
  );
  final manifestBytes = manifestData.buffer.asUint8List(
    manifestData.offsetInBytes,
    manifestData.lengthInBytes,
  );
  try {
    final manifestSource = utf8.decode(manifestBytes);
    final decodedManifest = jsonDecode(manifestSource);
    if (decodedManifest is! Map) {
      throw const FormatException(
        'Bible Pedia runtime manifest must be an object',
      );
    }
    final manifest = BiblePediaManifest.fromJson(
      Map<String, Object?>.from(decodedManifest),
    );
    manifest.verifyPayload('encyclopedia.bundle.json', bundleBytes);
    final dataset = const BiblePediaBundleCodec().decodeUtf8(bundleBytes);
    return BiblePediaArtifact(
      dataset: dataset,
      manifest: manifest,
      resourceRoot: biblePediaResourceRoot,
    );
  } on EncyclopediaLoadException {
    rethrow;
  } on FormatException catch (error) {
    throw InvalidEncyclopediaContentException(
      'invalid Bible Pedia runtime artifact: ${error.message}',
      artifact: 'runtime artifact',
      cause: error,
    );
  } on ArgumentError catch (error) {
    throw InvalidEncyclopediaContentException(
      'invalid Bible Pedia runtime artifact: ${error.message}',
      artifact: 'runtime artifact',
      cause: error,
    );
  }
}

/// Migration bridge that discards the artifact manifest and resource origin.
@Deprecated('Use loadBiblePediaArtifact')
Future<BiblePediaDataset> loadBiblePediaDataset({
  AssetBundle? assetBundle,
}) async => (await loadBiblePediaArtifact(assetBundle: assetBundle)).dataset;

@Deprecated('Use loadBiblePediaArtifact')
Future<BiblePediaDataset> loadBiblePediaBundle({AssetBundle? assetBundle}) =>
    loadBiblePediaDataset(assetBundle: assetBundle);

@visibleForTesting
void resetBiblePediaArtifactCache() {
  _defaultArtifactFuture = null;
}

@Deprecated('Use resetBiblePediaArtifactCache')
@visibleForTesting
void resetBiblePediaDatasetCache() => resetBiblePediaArtifactCache();

@Deprecated('Use resetBiblePediaArtifactCache')
@visibleForTesting
void resetBiblePediaBundleCache() => resetBiblePediaArtifactCache();
