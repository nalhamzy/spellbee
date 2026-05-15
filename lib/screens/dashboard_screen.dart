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

    return SafeArea(
      child: ResponsiveContentBox(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.s(20),
            context.s(16),
            context.s(20),
            context.s(120),
          ),
          children: [
            _Header(streak: stats.dailyStreak),
            SizedBox(height: context.s(16)),
            _StartTrailButton(
              level: level,
              onPressed: () => _start(context, level),
            ),
            SizedBox(height: context.s(14)),
            _HeroPanel(
              word: dailyWord,
              done: dailyDone,
              onStart: dailyDone
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TestScreen(
                            words: [dailyWord],
                            title: 'Daily word',
                            onComplete: () => ref
                                .read(playerStatsProvider.notifier)
                                .recordDailyWordComplete(),
                          ),
                        ),
                      );
                    },
            ),
            SizedBox(height: context.s(22)),
            _SectionTitle(
              title: 'Practice level',
              subtitle: kLevelLabels[level] ?? 'Level $level',
            ),
            SizedBox(height: context.s(10)),
            _levelPicker(context, ref, level),
            SizedBox(height: context.s(18)),
            _SimpleChoices(ref: ref),
            if (!ref.watch(isPremiumProvider)) ...[
              SizedBox(height: context.s(22)),
              _PremiumBanner(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                },
              ),
            ],
            SizedBox(height: context.s(22)),
            _SectionTitle(title: 'Parent view', subtitle: 'Progress'),
            SizedBox(height: context.s(10)),
            _StatsRail(
              tests: stats.totalTests,
              accuracy: accPct,
              bestStreak: stats.bestStreak,
            ),
          ],
        ),
      ),
    );
  }

  static void _start(BuildContext context, int level) {
    final pool = kWordsCatalog[level] ?? [];
    if (pool.isEmpty) return;
    final sampled = [...pool]..shuffle();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TestScreen(
          words: sampled.take(10).toList(),
          title: 'Level $level trail',
        ),
      ),
    );
  }

  String _chipLabel(int lvl) {
    switch (lvl) {
      case 1:
        return 'K-1';
      case 2:
        return 'Grade 2';
      case 3:
        return 'Grade 3';
      case 4:
        return 'Grade 4';
      case 5:
        return 'Grade 5';
      case 6:
        return 'Middle';
      case 7:
        return 'Regional';
      case 8:
        return 'Champion';
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
                  padding: EdgeInsets.symmetric(horizontal: c.s(15)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: lvl == level ? AppTheme.ink : AppTheme.surface,
                    border: Border.all(
                      color: lvl == level ? AppTheme.ink : AppTheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: lvl == level ? AppTheme.softShadow : null,
                  ),
                  child: Text(
                    _chipLabel(lvl),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: lvl == level ? Colors.white : AppTheme.mute,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int streak;
  const _Header({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SpellBee',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'A cozy spelling room for brave little readers.',
                style: TextStyle(color: AppTheme.mute, fontSize: 13),
              ),
            ],
          ),
        ),
        if (streak > 0) _StreakBadge(streak: streak),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final Word word;
  final bool done;
  final VoidCallback? onStart;

  const _HeroPanel({
    required this.word,
    required this.done,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.s(18)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.surface2, AppTheme.aqua],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.s(28)),
        border: Border.all(color: AppTheme.outline),
        boxShadow: AppTheme.softShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showMascot = constraints.maxWidth >= 360;
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabelPill(
                      icon: done
                          ? Icons.check_circle_rounded
                          : Icons.wb_sunny_rounded,
                      label: done ? 'Daily word done' : 'Daily word',
                      color: done ? AppTheme.sage : AppTheme.honeyDark,
                    ),
                    SizedBox(height: context.s(12)),
                    Text(
                      word.text.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: context.s(30),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: context.s(6)),
                    Text(
                      word.definition,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.mute,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: context.s(14)),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: done ? AppTheme.sage : AppTheme.ink,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: context.s(16),
                          vertical: context.s(12),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.s(16)),
                        ),
                      ),
                      onPressed: onStart,
                      icon: Icon(
                        done ? Icons.done_rounded : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        done ? 'Come back later' : 'Spell it now',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
              if (showMascot) ...[
                SizedBox(width: context.s(10)),
                SizedBox(
                  width: context.s(108),
                  height: context.s(118),
                  child: const _BeeMascot(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BeeMascot extends StatelessWidget {
  const _BeeMascot();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 10,
          left: 3,
          child: _wing(AppTheme.surface.withValues(alpha: 0.82)),
        ),
        Positioned(
          top: 10,
          right: 3,
          child: _wing(AppTheme.surface.withValues(alpha: 0.82)),
        ),
        Container(
          width: 76,
          height: 86,
          decoration: BoxDecoration(
            color: AppTheme.honey,
            borderRadius: BorderRadius.circular(38),
            border: Border.all(color: AppTheme.ink, width: 3),
          ),
        ),
        Positioned(
          top: 34,
          child: Container(width: 70, height: 8, color: AppTheme.ink),
        ),
        Positioned(
          top: 56,
          child: Container(width: 62, height: 8, color: AppTheme.ink),
        ),
        const Positioned(top: 22, left: 36, child: _Eye()),
        const Positioned(top: 22, right: 36, child: _Eye()),
      ],
    );
  }

  Widget _wing(Color color) {
    return Container(
      width: 42,
      height: 54,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.35)),
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: AppTheme.ink,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _StatsRail extends StatelessWidget {
  final int tests;
  final int accuracy;
  final int bestStreak;

  const _StatsRail({
    required this.tests,
    required this.accuracy,
    required this.bestStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MiniStat(label: 'Tests', value: '$tests', color: AppTheme.sky),
        SizedBox(width: context.s(9)),
        _MiniStat(label: 'Accuracy', value: '$accuracy%', color: AppTheme.sage),
        SizedBox(width: context.s(9)),
        _MiniStat(
          label: 'Best run',
          value: '$bestStreak',
          color: AppTheme.coral,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.s(12)),
        decoration: AppTheme.card(color: color.withValues(alpha: 0.15)),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: context.s(22),
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.mute,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        Flexible(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppTheme.mute,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _StartTrailButton extends StatelessWidget {
  final int level;
  final VoidCallback onPressed;

  const _StartTrailButton({required this.level, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: context.s(58),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.honey,
          foregroundColor: AppTheme.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.s(20)),
          ),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 30),
        label: Text(
          'Start level $level trail',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _SimpleChoices extends StatelessWidget {
  final WidgetRef ref;
  const _SimpleChoices({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WideActionCard(
          icon: Icons.auto_awesome_rounded,
          color: AppTheme.violet,
          background: AppTheme.lilac,
          title: 'Make a word pack',
          subtitle: 'Pick a theme and practice a fresh set.',
          onTap: () => ref.read(tabProvider.notifier).go(AppTab.practice),
        ),
        SizedBox(height: context.s(10)),
        _WideActionCard(
          icon: Icons.library_books_rounded,
          color: AppTheme.sky,
          background: AppTheme.aqua,
          title: 'Practice my list',
          subtitle: 'Use spelling words from school or home.',
          onTap: () => ref.read(tabProvider.notifier).go(AppTab.lists),
        ),
      ],
    );
  }
}

class _WideActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WideActionCard({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.s(22)),
      child: Container(
        padding: EdgeInsets.all(context.s(15)),
        decoration: AppTheme.card(color: background, radius: context.s(22)),
        child: Row(
          children: [
            Container(
              width: context.s(48),
              height: context.s(48),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(context.s(16)),
              ),
              child: Icon(icon, color: color, size: context.s(26)),
            ),
            SizedBox(width: context.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: context.s(2)),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.mute, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.s(24)),
      child: Container(
        padding: EdgeInsets.all(context.s(16)),
        decoration: AppTheme.card(color: AppTheme.lilac, radius: context.s(24)),
        child: Row(
          children: [
            Container(
              width: context.s(46),
              height: context.s(46),
              decoration: const BoxDecoration(
                color: AppTheme.violet,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
              ),
            ),
            SizedBox(width: context.s(12)),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlock the studio voice',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Unlimited word packs, no ads, better pronunciation.',
                    style: TextStyle(color: AppTheme.mute, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.violet),
          ],
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.rose,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.coral.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: AppTheme.coral,
            size: 17,
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _LabelPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
