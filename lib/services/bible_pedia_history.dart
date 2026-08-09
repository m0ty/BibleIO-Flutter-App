import 'package:shared_preferences/shared_preferences.dart';

/// Persists the most recently opened Bible-pedia entry IDs.
class BiblePediaHistory {
  const BiblePediaHistory(this._preferences);

  static const preferenceKey = 'bible_pedia_recent_entry_ids_v1';
  static const maxEntries = 12;

  final SharedPreferences _preferences;

  /// Returns stable entry IDs in most-recent-first order.
  ///
  /// Invalid or legacy values are normalized at the boundary so callers never
  /// need to handle blank, duplicate, or over-capacity histories.
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
