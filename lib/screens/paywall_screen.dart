import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selected = IapProductIds.premiumYearly;

  Future<void> _buy() async {
    try {
      await ref.read(iapServiceProvider).buy(_selected);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t start purchase: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(iapProductsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        foregroundColor: AppTheme.ink,
        actions: [
          TextButton(
            onPressed: () => ref.read(iapServiceProvider).restore(),
            child: const Text('Restore'),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContentBox(
          child: Padding(
            padding: EdgeInsets.all(context.s(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('🐝', style: TextStyle(fontSize: context.s(40))),
                    SizedBox(width: context.s(8)),
                    Text('SpellBee',
                        style: Theme.of(context).textTheme.headlineLarge),
                  ],
                ),
                SizedBox(height: context.s(4)),
                Text('Premium',
                    style: TextStyle(
                      fontSize: context.s(30),
                      fontWeight: FontWeight.w900,
                      color: AppTheme.violet,
                    )),
                SizedBox(height: context.s(12)),
                _perks(context),
                SizedBox(height: context.s(22)),
                productsAsync.when(
                  data: (products) => _tiers(context, products),
                  error: (_, __) => _tiers(context, const []),
                  loading: () => Padding(
                    padding: EdgeInsets.all(context.s(24)),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: context.s(56),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.violet,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.s(16))),
                    ),
                    onPressed: _buy,
                    child: const Text('Unlock Premium',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                ),
                SizedBox(height: context.s(8)),
                const Text(
                  'Subscriptions renew automatically until cancelled in the '
                  'App Store / Google Play. Lifetime is a one-time payment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.mute, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _perks(BuildContext c) {
    Widget row(IconData i, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(i, size: 20, color: AppTheme.violet),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: AppTheme.ink, fontSize: 14))),
          ]),
        );
    return Column(children: [
      row(Icons.all_inclusive_rounded, 'Unlimited AI-generated word packs'),
      row(Icons.list_alt_rounded, 'Unlimited parent-made word lists'),
      row(Icons.block_rounded, 'No ads, ever'),
      row(Icons.record_voice_over_rounded, 'Enhanced voice pronunciation'),
    ]);
  }

  Widget _tiers(BuildContext c, List<IapProduct> products) {
    IapProduct? find(String id) =>
        products.where((p) => p.id == id).cast<IapProduct?>().firstOrNull;

    final monthly = find(IapProductIds.premiumMonthly);
    final yearly = find(IapProductIds.premiumYearly);
    final lifetime = find(IapProductIds.premiumLifetime);

    return Column(
      children: [
        _tile(
          id: IapProductIds.premiumMonthly,
          title: 'Monthly',
          subtitle: 'Try premium month-to-month',
          price: monthly?.price ?? '\$2.99',
          period: '/month',
        ),
        SizedBox(height: c.s(8)),
        _tile(
          id: IapProductIds.premiumYearly,
          title: 'Yearly',
          subtitle: 'Best value — save 44%',
          price: yearly?.price ?? '\$19.99',
          period: '/year',
          highlight: true,
        ),
        SizedBox(height: c.s(8)),
        _tile(
          id: IapProductIds.premiumLifetime,
          title: 'Lifetime',
          subtitle: 'Pay once. Keep forever.',
          price: lifetime?.price ?? '\$39.99',
          period: 'one-time',
        ),
      ],
    );
  }

  Widget _tile({
    required String id,
    required String title,
    required String subtitle,
    required String price,
    required String period,
    bool highlight = false,
  }) {
    final selected = _selected == id;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _selected = id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.violet : AppTheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppTheme.violet : AppTheme.mute,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.ink,
                            fontSize: 15)),
                    if (highlight) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.honey,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('POPULAR',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.ink)),
                      ),
                    ],
                  ]),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.mute, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppTheme.ink)),
                Text(period,
                    style: const TextStyle(
                        color: AppTheme.mute, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
