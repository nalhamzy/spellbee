import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:spellbee/core/constants/iap_ids.dart';

class IapProduct {
  final String id;
  final String title;
  final String price;
  final String description;
  const IapProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
  });
}

/// Thin wrapper around in_app_purchase.
///
/// Entitlement is persisted by [persistEntitlement] — wired in main() BEFORE
/// the purchase stream is subscribed — so a transaction delivered at launch
/// (interrupted purchase, Ask to Buy approval, restore) lands in storage
/// even when no screen has attached its snackbar callbacks yet. The UI
/// callbacks are decoration; the money path must not depend on them.
class IapService {
  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _available = false;

  /// Persists the entitlement. MUST be set before [initialize].
  Future<void> Function(String productId)? persistEntitlement;

  void Function(String productId)? onPurchaseSuccess;
  void Function(String message)? onPurchaseError;

  InAppPurchase get _store => _iap ??= InAppPurchase.instance;

  Future<void> initialize() async {
    await _ensureListening();
  }

  /// Subscribe to the purchase stream, retrying availability each call.
  /// isAvailable() is false transiently on Android (billing service not yet
  /// bound, Play Store updating); giving up permanently on the first launch
  /// check meant a later successful buy() had NO listener — the user paid,
  /// nothing handled the purchase, and Google auto-refunded after 3 days.
  Future<bool> _ensureListening() async {
    if (_sub != null) return true;
    _available = await _store.isAvailable();
    if (!_available) return false;
    _sub = _store.purchaseStream.listen(
      _handle,
      onDone: () => _sub?.cancel(),
      onError: (e) => onPurchaseError?.call(e.toString()),
    );
    return true;
  }

  Future<List<IapProduct>> loadProducts() async {
    if (!await _ensureListening()) return const [];
    final resp = await _store.queryProductDetails(IapProductIds.all);
    return resp.productDetails
        .map(
          (p) => IapProduct(
            id: p.id,
            title: p.title,
            price: p.price,
            description: p.description,
          ),
        )
        .toList();
  }

  Future<void> buy(String productId) async {
    if (!await _ensureListening()) {
      onPurchaseError?.call('Purchases are not available on this device.');
      return;
    }
    final resp = await _store.queryProductDetails({productId});
    if (resp.productDetails.isEmpty) {
      onPurchaseError?.call('Store did not return that product.');
      return;
    }
    final p = PurchaseParam(productDetails: resp.productDetails.first);
    // in_app_purchase routes subscriptions through buyNonConsumable too.
    await _store.buyNonConsumable(purchaseParam: p);
  }

  Future<void> restore({bool silent = false}) async {
    if (!await _ensureListening()) {
      if (!silent) {
        onPurchaseError?.call('Purchases are not available on this device.');
      }
      return;
    }
    await _store.restorePurchases();
  }

  void _handle(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.canceled:
          // A user closing the payment sheet is not an error; stay quiet.
          if (p.pendingCompletePurchase) _store.completePurchase(p);
          break;
        case PurchaseStatus.error:
          onPurchaseError?.call(p.error?.message ?? 'Purchase failed.');
          if (p.pendingCompletePurchase) _store.completePurchase(p);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _grant(p);
          break;
      }
    }
  }

  Future<void> _grant(PurchaseDetails p) async {
    try {
      // Persist BEFORE completing: once completePurchase acknowledges the
      // transaction the store never redelivers it, so completing first and
      // persisting second turns any write hiccup into a paid-but-locked
      // customer.
      await persistEntitlement?.call(p.productID);
      onPurchaseSuccess?.call(p.productID);
    } finally {
      if (p.pendingCompletePurchase) await _store.completePurchase(p);
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
