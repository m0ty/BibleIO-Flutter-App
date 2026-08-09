import 'package:bible_io/bible_io.dart';
import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays one Bible Pedia entry and its structured relationships.
class BiblePediaEntryPage extends StatelessWidget {
  const BiblePediaEntryPage({
    super.key,
    required this.entry,
    required this.encyclopedia,
    required this.onEntryOpened,
    this.onCitationSelected,
  });

  static const double _maxContentWidth = 760;

  final EncyclopediaEntry entry;
  final BibleEncyclopedia encyclopedia;
  final ValueChanged<EncyclopediaEntry> onEntryOpened;
  final ValueChanged<BibleCitation>? onCitationSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: '${entry.title}, ${_categoryLabel(entry.type)}',
      child: Scaffold(
        key: const Key('bible_pedia_entry_page'),
        appBar: AppBar(title: const Text('Bible Pedia')),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 900
                  ? 32.0
                  : 16.0;
              return SingleChildScrollView(
                key: const Key('bible_pedia_entry_scroll_view'),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  20,
                  horizontalPadding,
                  36,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: KeyedSubtree(
                      key: ValueKey('bible_pedia_entry_${entry.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _EntryHeader(entry: entry),
                          const SizedBox(height: 20),
                          _buildDescriptionSection(),
                          const SizedBox(height: 16),
                          _buildReferencesSection(),
                          const SizedBox(height: 16),
                          _buildRelatedEntriesSection(context),
                          const SizedBox(height: 16),
                          _buildTagsSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final description = entry.descriptionMarkdown.trim();
    return _EntrySection(
      key: const Key('bible_pedia_entry_description_section'),
      icon: Icons.subject_rounded,
      title: 'About',
      child: description.isEmpty
          ? const _EmptySectionMessage(
              key: Key('bible_pedia_entry_description_empty'),
              message: 'No description is available for this entry yet.',
            )
          : _LightweightMarkdown(
              key: const Key('bible_pedia_entry_description'),
              data: description,
            ),
    );
  }

  Widget _buildReferencesSection() {
    final references = entry.bibleReferences;
    return _EntrySection(
      key: const Key('bible_pedia_entry_references_section'),
      icon: Icons.menu_book_outlined,
      title: 'Bible references',
      count: references.length,
      child: references.isEmpty
          ? const _EmptySectionMessage(
              key: Key('bible_pedia_entry_references_empty'),
              message: 'No Bible references are listed for this entry.',
            )
          : _ReferenceBookList(
              references: references,
              onCitationSelected: onCitationSelected,
            ),
    );
  }

  Widget _buildRelatedEntriesSection(BuildContext context) {
    final links = entry.relatedEntries;
    return _EntrySection(
      key: const Key('bible_pedia_entry_related_section'),
      icon: Icons.hub_outlined,
      title: 'Related entries',
      count: links.length,
      child: links.isEmpty
          ? const _EmptySectionMessage(
              key: Key('bible_pedia_entry_related_empty'),
              message: 'No related entries are listed.',
            )
          : Column(
              children: [
                for (var index = 0; index < links.length; index++) ...[
                  _buildRelatedEntryTile(context, links[index], index),
                  if (index != links.length - 1) const Divider(indent: 48),
                ],
              ],
            ),
    );
  }

  Widget _buildRelatedEntryTile(
    BuildContext context,
    EntryLink link,
    int index,
  ) {
    final relatedEntry = link.entryId == null
        ? null
        : encyclopedia.entryById(link.entryId!);
    final title = relatedEntry?.title ?? link.label;
    final semanticsLabel = relatedEntry == null
        ? '$title. Related entry unavailable.'
        : '$title. ${_categoryLabel(relatedEntry.type)}.';

    return Semantics(
      button: relatedEntry != null,
      enabled: relatedEntry != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: ListTile(
        key: ValueKey(
          'bible_pedia_related_${link.entryId ?? link.target}_$index',
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(
          relatedEntry == null
              ? Icons.link_off_rounded
              : _categoryIcon(relatedEntry.type),
        ),
        title: Text(title),
        subtitle: Text(
          relatedEntry == null
              ? 'This entry is not available.'
              : _categoryLabel(relatedEntry.type),
        ),
        trailing: relatedEntry == null
            ? null
            : const Icon(Icons.chevron_right_rounded),
        onTap: relatedEntry == null
            ? null
            : () => _openRelatedEntry(context, relatedEntry),
      ),
    );
  }

  void _openRelatedEntry(BuildContext context, EncyclopediaEntry relatedEntry) {
    onEntryOpened(relatedEntry);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/bible-pedia/entry/${relatedEntry.id}'),
        builder: (context) => BiblePediaEntryPage(
          entry: relatedEntry,
          encyclopedia: encyclopedia,
          onEntryOpened: onEntryOpened,
          onCitationSelected: onCitationSelected,
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    final tags = entry.tags;
    return _EntrySection(
      key: const Key('bible_pedia_entry_tags_section'),
      icon: Icons.sell_outlined,
      title: 'Tags',
      count: tags.length,
      child: tags.isEmpty
          ? const _EmptySectionMessage(
              key: Key('bible_pedia_entry_tags_empty'),
              message: 'No tags are listed for this entry.',
            )
          : Wrap(
              key: const Key('bible_pedia_entry_tags'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < tags.length; index++)
                  Chip(
                    key: ValueKey('bible_pedia_tag_$index'),
                    avatar: const Icon(Icons.tag_rounded, size: 17),
                    label: Text(tags[index]),
                  ),
              ],
            ),
    );
  }
}

class _EntryHeader extends StatelessWidget {
  const _EntryHeader({required this.entry});

  final EncyclopediaEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final aliases = entry.aliases.isEmpty
        ? ''
        : '. Also known as ${entry.aliases.join(', ')}';

    return Semantics(
      container: true,
      header: true,
      label: '${entry.title}, ${_categoryLabel(entry.type)}$aliases',
      excludeSemantics: true,
      child: DecoratedBox(
        key: const Key('bible_pedia_entry_header'),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        _categoryIcon(entry.type),
                        color: colors.onPrimary,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _categoryLabel(entry.type).toUpperCase(),
                          key: const Key('bible_pedia_entry_category'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          entry.title,
                          key: const Key('bible_pedia_entry_title'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (entry.aliases.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Also known as',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  key: const Key('bible_pedia_entry_aliases'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var index = 0; index < entry.aliases.length; index++)
                      Chip(
                        key: ValueKey('bible_pedia_alias_$index'),
                        label: Text(entry.aliases[index]),
                        backgroundColor: colors.surface.withValues(alpha: 0.72),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EntrySection extends StatelessWidget {
  const _EntrySection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.count,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(icon, size: 22, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (count != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReferenceBookList extends StatelessWidget {
  const _ReferenceBookList({
    required this.references,
    required this.onCitationSelected,
  });

  final List<BibleCitation> references;
  final ValueChanged<BibleCitation>? onCitationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final groups = _groupReferencesByBook(references);

    return Column(
      children: [
        for (var index = 0; index < groups.length; index++) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: ExpansionTile(
              key: ValueKey(
                'bible_pedia_reference_book_${groups[index].book.name}',
              ),
              maintainState: false,
              internalAddSemanticForOnTap: true,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(),
              collapsedShape: const RoundedRectangleBorder(),
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              leading: Icon(Icons.menu_book_outlined, color: colors.primary),
              title: Text(
                groups[index].book.fullName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${groups[index].references.length} '
                '${groups[index].references.length == 1 ? 'Bible reference' : 'Bible references'}',
              ),
              children: [
                const Divider(),
                _ReferenceList(
                  book: groups[index].book,
                  references: groups[index].references,
                  onCitationSelected: onCitationSelected,
                ),
              ],
            ),
          ),
          if (index != groups.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ReferenceList extends StatefulWidget {
  const _ReferenceList({
    required this.book,
    required this.references,
    required this.onCitationSelected,
  });

  static const pageSize = 30;

  final BibleBookEnum book;
  final List<BibleCitation> references;
  final ValueChanged<BibleCitation>? onCitationSelected;

  @override
  State<_ReferenceList> createState() => _ReferenceListState();
}

class _ReferenceListState extends State<_ReferenceList> {
  late int _visibleCount;

  int get _initialVisibleCount =>
      widget.references.length < _ReferenceList.pageSize
      ? widget.references.length
      : _ReferenceList.pageSize;

  @override
  void initState() {
    super.initState();
    _visibleCount = _initialVisibleCount;
  }

  @override
  void didUpdateWidget(_ReferenceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book != widget.book ||
        !listEquals(oldWidget.references, widget.references)) {
      _visibleCount = _initialVisibleCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.references.length - _visibleCount;
    return Column(
      children: [
        for (var index = 0; index < _visibleCount; index++) ...[
          _ReferenceTile(
            key: ValueKey('bible_pedia_citation_${widget.book.name}_$index'),
            citation: widget.references[index],
            onTap: widget.onCitationSelected == null
                ? null
                : () => widget.onCitationSelected!(widget.references[index]),
          ),
          if (index != _visibleCount - 1 || remaining > 0)
            const Divider(indent: 48),
        ],
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton.icon(
              key: ValueKey('bible_pedia_more_references_${widget.book.name}'),
              onPressed: () {
                setState(() {
                  final next = _visibleCount + _ReferenceList.pageSize;
                  _visibleCount = next < widget.references.length
                      ? next
                      : widget.references.length;
                });
              },
              icon: const Icon(Icons.expand_more_rounded),
              label: Text(
                'Show ${remaining < _ReferenceList.pageSize ? remaining : _ReferenceList.pageSize} more '
                '($remaining remaining)',
              ),
            ),
          ),
      ],
    );
  }
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({super.key, required this.citation, this.onTap});

  final BibleCitation citation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: onTap != null,
      label: onTap == null
          ? citation.sourceText
          : '${citation.sourceText}. Open this passage.',
      excludeSemantics: true,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(
          Icons.bookmark_outline_rounded,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          citation.sourceText,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: onTap == null ? null : const Text('Open in Bible reader'),
        trailing: onTap == null
            ? null
            : const Icon(Icons.open_in_new_rounded, size: 20),
        onTap: onTap,
      ),
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _LightweightMarkdown extends StatelessWidget {
  const _LightweightMarkdown({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final blocks = <Widget>[];
    final paragraphLines = <String>[];

    void flushParagraph() {
      if (paragraphLines.isEmpty) return;
      blocks.add(
        Text(
          _cleanInlineMarkdown(paragraphLines.join(' ')),
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
        ),
      );
      paragraphLines.clear();
    }

    final lines = data
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flushParagraph();
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (heading != null) {
        flushParagraph();
        final level = heading.group(1)!.length;
        final style = switch (level) {
          1 => theme.textTheme.titleLarge,
          2 => theme.textTheme.titleMedium,
          _ => theme.textTheme.titleSmall,
        };
        blocks.add(
          Text(
            _cleanInlineMarkdown(heading.group(2)!),
            style: style?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
          ),
        );
        continue;
      }

      final unorderedItem = RegExp(r'^[-+*]\s+(.+)$').firstMatch(line);
      if (unorderedItem != null) {
        flushParagraph();
        blocks.add(
          _MarkdownListItem(
            marker: '\u2022',
            text: _cleanInlineMarkdown(unorderedItem.group(1)!),
          ),
        );
        continue;
      }

      final orderedItem = RegExp(r'^(\d+)[.)]\s+(.+)$').firstMatch(line);
      if (orderedItem != null) {
        flushParagraph();
        blocks.add(
          _MarkdownListItem(
            marker: '${orderedItem.group(1)}.',
            text: _cleanInlineMarkdown(orderedItem.group(2)!),
          ),
        );
        continue;
      }

      final quote = RegExp(r'^>\s?(.*)$').firstMatch(line);
      if (quote != null) {
        flushParagraph();
        blocks.add(
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              border: BorderDirectional(
                start: BorderSide(color: colors.primary, width: 3),
              ),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
            child: Text(
              _cleanInlineMarkdown(quote.group(1)!),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        );
        continue;
      }

      if (RegExp(r'^([-*_])\1{2,}$').hasMatch(line)) {
        flushParagraph();
        blocks.add(const Divider());
        continue;
      }

      paragraphLines.add(line);
    }
    flushParagraph();

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < blocks.length; index++) ...[
            blocks[index],
            if (index != blocks.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _MarkdownListItem extends StatelessWidget {
  const _MarkdownListItem({required this.marker, required this.text});

  final String marker;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Text(
            marker,
            style: style?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

String _cleanInlineMarkdown(String source) {
  var result = source;
  result = result.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
    (match) => match.group(1)!.trim(),
  );
  result = result.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]*\)'),
    (match) => match.group(1)!,
  );
  result = result.replaceAllMapped(
    RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]'),
    (match) => match.group(2) ?? match.group(1)!,
  );
  result = result.replaceAll(RegExp(r'<[^>]+>'), '');
  result = result.replaceAll('**', '');
  result = result.replaceAll('__', '');
  result = result.replaceAll('~~', '');
  result = result.replaceAll('`', '');
  result = result.replaceAllMapped(
    RegExp(r'\*([^*\n]+)\*'),
    (match) => match.group(1)!,
  );
  result = result.replaceAllMapped(
    RegExp(r'_([^_\n]+)_'),
    (match) => match.group(1)!,
  );
  result = result
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}

IconData _categoryIcon(EntryType type) => switch (type) {
  EntryType.person => Icons.person_outline_rounded,
  EntryType.location => Icons.place_outlined,
  EntryType.event => Icons.event_outlined,
  EntryType.concept => Icons.lightbulb_outline_rounded,
  EntryType.other => Icons.category_outlined,
};

String _categoryLabel(EntryType type) => switch (type) {
  EntryType.person => 'Person',
  EntryType.location => 'Location',
  EntryType.event => 'Event',
  EntryType.concept => 'Concept',
  EntryType.other => 'Other',
};

final class _BookReferenceGroup {
  const _BookReferenceGroup({required this.book, required this.references});

  final BibleBookEnum book;
  final List<BibleCitation> references;
}

List<_BookReferenceGroup> _groupReferencesByBook(
  Iterable<BibleCitation> references,
) {
  final referencesByBook = <BibleBookEnum, List<BibleCitation>>{};
  for (final citation in references) {
    for (final book in citation.books) {
      referencesByBook.putIfAbsent(book, () => []).add(citation);
    }
  }

  final books = referencesByBook.keys.toList()
    ..sort((left, right) => left.index.compareTo(right.index));
  return List.unmodifiable([
    for (final book in books)
      _BookReferenceGroup(
        book: book,
        references: List.unmodifiable(referencesByBook[book]!),
      ),
  ]);
}
