import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/legal_urls.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/core/services/daily_reminder.dart';
import 'package:spellbee/core/services/event_logger.dart';
import 'package:spellbee/screens/paywall_screen.dart';
import 'package:spellbee/widgets/parent_gate.dart';
import 'package:spellbee/widgets/whykeeper_card.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final confirmingPurchase = ref.watch(pendingPurchaseProvider);
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
                      MaterialPageRoute(
                        builder: (_) => const PaywallScreen(
                          source: PaywallSource.studioVoice,
                        ),
                      ),
                    ),
                  ),
                  if (quality == VoiceQuality.studio) ...[
                    const Divider(height: 0),
                    _StudioVoicePicker(
                      ref: ref,
                      hasRemoteStudioVoice: hasRemoteStudioVoice,
                    ),
                  ],
                  const Divider(height: 0),
                  SwitchListTile(
                    value: ref.watch(autoListenProvider),
                    onChanged: (v) =>
                        ref.read(autoListenProvider.notifier).set(v),
                    activeThumbColor: AppTheme.ink,
                    activeTrackColor: AppTheme.honey,
                    secondary: const Icon(
                      Icons.hearing_rounded,
                      color: AppTheme.coral,
                    ),
                    title: const Text(
                      'Hands-free spell aloud',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text(
                      'In "Aloud" mode the mic opens by itself after each '
                      'word and checks the spelling when your child stops '
                      'talking. Say "repeat" to hear a word again.',
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.s(16)),
              const _SectionLabel('Practice reminder'),
              SizedBox(height: context.s(7)),
              const _SettingsCard(children: [_ReminderTile()]),
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
                          ? 'All adventures, unlimited lists and Math Bee.'
                          : confirmingPurchase
                          ? 'Purchase received, confirming with the store…'
                          : 'More adventures, school lists and Math Bee.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaywallScreen()),
                    ),
                  ),
                  const Divider(height: 0),
                  const _RestorePurchasesTile(),
                ],
              ),
              const WhykeeperCard(source: 'settings'),
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
                      final approved = await showParentGate(
                        context,
                        message: 'Please ask a parent to open this page.',
                      );
                      if (!approved || !context.mounted) return;
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
                      final approved = await showParentGate(
                        context,
                        message: 'Please ask a parent to open this page.',
                      );
                      if (!approved || !context.mounted) return;
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
                      'Spelling practice with voice, for ages 6 and up.',
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

/// Opt-in daily reminder. Every change goes through the parent gate, and the
/// OS permission is asked only when a grown-up turns it on.
class _ReminderTile extends ConsumerStatefulWidget {
  const _ReminderTile();

  @override
  ConsumerState<_ReminderTile> createState() => _ReminderTileState();
}

class _ReminderTileState extends ConsumerState<_ReminderTile> {
  bool _busy = false;

  String _time(int hour) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: hour, minute: 0));

  Future<int?> _pickHour(int current) => showDialog<int>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Remind every day at'),
      children: [
        for (final hour in ReminderSettings.hours)
          SimpleDialogOption(
            key: Key('reminder-hour-$hour'),
            onPressed: () => Navigator.pop(dialogContext, hour),
            child: Text(
              _time(hour),
              style: TextStyle(
                fontWeight: hour == current ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _change({required bool turnOn}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final approved = await showParentGate(
        context,
        message: 'Please ask a parent to set the practice reminder.',
        confirmLabel: 'Continue',
      );
      if (!approved || !mounted) return;
      final events = ref.read(eventLoggerProvider)
        ..log(FunnelEvent.parentGatePass, {'source': 'reminder'});
      final notifier = ref.read(reminderSettingsProvider.notifier);
      if (!turnOn) {
        await notifier.disable();
        messenger.showSnackBar(
          const SnackBar(content: Text('Daily reminder turned off.')),
        );
        return;
      }
      final hour = await _pickHour(ref.read(reminderSettingsProvider).hour);
      if (hour == null || !mounted) return;
      final result = await notifier.enable(hour);
      if (result == ReminderChange.enabled) {
        events.log(FunnelEvent.reminderEnabled);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            ReminderChange.enabled =>
              'Reminder set for ${_time(hour)} every day.',
            ReminderChange.permissionDenied =>
              'Notifications are off for SpellBee. Allow them in the phone '
                  'settings to get the reminder.',
            _ => 'Could not set the reminder. Please try again.',
          }),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(reminderSettingsProvider);
    return Column(
      children: [
        SwitchListTile(
          key: const Key('reminder-switch'),
          value: settings.enabled,
          onChanged: _busy ? null : (on) => _change(turnOn: on),
          activeThumbColor: AppTheme.ink,
          activeTrackColor: AppTheme.honey,
          secondary: const Icon(
            Icons.notifications_active_rounded,
            color: AppTheme.honeyDark,
          ),
          title: const Text(
            'Daily practice reminder',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            settings.enabled
                ? "Every day at ${_time(settings.hour)}: “Today's word is ready”."
                : 'Off. A grown-up can turn on one gentle reminder a day.',
          ),
        ),
        if (settings.enabled)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: TextButton(
                onPressed: _busy ? null : () => _change(turnOn: true),
                child: const Text('Change time'),
              ),
            ),
          ),
      ],
    );
  }
}

/// Awaits the restore and tells the parent the outcome (found, nothing to
/// restore, no longer active, confirming, error). An unanswered tap here is
/// a classic App Review flag.
class _RestorePurchasesTile extends ConsumerStatefulWidget {
  const _RestorePurchasesTile();

  @override
  ConsumerState<_RestorePurchasesTile> createState() =>
      _RestorePurchasesTileState();
}

class _RestorePurchasesTileState extends ConsumerState<_RestorePurchasesTile> {
  bool _busy = false;

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await restoreWithFeedback(
        context,
        ref.read(iapServiceProvider),
        events: ref.read(eventLoggerProvider),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.restore_rounded),
      title: Text(_busy ? 'Restoring purchases…' : 'Restore purchases'),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _busy ? null : _restore,
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
            title: 'Your practice voice',
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
                icon: Icon(Icons.auto_awesome_rounded),
                label: Text('Bee Buddy'),
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
          const SizedBox(height: 8),
          const Text(
            'Bee Buddy is an AI-generated voice, included for everyone. '
            'Built-in words and clues play offline. It is not a real child’s voice.',
            style: TextStyle(color: AppTheme.mute, fontSize: 12, height: 1.4),
          ),
          if (quality == VoiceQuality.studio && !isPremium) ...[
            SizedBox(height: context.s(10)),
            _Notice(
              icon: Icons.lock_open_rounded,
              color: AppTheme.violet,
              text:
                  'Premium adds online studio voices for your own words. '
                  'Bee Buddy stays free for built-in practice.',
              action: TextButton(
                onPressed: onPremiumTap,
                child: const Text('Unlock'),
              ),
            ),
          ] else if (quality == VoiceQuality.studio && hasStudioVoice) ...[
            SizedBox(height: context.s(10)),
            const _Notice(
              icon: Icons.offline_bolt_rounded,
              color: AppTheme.sage,
              text:
                  'Bee Buddy plays built-in words offline. Online studio voices speak custom words when connected.',
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
    final openAiVoice = ref.watch(openAiVoiceProvider);
    const voices = kOpenAiStudioVoices;
    final selectedVoice = voices.any((voice) => voice.id == openAiVoice)
        ? openAiVoice
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
            title: 'Voice for custom words',
            color: AppTheme.sky,
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
              ref.read(openAiVoiceProvider.notifier).set(value);
            },
          ),
          SizedBox(height: context.s(8)),
          Text(
            selectedOption.description,
            style: const TextStyle(color: AppTheme.mute, fontSize: 12),
          ),
          if (!hasRemoteStudioVoice) ...[
            SizedBox(height: context.s(10)),
            const _Notice(
              icon: Icons.key_off_rounded,
              color: AppTheme.honeyDark,
              text:
                  'Online studio voices are unavailable in this build. Bee Buddy and device voice still play offline.',
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
