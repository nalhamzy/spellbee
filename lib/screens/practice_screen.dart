import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/paywall_screen.dart';
import 'package:spellbee/screens/test_screen.dart';

/// AI word-pack generator. Free users get 1 generation/day; rewarded ad
/// grants +5 on demand. Premium = unlimited.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  final _themeCtrl = TextEditingController();
  bool _generating = false;

  @override
  void dispose() {
    _themeCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_generating) return;
    final isPremium = ref.read(isPremiumProvider);
    final credits = ref.read(aiCreditsProvider);
    if (!isPremium && credits <= 0) {
      _offerRewardedAd();
      return;
    }

    setState(() => _generating = true);
    final level = ref.read(selectedLevelProvider);
    final theme = _themeCtrl.text.trim();
    try {
      final words = await ref
          .read(aiGeneratorProvider)
          .generate(count: 10, level: level, theme: theme);
      if (!isPremium) await ref.read(aiCreditsProvider.notifier).consume();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TestScreen(
            words: words,
            title: theme.isEmpty ? 'Practice level $level' : theme,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _offerRewardedAd() {
    final ads = ref.read(adServiceProvider);
    if (!ads.hasRewardedAd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No credits left today. Come back tomorrow or unlock premium.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Out of word packs'),
        content: const Text(
          'Watch a short ad to unlock 5 more packs today, or go Premium for unlimited.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.honey),
            onPressed: () {
              Navigator.pop(ctx);
              ads.showRewardedAd(
                onRewarded: () async {
                  await ref.read(aiCreditsProvider.notifier).grant(5);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('+5 word packs unlocked')),
                    );
                  }
                },
                onUnavailable: () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ad not ready yet.')),
                    );
                  }
                },
              );
            },
            child: const Text('Watch ad'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(selectedLevelProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final credits = ref.watch(aiCreditsProvider);

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
            _Header(level: level),
            SizedBox(height: context.s(16)),
            _LabPanel(
              controller: _themeCtrl,
              generating: _generating,
              isPremium: isPremium,
              credits: credits,
              onGenerate: _generate,
              onPick: (value) {
                _themeCtrl.text = value;
                _themeCtrl.selection = TextSelection.collapsed(
                  offset: value.length,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int level;
  const _Header({required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: context.s(54),
          height: context.s(54),
          decoration: const BoxDecoration(
            color: AppTheme.lilac,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.violet),
        ),
        SizedBox(width: context.s(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Word Lab',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              Text(
                'Level $level - ${kLevelLabels[level]}',
                style: const TextStyle(color: AppTheme.mute, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabPanel extends StatelessWidget {
  final TextEditingController controller;
  final bool generating;
  final bool isPremium;
  final int credits;
  final VoidCallback onGenerate;
  final ValueChanged<String> onPick;

  const _LabPanel({
    required this.controller,
    required this.generating,
    required this.isPremium,
    required this.credits,
    required this.onGenerate,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.s(18)),
      decoration: AppTheme.card(color: AppTheme.surface, radius: context.s(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(context.s(16)),
            decoration: BoxDecoration(
              color: AppTheme.aqua,
              borderRadius: BorderRadius.circular(context.s(22)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pick a fun word pack',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap one choice. SpellBee makes 10 words.',
                        style: TextStyle(color: AppTheme.mute, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: context.s(54),
                  height: context.s(54),
                  decoration: const BoxDecoration(
                    color: AppTheme.honey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school_rounded, color: AppTheme.ink),
                ),
              ],
            ),
          ),
          SizedBox(height: context.s(12)),
          _ThemeChips(onPick: onPick),
          SizedBox(height: context.s(10)),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.edit_note_rounded,
                color: AppTheme.violet,
              ),
              title: const Text(
                'Parent custom theme',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: const Text(
                'Optional',
                style: TextStyle(color: AppTheme.mute, fontSize: 12),
              ),
              children: [
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'space, dinosaurs, cooking, ocean...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.s(16)),
          _CreditsCard(isPremium: isPremium, credits: credits),
          if (!isPremium) ...[
            SizedBox(height: context.s(10)),
            _UpgradeReminder(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PaywallScreen())),
            ),
          ],
          SizedBox(height: context.s(14)),
          SizedBox(
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
              onPressed: generating ? null : onGenerate,
              icon: generating
                  ? SizedBox(
                      width: context.s(18),
                      height: context.s(18),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.ink,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                generating ? 'Building pack...' : 'Make 10 words',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeReminder extends StatelessWidget {
  final VoidCallback onTap;
  const _UpgradeReminder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.s(18)),
      child: Container(
        padding: EdgeInsets.all(context.s(13)),
        decoration: AppTheme.card(
          color: AppTheme.lilac,
          border: AppTheme.violet.withValues(alpha: 0.32),
          shadow: false,
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: AppTheme.violet),
            SizedBox(width: context.s(8)),
            const Expanded(
              child: Text(
                'Premium unlocks unlimited themed lessons and the studio voice.',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.violet),
          ],
        ),
      ),
    );
  }
}

class _ThemeChips extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _ThemeChips({required this.onPick});

  @override
  Widget build(BuildContext context) {
    const suggestions = ['animals', 'space', 'sports', 'dinosaurs'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in suggestions)
          ActionChip(
            label: Text(s),
            avatar: const Icon(Icons.star_rounded, size: 16),
            backgroundColor: AppTheme.surface2,
            side: const BorderSide(color: AppTheme.outline),
            onPressed: () => onPick(s),
          ),
      ],
    );
  }
}

class _CreditsCard extends StatelessWidget {
  final bool isPremium;
  final int credits;
  const _CreditsCard({required this.isPremium, required this.credits});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.s(13)),
      decoration: AppTheme.card(
        color: isPremium ? AppTheme.lilac : AppTheme.peach,
        shadow: false,
      ),
      child: Row(
        children: [
          Icon(
            isPremium ? Icons.workspace_premium_rounded : Icons.bolt_rounded,
            color: isPremium ? AppTheme.violet : AppTheme.honeyDark,
          ),
          SizedBox(width: context.s(8)),
          Expanded(
            child: Text(
              isPremium
                  ? 'Premium: unlimited word packs.'
                  : 'Free tier: $credits pack(s) left today.',
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
