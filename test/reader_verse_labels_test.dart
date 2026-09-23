import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bible/app.dart';
import 'package:flutter_bible/services/bible_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ltrPath = 'test_bibles/labeled_english.json';
const _rtlPath = 'test_bibles/labeled_hebrew.json';
const _labels = ['1', '2–4', '5a', '5b', '123a-125b'];
const _texts = {
  '1': 'The first verse.',
  '2–4': 'A combined passage.',
  '5a': 'The first part.',
  '5b': 'The second part.',
  '123a-125b': 'A longer range.',
};
const _rtlTexts = {
  '1': 'טקסט ראשון',
  '2–4': 'טקסט משולב',
  '5a': 'חלק ראשון',
  '5b': 'חלק שני',
  '123a-125b': 'טקסט ארוך',
};

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final assets = {
    'bible_io_json/bible_list.json': jsonEncode([
      {
        'id': 'labeled-english',
        'assetPath': _ltrPath,
        'languageName': 'English',
        'languageCode': 'en',
        'translationName': 'Labeled English',
        'direction': 'ltr',
      },
      {
        'id': 'labeled-hebrew',
        'assetPath': _rtlPath,
        'languageName': 'Hebrew',
        'languageCode': 'he',
        'translationName': 'Labeled Hebrew',
        'direction': 'rtl',
      },
    ]),
    _ltrPath: _bibleJson(),
    _rtlPath: _bibleJson(rtl: true),
  };

  void mockAssets() {
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      final path = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      final asset = assets[path];
      return asset == null
          ? null
          : ByteData.sublistView(Uint8List.fromList(utf8.encode(asset)));
    });
  }

  setUpAll(() async {
    mockAssets();
    // Complete the shared catalog future outside any widget test's fake clock.
    await loadBibleCatalog();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'bible_file_path': _ltrPath});
    PackageInfo.setMockInitialValues(
      appName: 'BibleIO Reader',
      packageName: 'flutter_bible',
      version: '1.0.0',
      buildNumber: '',
      buildSignature: '',
    );
    rootBundle.clear();
    mockAssets();
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      null,
    );
    rootBundle.clear();
  });

  testWidgets(
    'complete labels fit compact and wide readers at large text sizes',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'bible_file_path': _ltrPath,
        'bible_text_size': 28.0,
      });
      _setViewport(tester, const Size(390, 844));
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _openReader(tester);
      _expectUnclippedLabels(tester);
      expect(find.text('Find a book'), findsNothing);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();

      expect(find.text('Find a book'), findsOneWidget);
      _expectUnclippedLabels(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reference navigation focuses the exact matching source entry', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _openReader(tester);

    for (final entry in {
      'Genesis 1:5b': '5b',
      'Genesis 1:4': '2–4',
      'Genesis 1:5': '5a',
    }.entries) {
      await tester.tap(find.byTooltip('Go to a Bible reference'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reference_field')),
        entry.key,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Go'));
      await tester.pumpAndSettle();

      _expectFocusedLabel(tester, entry.value);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'search returns to the exact subverse and chapter navigation saves',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _openReader(tester);
      await tester.tap(find.byTooltip('Search verses'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('search_query_field')),
        'second part',
      );
      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();
      final result = find.byKey(const ValueKey('search_result_genesis_1_5b'));
      await tester.scrollUntilVisible(
        result,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(result);
      await tester.pumpAndSettle();

      _expectFocusedLabel(tester, '5b');
      expect(find.text('Genesis 1'), findsOneWidget);
      final preferences = await SharedPreferences.getInstance();
      expect(_savedLocation(preferences), {'book': 'gn', 'chapter': 1});

      await tester.tap(find.byTooltip('Next chapter'));
      await tester.pumpAndSettle();
      expect(find.text('Genesis 2'), findsOneWidget);
      expect(_focusedRows(), findsNothing);
      expect(_savedLocation(preferences), {'book': 'gn', 'chapter': 2});

      await tester.tap(find.byTooltip('Previous chapter'));
      await tester.pumpAndSettle();
      expect(find.text('Genesis 1'), findsOneWidget);
      expect(_focusedRows(), findsNothing);
      expect(_savedLocation(preferences), {'book': 'gn', 'chapter': 1});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('RTL labels keep source order with compact spacing and copying', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'bible_file_path': _rtlPath});
    _setViewport(tester, const Size(390, 844));
    await _openReader(tester, chapterTitle: 'בראשית 1');
    expect(tester.takeException(), isNull);
    final normalHeight = tester.getSize(_verseRow('5b')).height;
    await tester.tap(find.byTooltip('Reader settings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Display'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final compactSwitch = find.byKey(const Key('show_verses_inline_switch'));
    await tester.ensureVisible(compactSwitch);
    await tester.tap(compactSwitch);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(tester.getSize(_verseRow('5b')).height, lessThan(normalHeight));
    _expectUnclippedLabels(tester);
    for (final label in _labels) {
      final row = _verseRow(label);
      final number = tester.widget<Text>(
        find.descendant(of: row, matching: find.text(label)),
      );
      final scripture = tester.widget<Text>(
        find.descendant(of: row, matching: find.text(_rtlTexts[label]!)),
      );
      expect(number.textDirection, TextDirection.ltr);
      expect(scripture.textDirection, TextDirection.rtl);
    }

    String? copiedText;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final selection = tester.state<SelectionAreaState>(
      find.byType(SelectionArea),
    );
    selection.selectableRegion.selectAll(SelectionChangedCause.keyboard);
    await tester.pump();
    selection.selectableRegion.contextMenuButtonItems
        .singleWhere((item) => item.type == ContextMenuButtonType.copy)
        .onPressed!();
    await tester.pump();
    for (final label in _labels) {
      expect(copiedText, contains(label));
      expect(copiedText, contains(_rtlTexts[label]));
    }
    expect(tester.takeException(), isNull);
  });
}

String _bibleJson({bool rtl = false}) => jsonEncode({
  'language': rtl ? 'Hebrew' : 'English',
  'books': {
    'gn': {
      'name': rtl ? 'בראשית' : 'Genesis',
      'chapters': {
        '1': rtl ? _rtlTexts : _texts,
        '2': {'1': rtl ? 'פרק שני' : 'The next chapter.'},
      },
    },
  },
});

Finder _verseRow(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == 'Verse $label',
);

Finder _focusedRows() => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      (widget.properties.label?.startsWith('Verse ') ?? false) &&
      widget.properties.selected == true,
);

void _expectFocusedLabel(WidgetTester tester, String label) {
  expect(_focusedRows(), findsOneWidget);
  expect(
    tester.widget<Semantics>(_focusedRows()).properties.label,
    'Verse $label',
  );
}

void _expectUnclippedLabels(WidgetTester tester) {
  for (final label in _labels) {
    final text = find.descendant(
      of: _verseRow(label),
      matching: find.text(label),
    );
    expect(text, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      paragraph.size.width,
      greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)),
      reason: 'The complete $label source label must fit its gutter.',
    );
  }
}

Object? _savedLocation(SharedPreferences preferences) =>
    (jsonDecode(preferences.getString('reading_locations_v2')!)
        as Map<String, dynamic>)['labeled-english'];

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openReader(
  WidgetTester tester, {
  String chapterTitle = 'Genesis 1',
}) async {
  await tester.pumpWidget(const BibleReaderApp());
  final stopwatch = Stopwatch()..start();
  while (find.text(chapterTitle).evaluate().isEmpty &&
      stopwatch.elapsed < const Duration(seconds: 15)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  expect(
    find.text(chapterTitle),
    findsOneWidget,
    reason: tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .join('\n'),
  );
  await tester.pumpAndSettle();
}
