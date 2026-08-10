import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bible/pages/bible_pedia_entry_page.dart';
import 'package:flutter_bible/services/bible_pedia_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shipped artifact uses singular category labels on details', (
    tester,
  ) async {
    final artifact = await loadBiblePediaArtifact(assetBundle: rootBundle);
    final entry = artifact.dataset.entryById('person/abraham')!;

    await tester.pumpWidget(
      MaterialApp(
        home: BiblePediaEntryPage(
          entry: entry,
          artifact: artifact,
          onEntryOpened: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PERSON'), findsOneWidget);
    expect(find.text('PEOPLE'), findsNothing);
  });
}
