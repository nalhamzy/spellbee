import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/word.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/paywall_screen.dart';
import 'package:spellbee/screens/test_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(playerStatsProvider);
    final level = ref.watch(selectedLevelProvider);
    final accPct = (stats.accuracy * 100).round();

    final dailyWord = ref.watch(dailyWordProvider);
    final dailyDone = ref.watch(dailyWordDoneProvider);
    final dailyStreak = stats.dailyStreak;

    return SafeArea(
      child: ResponsiveContentBox(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              context.s(20), context.s(16), context.s(20), context.s(120)),
          children: [
            Row(
              children: [
                Text('🐝',
                    style: TextStyle(fontSize: context.s(36))),
                SizedBox(width: context.s(10)),
                Text('SpellBee',
                    style: TextStyle(
                      fontSize: context.s(30),
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    )),
                if (dailyStreak > 0) ...[
                  const Spacer(),
                  _StreakBadge(streak: dailyStreak),
                ],
              ],
            ),
            SizedBox(height: context.s(18)),
            _DailyWordCard(word: dailyWord, done: dailyDone),
            SizedBox(height: context.s(16)),
            _statsRow(context, stats.totalTests, accPct, stats.bestStreak),
            SizedBox(height: context.s(22)),
            Text('Start a quick bee  •  Pick your grade',
                style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: context.s(10)),
            _levelPicker(context, ref, level),
            SizedBox(height: context.s(12)),
            _primaryStart(context, ref, level),
            SizedBox(height: context.s(22)),
            Text('Or jump into',
                style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: context.s(10)),
            _quickCards(context, ref),
            SizedBox(height: context.s(22)),
            if (!ref.watch(isPremiumProvider)) _premiumBanner(context),
          ],
        ),
      ),
    );
  }

  Widget _statsRow(BuildContext c, int tests, int accPct, int best) {
    Widget cell(String label, String value, {Color? color}) {
      return Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: c.s(12)),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border.all(color: AppTheme.outline),
            borderRadius: BorderRadius.circular(c.s(14)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                    fontSize: c.s(22),
                    fontWeight: FontWeight.w900,
                    color: color ?? AppTheme.honeyDark,
                  )),
              Text(label,
                  style: const TextStyle(
                    color: AppTheme.mute,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        cell('Tests', '$tests'),
        SizedBox(width: c.s(8)),
        cell('Accuracy', '$accPct%', color: AppTheme.sage),
        SizedBox(width: c.s(8)),
        cell('Best streak', '$best', color: AppTheme.coral),
      ],
    );
  }

  String _chipLabel(int lvl) {
    switch (lvl) {
      case 1:
        return 'Grade K-1';
      case 2:
        return 'Grade 2';
      case 3:
        return 'Grade 3';
      case 4:
        return 'Grade 4';
      case 5:
        return 'Grade 5';
      case 6:
        return 'Middle School';
      case 7:
        return 'Regional Bee';
      case 8:
        return 'Championship';
      default:
        return 'Level $lvl';
    }
  }

  Widget _levelPicker(BuildContext c, WidgetRef ref, int level) {
    return SizedBox(
      height: c.s(44),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final lvl in kLevelLabels.keys)
            Padding(
              padding: EdgeInsets.only(right: c.s(8)),
              child: GestureDetector(
                onTap: () => ref.read(selectedLevelProvider.notifier).set(lvl),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      EdgeInsets.symmetric(horizontal: c.s(14), vertical: 0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: lvl == level ? AppTheme.honey : AppTheme.surface,
                    border: Border.all(
                      color: lvl == level ? AppTheme.honey : AppTheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _chipLabel(lvl),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: lvl == level ? AppTheme.ink : AppTheme.mute,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _primaryStart(BuildContext c, WidgetRef ref, int level) {
    return SizedBox(
      width: double.infinity,
      height: c.s(56),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.honey,
          foregroundColor: AppTheme.ink,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(c.s(16))),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 28),
        label: Text('Start  •  ${kLevelLabels[level]}',
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        onPressed: () {
          final pool = kWordsCatalog[level] ?? [];
          if (pool.isEmpty) return;
          final sampled = [...pool]..shuffle();
          Navigator.of(c).push(MaterialPageRoute(
            builder: (_) => TestScreen(
              words: sampled.take(10).toList(),
              title: 'Level $level test',
            ),
          ));
        },
      ),
    );
  }

  Widget _quickCards(BuildContext c, WidgetRef ref) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: c.s(10),
      mainAxisSpacing: c.s(10),
      childAspectRatio: 1.35,
      children: [
        _QuickCard(
          icon: Icons.auto_awesome_rounded,
          color: AppTheme.violet,
          title: 'AI word pack',
          subtitle: 'Thematic 10-word drill',
          onTap: () => ref.read(tabProvider.notifier).go(AppTab.practice),
        ),
        _QuickCard(
          icon: Icons.library_books_rounded,
          color: AppTheme.sky,
          title: 'My lists',
          subtitle: 'Parent-made word sets',
          onTap: () => ref.read(tabProvider.notifier).go(AppTab.lists),
        ),
        _QuickCard(
          icon: Icons.timeline_rounded,
          color: AppTheme.sage,
          title: 'Stats',
          subtitle: 'Streaks & accuracy',
          onTap: () => ref.read(tabProvider.notifier).go(AppTab.stats),
        ),
        _QuickCard(
          icon: Icons.settings_rounded,
          color: AppTheme.coral,
          title: 'Settings',
          subtitle: 'Pin + voice + data',
          onTap: () => ref.read(tabProvider.notifier).go(AppTab.settings),
        ),
      ],
    );
  }

  Widget _premiumBanner(BuildContext c) {
    return InkWell(
      onTap: () => Navigator.of(c)
          .push(MaterialPageRoute(builder: (_) => const PaywallScreen())),
      borderRadius: BorderRadius.circular(c.s(20)),
      child: Container(
        padding: EdgeInsets.all(c.s(16)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.violet, AppTheme.violet.withValues(alpha: 0.75)],
          ),
          borderRadius: BorderRadius.circular(c.s(20)),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 30),
            SizedBox(width: c.s(12)),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Go Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      )),
                  SizedBox(height: 2),
                  Text('Unlimited AI word packs, no ads, unlimited lists.',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ── Daily Word Card ──────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.honey,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.honeyDark.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text('$streak day${streak == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppTheme.ink)),
        ],
      ),
    );
  }
}

class _DailyWordCard extends ConsumerWidget {
  final Word word;
  final bool done;
  const _DailyWordCard({required this.word, required this.done});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(context.s(16)),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(context.s(18)),
        border: Border.all(
          color: done ? AppTheme.sage : AppTheme.honeyDark,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (done ? AppTheme.sage : AppTheme.honey)
                .withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.wb_sunny_rounded,
                color: done ? AppTheme.sage : AppTheme.honeyDark,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                done ? 'Word of the Day — done!' : 'Word of the Day',
                style: TextStyle(
                  color: done ? AppTheme.sage : AppTheme.honeyDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: context.s(8)),
          Text(
            word.text.toUpperCase(),
            style: TextStyle(
              fontSize: context.s(26),
              fontWeight: FontWeight.w900,
              color: AppTheme.ink,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: context.s(4)),
          Text(
            word.definition,
            style: const TextStyle(color: AppTheme.mute, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: context.s(12)),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    done ? AppTheme.sage : AppTheme.honey,
                foregroundColor: done ? Colors.white : AppTheme.ink,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(context.s(12))),
                padding:
                    EdgeInsets.symmetric(vertical: context.s(10)),
              ),
              onPressed: done
                  ? null
                  : () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TestScreen(
                          words: [word],
                          title: 'Word of the Day',
                          onComplete: () => ref
                              .read(playerStatsProvider.notifier)
                              .recordDailyWordComplete(),
                        ),
                      ));
                    },
              child: Text(
                done ? 'Come back tomorrow' : 'Spell it now',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.outline),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppTheme.ink)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    color: AppTheme.mute, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
