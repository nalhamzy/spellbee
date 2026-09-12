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
  IapService({InAppPurchase? store}) : _iap = store;

  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Future<bool>? _connecting;
  Future<void> _updates = Future<void>.value();
  final _delivered = <String, bool>{};
  final _completed = <String>{};
  bool _disposed = false;
  bool _startingPurchase = false;
  int _silentRestores = 0;

  /// Persists the entitlement. MUST be set before [initialize].
  Future<bool> Function(PurchaseDetails purchase)? persistEntitlement;
  Future<void> Function()? refreshEntitlement;

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
    if (_disposed) return false;
    if (_sub != null) return true;
    final pending = _connecting;
    if (pending != null) return pending;
    final connection = _connect();
    _connecting = connection;
    try {
      return await connection;
    } finally {
      _connecting = null;
    }
  }

  Future<bool> _connect() async {
    if (!await _store.isAvailable() || _disposed) return false;
    _sub = _store.purchaseStream.listen(
      (purchases) {
        // Stream.listen does not await async handlers. Queue batches so a
        // restore or redelivery cannot race an unfinished entitlement write.
        _updates = _updates.then((_) => _handle(purchases));
      },
      onDone: () => _sub = null,
      onError: (_) =>
          _reportError('The store connection was interrupted. Try Restore.'),
    );
    return true;
  }

  Future<List<IapProduct>> loadProducts() async {
    if (!await _ensureListening()) return const [];
    final resp = await _store.queryProductDetails(IapProductIds.all);
    return resp.productDetails
        .where((p) => IapProductIds.all.contains(p.id))
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
    if (_startingPurchase) return;
    _startingPurchase = true;
    try {
      await _buy(productId);
    } finally {
      _startingPurchase = false;
    }
  }

  Future<void> _buy(String productId) async {
    if (!IapProductIds.all.contains(productId)) {
      _reportError('This plan is not available. Please choose another plan.');
      return;
    }
    if (!await _ensureListening()) {
      _reportError('Purchases are not available on this device.');
      return;
    }
    final resp = await _store.queryProductDetails({productId});
    final product = resp.productDetails
        .where((p) => p.id == productId)
        .firstOrNull;
    if (product == null) {
      _reportError('The store could not load this plan. Please try again.');
      return;
    }
    final p = PurchaseParam(productDetails: product);
    // in_app_purchase routes subscriptions through buyNonConsumable too.
    if (!await _store.buyNonConsumable(purchaseParam: p)) {
      _reportError('The store could not start the purchase. Please try again.');
    }
  }

  Future<void> restore({bool silent = false}) async {
    if (!await _ensureListening()) {
      if (!silent) {
        _reportError('Purchases are not available on this device.');
      }
      return;
    }
    if (silent) _silentRestores++;
    try {
      // The saved proof can expose a refund omitted from native restore.
      // A failed refresh must not prevent native store recovery.
      await refreshEntitlement?.call().catchError((_) {});
      await _updates;
      // Restore must reverify previously delivered transactions so a renewal
      // or refund is visible without restarting the app.
      _delivered.clear();
      _completed.clear();
      await _store.restorePurchases();
      await _updates;
    } finally {
      if (silent) _silentRestores--;
    }
  }

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      try {
        switch (p.status) {
          case PurchaseStatus.pending:
            break;
          case PurchaseStatus.canceled:
            // A user closing the payment sheet is not an error; stay quiet.
            if (p.pendingCompletePurchase) await _store.completePurchase(p);
            break;
          case PurchaseStatus.error:
            _reportError(p.error?.message ?? 'Purchase failed.');
            if (p.pendingCompletePurchase) await _store.completePurchase(p);
            break;
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await _grant(p);
            break;
        }
      } catch (_) {
        // Leave unsuccessful delivery/completion pending for redelivery or
        // Restore. One failed transaction must not block the next batch.
        _reportError(
          'We could not finish saving your purchase. Please try Restore.',
        );
      }
    }
  }

  Future<void> _grant(PurchaseDetails p) async {
    if (!IapProductIds.all.contains(p.productID)) {
      _reportError(
        'The store returned an unrecognized purchase. Please contact support.',
      );
      return;
    }
    final persist = persistEntitlement;
    if (persist == null) throw StateError('Entitlement storage is not ready');
    // Without a transaction ID, do not accidentally merge distinct purchases.
    final id = p.purchaseID;
    final key = id == null || id.isEmpty
        ? null
        : '${p.productID}:$id:${p.transactionDate}';
    if (key != null && _completed.contains(key)) return;
    bool active;
    if (key == null || !_delivered.containsKey(key)) {
      active = await persist(p);
      if (key != null) _delivered[key] = active;
    } else {
      active = _delivered[key]!;
    }
    // Only acknowledge AFTER successful persistence. A completion failure can
    // retry without extending the entitlement or repeating delivery.
    if (p.pendingCompletePurchase) await _store.completePurchase(p);
    if (key != null) _completed.add(key);
    try {
      if (active && _silentRestores == 0) onPurchaseSuccess?.call(p.productID);
    } catch (_) {
      // A UI callback must not change the outcome of a completed transaction.
    }
  }

  void _reportError(String message) {
    if (_silentRestores > 0) return;
    try {
      onPurchaseError?.call(message);
    } catch (_) {
      // Notification failures must not poison the transaction queue.
    }
  }

  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _sub = null;
  }
}
