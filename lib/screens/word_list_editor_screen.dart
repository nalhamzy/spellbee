import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/models/word.dart';
import 'package:spellbee/core/models/word_list.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';

class WordListEditorScreen extends ConsumerStatefulWidget {
  final WordList? existing;
  const WordListEditorScreen({super.key, this.existing});

  @override
  ConsumerState<WordListEditorScreen> createState() =>
      _WordListEditorScreenState();
}

class _WordListEditorScreenState
    extends ConsumerState<WordListEditorScreen> {
  late final TextEditingController _nameCtrl;
  late final List<Word> _words;

  final _wordCtrl = TextEditingController();
  final _defCtrl = TextEditingController();
  final _exCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _words = [...?widget.existing?.words];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _wordCtrl.dispose();
    _defCtrl.dispose();
    _exCtrl.dispose();
    super.dispose();
  }

  void _addWord() {
    final w = _wordCtrl.text.trim().toLowerCase();
    if (w.isEmpty) return;
    setState(() {
      _words.add(Word(w, _defCtrl.text.trim(), _exCtrl.text.trim()));
      _wordCtrl.clear();
      _defCtrl.clear();
      _exCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please name the list.')),
      );
      return;
    }
    if (_words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one word.')),
      );
      return;
    }
    final list = WordList(
      id: widget.existing?.id ??
          'wl_${DateTime.now().microsecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      words: _words,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    await ref.read(wordListsProvider.notifier).upsert(list);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete list?'),
        content: Text(
            'Permanently delete "${widget.existing!.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(wordListsProvider.notifier).delete(id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        foregroundColor: AppTheme.ink,
        title: Text(widget.existing == null ? 'New list' : 'Edit list'),
        actions: [
          if (widget.existing != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: AppTheme.honeyDark)),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContentBox(
          child: ListView(
            padding: EdgeInsets.all(context.s(20)),
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'List name',
                  hintText: 'e.g. Mrs. Lee\'s week 12',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.s(14)),
                    borderSide: const BorderSide(color: AppTheme.outline),
                  ),
                ),
              ),
              SizedBox(height: context.s(18)),
              Text('Add a word',
                  style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: context.s(8)),
              Container(
                padding: EdgeInsets.all(context.s(12)),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.outline),
                  borderRadius: BorderRadius.circular(context.s(14)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _wordCtrl,
                      textInputAction: TextInputAction.next,
                      decoration:
                          const InputDecoration(labelText: 'Word (required)'),
                    ),
                    SizedBox(height: context.s(8)),
                    TextField(
                      controller: _defCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Definition (optional)'),
                    ),
                    SizedBox(height: context.s(8)),
                    TextField(
                      controller: _exCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Used in a sentence (optional)'),
                    ),
                    SizedBox(height: context.s(12)),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _addWord,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.honey,
                          foregroundColor: AppTheme.ink,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add to list'),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.s(20)),
              Text('Words (${_words.length})',
                  style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: context.s(8)),
              for (int i = 0; i < _words.length; i++)
                _wordRow(context, i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wordRow(BuildContext c, int i) {
    final w = _words[i];
    return Container(
      margin: EdgeInsets.only(bottom: c.s(6)),
      padding: EdgeInsets.all(c.s(12)),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
        borderRadius: BorderRadius.circular(c.s(10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.text,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppTheme.ink)),
                if (w.definition.isNotEmpty)
                  Text(w.definition,
                      style:
                          const TextStyle(color: AppTheme.mute, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: AppTheme.mute,
            onPressed: () => setState(() => _words.removeAt(i)),
          ),
        ],
      ),
    );
  }
}
