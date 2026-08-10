import 'dart:ui' show SemanticsAction;

import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bible/widgets/bible_pedia_document.dart';

void main() {
  testWidgets('renders parsed structure and preserves link destinations', (
    tester,
  ) async {
    MarkdownLink? selectedLink;
    final document = BiblePediaMarkdown.parse('''
# Heading

Read **bold**, *emphasized*, and `code`.

[**Abraham**](entry://person/abraham)

> Quoted text

- First item
- Second item

```text
literal * code
```
''');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BiblePediaDocumentView(
            document: document,
            onLinkSelected: (link) => selectedLink = link,
          ),
        ),
      ),
    );
    final semanticsHandle = tester.ensureSemantics();

    expect(find.text('Heading'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Heading'),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.header == true,
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Read bold'), findsOneWidget);
    expect(find.text('Quoted text'), findsOneWidget);
    expect(find.text('First item'), findsOneWidget);
    expect(find.text('literal * code'), findsOneWidget);
    expect(find.textContaining('entry://'), findsNothing);

    final linkText = find.text('Abraham', findRichText: true);
    expect(linkText, findsOneWidget);
    await tester.tapOnText(find.textRange.ofSubstring('Abraham'));
    expect(selectedLink?.destination, 'entry://person/abraham');
    expect(selectedLink?.entryUri?.entryId, 'person/abraham');

    final linkSemantics = find.semantics.byLabel('Abraham');
    expect(linkSemantics, findsOne);
    expect(
      linkSemantics.evaluate().single.getSemanticsData().hasAction(
        SemanticsAction.tap,
      ),
      isTrue,
    );
    selectedLink = null;
    tester.semantics.tap(linkSemantics);
    expect(selectedLink?.entryUri?.entryId, 'person/abraham');
    semanticsHandle.dispose();
  });
}
