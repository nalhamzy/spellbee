import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/constants/legal_urls.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  final bool screenshotMode;

  /// Contextual line under the title — "Unlimited Math Bee rounds" when the
  /// kid hit that cap, the generic promise otherwise. Parents convert on
  /// the thing they were just stopped from doing, not on a feature list.
  final String? headline;
  const PaywallScreen({super.key, this.screenshotMode = false, this.headline});

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not start purchase: $e')));
      }
    }
  }

  Future<void> _openUrl(Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that link.')),
      );
    }
  }

  Widget _storeUnavailable(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.s(16)),
      decoration: AppTheme.card(color: AppTheme.surface),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppTheme.mute, size: 32),
          SizedBox(height: context.s(8)),
          const Text(
            "We couldn't reach the store to load prices. Check your "
            'connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.ink, fontSize: 13),
          ),
          SizedBox(height: context.s(10)),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(iapProductsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = widget.screenshotMode
        ? null
        : ref.watch(iapProductsProvider);
    final hasProducts =
        productsAsync == null ||
        productsAsync.maybeWhen(
          data: (products) => products.isNotEmpty,
          orElse: () => false,
        );

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => ref.read(iapServiceProvider).restore(),
            child: const Text('Restore'),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: responsiveViewportWidth(context),
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: responsiveMaxContentWidth(context),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(context.s(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _hero(context),
                        SizedBox(height: context.s(14)),
                        _perks(context),
                        SizedBox(height: context.s(14)),
                        _ValueNudge(context),
                        SizedBox(height: context.s(22)),
                        if (productsAsync == null)
                          _tiers(context, _screenshotProducts)
                        else
                          productsAsync.when(
                            // Never invent prices: a tier list built from
                            // hardcoded USD fallbacks shows the wrong amount
                            // on every non-US storefront and contradicts the
                            // store's own payment sheet. If the store gave us
                            // nothing, say so and offer a retry.
                            data: (products) => products.isEmpty
                                ? _storeUnavailable(context)
                                : _tiers(context, products),
                            error: (_, _) => _storeUnavailable(context),
                            loading: () => Padding(
                              padding: EdgeInsets.all(context.s(24)),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                        SizedBox(height: context.s(18)),
                        SizedBox(
                          width: double.infinity,
                          height: context.s(56),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.violet,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  context.s(18),
                                ),
                              ),
                            ),
                            // No live products = nothing trustworthy to sell;
                            // a dead CTA beats charging against a price the
                            // user never saw.
                            onPressed: hasProducts ? _buy : null,
                            child: Text(
                              _selected == IapProductIds.premiumLifetime
                                  ? 'Pay Once & Unlock'
                                  : 'Start Premium',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: context.s(8)),
                        _SubscriptionDisclosure(
                          selectedProductId: _selected,
                          products: productsAsync == null
                              ? _screenshotProducts
                              : productsAsync.maybeWhen(
                                  data: (products) => products,
                                  orElse: () => const <IapProduct>[],
                                ),
                        ),
                        SizedBox(height: context.s(8)),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          runSpacing: 0,
                          children: [
                            TextButton(
                              onPressed: () => _openUrl(LegalUrls.privacy),
                              child: const Text('Privacy Policy'),
                            ),
                            TextButton(
                              onPressed: () => _openUrl(LegalUrls.terms),
                              child: const Text('Terms of Use (EULA)'),
                            ),
                          ],
                        ),
                        Text(
                          'Manage or cancel subscriptions in your App Store account settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.mute,
                            fontSize: context.s(10).clamp(10, 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.s(18)),
      decoration: AppTheme.card(color: AppTheme.lilac, radius: context.s(28)),
      child: Row(
        children: [
          Container(
            width: context.s(58),
            height: context.s(58),
            decoration: const BoxDecoration(
              color: AppTheme.violet,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
            ),
          ),
          SizedBox(width: context.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SpellBee Premium',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.headline ??
                      'A calmer, richer spelling room for daily practice.',
                  style: const TextStyle(color: AppTheme.mute, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _perks(BuildContext c) {
    Widget row(IconData i, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(i, size: 20, color: AppTheme.violet),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.ink, fontSize: 14),
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        row(
          Icons.all_inclusive_rounded,
          'Unlimited themed word packs — no daily cap',
        ),
        row(Icons.calculate_rounded, 'Unlimited Math Bee rounds in Number Bee'),
        row(Icons.list_alt_rounded, 'Unlimited parent-made word lists'),
        row(Icons.record_voice_over_rounded, 'Studio voice pronunciation'),
      ],
    );
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
          id: IapProductIds.premiumYearly,
          title: 'Premium Yearly',
          subtitle: 'Best value for steady school practice',
          price: yearly?.price ?? '—',
          period: '/year',
          highlight: true,
        ),
        SizedBox(height: c.s(8)),
        _tile(
          id: IapProductIds.premiumLifetime,
          title: 'Premium Lifetime',
          subtitle: 'Pay once for this family',
          price: lifetime?.price ?? '—',
          period: 'one-time',
        ),
        SizedBox(height: c.s(8)),
        _tile(
          id: IapProductIds.premiumMonthly,
          title: 'Premium Monthly',
          subtitle: 'Try premium month-to-month',
          price: monthly?.price ?? '—',
          period: '/month',
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
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _selected = id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlight ? AppTheme.surface2 : AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.violet : AppTheme.outline,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? AppTheme.softShadow : null,
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
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.ink,
                          fontSize: 15,
                        ),
                      ),
                      if (highlight) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.honey,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'POPULAR',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.mute, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppTheme.ink,
                  ),
                ),
                Text(
                  period,
                  style: const TextStyle(color: AppTheme.mute, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _screenshotProducts = <IapProduct>[
  IapProduct(
    id: IapProductIds.premiumYearly,
    title: 'Premium Yearly',
    price: '\$29.99',
    description: 'Best value for steady school practice',
  ),
  IapProduct(
    id: IapProductIds.premiumLifetime,
    title: 'Premium Lifetime',
    price: '\$49.99',
    description: 'Pay once for this family',
  ),
  IapProduct(
    id: IapProductIds.premiumMonthly,
    title: 'Premium Monthly',
    price: '\$4.99',
    description: 'Try premium month-to-month',
  ),
];

class _SubscriptionDisclosure extends StatelessWidget {
  final String selectedProductId;
  final List<IapProduct> products;

  const _SubscriptionDisclosure({
    required this.selectedProductId,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    final product = products
        .where((p) => p.id == selectedProductId)
        .cast<IapProduct?>()
        .firstOrNull;
    // Only ever state a price the store itself returned — a hardcoded USD
    // amount in this legally load-bearing disclosure is wrong on every
    // non-US storefront.
    final price = product?.price;
    final text = switch (selectedProductId) {
      IapProductIds.premiumMonthly when price != null =>
        'SpellBee Premium Monthly: $price per month. Auto-renews monthly until cancelled.',
      IapProductIds.premiumMonthly =>
        'SpellBee Premium Monthly auto-renews monthly until cancelled. The price is shown at checkout.',
      IapProductIds.premiumYearly when price != null =>
        'SpellBee Premium Yearly: $price per year. Auto-renews yearly until cancelled.',
      IapProductIds.premiumYearly =>
        'SpellBee Premium Yearly auto-renews yearly until cancelled. The price is shown at checkout.',
      IapProductIds.premiumLifetime when price != null =>
        'SpellBee Premium Lifetime: $price one-time purchase. No subscription renewal.',
      IapProductIds.premiumLifetime =>
        'SpellBee Premium Lifetime is a one-time purchase. No subscription renewal.',
      _ => 'Review the selected purchase before confirming in the App Store.',
    };

    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppTheme.mute, fontSize: 11, height: 1.35),
    );
  }
}

class _ValueNudge extends StatelessWidget {
  final BuildContext pageContext;
  const _ValueNudge(this.pageContext);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(pageContext.s(12)),
      decoration: AppTheme.card(
        color: AppTheme.mint,
        border: AppTheme.sage.withValues(alpha: 0.35),
        shadow: false,
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: AppTheme.sage),
          SizedBox(width: pageContext.s(8)),
          const Expanded(
            child: Text(
              'Designed for daily practice: clearer pronunciation, unlimited custom lessons, and simple store checkout.',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
