import 'package:flutter/material.dart';
import 'package:spellbee/core/utils/school_word_import.dart';

/// Changes stay in this dialog until the parent confirms the preview.
class SchoolWordImportDialog extends StatefulWidget {
  final Iterable<String> existingWords;

  const SchoolWordImportDialog({super.key, required this.existingWords});

  @override
  State<SchoolWordImportDialog> createState() => _SchoolWordImportDialogState();
}

class _SchoolWordImportDialogState extends State<SchoolWordImportDialog> {
  final _controller = TextEditingController();
  bool _reviewing = false;
  String? _cleanupNotice;

  SchoolWordImport get _parsed => SchoolWordImport.parse(
    _controller.text,
    existingWords: widget.existingWords,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _review() {
    final parsed = _parsed;
    setState(() {
      _reviewing = true;
      _cleanupNotice = _notice(parsed);
      _controller.text = parsed.words.join('\n');
    });
  }

  String? _notice(SchoolWordImport parsed) {
    final messages = <String>[
      if (parsed.duplicates > 0)
        '${parsed.duplicates} duplicate ${parsed.duplicates == 1 ? 'entry' : 'entries'} skipped.',
      if (parsed.invalidEntries > 0)
        '${parsed.invalidEntries} ${parsed.invalidEntries == 1 ? 'entry has' : 'entries have'} no English letters and ${parsed.invalidEntries == 1 ? 'was' : 'were'} skipped.',
    ];
    return messages.isEmpty ? null : messages.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final notice = _notice(parsed) ?? _cleanupNotice;
    return AlertDialog(
      scrollable: true,
      title: Text(_reviewing ? 'Review school words' : 'Paste school words'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _reviewing
                  ? 'Check the spelling and edit any words below. Keep one word or phrase per line.'
                  : 'Copy your school list here, with one word per line or separated by commas.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('school-word-import-text'),
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              autocorrect: false,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                labelText: _reviewing ? 'Words to add' : 'School words',
                hintText: 'bridge\nbeautiful\nwell-being',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text(
              '${parsed.words.length} new ${parsed.words.length == 1 ? 'word' : 'words'}',
            ),
            if (notice != null) ...[const SizedBox(height: 8), Text(notice)],
            const SizedBox(height: 8),
            const Text(
              'Existing words and their definitions stay in your list.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: parsed.words.isEmpty
              ? null
              : _reviewing
              ? () => Navigator.pop(context, parsed.words)
              : _review,
          child: Text(
            _reviewing
                ? 'Add ${parsed.words.length} ${parsed.words.length == 1 ? 'word' : 'words'}'
                : 'Review words',
          ),
        ),
      ],
    );
  }
}
