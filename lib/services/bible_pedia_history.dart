import 'package:shared_preferences/shared_preferences.dart';

/// Persists the most recently opened Bible-pedia entry IDs.
class BiblePediaHistory {
  const BiblePediaHistory(this._preferences);

  static const preferenceKey = 'bible_pedia_recent_entry_ids_v1';
  static const maxEntries = 12;

  final SharedPreferences _preferences;

  /// Returns stable entry IDs in most-recent-first order.
  ///
  /// Blank, duplicate, and over-capacity values are normalized at this
  /// boundary. The Bible Pedia page resolves historical IDs against the loaded
  /// dataset and persists their canonical replacements with [replace].
  List<String> read() {
    try {
      return List.unmodifiable(
        _normalize(_preferences.getStringList(preferenceKey) ?? const []),
      );
    } on Object {
      return const [];
    }
  }

  /// Makes [entryId] the most recently opened entry.
  ///
  /// Blank IDs are ignored. Existing IDs are moved to the front and the
  /// persisted history is capped at [maxEntries].
  Future<void> record(String entryId) async {
    final normalizedId = entryId.trim();
    if (normalizedId.isEmpty) return;

    final updated = _normalize([
      normalizedId,
      ...read().where((id) => id != normalizedId),
    ]);
    await _preferences.setStringList(preferenceKey, updated);
  }

  /// Replaces the persisted history with already-resolved canonical IDs.
  ///
  /// The same normalization rules as [record] are applied so migrations can
  /// safely discard missing IDs and collapse multiple legacy IDs that now
  /// resolve to one entry.
  Future<void> replace(Iterable<String> entryIds) async {
    await _preferences.setStringList(preferenceKey, _normalize(entryIds));
  }

  /// Removes all persisted Bible-pedia history.
  Future<void> clear() async {
    await _preferences.remove(preferenceKey);
  }

  static List<String> _normalize(Iterable<String> entryIds) {
    final normalized = <String>[];
    final seen = <String>{};

    for (final entryId in entryIds) {
      final trimmed = entryId.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      normalized.add(trimmed);
      if (normalized.length == maxEntries) break;
    }

    return normalized;
  }
}
