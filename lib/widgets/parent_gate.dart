import 'dart:math';

import 'package:flutter/material.dart';

/// Multiplication question that keeps grown-up actions (buying, rating the
/// app, notification settings) away from the child. A fresh question is asked
/// every time and approval is never persisted.
///
/// Returns true only when the grown-up answered correctly.
Future<bool> showParentGate(
  BuildContext context, {
  String message = 'Please ask a parent to continue to the store.',
  String confirmLabel = 'Continue to store',
}) async {
  final approved = await showDialog<bool>(
    context: context,
    builder: (_) => ParentGate(message: message, confirmLabel: confirmLabel),
  );
  return approved == true;
}

class ParentGate extends StatefulWidget {
  final String message;
  final String confirmLabel;

  const ParentGate({
    super.key,
    this.message = 'Please ask a parent to continue to the store.',
    this.confirmLabel = 'Continue to store',
  });

  @override
  State<ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<ParentGate> {
  final _answer = TextEditingController();
  final _left = 12 + Random().nextInt(8);
  final _right = 3 + Random().nextInt(6);
  int _attempts = 0;
  String? _error;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _check() {
    if (int.tryParse(_answer.text.trim()) == _left * _right) {
      Navigator.pop(context, true);
    } else if (++_attempts >= 3) {
      Navigator.pop(context, false);
    } else {
      setState(() => _error = 'Please ask a grown-up to help.');
      _answer.clear();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('A moment for grown-ups'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          Text('What is $_left × $_right?', key: const Key('parent-challenge')),
          const SizedBox(height: 12),
          TextField(
            key: const Key('parent-answer'),
            controller: _answer,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _check(),
            decoration: InputDecoration(
              labelText: 'Your answer',
              errorText: _error,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Not now'),
      ),
      FilledButton(onPressed: _check, child: Text(widget.confirmLabel)),
    ],
  );
}
