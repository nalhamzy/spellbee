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

/// Thin wrapper around in_app_purchase. Caller sets [onPurchaseSuccess]
/// which fires with the product ID when a purchase is verified.
class IapService {
  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _available = false;

  void Function(String productId)? onPurchaseSuccess;
  void Function(String message)? onPurchaseError;

  InAppPurchase get _store => _iap ??= InAppPurchase.instance;

  Future<void> initialize() async {
    _available = await _store.isAvailable();
    if (!_available || _sub != null) return;
    _sub = _store.purchaseStream.listen(
      _handle,
      onDone: () => _sub?.cancel(),
      onError: (e) => onPurchaseError?.call(e.toString()),
    );
  }

  Future<List<IapProduct>> loadProducts() async {
    if (!_available && !await _store.isAvailable()) return const [];
    _available = true;
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
    if (!_available && !await _store.isAvailable()) {
      onPurchaseError?.call('Purchases are not available on this device.');
      return;
    }
    _available = true;
    final resp = await _store.queryProductDetails({productId});
    if (resp.productDetails.isEmpty) {
      onPurchaseError?.call('Store did not return that product.');
      return;
    }
    final p = PurchaseParam(productDetails: resp.productDetails.first);
    if (IapProductIds.nonConsumableIds.contains(productId)) {
      await _store.buyNonConsumable(purchaseParam: p);
    } else {
      await _store.buyNonConsumable(purchaseParam: p); // subs also use this API
    }
  }

  Future<void> restore() async {
    if (!_available && !await _store.isAvailable()) {
      onPurchaseError?.call('Purchases are not available on this device.');
      return;
    }
    _available = true;
    await _store.restorePurchases();
  }

  void _handle(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          onPurchaseError?.call(p.error?.message ?? 'Purchase was cancelled.');
          if (p.pendingCompletePurchase) _store.completePurchase(p);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          onPurchaseSuccess?.call(p.productID);
          if (p.pendingCompletePurchase) _store.completePurchase(p);
          break;
      }
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
