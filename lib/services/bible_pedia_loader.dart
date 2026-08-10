import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const biblePediaBundleAssetKey = 'assets/bible_pedia/encyclopedia.bundle.json';

Future<BiblePediaDataset>? _defaultDatasetFuture;

/// Lazily loads and validates the bundled Bible-pedia data.
///
/// The default [rootBundle] load is cached for the lifetime of the application.
/// An injected [assetBundle] is never cached, keeping tests and callers with
/// independently managed bundles isolated from the application-wide cache.
Future<BiblePediaDataset> loadBiblePediaDataset({AssetBundle? assetBundle}) {
  if (assetBundle != null) {
    return _loadBiblePediaDataset(assetBundle);
  }

  final cached = _defaultDatasetFuture;
  if (cached != null) return cached;

  late final Future<BiblePediaDataset> future;
  future = _loadBiblePediaDataset(rootBundle).onError((
    Object error,
    StackTrace stackTrace,
  ) {
    if (identical(_defaultDatasetFuture, future)) {
      _defaultDatasetFuture = null;
    }
    Error.throwWithStackTrace(error, stackTrace);
  });
  _defaultDatasetFuture = future;
  return future;
}

Future<BiblePediaDataset> _loadBiblePediaDataset(
  AssetBundle assetBundle,
) async {
  final source = await assetBundle.loadString(biblePediaBundleAssetKey);
  return BibleEncyclopediaBundle.fromJsonString(source);
}

/// Backward-compatible spelling for callers migrating to
/// [loadBiblePediaDataset].
@Deprecated('Use loadBiblePediaDataset')
Future<BiblePediaDataset> loadBiblePediaBundle({AssetBundle? assetBundle}) =>
    loadBiblePediaDataset(assetBundle: assetBundle);

@visibleForTesting
void resetBiblePediaDatasetCache() {
  _defaultDatasetFuture = null;
}

@Deprecated('Use resetBiblePediaDatasetCache')
@visibleForTesting
void resetBiblePediaBundleCache() => resetBiblePediaDatasetCache();
