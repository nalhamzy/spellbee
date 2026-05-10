import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/services/openai_tts_service.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/paywall_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    return SafeArea(
      child: ResponsiveContentBox(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              context.s(20), context.s(16), context.s(20), context.s(120)),
          children: [
            Text('Settings',
                style: Theme.of(context).textTheme.headlineLarge),
            SizedBox(height: context.s(16)),
            Text('VOICE',
                style: const TextStyle(
                  color: AppTheme.mute,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                )),
            SizedBox(height: context.s(6)),
            _card(context, [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded,
                        color: AppTheme.honeyDark),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Pronunciation speed',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: SegmentedButton<VoiceSpeed>(
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppTheme.honey,
                    selectedForegroundColor: AppTheme.ink,
                  ),
                  segments: const [
                    ButtonSegment(
                        value: VoiceSpeed.calm, label: Text('Calm')),
                    ButtonSegment(
                        value: VoiceSpeed.normal, label: Text('Normal')),
                    ButtonSegment(
                        value: VoiceSpeed.fast, label: Text('Fast')),
                  ],
                  selected: {ref.watch(voiceSpeedProvider)},
                  onSelectionChanged: (s) =>
                      ref.read(voiceSpeedProvider.notifier).set(s.first),
                ),
              ),
            ]),
            SizedBox(height: context.s(16)),
            _card(context, [
              ListTile(
                leading: Icon(
                    isPremium
                        ? Icons.workspace_premium_rounded
                        : Icons.lock_outline_rounded,
                    color: isPremium ? AppTheme.violet : AppTheme.mute),
                title: Text(isPremium ? 'Premium active' : 'Go Premium'),
                subtitle: Text(isPremium
                    ? 'Thank you for supporting SpellBee.'
                    : 'Unlimited AI word packs, no ads.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PaywallScreen(),
                )),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: const Text('Restore purchases'),
                onTap: () => ref.read(iapServiceProvider).restore(),
              ),
            ]),
            SizedBox(height: context.s(12)),
            _card(context, [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                subtitle:
                    const Text('All data stored locally. Nothing sent.'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () {},
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('About SpellBee'),
                subtitle: Text(
                    'v1.0.0 · Premium voice: ${OpenAiTtsService.hasKey ? "OpenAI" : "device TTS"}'),
                onTap: () {},
              ),
            ]),
            if (kDebugMode) ...[
              SizedBox(height: context.s(16)),
              Text('DEV tools',
                  style: const TextStyle(
                    color: AppTheme.coral,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  )),
              SizedBox(height: context.s(6)),
              _card(context, [
                SwitchListTile(
                  value: isPremium,
                  secondary: const Icon(Icons.science_outlined,
                      color: AppTheme.coral),
                  title: const Text('Unlock premium (dev)'),
                  subtitle: const Text(
                      'Flip on to test premium flows without paying. '
                      'Not shown in release builds.'),
                  onChanged: (on) async {
                    if (on) {
                      await ref
                          .read(premiumProvider.notifier)
                          .activate(IapProductIds.premiumLifetime);
                    } else {
                      await ref.read(premiumProvider.notifier).clear();
                    }
                  },
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext c, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(c.s(14)),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(children: children),
    );
  }
}
