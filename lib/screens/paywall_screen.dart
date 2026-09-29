import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/constants/legal_urls.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:url_launcher/url_launcher.dart';

enum PaywallSource {
  general,
  adventures,
  customLists,
  mathBee,
  wordPacks,
  studioVoice,
}

class PaywallScreen extends ConsumerStatefulWidget {
  final bool screenshotMode;
  final PaywallSource source;

  /// Contextual line under the title — "Unlimited Math Bee rounds" when the
  /// kid hit that cap, the generic promise otherwise. Parents convert on
  /// the thing they were just stopped from doing, not on a feature list.
  final String? headline;
  const PaywallScreen({
    super.key,
    this.screenshotMode = false,
    this.headline,
    this.source = PaywallSource.general,
  });

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selected = IapProductIds.premiumYearly;
  bool _startingPurchase = false;
  bool _openingStore = false;
  bool _restoring = false;
  bool _showMonthly = false;

  Future<void> _buy(String productId) async {
    if (_startingPurchase || _restoring || widget.screenshotMode) return;
    setState(() => _startingPurchase = true);
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (_) => const _ParentPurchaseGate(),
      );
      if (approved != true || !mounted) return;
      if (ref.read(isPremiumProvider)) return;
      setState(() => _openingStore = true);
      await ref.read(iapServiceProvider).buy(productId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start the purchase. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _startingPurchase = false;
          _openingStore = false;
        });
      }
    }
  }

  Future<void> _restore() async {
    if (_restoring || _startingPurchase || widget.screenshotMode) return;
    setState(() => _restoring = true);
    try {
      await ref.read(iapServiceProvider).restore();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not restore purchases. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _openUrl(Uri url) async {
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      // A missing browser should leave the paywall usable.
    }
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
    if (!widget.screenshotMode) {
      ref.listen<bool>(isPremiumProvider, (previous, active) {
        if (previous == false &&
            active &&
            mounted &&
            ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).maybePop(true);
        }
      });
      if (ref.watch(isPremiumProvider)) {
        return Scaffold(
          appBar: AppBar(title: const Text('SpellBee Premium')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: AppTheme.violet,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Premium is ready',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your purchase is active. Let the next adventure begin.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(true),
                    child: const Text('Back to practice'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    final productsAsync = widget.screenshotMode
        ? null
        : ref.watch(iapProductsProvider);
    final products =
        (productsAsync == null
                ? _screenshotProducts
                : productsAsync.maybeWhen(
                    data: (products) => products,
                    orElse: () => const <IapProduct>[],
                  ))
            .where((p) => IapProductIds.all.contains(p.id))
            .toList();
    final availableIds = products.map((p) => p.id).toSet();
    final selected = availableIds.contains(_selected)
        ? _selected
        : [
            IapProductIds.premiumYearly,
            IapProductIds.premiumLifetime,
            IapProductIds.premiumMonthly,
          ].where(availableIds.contains).firstOrNull;
    final busy = _startingPurchase || _restoring;

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: busy || widget.screenshotMode ? null : _restore,
            child: Text(_restoring ? 'Restoring…' : 'Restore'),
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
                        _FreePracticeNote(context),
                        SizedBox(height: context.s(22)),
                        if (productsAsync == null)
                          _tiers(context, products, selected)
                        else
                          productsAsync.when(
                            // Never invent prices: a tier list built from
                            // hardcoded USD fallbacks shows the wrong amount
                            // on every non-US storefront and contradicts the
                            // store's own payment sheet. If the store gave us
                            // nothing, say so and offer a retry.
                            data: (_) => products.isEmpty
                                ? _storeUnavailable(context)
                                : _tiers(context, products, selected),
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

                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.violet,
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, context.s(56)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  context.s(18),
                                ),
                              ),
                            ),
                            onPressed:
                                selected == null ||
                                    busy ||
                                    widget.screenshotMode
                                ? null
                                : () => _buy(selected),
                            child: Text(
                              _startingPurchase
                                  ? (_openingStore
                                        ? 'Opening store…'
                                        : 'Waiting for parent…')
                                  : selected == IapProductIds.premiumLifetime
                                  ? 'Unlock with one payment'
                                  : selected == IapProductIds.premiumMonthly
                                  ? 'Continue with monthly'
                                  : 'Continue with yearly',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: context.s(8)),
                        const Text(
                          'For parents · Store confirmation comes next',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.mute, fontSize: 12),
                        ),
                        SizedBox(height: context.s(8)),
                        if (selected != null)
                          _SubscriptionDisclosure(
                            selectedProductId: selected,
                            products: products,
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
                        if (IapProductIds.subscriptionIds.contains(selected))
                          Text(
                            Theme.of(context).platform == TargetPlatform.android
                                ? 'Manage or cancel subscriptions in Google Play.'
                                : 'Manage or cancel subscriptions in your App Store account settings.',
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

  String get _contextHeadline => switch (widget.source) {
    PaywallSource.adventures =>
      'Keep exploring together, one little spelling victory at a time.',
    PaywallSource.customLists =>
      'Keep every school list ready for a little practice, any day.',
    PaywallSource.mathBee =>
      'Keep the number-word practice going with more Math Bee rounds.',
    PaywallSource.wordPacks =>
      'Make more room for the words your child wants to explore.',
    PaywallSource.studioVoice =>
      'More voice choices for your own practice words.',
    PaywallSource.general => 'Turn school words into small, happy wins.',
  };

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
                  widget.headline ?? _contextHeadline,
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
          Icons.explore_rounded,
          'All three Bee Adventures — more worlds to explore',
        ),
        row(
          Icons.list_alt_rounded,
          'Unlimited school word lists — paste, save, practise',
        ),
        row(
          Icons.calculate_rounded,
          'Unlimited Math Bee rounds — keep the practice going',
        ),
        row(
          Icons.record_voice_over_rounded,
          'Online studio voices for custom practice words',
        ),
      ],
    );
  }

  Widget _tiers(BuildContext c, List<IapProduct> products, String? selected) {
    IapProduct? find(String id) =>
        products.where((p) => p.id == id).cast<IapProduct?>().firstOrNull;

    final monthly = find(IapProductIds.premiumMonthly);
    final yearly = find(IapProductIds.premiumYearly);
    final lifetime = find(IapProductIds.premiumLifetime);

    return Column(
      children: [
        if (yearly != null)
          _tile(
            id: IapProductIds.premiumYearly,
            selected: selected == IapProductIds.premiumYearly,
            title: 'Premium Yearly',
            subtitle: 'A full year of Premium',
            price: yearly.price,
            period: '/year',
            highlight: true,
          ),
        SizedBox(height: c.s(8)),
        if (lifetime != null)
          _tile(
            id: IapProductIds.premiumLifetime,
            selected: selected == IapProductIds.premiumLifetime,
            title: 'Premium Lifetime',
            subtitle: 'One payment. No renewal.',
            price: lifetime.price,
            period: 'one-time',
          ),
        SizedBox(height: c.s(8)),
        if (monthly != null && (yearly != null || lifetime != null))
          TextButton(
            onPressed: _startingPurchase || _restoring
                ? null
                : () => setState(() => _showMonthly = !_showMonthly),
            child: Text(
              _showMonthly ? 'Hide monthly option' : 'Prefer monthly? See plan',
            ),
          ),
        if (monthly != null &&
            (_showMonthly ||
                selected == monthly.id ||
                (yearly == null && lifetime == null)))
          _tile(
            id: IapProductIds.premiumMonthly,
            selected: selected == IapProductIds.premiumMonthly,
            title: 'Premium Monthly',
            subtitle: 'Billed each month. Cancel anytime.',
            price: monthly.price,
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
    required bool selected,
    bool highlight = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _startingPurchase || _restoring
          ? null
          : () => setState(() => _selected = id),
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
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
                            'YEARLY',
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
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    textAlign: TextAlign.right,
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
    description: 'A full year of Premium',
  ),
  IapProduct(
    id: IapProductIds.premiumLifetime,
    title: 'Premium Lifetime',
    price: '\$49.99',
    description: 'One payment. No renewal.',
  ),
  IapProduct(
    id: IapProductIds.premiumMonthly,
    title: 'Premium Monthly',
    price: '\$4.99',
    description: 'Billed each month. Cancel anytime.',
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

class _FreePracticeNote extends StatelessWidget {
  final BuildContext pageContext;
  const _FreePracticeNote(this.pageContext);

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
              'Always included free: daily review, tricky-word practice, progress and the clear Bee buddy voice.',
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

/// Fresh approval is required for each purchase attempt and is never persisted.
class _ParentPurchaseGate extends StatefulWidget {
  const _ParentPurchaseGate();
  @override
  State<_ParentPurchaseGate> createState() => _ParentPurchaseGateState();
}

class _ParentPurchaseGateState extends State<_ParentPurchaseGate> {
  final _answer = TextEditingController();
  final _left = 12 + Random().nextInt(8);
  final _right = 3 + Random().nextInt(6);
  int _attempts = 0;
  String? _error;
  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _check() {
    if (int.tryParse(_answer.text.trim()) == _left * _right) {
      Navigator.pop(context, true);
    } else if (++_attempts >= 3) {
      Navigator.pop(context, false);
    } else {
      setState(() => _error = 'Please ask a grown-up to help.');
      _answer.clear();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('A moment for grown-ups'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Please ask a parent to continue to the store.'),
          const SizedBox(height: 16),
          Text('What is $_left × $_right?', key: const Key('parent-challenge')),
          const SizedBox(height: 12),
          TextField(
            key: const Key('parent-answer'),
            controller: _answer,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _check(),
            decoration: InputDecoration(
              labelText: 'Your answer',
              errorText: _error,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Not now'),
      ),
      FilledButton(onPressed: _check, child: const Text('Continue to store')),
    ],
  );
}
