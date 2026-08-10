import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef BiblePediaDocumentLinkSelected = void Function(MarkdownLink link);

/// Renders the package-owned, platform-neutral Bible Pedia document tree.
class BiblePediaDocumentView extends StatelessWidget {
  const BiblePediaDocumentView({
    super.key,
    required this.document,
    this.onLinkSelected,
  });

  final BiblePediaDocument document;
  final BiblePediaDocumentLinkSelected? onLinkSelected;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: _DocumentBlocks(
        blocks: document.blocks,
        onLinkSelected: onLinkSelected,
      ),
    );
  }
}

class _DocumentBlocks extends StatelessWidget {
  const _DocumentBlocks({required this.blocks, this.onLinkSelected});

  final List<MarkdownBlock> blocks;
  final BiblePediaDocumentLinkSelected? onLinkSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          _buildBlock(context, blocks[index]),
          if (index != blocks.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildBlock(BuildContext context, MarkdownBlock block) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return switch (block) {
      MarkdownParagraph(:final children) => _MarkdownInlineText(
        inlines: children,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
        onLinkSelected: onLinkSelected,
      ),
      MarkdownHeading(:final level, :final children) => Semantics(
        header: true,
        child: _MarkdownInlineText(
          inlines: children,
          style: switch (level) {
            1 => theme.textTheme.titleLarge,
            2 => theme.textTheme.titleMedium,
            _ => theme.textTheme.titleSmall,
          }?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
          onLinkSelected: onLinkSelected,
        ),
      ),
      MarkdownBlockQuote(:final blocks) => Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          border: BorderDirectional(
            start: BorderSide(color: colors.primary, width: 3),
          ),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontStyle: FontStyle.italic),
          child: _DocumentBlocks(
            blocks: blocks,
            onLinkSelected: onLinkSelected,
          ),
        ),
      ),
      MarkdownList(:final ordered, :final start, :final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < items.length; index++)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
              child: _MarkdownListItemView(
                marker: ordered ? '${start + index}.' : '\u2022',
                item: items[index],
                onLinkSelected: onLinkSelected,
              ),
            ),
        ],
      ),
      MarkdownCodeBlock(:final code, :final language) => Semantics(
        label: language == null ? 'Code block' : '$language code block',
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              code,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
      MarkdownThematicBreak() => const Divider(),
    };
  }
}

class _MarkdownListItemView extends StatelessWidget {
  const _MarkdownListItemView({
    required this.marker,
    required this.item,
    this.onLinkSelected,
  });

  final String marker;
  final MarkdownListItem item;
  final BiblePediaDocumentLinkSelected? onLinkSelected;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Text(
            marker,
            style: style?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: _DocumentBlocks(
            blocks: item.blocks,
            onLinkSelected: onLinkSelected,
          ),
        ),
      ],
    );
  }
}

class _MarkdownInlineText extends StatefulWidget {
  const _MarkdownInlineText({
    required this.inlines,
    required this.style,
    this.onLinkSelected,
  });

  final List<MarkdownInline> inlines;
  final TextStyle? style;
  final BiblePediaDocumentLinkSelected? onLinkSelected;

  @override
  State<_MarkdownInlineText> createState() => _MarkdownInlineTextState();
}

class _MarkdownInlineTextState extends State<_MarkdownInlineText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final colors = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(children: _spans(widget.inlines, colors)),
      style: widget.style,
    );
  }

  List<InlineSpan> _spans(
    Iterable<MarkdownInline> inlines,
    ColorScheme colors, {
    TapGestureRecognizer? recognizer,
    MouseCursor? mouseCursor,
  }) => [
    for (final inline in inlines)
      _span(inline, colors, recognizer: recognizer, mouseCursor: mouseCursor),
  ];

  InlineSpan _span(
    MarkdownInline inline,
    ColorScheme colors, {
    TapGestureRecognizer? recognizer,
    MouseCursor? mouseCursor,
  }) {
    return switch (inline) {
      MarkdownText(:final text) => TextSpan(
        text: text,
        recognizer: recognizer,
        mouseCursor: mouseCursor,
      ),
      MarkdownEmphasis(:final children) => TextSpan(
        style: const TextStyle(fontStyle: FontStyle.italic),
        children: _spans(
          children,
          colors,
          recognizer: recognizer,
          mouseCursor: mouseCursor,
        ),
      ),
      MarkdownStrong(:final children) => TextSpan(
        style: const TextStyle(fontWeight: FontWeight.w700),
        children: _spans(
          children,
          colors,
          recognizer: recognizer,
          mouseCursor: mouseCursor,
        ),
      ),
      MarkdownStrikethrough(:final children) => TextSpan(
        style: const TextStyle(decoration: TextDecoration.lineThrough),
        children: _spans(
          children,
          colors,
          recognizer: recognizer,
          mouseCursor: mouseCursor,
        ),
      ),
      MarkdownCode(:final code) => TextSpan(
        text: code,
        style: TextStyle(
          fontFamily: 'monospace',
          backgroundColor: colors.surfaceContainerHighest,
        ),
        recognizer: recognizer,
        mouseCursor: mouseCursor,
      ),
      MarkdownLink() => _linkSpan(inline, colors),
      MarkdownImage(:final altText) => TextSpan(
        text: altText,
        style: const TextStyle(fontStyle: FontStyle.italic),
        semanticsLabel: altText,
        recognizer: recognizer,
        mouseCursor: mouseCursor,
      ),
      MarkdownLineBreak() => TextSpan(
        text: '\n',
        recognizer: recognizer,
        mouseCursor: mouseCursor,
      ),
    };
  }

  InlineSpan _linkSpan(MarkdownLink link, ColorScheme colors) {
    final callback = widget.onLinkSelected;
    TapGestureRecognizer? recognizer;
    if (callback != null) {
      recognizer = TapGestureRecognizer()..onTap = () => callback(link);
      _recognizers.add(recognizer);
    }
    return TextSpan(
      children: _spans(
        link.children,
        colors,
        recognizer: recognizer,
        mouseCursor: callback == null ? null : SystemMouseCursors.click,
      ),
      style: TextStyle(
        color: colors.primary,
        decoration: TextDecoration.underline,
        decorationColor: colors.primary,
      ),
    );
  }
}
