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
  if (assetBundle != null) {
    return _loadBiblePediaArtifact(assetBundle, useIsolate: false);
  }

  final cached = _defaultArtifactFuture;
  if (cached != null) return cached;

  late final Future<BiblePediaArtifact> future;
  future = _loadBiblePediaArtifact(rootBundle, useIsolate: true).onError((
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
  AssetBundle assetBundle, {
  required bool useIsolate,
}) async {
  final assets = await Future.wait<ByteData>([
    _loadRuntimeAsset(assetBundle, biblePediaBundleAssetKey),
    _loadRuntimeAsset(assetBundle, biblePediaManifestAssetKey),
  ], eagerError: true);
  final bundleData = assets[0];
  final manifestData = assets[1];
  final bundleBytes = bundleData.buffer.asUint8List(
    bundleData.offsetInBytes,
    bundleData.lengthInBytes,
  );
  final manifestBytes = manifestData.buffer.asUint8List(
    manifestData.offsetInBytes,
    manifestData.lengthInBytes,
  );
  final codec = const BiblePediaArtifactCodec();
  if (!useIsolate) {
    return codec.decode(
      manifestBytes: manifestBytes,
      bundleBytes: bundleBytes,
      resourceRoot: biblePediaResourceRoot,
    );
  }
  return codec.decodeAsync(
    manifestBytes: manifestBytes,
    bundleBytes: bundleBytes,
    resourceRoot: biblePediaResourceRoot,
    delegate:
        ({
          required manifestBytes,
          required bundleBytes,
          required resourceRoot,
        }) => compute(_decodeBiblePediaArtifact, (
          manifestBytes: manifestBytes,
          bundleBytes: bundleBytes,
          resourceRoot: resourceRoot.toString(),
        )),
  );
}

Future<ByteData> _loadRuntimeAsset(AssetBundle assetBundle, String key) async {
  try {
    return await assetBundle.load(key);
  } on EncyclopediaLoadException {
    rethrow;
  } catch (error) {
    throw EncyclopediaRepositoryException(
      code: BiblePediaErrorCode.repositoryNotFound,
      message: 'Bible Pedia runtime asset "$key" could not be loaded',
      operation: 'load runtime artifact asset',
      path: key,
      cause: error,
    );
  }
}

BiblePediaArtifact _decodeBiblePediaArtifact(
  ({Uint8List manifestBytes, Uint8List bundleBytes, String resourceRoot}) input,
) => const BiblePediaArtifactCodec().decode(
  manifestBytes: input.manifestBytes,
  bundleBytes: input.bundleBytes,
  resourceRoot: BiblePediaResourceRoot.parse(input.resourceRoot),
);

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
