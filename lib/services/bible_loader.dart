import 'package:bible_io/bible_io.dart';
import 'package:flutter/services.dart';

const bibleCatalogAssetPath = 'bible_io_json/bible_list.json';

// These legacy source files intentionally contain empty chapters. Bible IO
// 1.1 rejects skeletal content under its strict default validation policy:
//
// * zho-ncv-trad-shen: Song of Solomon 1-8
// * kor-krv-1938: Job 42 and 1 Peter 5
//
// Keep the compatibility exception path-specific so malformed or incomplete
// content added later still fails strict validation instead of being hidden.
const _partialBibleAssetPaths = {
  'bible_io_json/Chinese/zho-ncv-trad-shen.json',
  'bible_io_json/Korean/kor-krv-1938.json',
};

const _strictLoadOptions = BibleLoadOptions(
  searchIndexMode: SearchIndexMode.lazy,
  parseInBackground: true,
);

const _partialLoadOptions = BibleLoadOptions(
  validation: BibleDataValidationOptions.permissive,
  searchIndexMode: SearchIndexMode.lazy,
  parseInBackground: true,
);

Future<BibleCatalog>? _catalogFuture;

/// Whether [assetPath] is a known, intentionally incomplete bundled edition.
bool isPartialBibleAsset(String assetPath) {
  return _partialBibleAssetPaths.contains(_normalizeAssetPath(assetPath));
}

/// Loads the bundled translation catalog using Bible IO's validated API.
///
/// The catalog is cached because it is immutable and shared by every edition
/// load during the lifetime of the application.
Future<BibleCatalog> loadBibleCatalog() {
  return _catalogFuture ??= BibleCatalog.loadAsset(
    rootBundle,
    bibleCatalogAssetPath,
  );
}

/// Finds the catalog source whose asset path matches [assetPath].
BibleSource? bibleSourceForAsset(BibleCatalog catalog, String assetPath) {
  final normalizedPath = _normalizeAssetPath(assetPath);
  for (final source in catalog.sources) {
    if (_normalizeAssetPath(source.assetPath) == normalizedPath) {
      return source;
    }
  }
  return null;
}

/// Loads a bundled Bible without blocking the UI where isolates are available.
///
/// Search indexes are lazy so the reader can appear before search data is
/// retained. Call [Bible.prewarmSearchIndexAsync] after the first reader frame
/// when search should be ready before the user opens it.
Future<Bible> loadBibleAsset(
  String assetPath, {
  BibleSource? source,
  BibleLoadProgressCallback? onLoadProgress,
}) async {
  final resolvedSource =
      source ?? bibleSourceForAsset(await loadBibleCatalog(), assetPath);

  return Bible.loadAsset(
    rootBundle,
    assetPath,
    source: resolvedSource,
    options: isPartialBibleAsset(assetPath)
        ? _partialLoadOptions
        : _strictLoadOptions,
    onLoadProgress: onLoadProgress,
  );
}

String _normalizeAssetPath(String assetPath) {
  var normalized = assetPath.trim().replaceAll('\\', '/');
  while (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  return normalized;
}
