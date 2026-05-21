import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/legal_urls.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/paywall_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final quality = ref.watch(voiceQualityProvider);
    final ttsService = ref.read(ttsServiceProvider);
    final hasStudioVoice = ttsService.hasPremiumVoice;
    final hasRemoteStudioVoice = ttsService.hasRemoteStudioVoice;

    return SafeArea(
      child: ResponsiveContentBox(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.s(20)),
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, context.s(16), 0, context.s(120)),
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
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
                  if (quality == VoiceQuality.studio) ...[
                    const Divider(height: 0),
                    _StudioVoicePicker(
                      ref: ref,
                      hasRemoteStudioVoice: hasRemoteStudioVoice,
                    ),
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
                          ? 'Studio voice and unlimited word packs.'
                          : 'Unlock studio voice and unlimited packs.',
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
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy policy'),
                    subtitle: const Text(
                      'Progress stays local on this device.',
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () async {
                      final ok = await launchUrl(
                        LegalUrls.privacy,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open privacy policy.'),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: const Text('Terms of Use (EULA)'),
                    subtitle: const Text(
                      'Apple standard terms for subscriptions.',
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () async {
                      final ok = await launchUrl(
                        LegalUrls.terms,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open Terms of Use.'),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('About SpellBee'),
                    subtitle: Text(
                      'Studio voice: ${hasStudioVoice ? "ready" : "not configured"}',
                    ),
                  ),
                ],
              ),
            ],
          ),
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
          if (quality == VoiceQuality.studio && hasStudioVoice) ...[
            SizedBox(height: context.s(10)),
            const _Notice(
              icon: Icons.offline_bolt_rounded,
              color: AppTheme.sage,
              text:
                  'Studio voice is ready. Bundled premium audio plays offline for core words and phrases.',
            ),
          ],
        ],
      ),
    );
  }
}

class _StudioVoicePicker extends StatelessWidget {
  final WidgetRef ref;
  final bool hasRemoteStudioVoice;

  const _StudioVoicePicker({
    required this.ref,
    required this.hasRemoteStudioVoice,
  });

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(studioVoiceSourceProvider);
    final openAiVoice = ref.watch(openAiVoiceProvider);
    final pollyVoice = ref.watch(pollyVoiceProvider);
    final hasSelectedProviderKey = source == StudioVoiceProvider.openAi
        ? OpenAiTtsService.hasKey
        : AwsPollyTtsService.hasKey;
    final voices = source == StudioVoiceProvider.openAi
        ? kOpenAiStudioVoices
        : kPollyStudioVoices;
    final selectedVoice =
        voices.any(
          (voice) =>
              voice.id ==
              (source == StudioVoiceProvider.openAi ? openAiVoice : pollyVoice),
        )
        ? (source == StudioVoiceProvider.openAi ? openAiVoice : pollyVoice)
        : voices.first.id;
    final selectedOption = voices.firstWhere(
      (voice) => voice.id == selectedVoice,
      orElse: () => voices.first,
    );

    return Padding(
      padding: EdgeInsets.all(context.s(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TileHeader(
            icon: Icons.mic_rounded,
            title: 'Studio voice',
            color: AppTheme.sky,
          ),
          SizedBox(height: context.s(12)),
          SegmentedButton<StudioVoiceProvider>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppTheme.aqua,
              selectedForegroundColor: AppTheme.ink,
            ),
            segments: const [
              ButtonSegment(
                value: StudioVoiceProvider.openAi,
                icon: Icon(Icons.auto_awesome_rounded),
                label: Text('OpenAI'),
              ),
              ButtonSegment(
                value: StudioVoiceProvider.polly,
                icon: Icon(Icons.cloud_queue_rounded),
                label: Text('Polly'),
              ),
            ],
            selected: {source},
            onSelectionChanged: (s) =>
                ref.read(studioVoiceSourceProvider.notifier).set(s.first),
          ),
          SizedBox(height: context.s(12)),
          DropdownButtonFormField<String>(
            initialValue: selectedVoice,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppTheme.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.s(16)),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: context.s(14),
                vertical: context.s(12),
              ),
            ),
            items: [
              for (final voice in voices)
                DropdownMenuItem(value: voice.id, child: Text(voice.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              if (source == StudioVoiceProvider.openAi) {
                ref.read(openAiVoiceProvider.notifier).set(value);
              } else {
                ref.read(pollyVoiceProvider.notifier).set(value);
              }
            },
          ),
          SizedBox(height: context.s(8)),
          Text(
            '${source.label}: ${selectedOption.description}',
            style: const TextStyle(color: AppTheme.mute, fontSize: 12),
          ),
          if (!hasRemoteStudioVoice) ...[
            SizedBox(height: context.s(10)),
            const _Notice(
              icon: Icons.key_off_rounded,
              color: AppTheme.honeyDark,
              text:
                  'No OpenAI or AWS key is in this tester build yet. Bundled and device voice will play until a key is provided.',
            ),
          ],
          if (hasRemoteStudioVoice && !hasSelectedProviderKey) ...[
            SizedBox(height: context.s(10)),
            _Notice(
              icon: Icons.sync_rounded,
              color: AppTheme.honeyDark,
              text:
                  '${source.label} is not configured in this build. The other available studio provider will be used as fallback.',
            ),
          ],
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
      decoration: AppTheme.card(
        gradient: AppTheme.surfaceLiftGradient,
        radius: context.s(24),
      ),
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
        gradient: color == AppTheme.sage
            ? AppTheme.successGradient
            : color == AppTheme.honeyDark
            ? AppTheme.ctaGradient
            : AppTheme.premiumGradient,
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

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: AppTheme.mute,
        fontSize: 11,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
