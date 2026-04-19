import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
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
      final words = await ref.read(aiGeneratorProvider).generate(
            count: 10,
            level: level,
            theme: theme,
          );
      if (!isPremium) await ref.read(aiCreditsProvider.notifier).consume();
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TestScreen(
          words: words,
          title: theme.isEmpty
              ? 'Practice · Level $level'
              : 'Practice · $theme',
        ),
      ));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _offerRewardedAd() {
    final ads = ref.read(adServiceProvider);
    if (!ads.hasRewardedAd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No credits left today. Come back tomorrow or unlock premium.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Out of AI credits'),
        content: const Text(
            'Watch a short ad to unlock 5 more word packs today, or go Premium for unlimited.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.honey),
            onPressed: () {
              Navigator.pop(ctx);
              ads.showRewardedAd(
                onRewarded: () async {
                  await ref.read(aiCreditsProvider.notifier).grant(5);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('+5 word packs unlocked!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                onUnavailable: () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ad not ready. Try again in a moment.'),
                        duration: Duration(seconds: 2),
                      ),
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
              context.s(20), context.s(16), context.s(20), context.s(120)),
          children: [
            Text('AI word pack',
                style: Theme.of(context).textTheme.headlineLarge),
            SizedBox(height: context.s(6)),
            Text(
              'Give us a theme (or leave it blank) and we\'ll pick 10 words '
              'at level $level · ${kLevelLabels[level]}.',
              style: const TextStyle(color: AppTheme.mute, fontSize: 14),
            ),
            SizedBox(height: context.s(18)),
            TextField(
              controller: _themeCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. space, dinosaurs, cooking',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.s(14)),
                  borderSide: const BorderSide(color: AppTheme.outline),
                ),
              ),
            ),
            SizedBox(height: context.s(14)),
            _chipsRow([
              'animals', 'space', 'sports', 'science',
              'food', 'nature', 'weather', 'fantasy',
            ]),
            SizedBox(height: context.s(18)),
            _creditsStrip(isPremium: isPremium, credits: credits),
            SizedBox(height: context.s(14)),
            SizedBox(
              width: double.infinity,
              height: context.s(56),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.honey,
                  foregroundColor: AppTheme.ink,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.s(16))),
                ),
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? SizedBox(
                        width: context.s(18),
                        height: context.s(18),
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.ink),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _generating ? 'Generating…' : 'Generate 10 words',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipsRow(List<String> suggestions) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in suggestions)
          ActionChip(
            label: Text(s),
            backgroundColor: AppTheme.surface,
            side: const BorderSide(color: AppTheme.outline),
            onPressed: () {
              _themeCtrl.text = s;
              _themeCtrl.selection =
                  TextSelection.collapsed(offset: s.length);
            },
          ),
      ],
    );
  }

  Widget _creditsStrip(
      {required bool isPremium, required int credits}) {
    final text = isPremium
        ? 'Premium: unlimited AI word packs.'
        : 'Free tier: $credits AI pack(s) left today.';
    return Container(
      padding: EdgeInsets.all(context.s(12)),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(context.s(12)),
      ),
      child: Row(
        children: [
          Icon(
            isPremium
                ? Icons.workspace_premium_rounded
                : Icons.bolt_rounded,
            color: isPremium ? AppTheme.violet : AppTheme.honeyDark,
          ),
          SizedBox(width: context.s(8)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppTheme.ink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
