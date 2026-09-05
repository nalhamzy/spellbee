import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/models/word.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/number_bee_screen.dart';
import 'package:spellbee/screens/paywall_screen.dart';
import 'package:spellbee/screens/test_screen.dart';
import 'package:spellbee/widgets/progress_cards.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(playerStatsProvider);
    final level = ref.watch(selectedLevelProvider);
    final accPct = (stats.accuracy * 100).round();
    final dailyWord = ref.watch(dailyWordProvider);
    final dailyDone = ref.watch(dailyWordDoneProvider);
    final progression = ref.watch(progressionProvider);
    final quests = ref.watch(dailyQuestsProvider);
    final fact = ref.watch(dailyFactProvider);

    return SafeArea(
      child: ResponsiveContentBox(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.s(20)),
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, context.s(16), 0, context.s(120)),
            children: [
              _Header(streak: stats.dailyStreak),
              SizedBox(height: context.s(14)),
              RankCard(progression: progression, compact: true),
              SizedBox(height: context.s(14)),
              _StartTrialButton(
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
                              kind: RoundKind.daily,
                              onComplete: () => ref
                                  .read(playerStatsProvider.notifier)
                                  .recordDailyWordComplete(),
                            ),
                          ),
                        );
                      },
              ),
              SizedBox(height: context.s(14)),
              QuestsCard(quests: quests, progression: progression),
              SizedBox(height: context.s(22)),
              _SectionTitle(
                title: 'Practice level',
                subtitle: kLevelLabels[level] ?? 'Level $level',
              ),
              SizedBox(height: context.s(10)),
              _levelPicker(context, ref, level),
              SizedBox(height: context.s(22)),
              const _SectionTitle(title: 'Play', subtitle: 'Pick a game'),
              SizedBox(height: context.s(10)),
              _ActivityGrid(
                onWordPacks: () =>
                    ref.read(tabProvider.notifier).go(AppTab.practice),
                onLists: () => ref.read(tabProvider.notifier).go(AppTab.lists),
                onNumberBee: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NumberBeeScreen()),
                ),
                onTiles: () => _start(
                  context,
                  level,
                  mode: InputMode.tiles,
                  title: 'Tile builder',
                  count: 8,
                ),
              ),
              SizedBox(height: context.s(14)),
              _FactCard(
                fact: fact,
                onHear: () async {
                  final tts = ref.read(ttsServiceProvider);
                  await tts.stop();
                  await tts.speakText(
                    fact,
                    premium: ref.read(isPremiumProvider),
                  );
                  await ref.read(progressionProvider.notifier).recordFactRead();
                },
              ),
              if (!ref.watch(isPremiumProvider)) ...[
                SizedBox(height: context.s(22)),
                _PremiumBanner(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  ),
                ),
              ],
              SizedBox(height: context.s(22)),
              const _SectionTitle(title: 'Parent view', subtitle: 'Progress'),
              SizedBox(height: context.s(10)),
              _StatsRail(
                tests: stats.totalTests,
                accuracy: accPct,
                bestStreak: stats.bestStreak,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _start(
    BuildContext context,
    int level, {
    InputMode mode = InputMode.keyboard,
    String? title,
    int count = 10,
  }) {
    final pool = kWordsCatalog[level] ?? [];
    if (pool.isEmpty) return;
    final sampled = [...pool]..shuffle();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TestScreen(
          words: sampled.take(count).toList(),
          title: title ?? 'Level $level trial',
          level: level,
          initialMode: mode,
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
    final screenshotMode = Uri.base.queryParameters['screenshot'] == '1';
    final levels = screenshotMode ? const [1, 2, 3, 4] : kLevelLabels.keys;

    Widget chip(int lvl) {
      return GestureDetector(
        onTap: () => ref.read(selectedLevelProvider.notifier).set(lvl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: c.s(15), vertical: c.s(10)),
          constraints: BoxConstraints(minHeight: c.s(44)),
          decoration: BoxDecoration(
            color: lvl == level ? AppTheme.ink : AppTheme.surface,
            border: Border.all(
              color: lvl == level ? AppTheme.ink : AppTheme.outline,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: lvl == level ? AppTheme.softShadow : null,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              _chipLabel(lvl),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: lvl == level ? Colors.white : AppTheme.mute,
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: c.s(8),
      runSpacing: c.s(8),
      children: [for (final lvl in levels) chip(lvl)],
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
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(context.s(28)),
        border: Border.all(color: AppTheme.outline),
        boxShadow: AppTheme.liftedShadow,
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
                        done ? 'Come back tomorrow' : 'Spell it now',
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

class _StartTrialButton extends StatelessWidget {
  final int level;
  final VoidCallback onPressed;

  const _StartTrialButton({required this.level, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: context.s(58),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(context.s(20)),
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppTheme.ctaGradient,
              borderRadius: BorderRadius.circular(context.s(20)),
              border: Border.all(
                color: AppTheme.honeyDark.withValues(alpha: 0.36),
              ),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 30,
                  color: AppTheme.ink,
                ),
                SizedBox(width: context.s(6)),
                Flexible(
                  child: Text(
                    'Start level $level trial',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 2×2 game grid from the design references: one tile per activity,
/// each in its own pastel so a pre-reader can find it by colour.
class _ActivityGrid extends StatelessWidget {
  final VoidCallback onWordPacks;
  final VoidCallback onLists;
  final VoidCallback onNumberBee;
  final VoidCallback onTiles;

  const _ActivityGrid({
    required this.onWordPacks,
    required this.onLists,
    required this.onNumberBee,
    required this.onTiles,
  });

  @override
  Widget build(BuildContext context) {
    final gap = context.s(10);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActivityTile(
                icon: Icons.pin_rounded,
                color: AppTheme.sage,
                background: AppTheme.mint,
                gradient: AppTheme.successGradient,
                title: 'Number Bee',
                subtitle: 'Spell numbers & sums',
                badge: 'NEW',
                onTap: onNumberBee,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _ActivityTile(
                icon: Icons.grid_view_rounded,
                color: AppTheme.coral,
                background: AppTheme.rose,
                gradient: AppTheme.errorGradient,
                title: 'Tile builder',
                subtitle: 'Tap letters into words',
                badge: 'NEW',
                onTap: onTiles,
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _ActivityTile(
                icon: Icons.auto_awesome_rounded,
                color: AppTheme.violet,
                background: AppTheme.lilac,
                gradient: AppTheme.premiumGradient,
                title: 'Word packs',
                subtitle: 'Pick a theme, get 10',
                onTap: onWordPacks,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _ActivityTile(
                icon: Icons.library_books_rounded,
                color: AppTheme.sky,
                background: AppTheme.aqua,
                gradient: AppTheme.voiceGradient,
                title: 'My lists',
                subtitle: 'Words from school',
                onTap: onLists,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final Gradient gradient;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.icon,
    required this.color,
    required this.background,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.s(22)),
      child: Container(
        padding: EdgeInsets.all(context.s(14)),
        decoration: AppTheme.card(
          color: background,
          gradient: gradient,
          radius: context.s(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: context.s(46),
                  height: context.s(46),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(context.s(15)),
                  ),
                  child: Icon(icon, color: color, size: context.s(26)),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: context.s(12)),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: context.s(2)),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.mute, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Bee fact of the day" — the pronouncer reads it out on tap.
class _FactCard extends StatelessWidget {
  final String fact;
  final VoidCallback onHear;
  const _FactCard({required this.fact, required this.onHear});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onHear,
      borderRadius: BorderRadius.circular(context.s(22)),
      child: Container(
        padding: EdgeInsets.all(context.s(15)),
        decoration: AppTheme.card(
          color: AppTheme.peach,
          gradient: AppTheme.ctaGradient,
          border: AppTheme.honeyDark.withValues(alpha: 0.3),
          radius: context.s(22),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: context.s(44),
              height: context.s(44),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(context.s(14)),
              ),
              child: const Icon(
                Icons.lightbulb_rounded,
                color: AppTheme.honeyDark,
              ),
            ),
            SizedBox(width: context.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bee fact of the day',
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.volume_up_rounded,
                        color: AppTheme.honeyDark,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fact,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to hear it',
                    style: TextStyle(
                      color: AppTheme.mute,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
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
        decoration: AppTheme.card(
          color: AppTheme.lilac,
          gradient: AppTheme.premiumGradient,
          radius: context.s(24),
        ),
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
                    'Go Premium',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Unlimited word packs, Math Bee rounds, lists and the studio voice.',
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
