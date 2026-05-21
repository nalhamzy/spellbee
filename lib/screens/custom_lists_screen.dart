import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/models/player_stats.dart';
import 'package:spellbee/core/models/word_list.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/paywall_screen.dart';
import 'package:spellbee/screens/test_screen.dart';
import 'package:spellbee/screens/word_list_editor_screen.dart';

class CustomListsScreen extends ConsumerWidget {
  const CustomListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(wordListsProvider);
    final listScores = ref.watch(playerStatsProvider).listScores;
    final isPremium = ref.watch(isPremiumProvider);
    final freeCap = 3;

    return SafeArea(
      child: ResponsiveContentBox(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.s(20),
                context.s(16),
                context.s(20),
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'My word lists',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  SizedBox(width: context.s(8)),
                  IconButton.filled(
                    onPressed: () {
                      if (!isPremium && lists.length >= freeCap) {
                        _showUpsell(context);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WordListEditorScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 22),
                    tooltip: 'New list',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.honey,
                      foregroundColor: AppTheme.ink,
                      fixedSize: Size(context.s(48), context.s(48)),
                    ),
                  ),
                ],
              ),
            ),
            if (!isPremium)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.s(20),
                  context.s(8),
                  context.s(20),
                  0,
                ),
                child: Text(
                  'Free tier: up to $freeCap lists. Premium = unlimited.',
                  style: const TextStyle(color: AppTheme.mute, fontSize: 12),
                ),
              ),
            SizedBox(height: context.s(10)),
            Expanded(
              child: lists.isEmpty
                  ? _empty(context)
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        context.s(20),
                        0,
                        context.s(20),
                        context.s(120),
                      ),
                      itemCount: lists.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: context.s(10)),
                      itemBuilder: (_, i) => _listCard(
                        context,
                        ref,
                        lists[i],
                        listScores[lists[i].id],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext c) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(c.s(40)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hive_rounded, size: c.s(60), color: AppTheme.honeyDark),
            SizedBox(height: c.s(14)),
            Text(
              'No custom lists yet',
              style: Theme.of(c).textTheme.headlineSmall,
            ),
            SizedBox(height: c.s(6)),
            const Text(
              'Tap "New" to create a spelling list for your child. Great for '
              'this week\'s school words or a friend\'s bee.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.mute),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listCard(
    BuildContext c,
    WidgetRef ref,
    WordList list,
    ListScoreSummary? score,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(c.s(16)),
      onTap: () => Navigator.of(c).push(
        MaterialPageRoute(builder: (_) => WordListEditorScreen(existing: list)),
      ),
      child: Container(
        padding: EdgeInsets.all(c.s(14)),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.outline),
          borderRadius: BorderRadius.circular(c.s(16)),
        ),
        child: Row(
          children: [
            Container(
              width: c.s(48),
              height: c.s(48),
              decoration: BoxDecoration(
                color: AppTheme.honey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(c.s(12)),
              ),
              child: const Icon(
                Icons.format_list_bulleted_rounded,
                color: AppTheme.honeyDark,
              ),
            ),
            SizedBox(width: c.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.ink,
                    ),
                  ),
                  Text(
                    '${list.size} words',
                    style: const TextStyle(color: AppTheme.mute, fontSize: 12),
                  ),
                  SizedBox(height: c.s(8)),
                  if (score == null || score.lastTotal == 0)
                    const Text(
                      'No score yet',
                      style: TextStyle(
                        color: AppTheme.mute,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Wrap(
                      spacing: c.s(6),
                      runSpacing: c.s(6),
                      children: [
                        _ScorePill(
                          icon: Icons.history_rounded,
                          label: 'Last ${score.lastCorrect}/${score.lastTotal}',
                        ),
                        _ScorePill(
                          icon: Icons.emoji_events_rounded,
                          label: 'Best ${(score.bestAccuracy * 100).round()}%',
                        ),
                        _ScorePill(
                          icon: Icons.repeat_rounded,
                          label:
                              '${score.attempts} ${score.attempts == 1 ? 'try' : 'tries'}',
                        ),
                      ],
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Practice',
              icon: const Icon(Icons.play_arrow_rounded),
              color: AppTheme.ink,
              onPressed: list.words.isEmpty
                  ? null
                  : () => Navigator.of(c).push(
                      MaterialPageRoute(
                        builder: (_) => TestScreen(
                          words: list.words,
                          title: list.name,
                          sourceListId: list.id,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpsell(BuildContext c) {
    showDialog(
      context: c,
      builder: (ctx) => AlertDialog(
        title: const Text('Free list limit'),
        content: const Text(
          'You can create up to 3 custom lists on the free tier. Upgrade to '
          'Premium for unlimited parent-curated lists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.of(
                c,
              ).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
            },
            child: const Text('See Premium'),
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ScorePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.mint.withValues(alpha: 0.45),
        border: Border.all(color: AppTheme.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.sage),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
