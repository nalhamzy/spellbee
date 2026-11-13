import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/services/event_logger.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/widgets/parent_gate.dart';
import 'package:url_launcher/url_launcher.dart';

/// "For grown-ups" recommendation of Whykeeper. Renders nothing unless the
/// remote switch gave a valid store URL for this platform. Tapping goes
/// through the parent gate before the store link opens outside the app.
/// Only for grown-up screens ([source] is 'settings' or 'stats').
class WhykeeperCard extends ConsumerWidget {
  final String source;
  const WhykeeperCard({super.key, required this.source});

  Future<void> _open(BuildContext context, WidgetRef ref, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final approved = await showParentGate(
      context,
      message: 'Please ask a parent to continue to the store.',
    );
    if (!approved) return;
    ref.read(eventLoggerProvider)
      ..log(FunnelEvent.parentGatePass, {'source': 'promo'})
      ..log(FunnelEvent.promoOpen, {'source': source});
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the store.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(whykeeperPromoProvider).asData?.value;
    if (url == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: context.s(16)),
      child: Container(
        key: Key('whykeeper-card-$source'),
        padding: EdgeInsets.all(context.s(14)),
        decoration: AppTheme.card(
          color: AppTheme.surface,
          radius: context.s(16),
          shadow: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FOR GROWN-UPS',
              style: TextStyle(
                color: AppTheme.mute,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Homework help for grown-ups',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Whykeeper turns a page of your child's schoolbook into a "
              'lesson you can teach together. From the makers of SpellBee.',
              style: TextStyle(color: AppTheme.ink, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => _open(context, ref, url),
              child: const Text('See Whykeeper'),
            ),
          ],
        ),
      ),
    );
  }
}
