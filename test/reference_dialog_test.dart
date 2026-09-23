import 'package:bible_io/bible_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bible/widgets/reference_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in {
    'John 1:5': '5a',
    'John 1:5b': '5b',
    'John 1:4': '3–4',
    'John 1:3-4': '3–4',
    'John 1:5b-6a': '5b',
    'John 1:7a': '6a–7b',
    'John 1:5b, 8': '5b',
  }.entries) {
    testWidgets('opens ${entry.key} at source entry ${entry.value}', (
      tester,
    ) async {
      BibleLocation? result;
      await _openDialog(tester, onSelected: (location) => result = location);

      await tester.enterText(
        find.byKey(const Key('reference_field')),
        entry.key,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Go'));
      await tester.pumpAndSettle();

      expect(
        result,
        _bible().getVerseByLabel(BibleBookEnum.john, 1, entry.value).location,
      );
      expect(find.byType(ReferenceDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing subdivision stays open and can be corrected', (
    tester,
  ) async {
    BibleLocation? result;
    await _openDialog(tester, onSelected: (location) => result = location);
    final field = find.byKey(const Key('reference_field'));

    await tester.enterText(field, 'John 1:5c');
    await tester.tap(find.widgetWithText(FilledButton, 'Go'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(ReferenceDialog), findsOneWidget);
    expect(tester.widget<TextField>(field).decoration!.errorText, isNotEmpty);

    await tester.enterText(field, 'John 1:5b');
    await tester.pump();
    expect(tester.widget<TextField>(field).decoration!.errorText, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(result?.verseLabel, '5b');
    expect(find.byType(ReferenceDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openDialog(
  WidgetTester tester, {
  required ValueChanged<BibleLocation?> onSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              onSelected(
                await showDialog<BibleLocation>(
                  context: context,
                  builder: (_) => ReferenceDialog(bible: _bible()),
                ),
              );
            },
            child: const Text('Open reference'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open reference'));
  await tester.pumpAndSettle();
}

Bible _bible() => Bible.fromDecodedJson({
  'language': 'English',
  'books': {
    'jo': {
      'chapters': {
        '1': {
          '1': 'First verse.',
          '3–4': 'A combined verse.',
          '5a': 'First subdivision.',
          '5b': 'Second subdivision.',
          '6a–7b': 'Combined subdivisions.',
          '8': 'Last verse.',
        },
      },
    },
  },
});
