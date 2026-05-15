import 'package:flutter/material.dart';
import 'package:spellbee/core/constants/theme.dart';

Future<bool> showParentGate(
  BuildContext context, {
  String reason = 'Premium is for grown-ups.',
}) async {
  const answer = '12';
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Parent check'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reason),
          const SizedBox(height: 12),
          const Text(
            'To continue, type the answer: 7 + 5',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Answer',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) =>
                Navigator.pop(ctx, controller.text.trim() == answer),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
          onPressed: () => Navigator.pop(ctx, controller.text.trim() == answer),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result ?? false;
}

Future<void> openPaywallAfterParentGate(BuildContext context) async {
  final passed = await showParentGate(
    context,
    reason: 'Ask a parent before opening SpellBee Premium.',
  );
  if (!passed || !context.mounted) return;
  await Navigator.of(context).pushNamed('/paywall');
}
