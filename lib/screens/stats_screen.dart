import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(playerStatsProvider);
    final accPct = (s.accuracy * 100).round();

    return SafeArea(
      child: ResponsiveContentBox(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              context.s(20), context.s(16), context.s(20), context.s(120)),
          children: [
            Text('Your stats',
                style: Theme.of(context).textTheme.headlineLarge),
            SizedBox(height: context.s(6)),
            const Text(
              'All stored on your device. Nothing sent to any server.',
              style: TextStyle(color: AppTheme.mute, fontSize: 12),
            ),
            SizedBox(height: context.s(20)),
            _Card(title: 'Tests taken', value: '${s.totalTests}'),
            _Card(title: 'Words asked', value: '${s.totalWordsAsked}'),
            _Card(
                title: 'Words correct',
                value: '${s.totalWordsCorrect}',
                valueColor: AppTheme.sage),
            _Card(
                title: 'Accuracy',
                value: '$accPct%',
                valueColor: AppTheme.honeyDark),
            _Card(
                title: 'Best streak (within a test)',
                value: '${s.bestStreak}',
                valueColor: AppTheme.coral),
            _Card(
                title: 'Perfect-test streak',
                value: '${s.currentStreak}',
                valueColor: AppTheme.violet),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;
  const _Card(
      {required this.title, required this.value, this.valueColor});

  @override
  Widget build(BuildContext c) {
    return Container(
      margin: EdgeInsets.only(bottom: c.s(8)),
      padding: EdgeInsets.all(c.s(16)),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
        borderRadius: BorderRadius.circular(c.s(14)),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: AppTheme.mute,
                      fontWeight: FontWeight.w700,
                      fontSize: 13))),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: valueColor ?? AppTheme.ink)),
        ],
      ),
    );
  }
}
