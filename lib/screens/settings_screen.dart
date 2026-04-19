import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
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
                    : 'Unlimited AI, no ads, PDF export.'),
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
                subtitle: const Text('v1.0.0 · Made by Ideal AI'),
                onTap: () {},
              ),
            ]),
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
