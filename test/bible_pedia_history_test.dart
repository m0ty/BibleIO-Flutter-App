import 'package:flutter_bible/services/bible_pedia_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late BiblePediaHistory history;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    history = BiblePediaHistory(preferences);
  });

  test('reads normalized entry IDs in persisted recency order', () async {
    await preferences.setStringList(BiblePediaHistory.preferenceKey, [
      ' person:moses ',
      '',
      'event:exodus',
      'person:moses',
      '   ',
      ...List.generate(14, (index) => 'entry:$index'),
    ]);

    expect(history.read(), [
      'person:moses',
      'event:exodus',
      ...List.generate(10, (index) => 'entry:$index'),
    ]);
  });

  test('record trims IDs and moves an existing entry to the front', () async {
    await history.record('person:moses');
    await history.record('event:exodus');
    await history.record('  person:moses  ');

    expect(history.read(), ['person:moses', 'event:exodus']);
    expect(preferences.getStringList(BiblePediaHistory.preferenceKey), [
      'person:moses',
      'event:exodus',
    ]);
  });

  test('record ignores blank IDs without changing persisted history', () async {
    await history.record('person:moses');
    final before = preferences.getStringList(BiblePediaHistory.preferenceKey);

    await history.record('   ');

    expect(history.read(), ['person:moses']);
    expect(preferences.getStringList(BiblePediaHistory.preferenceKey), before);
  });

  test('record caps persisted history at twelve entries', () async {
    for (var index = 0; index < 15; index++) {
      await history.record('entry:$index');
    }

    final expected = List.generate(12, (index) => 'entry:${14 - index}');
    expect(history.read(), expected);
    expect(
      preferences.getStringList(BiblePediaHistory.preferenceKey),
      expected,
    );
  });

  test('clear removes the versioned preference', () async {
    await history.record('person:moses');

    await history.clear();

    expect(history.read(), isEmpty);
    expect(preferences.containsKey(BiblePediaHistory.preferenceKey), isFalse);
  });
}
