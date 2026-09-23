import 'dart:convert';

import 'package:bible_io/bible_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _legacyLastBookIndexKey = 'last_book_index';
const _legacyLastChapterKey = 'last_chapter';
const _readingLocationsKey = 'reading_locations_v2';

/// Persists chapter positions per edition and restores older reader settings.
class ReadingLocationStore {
  ReadingLocationStore(this._preferences)
    : _locations = _decode(_preferences.getString(_readingLocationsKey));

  final SharedPreferences _preferences;
  Map<String, Object?> _locations;

  BibleLocation? restore(
    Bible bible,
    BibleSource source, {
    required bool allowLegacyPosition,
  }) {
    final editionId = bible.id ?? source.id;
    final stored = _locations[editionId];
    if (stored is Map) {
      try {
        final location = BibleLocation.fromJson(
          Map<String, Object?>.from(stored),
        ).copyWith(verse: null);
        if (bible.containsReference(location)) return location;
      } on Object {
        // Fall through to the legacy position or the edition's first chapter.
      }
    }

    if (allowLegacyPosition && bible.books.isNotEmpty) {
      final legacyBookIndex =
          (_preferences.getInt(_legacyLastBookIndexKey) ?? 0).clamp(
            0,
            bible.books.length - 1,
          );
      final book = bible.books[legacyBookIndex];
      final legacyChapter = _preferences.getInt(_legacyLastChapterKey) ?? 1;
      for (final chapter in book.chapters) {
        if (chapter.chapterNumber == legacyChapter) {
          return BibleLocation(
            book: book.bookEnum,
            chapter: chapter.chapterNumber,
          );
        }
      }
    }

    for (final book in bible.books) {
      if (book.chapters.isNotEmpty) {
        return BibleLocation(
          book: book.bookEnum,
          chapter: book.chapters.first.chapterNumber,
        );
      }
    }
    return null;
  }

  Future<void> save(String editionId, BibleLocation location) async {
    _locations = {
      ..._locations,
      editionId: location.copyWith(verse: null).toJson(),
    };
    await _preferences.setString(_readingLocationsKey, json.encode(_locations));
  }

  static Map<String, Object?> _decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const {};
    try {
      final value = json.decode(encoded);
      if (value is Map) return Map<String, Object?>.from(value);
    } on Object {
      // Corrupt preferences should not prevent the reader from opening.
    }
    return const {};
  }
}
