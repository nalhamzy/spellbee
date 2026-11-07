import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

/// Reads store intro offers so the paywall can show a free trial exactly as
/// the store configured it, and nothing when there is none.
///
/// Play returns one [GooglePlayProductDetails] per base plan and per offer,
/// and only offers the customer is eligible for. An offer whose first
/// pricing phase costs 0 is a free trial; its own `price` is that free phase,
/// so the recurring price must come from the base plan (or the offer's last
/// phase). On the App Store the intro offer is `skProduct.introductoryPrice`;
/// StoreKit 1 cannot tell whether this Apple ID already used it, so callers
/// pass an eligibility check (StoreKit 2) and hide the trial when unsure.
enum TrialUnit { day, week, month, year }

class FreeTrial {
  final int count;
  final TrialUnit unit;

  const FreeTrial(this.count, this.unit);

  /// Length in days for day/week trials (Apple configures "1 week").
  int? get days => switch (unit) {
    TrialUnit.day => count,
    TrialUnit.week => count * 7,
    _ => null,
  };

  /// "7 days", "1 month", "2 months", "1 year".
  String get label {
    final d = days;
    if (d != null) return d == 1 ? '1 day' : '$d days';
    final noun = unit == TrialUnit.month ? 'month' : 'year';
    return count == 1 ? '1 $noun' : '$count ${noun}s';
  }

  /// "7-day", "1-month" (for "Start your 7-day free trial").
  String get adjective {
    final d = days;
    if (d != null) return '$d-day';
    return '$count-${unit == TrialUnit.month ? 'month' : 'year'}';
  }

  @override
  bool operator ==(Object other) =>
      other is FreeTrial && other.count == count && other.unit == unit;

  @override
  int get hashCode => Object.hash(count, unit);

  @override
  String toString() => 'FreeTrial($label)';
}

/// Parses an ISO 8601 billing period such as P7D, P1W, P1M, P1Y.
FreeTrial? parseIsoPeriod(String iso, {int times = 1}) {
  final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(iso.trim());
  if (match == null) return null;
  final count = int.parse(match.group(1)!) * (times < 1 ? 1 : times);
  if (count <= 0) return null;
  final unit = switch (match.group(2)) {
    'D' => TrialUnit.day,
    'W' => TrialUnit.week,
    'M' => TrialUnit.month,
    _ => TrialUnit.year,
  };
  return FreeTrial(count, unit);
}

SubscriptionOfferDetailsWrapper? _playOffer(GooglePlayProductDetails p) {
  final index = p.subscriptionIndex;
  final offers = p.productDetails.subscriptionOfferDetails;
  if (index == null || offers == null || index >= offers.length) return null;
  return offers[index];
}

/// The free trial this store entry starts with, or null.
FreeTrial? freeTrialOf(ProductDetails p) {
  if (p is GooglePlayProductDetails) {
    final offer = _playOffer(p);
    if (offer == null || offer.offerId == null) return null;
    final phases = offer.pricingPhases;
    if (phases.length < 2) return null;
    final first = phases.first;
    if (first.priceAmountMicros != 0) return null;
    return parseIsoPeriod(first.billingPeriod, times: first.billingCycleCount);
  }
  if (p is AppStoreProductDetails) {
    final intro = p.skProduct.introductoryPrice;
    if (intro == null ||
        intro.paymentMode != SKProductDiscountPaymentMode.freeTrail) {
      return null;
    }
    final period = intro.subscriptionPeriod;
    final unit = switch (period.unit) {
      SKSubscriptionPeriodUnit.day => TrialUnit.day,
      SKSubscriptionPeriodUnit.week => TrialUnit.week,
      SKSubscriptionPeriodUnit.month => TrialUnit.month,
      SKSubscriptionPeriodUnit.year => TrialUnit.year,
    };
    final periods = intro.numberOfPeriods < 1 ? 1 : intro.numberOfPeriods;
    final count = period.numberOfUnits * periods;
    return count > 0 ? FreeTrial(count, unit) : null;
  }
  return null;
}

/// True for a Play base-plan entry (no offer) and for every non-Play entry.
bool isBasePlan(ProductDetails p) =>
    p is! GooglePlayProductDetails || _playOffer(p)?.offerId == null;

/// The price the customer pays once any intro phase is over.
String regularPriceOf(ProductDetails p) {
  if (p is GooglePlayProductDetails) {
    final phases = _playOffer(p)?.pricingPhases;
    if (phases != null && phases.isNotEmpty) return phases.last.formattedPrice;
  }
  return p.price;
}

/// One store's view of one product id: its regular price and, when the
/// customer can use it, its free trial and the entry to buy it with.
class StorePlan {
  final String id;
  final String title;
  final String description;
  final String price;
  final FreeTrial? freeTrial;
  final ProductDetails purchaseDetails;

  const StorePlan({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.freeTrial,
    required this.purchaseDetails,
  });
}

/// Collapses the store's per-offer entries into one plan per product id.
/// [trialEligible] filters App Store trials (Play already filters offers).
List<StorePlan> collapseStorePlans(
  Iterable<ProductDetails> details, {
  bool Function(String productId) trialEligible = _always,
}) {
  final byId = <String, List<ProductDetails>>{};
  for (final d in details) {
    byId.putIfAbsent(d.id, () => []).add(d);
  }
  return [
    for (final entry in byId.entries)
      _plan(entry.key, entry.value, trialEligible(entry.key)),
  ];
}

bool _always(String _) => true;

StorePlan _plan(String id, List<ProductDetails> entries, bool eligible) {
  final base = entries.where(isBasePlan).firstOrNull ?? entries.first;
  final withTrial = eligible
      ? entries.where((e) => freeTrialOf(e) != null).firstOrNull
      : null;
  final buyWith = withTrial ?? base;
  return StorePlan(
    id: id,
    title: base.title,
    description: base.description,
    price: regularPriceOf(base),
    freeTrial: withTrial == null ? null : freeTrialOf(withTrial),
    purchaseDetails: buyWith,
  );
}
