import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/data/words_catalog.dart';
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
              ],
            ),
            SizedBox(height: context.s(18)),
            _statsRow(context, stats.totalTests, accPct, stats.bestStreak),
            SizedBox(height: context.s(22)),
            Text('Start a quick bee',
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
                    'Lv $lvl  •  ${kLevelLabels[lvl]}',
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
        label: const Text('Start a 10-word test',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
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
                  Text('Unlimited AI word packs, no ads, parent PDF reports.',
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
