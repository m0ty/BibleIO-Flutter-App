import 'dart:io';
import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bible/pages/bible_pedia_entry_page.dart';
import 'package:flutter_bible/widgets/bible_pedia_image.dart';
import 'package:flutter_test/flutter_test.dart';

const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  testWidgets('entry page renders structured image metadata', (tester) async {
    final image = EncyclopediaImage(
      source: 'data:image/png;base64,$_onePixelPng',
      altText: 'A map of the journey',
      caption: 'The journey to Damascus',
      credit: 'Example Archive',
      license: 'CC BY 4.0',
      mimeType: 'image/png',
      aspectRatio: 2,
    );
    final entry = EncyclopediaEntry(
      id: 'event/test-journey',
      title: 'Test journey',
      type: EntryType.event,
      descriptionMarkdown: 'A journey used by this widget test.',
      images: [image],
      sourcePath: 'event/test-journey.md',
    );
    final dataset = BibleEncyclopediaBundle(
      languageCode: 'en',
      contentVersion: 'image-test',
      entries: [entry],
    );
    final artifact = _artifactFor(dataset);

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

    expect(
      find.byKey(const Key('bible_pedia_entry_images_section')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bible_pedia_image_0')), findsOneWidget);
    expect(
      tester
          .widget<Image>(find.byKey(const Key('bible_pedia_image_media')))
          .image,
      isA<MemoryImage>(),
    );
    expect(find.text('The journey to Damascus'), findsOneWidget);
    expect(
      find.text('Credit: Example Archive \u2022 License: CC BY 4.0'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('local image resolves against the artifact asset root', (
    tester,
  ) async {
    final image = EncyclopediaImage(
      source: r'images\people\paul.png',
      altText: 'Paul',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BiblePediaImageFigure(
            image: image,
            artifact: _artifactForImage(
              image,
              resourceRoot: BiblePediaResourceRoot.asset(
                'assets/translations/en/pedia',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final provider = tester
        .widget<Image>(find.byKey(const Key('bible_pedia_image_media')))
        .image;
    expect(provider, isA<AssetImage>());
    expect(
      (provider as AssetImage).assetName,
      'assets/translations/en/pedia/images/people/paul.png',
    );
    // The test bundle does not contain this generated asset. The production
    // errorBuilder must contain a missing/corrupt asset without escaping the
    // entry page as a framework error.
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('bible_pedia_image_unavailable')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('undeclared local image is refused', (tester) async {
    final image = EncyclopediaImage(
      source: 'images/people/paul.png',
      altText: 'Paul',
    );
    final dataset = BibleEncyclopediaBundle(
      languageCode: 'en',
      contentVersion: 'image-test',
      entries: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BiblePediaImageFigure(
            image: image,
            artifact: _artifactFor(dataset),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(
      find.text(
        'This image is not declared by the loaded Bible Pedia artifact.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('HTTPS source uses a network image provider', (tester) async {
    await _pumpFigure(
      tester,
      EncyclopediaImage(
        source: 'https://cdn.example.test/paul.png',
        altText: 'Paul',
      ),
    );

    final provider = tester
        .widget<Image>(find.byKey(const Key('bible_pedia_image_media')))
        .image;
    expect(provider, isA<NetworkImage>());

    // Flutter's test binding rejects real network requests. The production
    // errorBuilder must turn that failure into a stable inline fallback.
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('bible_pedia_image_unavailable')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('local source can resolve against an HTTPS artifact root', (
    tester,
  ) async {
    await _pumpFigure(
      tester,
      EncyclopediaImage(source: 'images/paul.png', altText: 'Paul'),
      artifact: _artifactForImage(
        EncyclopediaImage(source: 'images/paul.png', altText: 'Paul'),
        resourceRoot: BiblePediaResourceRoot.parse(
          'https://cdn.example.test/datasets/en/',
        ),
      ),
    );

    final provider = tester
        .widget<Image>(find.byKey(const Key('bible_pedia_image_media')))
        .image;
    expect(provider, isA<NetworkImage>());
    expect(
      (provider as NetworkImage).url,
      'https://cdn.example.test/datasets/en/images/paul.png',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('insecure remote and oversized inline images are refused', (
    tester,
  ) async {
    await _pumpFigure(
      tester,
      EncyclopediaImage(
        source: 'http://cdn.example.test/paul.png',
        altText: 'Paul',
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(
      find.text('Only secure remote images can be displayed.'),
      findsOneWidget,
    );

    await _pumpFigure(
      tester,
      EncyclopediaImage(
        source: 'data:image/png;base64,$_onePixelPng',
        altText: 'Paul',
      ),
      maxInlineImageBytes: 1,
    );
    expect(find.byType(Image), findsNothing);
    expect(
      find.text('This inline image is too large to display.'),
      findsOneWidget,
    );
  });

  test('generated pubspec block covers every runtime artifact file', () {
    const startMarker = '    # BEGIN GENERATED BIBLE PEDIA RUNTIME ASSETS';
    const endMarker = '    # END GENERATED BIBLE PEDIA RUNTIME ASSETS';
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final start = pubspec.indexOf(startMarker);
    final end = pubspec.indexOf(endMarker, start + startMarker.length);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    expect(pubspec.indexOf(startMarker, start + startMarker.length), -1);
    final declared = pubspec
        .substring(start + startMarker.length, end)
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.startsWith('- '))
        .map((line) => line.substring(2).trim())
        .map(_decodeSingleQuotedYaml)
        .toSet();
    final actual = Directory('assets/bible_pedia')
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .map((file) => file.path.replaceAll('\\', '/'))
        .toSet();

    expect(declared, actual);
  });
}

Future<void> _pumpFigure(
  WidgetTester tester,
  EncyclopediaImage image, {
  int maxInlineImageBytes = BiblePediaImageFigure.defaultMaxInlineImageBytes,
  BiblePediaArtifact? artifact,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: BiblePediaImageFigure(
        image: image,
        artifact: artifact ?? _artifactForImage(image),
        maxInlineImageBytes: maxInlineImageBytes,
      ),
    ),
  ),
);

BiblePediaArtifact _artifactFor(
  BiblePediaDataset dataset, {
  BiblePediaResourceRoot? resourceRoot,
}) => BiblePediaArtifact(
  dataset: dataset,
  manifest: BiblePediaManifest.forDataset(
    dataset,
    files: [
      for (final entry in dataset.entries)
        for (final image in entry.images)
          if (image.imageSource case final LocalImageSource source)
            BiblePediaManifestFile(path: source.portablePath),
    ],
  ),
  resourceRoot:
      resourceRoot ?? BiblePediaResourceRoot.asset('assets/bible_pedia'),
);

BiblePediaArtifact _artifactForImage(
  EncyclopediaImage image, {
  BiblePediaResourceRoot? resourceRoot,
}) {
  final entry = EncyclopediaEntry(
    id: 'person/image-test',
    title: 'Image test',
    type: EntryType.person,
    descriptionMarkdown: 'Image fixture.',
    images: [image],
    sourcePath: 'person/image-test.md',
  );
  return _artifactFor(
    BibleEncyclopediaBundle(
      languageCode: 'en',
      contentVersion: 'image-test',
      entries: [entry],
    ),
    resourceRoot: resourceRoot,
  );
}

String _decodeSingleQuotedYaml(String source) {
  expect(source, startsWith("'"));
  expect(source, endsWith("'"));
  return source.substring(1, source.length - 1).replaceAll("''", "'");
}
