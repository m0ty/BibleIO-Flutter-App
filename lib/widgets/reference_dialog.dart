import 'package:bible_io/bible_io.dart';
import 'package:flutter/material.dart';

class ReferenceDialog extends StatefulWidget {
  const ReferenceDialog({super.key, required this.bible});

  final Bible bible;

  @override
  State<ReferenceDialog> createState() => _ReferenceDialogState();
}

class _ReferenceDialogState extends State<ReferenceDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    try {
      final verses = widget.bible.getPassage(query);
      if (verses.isEmpty) {
        setState(() => _error = 'No verses were found for that reference.');
        return;
      }
      Navigator.pop(context, verses.first.location);
    } on Object catch (error) {
      setState(() {
        _error = error is BibleError
            ? error.message
            : 'Try John 3:16, Romans 8:1-4, or John 1:5b.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.short_text_rounded),
      title: const Text('Go to a passage'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('reference_field'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.go,
              decoration: InputDecoration(
                labelText: 'Bible reference',
                hintText: 'John 3:16',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Text(
              'Book names in multiple languages are supported, as are sub-verses such as John 1:5b. Ranges and passage lists open at their first verse. Combined verses stay together.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Go')),
      ],
    );
  }
}
