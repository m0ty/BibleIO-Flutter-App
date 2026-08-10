import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bible/pages/bible_pedia_entry_page.dart';
import 'package:flutter_bible/widgets/bible_pedia_image.dart';
import 'package:flutter_test/flutter_test.dart';

const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+A8AAQUBAScY42YAAAAASUVORK5CYII=';

final _onePixelBytes = Uint8List.fromList(base64Decode(_onePixelPng));

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

  testWidgets('entry page renders a Markdown-only image at its AST position', (
    tester,
  ) async {
    final entry = EncyclopediaEntry(
      id: 'concept/markdown-image',
      title: 'Markdown image',
      type: EntryType.concept,
      descriptionMarkdown:
          '''
Before the image.

![A small inline map](data:image/png;base64,$_onePixelPng "Inline map caption")

After the image.
''',
      sourcePath: 'concept/markdown-image.md',
    );
    final dataset = BibleEncyclopediaBundle(
      languageCode: 'en',
      contentVersion: 'markdown-image-test',
      entries: [entry],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BiblePediaEntryPage(
          entry: entry,
          artifact: _artifactFor(dataset),
          onEntryOpened: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = find.text('Before the image.', findRichText: true);
    final media = find.byKey(const Key('bible_pedia_image_media'));
    final after = find.text('After the image.', findRichText: true);
    expect(
      find.byKey(const Key('bible_pedia_entry_images_section')),
      findsNothing,
    );
    expect(media, findsOneWidget);
    expect(find.text('Inline map caption'), findsOneWidget);
    expect(tester.getTopLeft(before).dy, lessThan(tester.getTopLeft(media).dy));
    expect(tester.getTopLeft(media).dy, lessThan(tester.getTopLeft(after).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('entry page treats a comment-only compiled document as empty', (
    tester,
  ) async {
    final entry = EncyclopediaEntry(
      id: 'concept/comment-only',
      title: 'Comment only',
      type: EntryType.concept,
      descriptionMarkdown: '<!-- authoring note only -->',
      sourcePath: 'concept/comment-only.md',
    );
    final dataset = BibleEncyclopediaBundle(
      languageCode: 'en',
      contentVersion: 'comment-only-test',
      entries: [entry],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BiblePediaEntryPage(
          entry: entry,
          artifact: _artifactFor(dataset),
          onEntryOpened: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('bible_pedia_entry_description_empty')),
      findsOneWidget,
    );
    expect(
      find.text('No description is available for this entry yet.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('bible_pedia_entry_description')),
      findsNothing,
    );
  });

  testWidgets(
    'Markdown images keep metadata and are omitted from the top gallery',
    (tester) async {
      const embeddedSource = 'data:image/png;base64,$_onePixelPng';
      const gallerySource =
          'data:image/png;variant=gallery;base64,$_onePixelPng';
      final embedded = EncyclopediaImage(
        source: embeddedSource,
        altText: 'Embedded map',
        caption: 'Embedded caption',
        credit: 'Embedded Archive',
        license: 'CC BY 4.0',
      );
      final gallery = EncyclopediaImage(
        source: gallerySource,
        altText: 'Gallery map',
        caption: 'Gallery caption',
      );
      final entry = EncyclopediaEntry(
        id: 'concept/mixed-images',
        title: 'Mixed images',
        type: EntryType.concept,
        descriptionMarkdown:
            '''
Before embedded media.

![Embedded map]($embeddedSource)

After embedded media.
''',
        images: [embedded, gallery],
        sourcePath: 'concept/mixed-images.md',
      );
      final dataset = BibleEncyclopediaBundle(
        languageCode: 'en',
        contentVersion: 'mixed-image-test',
        entries: [entry],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BiblePediaEntryPage(
            entry: entry,
            artifact: _artifactFor(dataset),
            onEntryOpened: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final media = find.byKey(const Key('bible_pedia_image_media'));
      final before = find.text('Before embedded media.', findRichText: true);
      final after = find.text('After embedded media.', findRichText: true);
      expect(
        find.byKey(const Key('bible_pedia_entry_images_section')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('bible_pedia_image_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('bible_pedia_image_1')), findsNothing);
      expect(media, findsNWidgets(2));
      expect(find.text('Embedded caption'), findsOneWidget);
      expect(
        find.text('Credit: Embedded Archive \u2022 License: CC BY 4.0'),
        findsOneWidget,
      );
      expect(find.text('Gallery caption'), findsOneWidget);
      expect(
        tester.getTopLeft(media.at(0)).dy,
        lessThan(tester.getTopLeft(before).dy),
      );
      expect(
        tester.getTopLeft(before).dy,
        lessThan(tester.getTopLeft(media.at(1)).dy),
      );
      expect(
        tester.getTopLeft(media.at(1)).dy,
        lessThan(tester.getTopLeft(after).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('local image resolves against the artifact asset root', (
    tester,
  ) async {
    final image = EncyclopediaImage(
      source: r'images\people\paul.png',
      altText: 'Paul',
    );
    final loader = _TestResourceLoader(_onePixelBytes);
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
            resourceLoader: loader,
            verifiedByteCache: BiblePediaMemoryVerifiedByteCache(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final provider = tester
        .widget<Image>(find.byKey(const Key('bible_pedia_image_media')))
        .image;
    expect(provider, isA<MemoryImage>());
    expect(
      loader.uris.single.toString(),
      'asset:/assets/translations/en/pedia/images/people/paul.png',
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
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(
      find.text(
        'This image is not declared by the loaded Bible Pedia artifact.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('HTTPS source is policy-checked and rendered from loaded bytes', (
    tester,
  ) async {
    final loader = _TestResourceLoader(_onePixelBytes);
    await _pumpFigure(
      tester,
      EncyclopediaImage(
        source: 'https://cdn.example.test/paul.png',
        altText: 'Paul',
      ),
      resourceLoader: loader,
    );

    final provider = tester
        .widget<Image>(find.byKey(const Key('bible_pedia_image_media')))
        .image;
    expect(provider, isA<MemoryImage>());
    expect(loader.uris.single.toString(), 'https://cdn.example.test/paul.png');
    expect(tester.takeException(), isNull);
  });

  testWidgets('local source can resolve against an HTTPS artifact root', (
    tester,
  ) async {
    final loader = _TestResourceLoader(_onePixelBytes);
    await _pumpFigure(
      tester,
      EncyclopediaImage(source: 'images/paul.png', altText: 'Paul'),
      artifact: _artifactForImage(
        EncyclopediaImage(source: 'images/paul.png', altText: 'Paul'),
        resourceRoot: BiblePediaResourceRoot.parse(
          'https://cdn.example.test/datasets/en/',
        ),
      ),
      resourceLoader: loader,
    );

    final provider = tester
        .widget<Image>(find.byKey(const Key('bible_pedia_image_media')))
        .image;
    expect(provider, isA<MemoryImage>());
    expect(
      loader.uris.single.toString(),
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
  BiblePediaResourceByteLoader? resourceLoader,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BiblePediaImageFigure(
          image: image,
          artifact: artifact ?? _artifactForImage(image),
          maxInlineImageBytes: maxInlineImageBytes,
          resourceLoader: resourceLoader ?? _TestResourceLoader(_onePixelBytes),
          verifiedByteCache: BiblePediaMemoryVerifiedByteCache(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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
            BiblePediaManifestFile(
              path: source.portablePath,
              sha256: sha256.convert(_onePixelBytes).toString(),
              byteLength: _onePixelBytes.length,
            ),
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

final class _TestResourceLoader implements BiblePediaResourceByteLoader {
  _TestResourceLoader(this.bytes);

  final Uint8List bytes;
  final List<Uri> uris = [];

  @override
  Future<Uint8List> loadBytes(Uri uri, {required int maximumBytes}) async {
    uris.add(uri);
    return Uint8List.fromList(bytes);
  }
}
