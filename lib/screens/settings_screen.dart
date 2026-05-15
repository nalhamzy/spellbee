import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/paywall_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final quality = ref.watch(voiceQualityProvider);
    final hasStudioVoice = OpenAiTtsService.hasKey || AwsPollyTtsService.hasKey;

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
            Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
            SizedBox(height: context.s(16)),
            const _SectionLabel('Voice'),
            SizedBox(height: context.s(7)),
            _SettingsCard(
              children: [
                _SpeedPicker(ref: ref),
                const Divider(height: 0),
                _QualityPicker(
                  quality: quality,
                  isPremium: isPremium,
                  hasStudioVoice: hasStudioVoice,
                  onChanged: (value) =>
                      ref.read(voiceQualityProvider.notifier).set(value),
                  onPremiumTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  ),
                ),
                if (AwsPollyTtsService.hasKey) ...[
                  const Divider(height: 0),
                  _PollyPicker(ref: ref),
                ],
              ],
            ),
            SizedBox(height: context.s(16)),
            _SettingsCard(
              children: [
                ListTile(
                  leading: Icon(
                    isPremium
                        ? Icons.workspace_premium_rounded
                        : Icons.lock_outline_rounded,
                    color: isPremium ? AppTheme.violet : AppTheme.mute,
                  ),
                  title: Text(isPremium ? 'Premium active' : 'Go Premium'),
                  subtitle: Text(
                    isPremium
                        ? 'Studio voice, unlimited word packs, and no ads.'
                        : 'Unlock studio voice, unlimited packs, and no ads.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  ),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Restore purchases'),
                  onTap: () => ref.read(iapServiceProvider).restore(),
                ),
              ],
            ),
            SizedBox(height: context.s(12)),
            _SettingsCard(
              children: [
                const ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Privacy policy'),
                  subtitle: Text('Progress stays local on this device.'),
                  trailing: Icon(Icons.open_in_new_rounded, size: 18),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About SpellBee'),
                  subtitle: Text(
                    'Studio voice: ${hasStudioVoice ? "configured" : "not configured"}',
                  ),
                ),
              ],
            ),
            if (kDebugMode) ...[
              SizedBox(height: context.s(16)),
              const _SectionLabel('Dev tools', color: AppTheme.coral),
              SizedBox(height: context.s(7)),
              _SettingsCard(
                children: [
                  SwitchListTile(
                    value: isPremium,
                    secondary: const Icon(
                      Icons.science_outlined,
                      color: AppTheme.coral,
                    ),
                    title: const Text('Unlock premium'),
                    subtitle: const Text('Visible in debug builds only.'),
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
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeedPicker extends StatelessWidget {
  final WidgetRef ref;
  const _SpeedPicker({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.s(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TileHeader(
            icon: Icons.speed_rounded,
            title: 'Pronunciation speed',
            color: AppTheme.honeyDark,
          ),
          SizedBox(height: context.s(12)),
          SegmentedButton<VoiceSpeed>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppTheme.honey,
              selectedForegroundColor: AppTheme.ink,
            ),
            segments: const [
              ButtonSegment(value: VoiceSpeed.calm, label: Text('Calm')),
              ButtonSegment(value: VoiceSpeed.normal, label: Text('Normal')),
              ButtonSegment(value: VoiceSpeed.fast, label: Text('Fast')),
            ],
            selected: {ref.watch(voiceSpeedProvider)},
            onSelectionChanged: (s) =>
                ref.read(voiceSpeedProvider.notifier).set(s.first),
          ),
        ],
      ),
    );
  }
}

class _QualityPicker extends StatelessWidget {
  final VoiceQuality quality;
  final bool isPremium;
  final bool hasStudioVoice;
  final ValueChanged<VoiceQuality> onChanged;
  final VoidCallback onPremiumTap;

  const _QualityPicker({
    required this.quality,
    required this.isPremium,
    required this.hasStudioVoice,
    required this.onChanged,
    required this.onPremiumTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.s(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TileHeader(
            icon: Icons.record_voice_over_rounded,
            title: 'Voice quality',
            color: AppTheme.violet,
          ),
          SizedBox(height: context.s(12)),
          SegmentedButton<VoiceQuality>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppTheme.lilac,
              selectedForegroundColor: AppTheme.ink,
            ),
            segments: const [
              ButtonSegment(
                value: VoiceQuality.device,
                icon: Icon(Icons.phone_iphone_rounded),
                label: Text('Device'),
              ),
              ButtonSegment(
                value: VoiceQuality.studio,
                icon: Icon(Icons.graphic_eq_rounded),
                label: Text('Studio'),
              ),
            ],
            selected: {quality},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
          SizedBox(height: context.s(10)),
          Text(
            quality.description,
            style: const TextStyle(color: AppTheme.mute, fontSize: 12),
          ),
          if (quality == VoiceQuality.studio && !isPremium) ...[
            SizedBox(height: context.s(10)),
            _Notice(
              icon: Icons.lock_open_rounded,
              color: AppTheme.violet,
              text: 'Studio voice is a Premium option.',
              action: TextButton(
                onPressed: onPremiumTap,
                child: const Text('Unlock'),
              ),
            ),
          ],
          if (quality == VoiceQuality.studio && !hasStudioVoice) ...[
            SizedBox(height: context.s(10)),
            const _Notice(
              icon: Icons.cloud_off_rounded,
              color: AppTheme.coral,
              text:
                  'No studio voice gateway is configured in this build, so device voice will be used.',
            ),
          ],
        ],
      ),
    );
  }
}

class _PollyPicker extends StatelessWidget {
  final WidgetRef ref;
  const _PollyPicker({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.s(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TileHeader(
            icon: Icons.mic_rounded,
            title: 'Legacy Polly voice',
            color: AppTheme.sky,
          ),
          SizedBox(height: context.s(12)),
          SegmentedButton<String>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppTheme.aqua,
              selectedForegroundColor: AppTheme.ink,
            ),
            segments: const [
              ButtonSegment(value: 'Kevin', label: Text('Kevin')),
              ButtonSegment(value: 'Joanna', label: Text('Joanna')),
              ButtonSegment(value: 'Matthew', label: Text('Matthew')),
            ],
            selected: {ref.watch(pollyVoiceProvider)},
            onSelectionChanged: (s) =>
                ref.read(pollyVoiceProvider.notifier).set(s.first),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.card(radius: context.s(24)),
      child: Column(children: children),
    );
  }
}

class _TileHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _TileHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  const _Notice({
    required this.icon,
    required this.color,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.s(12)),
      decoration: AppTheme.card(
        color: color.withValues(alpha: 0.12),
        border: color.withValues(alpha: 0.28),
        shadow: false,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: context.s(8)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionLabel(this.label, {this.color = AppTheme.mute});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 11,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
