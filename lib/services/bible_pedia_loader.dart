import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const biblePediaBundleAssetKey = 'assets/bible_pedia/encyclopedia.bundle.json';

Future<BibleEncyclopediaBundle>? _defaultBundleFuture;

/// Lazily loads and validates the bundled Bible-pedia data.
///
/// The default [rootBundle] load is cached for the lifetime of the application.
/// An injected [assetBundle] is never cached, keeping tests and callers with
/// independently managed bundles isolated from the application-wide cache.
Future<BibleEncyclopediaBundle> loadBiblePediaBundle({
  AssetBundle? assetBundle,
}) {
  if (assetBundle != null) {
    return _loadBiblePediaBundle(assetBundle);
  }

  final cached = _defaultBundleFuture;
  if (cached != null) return cached;

  late final Future<BibleEncyclopediaBundle> future;
  future = _loadBiblePediaBundle(rootBundle).onError((
    Object error,
    StackTrace stackTrace,
  ) {
    if (identical(_defaultBundleFuture, future)) {
      _defaultBundleFuture = null;
    }
    Error.throwWithStackTrace(error, stackTrace);
  });
  _defaultBundleFuture = future;
  return future;
}

Future<BibleEncyclopediaBundle> _loadBiblePediaBundle(
  AssetBundle assetBundle,
) async {
  final source = await assetBundle.loadString(biblePediaBundleAssetKey);
  return BibleEncyclopediaBundle.fromJsonString(source);
}

@visibleForTesting
void resetBiblePediaBundleCache() {
  _defaultBundleFuture = null;
}
