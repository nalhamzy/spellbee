import 'dart:async';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/services/pending_verification.dart';

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
///
/// A purchase whose server verification fails is never completed and never
/// forgotten: it is held as a [PendingVerification] marker and retried with
/// [VerificationBackoff] on launch, on resume and on a timer while the app is
/// in the foreground, until verification succeeds.
class IapService {
  IapService({
    InAppPurchase? store,
    PendingVerificationStore? pendingStore,
    bool? redeliverByRestore,
    DateTime Function()? clock,
  }) : _iap = store,
       _pending = pendingStore ?? InMemoryPendingVerificationStore(),
       _redeliverByRestore =
           redeliverByRestore ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android),
       _clock = clock ?? DateTime.now;

  InAppPurchase? _iap;
  final PendingVerificationStore _pending;

  /// Android: `restorePurchases()` is Play's `queryPurchases`, which hands an
  /// unacknowledged purchase back without any UI. iOS: StoreKit re-delivers
  /// unfinished transactions by itself, and restoreCompletedTransactions is
  /// reserved for an explicit parent tap, so iOS verifies the saved proof.
  final bool _redeliverByRestore;
  final DateTime Function() _clock;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Future<bool>? _connecting;
  Future<void> _updates = Future<void>.value();
  final _delivered = <String, bool>{};
  final _completed = <String>{};

  /// Native transactions held back while their verification is pending,
  /// keyed by [PendingVerification.key].
  final _awaiting = <String, PurchaseDetails>{};
  bool _disposed = false;
  bool _startingPurchase = false;
  bool _retrying = false;
  bool _foreground = true;
  Timer? _retryTimer;
  int _silentRestores = 0;

  /// Persists the entitlement. MUST be set before [initialize].
  Future<bool> Function(PurchaseDetails purchase)? persistEntitlement;
  Future<void> Function()? refreshEntitlement;

  /// Verifies a pending marker from its saved proof when the native
  /// transaction is not in memory (used where [_redeliverByRestore] is off).
  Future<bool> Function(PendingVerification pending)? verifyPending;

  void Function(String productId)? onPurchaseSuccess;
  void Function(String message)? onPurchaseError;

  /// A purchase was received but is still being confirmed. Not an error.
  void Function(String productId)? onPurchasePending;

  /// The set of pending markers changed (added, retried away, expired).
  void Function()? onPendingChanged;

  InAppPurchase get _store => _iap ??= InAppPurchase.instance;

  bool get hasPendingVerification =>
      _pending.loadPendingVerifications().isNotEmpty;

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

  // ── Pending verification retries ────────────────────────────────────

  /// The app came to the foreground (true) or left it (false). Retries only
  /// run on a timer while foregrounded; nothing polls in the background.
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }

  /// Retries every pending verification that is due. [force] (launch and
  /// resume) skips the backoff but still respects
  /// [VerificationBackoff.minimumGap].
  Future<void> retryPendingVerifications({bool force = false}) async {
    if (_disposed || _retrying) return;
    _retrying = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      final startedAt = _clock();
      final all = _pending.loadPendingVerifications();
      final live = all
          .where((m) => !VerificationBackoff.isExpired(m, startedAt))
          .toList();
      if (live.length != all.length) {
        for (final stale in all.where((m) => !live.contains(m))) {
          _awaiting.remove(stale.key);
        }
        await _savePending(live);
      }
      final due = live
          .where((m) => VerificationBackoff.isDue(m, startedAt, force: force))
          .toList();
      if (due.isEmpty) return;

      final detached = <PendingVerification>[];
      for (final marker in due) {
        final purchase = _awaiting[marker.key];
        if (purchase == null) {
          detached.add(marker);
        } else {
          _updates = _updates.then((_) => _handle([purchase]));
        }
      }
      await _updates;
      if (detached.isNotEmpty) {
        if (_redeliverByRestore) {
          await _redeliver();
        } else {
          for (final marker in detached) {
            await _verifyDetached(marker);
          }
        }
      }
      // A due marker nothing could attempt (Play no longer returns it, no
      // proof verifier) still counts, so its backoff keeps growing.
      final after = _pending.loadPendingVerifications();
      var changed = false;
      for (var i = 0; i < after.length; i++) {
        final m = after[i];
        final wasDue = due.any((d) => d.key == m.key);
        final attempted =
            m.lastAttempt != null && !m.lastAttempt!.isBefore(startedAt);
        if (wasDue && !attempted) {
          after[i] = m.failedAttempt(_clock());
          changed = true;
        }
      }
      if (changed) await _savePending(after, notify: false);
    } finally {
      _retrying = false;
      _scheduleRetry();
    }
  }

  /// Play's queryPurchases re-delivers unacknowledged purchases into the
  /// purchase stream; [_grant] then verifies and acknowledges them.
  Future<void> _redeliver() async {
    if (!await _ensureListening()) return;
    _silentRestores++;
    try {
      await _store.restorePurchases();
      await _updates;
    } catch (_) {
      // Store unreachable: the marker's backoff grows and we try again.
    } finally {
      _silentRestores--;
    }
  }

  Future<void> _verifyDetached(PendingVerification marker) async {
    final verify = verifyPending;
    if (verify == null) return;
    final bool active;
    try {
      active = await verify(marker);
    } catch (_) {
      await _recordFailure(marker.key);
      return;
    }
    // Access is saved. StoreKit finishes the native transaction when it
    // re-delivers it; [_grant] then completes it without a second unlock.
    _awaiting.remove(marker.key);
    await _savePending(
      _pending
          .loadPendingVerifications()
          .where((m) => m.key != marker.key)
          .toList(),
    );
    if (active) _notifySuccess(marker.productId);
  }

  Future<void> _recordFailure(String key) async {
    final items = _pending.loadPendingVerifications();
    final index = items.indexWhere((m) => m.key == key);
    if (index < 0) return;
    items[index] = items[index].failedAttempt(_clock());
    await _savePending(items, notify: false);
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_disposed || !_foreground) return;
    final items = _pending.loadPendingVerifications();
    if (items.isEmpty) return;
    final next = items
        .map(VerificationBackoff.nextAttemptAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    var delay = next.difference(_clock());
    if (delay < const Duration(seconds: 5)) delay = const Duration(seconds: 5);
    _retryTimer = Timer(delay, () => retryPendingVerifications());
  }

  Future<void> _savePending(
    List<PendingVerification> items, {
    bool notify = true,
  }) async {
    try {
      await _pending.savePendingVerifications(items);
    } catch (_) {
      // The in-memory hold still protects this session's transaction.
    }
    if (notify) {
      try {
        onPendingChanged?.call();
      } catch (_) {
        // UI refresh must not affect the money path.
      }
    }
  }

  /// Only purchases at risk of being lost are held: a fresh purchase, or an
  /// unacknowledged purchase Play handed back through queryPurchases.
  bool _holdsForRetry(PurchaseDetails p) =>
      purchaseCredential(p).isNotEmpty &&
      (p.status == PurchaseStatus.purchased ||
          (p.status == PurchaseStatus.restored &&
              p.pendingCompletePurchase &&
              _redeliverByRestore));

  Future<void> _holdForRetry(PurchaseDetails p) async {
    final credential = purchaseCredential(p);
    final key = PendingVerification.keyFor(p.productID, credential);
    final now = _clock();
    final items = _pending.loadPendingVerifications();
    final index = items.indexWhere((m) => m.key == key);
    final isNew = index < 0;
    if (isNew) {
      items.add(
        PendingVerification(
          productId: p.productID,
          source: p.verificationData.source,
          credential: credential,
          purchaseId: p.purchaseID,
          firstSeen: now,
          attempts: 1,
          lastAttempt: now,
        ),
      );
    } else {
      items[index] = items[index].failedAttempt(now);
    }
    _awaiting[key] = p;
    await _savePending(items, notify: isNew);
    if (isNew && _silentRestores == 0) {
      try {
        onPurchasePending?.call(p.productID);
      } catch (_) {
        // Notification failures must not poison the transaction queue.
      }
    }
    if (!_retrying) _scheduleRetry();
  }

  /// Returns true when a pending marker for [p] existed and was cleared.
  Future<bool> _releasePending(PurchaseDetails p) async {
    final key = PendingVerification.keyFor(p.productID, purchaseCredential(p));
    _awaiting.remove(key);
    final items = _pending.loadPendingVerifications();
    final remaining = items.where((m) => m.key != key).toList();
    if (remaining.length == items.length) return false;
    await _savePending(remaining);
    if (remaining.isEmpty) {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
    return true;
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
    var wasPending = false;
    if (key == null || !_delivered.containsKey(key)) {
      try {
        active = await persist(p);
      } catch (_) {
        // Verification or the local write failed. Keep the transaction
        // un-completed and keep retrying instead of losing the purchase.
        if (!_holdsForRetry(p)) rethrow;
        await _holdForRetry(p);
        return;
      }
      if (key != null) _delivered[key] = active;
      wasPending = await _releasePending(p);
    } else {
      active = _delivered[key]!;
    }
    // Only acknowledge AFTER successful persistence. A completion failure can
    // retry without extending the entitlement or repeating delivery.
    if (p.pendingCompletePurchase) await _store.completePurchase(p);
    if (key != null) _completed.add(key);
    // A purchase that was waiting on verification is announced even when it
    // was recovered by a silent launch-time redelivery.
    if (active && (_silentRestores == 0 || wasPending)) {
      _notifySuccess(p.productID);
    }
  }

  void _notifySuccess(String productId) {
    try {
      onPurchaseSuccess?.call(productId);
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
    _retryTimer?.cancel();
    _retryTimer = null;
    _sub?.cancel();
    _sub = null;
  }
}
