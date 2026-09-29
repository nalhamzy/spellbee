import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/adventure.dart';
import 'package:spellbee/core/services/tts_service.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/adventure_provider.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/paywall_screen.dart';
import 'package:spellbee/screens/test_screen.dart';

class AdventureHomeCard extends StatelessWidget {
  const AdventureHomeCard({super.key});
  @override
  Widget build(BuildContext context) => _StoryCard(
    world: adventureWorlds.first,
    title: 'A little spelling. A big adventure.',
    subtitle: 'Help your bee bring three magical places to life.',
    badge: 'BEE ADVENTURES',
    action: 'Explore • first adventure free',
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdventuresScreen())),
  );
}

class AdventuresScreen extends ConsumerWidget {
  const AdventuresScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(adventureProvider);
    final premium = ref.watch(isPremiumProvider);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Bee Adventures')),
      body: ResponsiveContentBox(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Small words. Wonderful worlds.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Listen, spell and help your bee. Four little stops in every story.',
              style: TextStyle(color: AppTheme.mute, height: 1.5),
            ),
            const SizedBox(height: 20),
            for (final world in adventureWorlds) ...[
              _StoryCard(
                world: world,
                title: world.title,
                subtitle: world.subtitle,
                badge: world.premium
                    ? (premium ? 'PREMIUM • INCLUDED' : 'PREMIUM')
                    : 'PLAY FREE',
                action: progress.count(world) == 4
                    ? 'Explore again • 4 of 4 stops complete'
                    : progress.count(world) > 0
                    ? 'Continue • ${progress.count(world)} of 4 stops complete'
                    : world.available(premium)
                    ? 'Let’s explore'
                    : 'Peek inside',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdventureWorldScreen(world: world),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'Practice at your selected level. Hints and retries are welcome. Story progress stays on this device.',
              style: TextStyle(color: AppTheme.mute, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class AdventureWorldScreen extends ConsumerStatefulWidget {
  final AdventureWorld world;
  const AdventureWorldScreen({super.key, required this.world});
  @override
  ConsumerState<AdventureWorldScreen> createState() => _AdventureWorldState();
}

class _AdventureWorldState extends ConsumerState<AdventureWorldScreen> {
  late final TtsService _tts;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_hear(widget.world.introduction));
    });
  }

  @override
  void dispose() {
    unawaited(_tts.stop());
    super.dispose();
  }

  Future<void> _hear(String text) async {
    await _tts.stop();
    if (!mounted) return;
    await _tts.speakText(text, premium: ref.read(isPremiumProvider));
  }

  Future<void> _play(int stop) async {
    if (_opening) return;
    final world = widget.world;
    if (!ref
        .read(adventureProvider)
        .canPlay(world, stop, premium: ref.read(isPremiumProvider))) {
      return;
    }
    setState(() => _opening = true);
    await _tts.stop();
    if (!mounted) return;
    final level = ref.read(selectedLevelProvider);
    final startedWithPremium = ref.read(isPremiumProvider);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TestScreen(
          words: adventureWords(world, stop, level, DateTime.now()),
          title: '${world.title} • ${stop + 1}/4',
          level: level,
          // Tiles are available inside every round, but independent spelling
          // remains the default so parents can see useful recall evidence.
          onComplete: () => ref
              .read(adventureProvider.notifier)
              .complete(world, stop, startedWithPremium: startedWithPremium),
          returnLabel: 'Back to adventure',
          completionMessage: stop == world.stops.length - 1
              ? world.reward
              : 'You helped! The next stop is ready.',
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final world = widget.world;
    final progress = ref.watch(adventureProvider);
    final premium = ref.watch(isPremiumProvider);
    final count = progress.count(world);
    final available = world.available(premium);
    final next =
        List.generate(
          world.stops.length,
          (i) => i,
        ).where((i) => !progress.isDone(world, i)).firstOrNull ??
        0;
    final level = ref.watch(selectedLevelProvider);
    final color = world.id == 'moonlight'
        ? AppTheme.lilac
        : world.id == 'rainbow'
        ? AppTheme.aqua
        : AppTheme.mint;
    final icon = world.id == 'moonlight'
        ? Icons.lightbulb_rounded
        : world.id == 'rainbow'
        ? Icons.water_drop_rounded
        : Icons.local_florist_rounded;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: Text(world.title)),
      body: ResponsiveContentBox(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: AspectRatio(
                aspectRatio: 1.6,
                child: Image.asset(
                  world.image,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              count == 4 ? world.reward : world.subtitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              world.introduction,
              style: const TextStyle(
                color: AppTheme.mute,
                height: 1.5,
                fontSize: 15,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _hear(world.introduction),
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('Hear the story'),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: AppTheme.card(color: color, radius: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          count == 4
                              ? 'A lovely place to return to'
                              : 'Your little journey',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      Text(
                        '$count/4',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < world.stops.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _StopTile(
                      title: world.stops[i],
                      icon: icon,
                      number: i + 1,
                      done: progress.isDone(world, i),
                      active:
                          available &&
                          progress.canPlay(world, i, premium: premium),
                      onTap: _opening ? null : () => _play(i),
                      onHear: () => _hear(world.stops[i]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (available) ...[
              FilledButton.icon(
                onPressed: _opening ? null : () => _play(next),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Text(
                    count == 4
                        ? 'Play the story again'
                        : 'Start stop ${next + 1} • 4 words',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${kLevelLabels[level] ?? 'Level $level'} • Listen, spell, try again.\nFinish every word to help this stop shine.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.mute,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: () async {
                  await _tts.stop();
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const PaywallScreen(source: PaywallSource.adventures),
                    ),
                  );
                },
                icon: const Icon(Icons.family_restroom_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Text('For grown-ups • explore Premium'),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sunny Meadow is always free. Premium includes all three adventures.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.mute,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  final String title;
  final int number;
  final IconData icon;
  final bool done, active;
  final VoidCallback? onTap;
  final VoidCallback onHear;
  const _StopTile({
    required this.title,
    required this.number,
    required this.icon,
    required this.done,
    required this.active,
    required this.onTap,
    required this.onHear,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: active || done ? 1 : .6),
    borderRadius: BorderRadius.circular(18),
    child: Semantics(
      button: active,
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: done ? AppTheme.honey : AppTheme.bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done
                      ? icon
                      : active
                      ? Icons.play_arrow_rounded
                      : Icons.lock_outline_rounded,
                  color: done || active ? AppTheme.ink : AppTheme.mute,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STOP $number${done ? ' • COMPLETE' : ''}',
                      style: const TextStyle(
                        color: AppTheme.mute,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onHear,
                tooltip: 'Hear stop $number',
                icon: const Icon(Icons.volume_up_outlined, size: 21),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StoryCard extends StatelessWidget {
  final AdventureWorld world;
  final String title, subtitle, badge, action;
  final VoidCallback onTap;
  const _StoryCard({
    required this.world,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.action,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: AppTheme.card(radius: 26),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Material(
        color: AppTheme.surface,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 2.15,
                    child: Image.asset(
                      world.image,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: .7,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppTheme.mute, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            action,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
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
