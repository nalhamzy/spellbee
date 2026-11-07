import 'package:spellbee/core/models/premium_state.dart';
import 'package:spellbee/core/services/iap_service.dart';

/// Decides what the app asks the store / verification server at launch and
/// when it returns to the foreground. Kept out of main() so the platform
/// rules are unit-tested.
///
/// iOS never calls restoreCompletedTransactions on its own except to migrate
/// a legacy (pre-verification) cache: Apple reserves it for a user action,
/// it can raise an Apple ID sign-in sheet, and it re-delivers every historic
/// transaction (one verification request each). StoreKit already delivers
/// renewals and unfinished transactions to the live observer, and the
/// server's subscription-status lookup keeps the cached expiry current.
class AccessRefresher {
  AccessRefresher({
    required this.iap,
    required this.cachedPremium,
    required this.isAndroid,
    DateTime Function()? clock,
    this.resumeRefreshInterval = const Duration(minutes: 15),
  }) : _clock = clock ?? DateTime.now;

  final IapService iap;
  final PremiumState Function() cachedPremium;
  final bool isAndroid;
  final Duration resumeRefreshInterval;
  final DateTime Function() _clock;
  DateTime? _lastRefresh;

  Future<void> onLaunch() async {
    final cached = cachedPremium();
    if (isAndroid) {
      // Play's queryPurchases is local and silent. Running it even with no
      // cached entitlement re-delivers a purchase stranded by a verification
      // outage, so it is verified and acknowledged before Play's 3-day
      // auto-refund.
      _lastRefresh = _clock();
      await iap.restore(silent: true);
    } else if (cached.activeProductId != null &&
        !cached.canRefresh &&
        cached.isPremium) {
      // Legacy cache without a saved proof: migrate it once through restore.
      _lastRefresh = _clock();
      await iap.restore(silent: true);
    } else if (cached.canRefresh) {
      _lastRefresh = _clock();
      await iap.refreshCachedEntitlement();
    }
    await iap.retryPendingVerifications(force: true);
  }

  Future<void> onResume() async {
    iap.setForeground(true);
    final cached = cachedPremium();
    if (cached.canRefresh && _refreshDue(cached)) {
      _lastRefresh = _clock();
      await iap.refreshCachedEntitlement();
    }
    if (isAndroid) {
      // Google's guidance: query purchases on resume to catch purchases
      // that completed while the app was away (cash / pending payments).
      // Already-handled purchases are not re-verified.
      await iap.redeliverPurchases();
    }
    await iap.retryPendingVerifications(force: true);
  }

  void onBackground() => iap.setForeground(false);

  bool _refreshDue(PremiumState cached) {
    final now = _clock();
    final last = _lastRefresh;
    if (last == null || now.difference(last) >= resumeRefreshInterval) {
      return true;
    }
    // A subscription that just reached its expiry is re-checked at once so a
    // renewal is not missed for the throttle window.
    final expiry = cached.expiresAt;
    return expiry != null && !expiry.isAfter(now) && last.isBefore(expiry);
  }
}
