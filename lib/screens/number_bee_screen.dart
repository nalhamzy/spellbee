import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/utils/number_words.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/paywall_screen.dart';
import 'package:spellbee/screens/test_screen.dart';

/// Number Bee: spelling meets counting. "Say the number" is always free;
/// Math Bee gives the free tier one round a day and Premium unlimited —
/// the same shape as the AI word-pack cap, so parents see one consistent
/// rule everywhere.
class NumberBeeScreen extends ConsumerStatefulWidget {
  const NumberBeeScreen({super.key});

  @override
  ConsumerState<NumberBeeScreen> createState() => _NumberBeeScreenState();
}

class _NumberBeeScreenState extends ConsumerState<NumberBeeScreen> {
  late NumberRange _range = NumberRange.forLevel(
    ref.read(selectedLevelProvider),
  );

  void _startNumbers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TestScreen(
          words: NumberBee.numberRound(_range),
          title: 'Say the number',
          kind: RoundKind.numbers,
        ),
      ),
    );
  }

  Future<void> _startMath() async {
    final premium = ref.read(isPremiumProvider);
    final used = ref.read(mathRoundsTodayProvider);
    if (!premium && used >= kFreeMathRoundsPerDay) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PaywallScreen(
            headline: 'Unlimited Math Bee rounds, every day.',
          ),
        ),
      );
      return;
    }
    if (!premium) {
      await ref.read(mathRoundsTodayProvider.notifier).increment();
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TestScreen(
          words: NumberBee.mathRound(_range),
          title: 'Math Bee',
          kind: RoundKind.math,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(isPremiumProvider);
    final used = ref.watch(mathRoundsTodayProvider);
    final mathLeft = (kFreeMathRoundsPerDay - used).clamp(0, 99);
    return Scaffold(
      appBar: AppBar(title: const Text('Number Bee')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
        child: SafeArea(
          child: ResponsiveContentBox(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                context.s(20),
                context.s(8),
                context.s(20),
                context.s(40),
              ),
              children: [
                _Hero(range: _range),
                SizedBox(height: context.s(18)),
                Text(
                  'How big?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: context.s(10)),
                Row(
                  children: [
                    for (final r in NumberRange.values) ...[
                      Expanded(
                        child: _RangeChip(
                          range: r,
                          selected: r == _range,
                          onTap: () => setState(() => _range = r),
                        ),
                      ),
                      if (r != NumberRange.values.last)
                        SizedBox(width: context.s(8)),
                    ],
                  ],
                ),
                SizedBox(height: context.s(20)),
                Text('Pick a game', style: Theme.of(context).textTheme.headlineSmall),
                SizedBox(height: context.s(10)),
                _GameCard(
                  icon: Icons.pin_rounded,
                  color: AppTheme.sky,
                  background: AppTheme.aqua,
                  gradient: AppTheme.voiceGradient,
                  title: 'Say the number',
                  subtitle:
                      'See the digits, hear the word, spell it. "38" becomes thirty-eight.',
                  badge: 'Free',
                  onTap: _startNumbers,
                ),
                SizedBox(height: context.s(12)),
                _GameCard(
                  icon: Icons.calculate_rounded,
                  color: AppTheme.violet,
                  background: AppTheme.lilac,
                  gradient: AppTheme.premiumGradient,
                  title: 'Math Bee',
                  subtitle:
                      'Hear a sum, work it out, then spell the answer as a word.',
                  badge: premium
                      ? 'Premium · unlimited'
                      : mathLeft > 0
                      ? '$mathLeft free round today'
                      : 'Premium',
                  locked: !premium && mathLeft == 0,
                  onTap: _startMath,
                ),
                SizedBox(height: context.s(18)),
                Container(
                  padding: EdgeInsets.all(context.s(14)),
                  decoration: AppTheme.card(
                    color: AppTheme.mint,
                    gradient: AppTheme.successGradient,
                    border: AppTheme.sage.withValues(alpha: 0.3),
                    shadow: false,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.school_rounded, color: AppTheme.sage),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Number words are the most-misspelled words in early grades — '
                          '"forty", "ninety" and "twelve" trip up almost everyone. '
                          'Every round here counts toward quests and honey.',
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
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

class _Hero extends StatelessWidget {
  final NumberRange range;
  const _Hero({required this.range});

  @override
  Widget build(BuildContext context) {
    final sample = range == NumberRange.little
        ? 17
        : range == NumberRange.big
        ? 64
        : 308;
    return Container(
      padding: EdgeInsets.all(context.s(18)),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(context.s(28)),
        border: Border.all(color: AppTheme.outline),
        boxShadow: AppTheme.liftedShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Spell the numbers',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Counting words, spelled right. ${range.description}.',
                  style: const TextStyle(color: AppTheme.mute, fontSize: 13),
                ),
              ],
            ),
          ),
          SizedBox(width: context.s(12)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.s(16),
              vertical: context.s(10),
            ),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(context.s(18)),
              border: Border.all(color: AppTheme.sky.withValues(alpha: 0.4)),
              boxShadow: AppTheme.tintedShadow(AppTheme.sky),
            ),
            child: Column(
              children: [
                Text(
                  '$sample',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: context.s(30),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  numberToWords(sample),
                  style: const TextStyle(
                    color: AppTheme.sky,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final NumberRange range;
  final bool selected;
  final VoidCallback onTap;
  const _RangeChip({
    required this.range,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.s(16)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(vertical: context.s(10)),
        decoration: BoxDecoration(
          color: selected ? AppTheme.ink : AppTheme.surface,
          borderRadius: BorderRadius.circular(context.s(16)),
          border: Border.all(
            color: selected ? AppTheme.ink : AppTheme.outline,
          ),
          boxShadow: selected ? AppTheme.softShadow : null,
        ),
        child: Column(
          children: [
            Text(
              range.label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.ink,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            Text(
              range.description,
              style: TextStyle(
                color: selected ? Colors.white70 : AppTheme.mute,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final Gradient gradient;
  final String title;
  final String subtitle;
  final String badge;
  final bool locked;
  final VoidCallback onTap;

  const _GameCard({
    required this.icon,
    required this.color,
    required this.background,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.s(24)),
      child: Container(
        padding: EdgeInsets.all(context.s(16)),
        decoration: AppTheme.card(
          color: background,
          gradient: gradient,
          radius: context.s(24),
        ),
        child: Row(
          children: [
            Container(
              width: context.s(56),
              height: context.s(56),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(context.s(18)),
              ),
              child: Icon(
                locked ? Icons.lock_rounded : icon,
                color: color,
                size: context.s(30),
              ),
            ),
            SizedBox(width: context.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.mute,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_fill_rounded, color: color, size: 30),
          ],
        ),
      ),
    );
  }
}
