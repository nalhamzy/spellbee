import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/player_stats.dart';
import 'package:spellbee/core/models/word.dart';
import 'package:spellbee/core/models/word_list.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/test_screen.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(playerStatsProvider);
    final lists = ref.watch(wordListsProvider);
    final accPct = (s.accuracy * 100).round();
    final focusWords = _focusWords(s.missedWordCounts).take(8).toList();
    final listProgress = _listProgress(s.listScores, lists).take(3).toList();

    return SafeArea(
      child: ResponsiveContentBox(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.s(20)),
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, context.s(16), 0, context.s(120)),
            children: [
              Text(
                'Your stats',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              SizedBox(height: context.s(6)),
              const Text(
                'All stored on your device. Nothing sent to any server.',
                style: TextStyle(color: AppTheme.mute, fontSize: 12),
              ),
              SizedBox(height: context.s(20)),
              _SummaryPanel(
                accuracy: accPct,
                totalTests: s.totalTests,
                dailyStreak: s.dailyStreak,
              ),
              SizedBox(height: context.s(16)),
              _FocusPanel(words: focusWords),
              SizedBox(height: context.s(16)),
              _ListProgressPanel(entries: listProgress),
              SizedBox(height: context.s(16)),
              Wrap(
                spacing: context.s(8),
                runSpacing: context.s(8),
                children: [
                  _MetricChip(
                    title: 'Words asked',
                    value: '${s.totalWordsAsked}',
                    color: AppTheme.sky,
                  ),
                  _MetricChip(
                    title: 'Words correct',
                    value: '${s.totalWordsCorrect}',
                    color: AppTheme.sage,
                  ),
                  _MetricChip(
                    title: 'Best run',
                    value: '${s.bestStreak}',
                    color: AppTheme.coral,
                  ),
                  _MetricChip(
                    title: 'Perfect tests',
                    value: '${s.currentStreak}',
                    color: AppTheme.violet,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_ListProgressEntry> _listProgress(
    Map<String, ListScoreSummary> scores,
    List<WordList> lists,
  ) {
    final byId = {for (final list in lists) list.id: list};
    final entries = <_ListProgressEntry>[];
    for (final scoreEntry in scores.entries) {
      final score = scoreEntry.value;
      if (score.lastTotal == 0) continue;
      final list = byId[scoreEntry.key];
      entries.add(
        _ListProgressEntry(
          name: list?.name ?? 'Saved list',
          wordCount: list?.size ?? score.lastTotal,
          score: score,
        ),
      );
    }
    entries.sort((a, b) {
      final byBest = b.score.bestAccuracy.compareTo(a.score.bestAccuracy);
      if (byBest != 0) return byBest;
      return b.score.attempts.compareTo(a.score.attempts);
    });
    return entries;
  }

  List<Word> _focusWords(Map<String, int> counts) {
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return [
      for (final entry in entries)
        _catalogWord(entry.key) ??
            Word(
              entry.key,
              'A word to practice again.',
              'Spell ${entry.key} one more time.',
            ),
    ];
  }

  Word? _catalogWord(String text) {
    final key = text.toLowerCase();
    for (final word in kAllWords) {
      if (word.text.toLowerCase() == key) return word;
    }
    return null;
  }
}

class _ListProgressEntry {
  final String name;
  final int wordCount;
  final ListScoreSummary score;

  const _ListProgressEntry({
    required this.name,
    required this.wordCount,
    required this.score,
  });
}

class _SummaryPanel extends StatelessWidget {
  final int accuracy;
  final int totalTests;
  final int dailyStreak;

  const _SummaryPanel({
    required this.accuracy,
    required this.totalTests,
    required this.dailyStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.s(18)),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(context.s(24)),
        border: Border.all(color: AppTheme.outline),
        boxShadow: AppTheme.liftedShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gap = context.s(10);
          final columns = constraints.maxWidth >= context.s(390) ? 3 : 2;
          final tileWidth =
              (constraints.maxWidth - (gap * (columns - 1))) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: tileWidth,
                child: _BigNumber(
                  label: 'Accuracy',
                  value: '$accuracy%',
                  color: AppTheme.sage,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _BigNumber(
                  label: 'Tests',
                  value: '$totalTests',
                  color: AppTheme.sky,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _BigNumber(
                  label: 'Daily run',
                  value: '$dailyStreak',
                  color: AppTheme.coral,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BigNumber extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BigNumber({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: context.s(12)),
      decoration: AppTheme.card(
        color: AppTheme.surface.withValues(alpha: 0.76),
        radius: context.s(18),
        shadow: false,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: context.s(24),
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: context.s(2)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.mute,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusPanel extends StatelessWidget {
  final List<Word> words;

  const _FocusPanel({required this.words});

  @override
  Widget build(BuildContext context) {
    final hasWords = words.isNotEmpty;
    return Container(
      padding: EdgeInsets.all(context.s(16)),
      decoration: AppTheme.card(
        gradient: AppTheme.surfaceLiftGradient,
        radius: context.s(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: context.s(42),
                height: context.s(42),
                decoration: BoxDecoration(
                  color: AppTheme.rose,
                  borderRadius: BorderRadius.circular(context.s(14)),
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: AppTheme.coral,
                ),
              ),
              SizedBox(width: context.s(10)),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coach focus',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Words missed most often rise to the top.',
                      style: TextStyle(color: AppTheme.mute, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.s(12)),
          if (hasWords)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final word in words)
                  Chip(
                    label: Text(word.text),
                    backgroundColor: AppTheme.surface2,
                    side: const BorderSide(color: AppTheme.outline),
                  ),
              ],
            )
          else
            Container(
              padding: EdgeInsets.all(context.s(13)),
              decoration: AppTheme.card(
                color: AppTheme.mint,
                gradient: AppTheme.successGradient,
                shadow: false,
              ),
              child: const Text(
                'No focus words yet. Take a trial and missed words will appear here for quick review.',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (hasWords) ...[
            SizedBox(height: context.s(14)),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.ink,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, context.s(52)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.s(16)),
                ),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      TestScreen(words: words, title: 'Coach focus round'),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'Start focus round',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListProgressPanel extends StatelessWidget {
  final List<_ListProgressEntry> entries;

  const _ListProgressPanel({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.s(16)),
      decoration: AppTheme.card(
        gradient: AppTheme.surfaceLiftGradient,
        radius: context.s(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: context.s(42),
                height: context.s(42),
                decoration: BoxDecoration(
                  color: AppTheme.aqua,
                  borderRadius: BorderRadius.circular(context.s(14)),
                ),
                child: const Icon(
                  Icons.library_books_rounded,
                  color: AppTheme.sky,
                ),
              ),
              SizedBox(width: context.s(10)),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'List progress',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Last score and best score for saved lists.',
                      style: TextStyle(color: AppTheme.mute, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.s(12)),
          if (entries.isEmpty)
            Container(
              padding: EdgeInsets.all(context.s(13)),
              decoration: AppTheme.card(
                color: AppTheme.aqua,
                gradient: AppTheme.voiceGradient,
                shadow: false,
              ),
              child: const Text(
                'Practice a custom list once and its score history will appear here.',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) SizedBox(height: context.s(10)),
              _ListProgressRow(entry: entries[i]),
            ],
        ],
      ),
    );
  }
}

class _ListProgressRow extends StatelessWidget {
  final _ListProgressEntry entry;

  const _ListProgressRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final score = entry.score;
    final bestPct = (score.bestAccuracy * 100).round();
    return Container(
      padding: EdgeInsets.all(context.s(12)),
      decoration: AppTheme.card(
        color: AppTheme.mint.withValues(alpha: 0.42),
        gradient: AppTheme.successGradient,
        radius: context.s(16),
        shadow: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Best $bestPct%',
                style: const TextStyle(
                  color: AppTheme.sage,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: context.s(7)),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score.bestAccuracy.clamp(0, 1),
              minHeight: context.s(8),
              color: AppTheme.sage,
              backgroundColor: AppTheme.surface.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(height: context.s(7)),
          Row(
            children: [
              Text(
                'Last ${score.lastCorrect}/${score.lastTotal}',
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${entry.wordCount} words - ${score.attempts} ${score.attempts == 1 ? 'try' : 'tries'}',
                style: const TextStyle(color: AppTheme.mute, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _MetricChip({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext c) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: c.s(150), maxWidth: c.s(190)),
      child: Container(
        padding: EdgeInsets.all(c.s(14)),
        decoration: AppTheme.card(
          color: color.withValues(alpha: 0.12),
          radius: c.s(16),
          shadow: false,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.mute,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
