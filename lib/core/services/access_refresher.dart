import 'package:spellbee/core/models/premium_state.dart';
import 'package:spellbee/core/services/iap_service.dart';

/// Decides what the app asks the store / verification server at launch and
/// when it returns to the foreground. Kept out of main() so the platform
/// rules are unit-tested.
class AccessRefresher {
  AccessRefresher({
    required this.iap,
    required this.cachedPremium,
    required this.isAndroid,
  });

  final IapService iap;
  final PremiumState Function() cachedPremium;
  final bool isAndroid;

  Future<void> onLaunch() async {
    if (isAndroid) {
      // Play's queryPurchases is local and silent. Running it even with no
      // cached entitlement re-delivers a purchase stranded by a verification
      // outage, so it is verified and acknowledged before Play's 3-day
      // auto-refund.
      await iap.restore(silent: true).catchError((_) {});
    } else if (cachedPremium().activeProductId != null) {
      await iap.restore(silent: true).catchError((_) {});
    }
    await iap.retryPendingVerifications(force: true);
  }

  Future<void> onResume() async {
    iap.setForeground(true);
    if (cachedPremium().activeProductId != null) {
      await iap.restore(silent: true).catchError((_) {});
    }
    await iap.retryPendingVerifications(force: true);
  }

  void onBackground() => iap.setForeground(false);
}
