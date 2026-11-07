import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/models/premium_state.dart';
import 'package:spellbee/core/services/access_refresher.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/pending_verification.dart';
import 'package:spellbee/core/services/storage_service.dart';

class RejectingPreferences extends Fake implements SharedPreferences {
  @override
  Future<bool> setString(String key, String value) async => false;
}

class FakeStore extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <String?>[];
  final started = <String>[];
  bool available = true;
  bool completeFails = false;
  bool startsPurchase = true;
  int availabilityChecks = 0;
  Completer<bool>? availabilityGate;
  List<ProductDetails> products = [];
  List<PurchaseDetails> restoredPurchases = [];
  int restoreCalls = 0;
  bool restoreThrows = false;

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
    if (restoreThrows) throw StateError('Store offline');
    updates.add(restoredPurchases);
    await pumpEventQueue();
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return availabilityGate == null
        ? available
        : await availabilityGate!.future;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(productDetails: products, notFoundIDs: []);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (completeFails) throw StateError('Store unavailable');
    completed.add(purchase.purchaseID);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    started.add(purchaseParam.productDetails.id);
    return startsPurchase;
  }
}

PurchaseDetails transaction({
  String? id = 'purchase-1',
  String productId = IapProductIds.premiumYearly,
  PurchaseStatus status = PurchaseStatus.purchased,
  String token = '',
}) => PurchaseDetails(
  purchaseID: id,
  productID: productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: token,
    source: 'test',
  ),
  transactionDate: '1000',
  status: status,
)..pendingCompletePurchase = true;

ProductDetails product(String id) => ProductDetails(
  id: id,
  title: id,
  description: '',
  price: 'AED 99',
  rawPrice: 99,
  currencyCode: 'AED',
);

void main() {
  late FakeStore store;
  late IapService service;
  late List<String> saved;
  late List<String> errors;
  late List<String> successes;

  setUp(() {
    store = FakeStore();
    saved = [];
    errors = [];
    successes = [];
    service = IapService(store: store)
      ..persistEntitlement = (id) async {
        saved.add(id.productID);
        return true;
      }
      ..onPurchaseError = errors.add
      ..onPurchaseSuccess = successes.add;
  });

  tearDown(() async {
    service.dispose();
    await store.updates.close();
  });

  Future<void> emit(PurchaseDetails purchase) async {
    store.updates.add([purchase]);
    await pumpEventQueue();
  }

  test('does not acknowledge until access is saved', () async {
    final gate = Completer<void>();
    service.persistEntitlement = (_) async {
      await gate.future;
      return true;
    };
    await service.initialize();
    await emit(transaction());
    expect(store.completed, isEmpty);
    expect(successes, isEmpty);
    gate.complete();
    await pumpEventQueue();
    expect(store.completed, ['purchase-1']);
    expect(successes, [IapProductIds.premiumYearly]);
  });

  test('failed persistence remains recoverable on restore', () async {
    service.persistEntitlement = (_) async {
      throw StateError('Disk full');
    };
    await service.initialize();
    await emit(transaction());
    expect(store.completed, isEmpty);
    expect(successes, isEmpty);
    expect(errors.single, contains('Restore'));
    service.persistEntitlement = (id) async {
      saved.add(id.productID);
      return true;
    };
    await emit(transaction(status: PurchaseStatus.restored));
    expect(saved, [IapProductIds.premiumYearly]);
    expect(store.completed, ['purchase-1']);
  });

  test('missing persistence handler cannot acknowledge a purchase', () async {
    service.persistEntitlement = null;
    await service.initialize();
    await emit(transaction());
    expect(store.completed, isEmpty);
    expect(errors, hasLength(1));
  });

  test(
    'verified inactive purchase completes without reporting an unlock',
    () async {
      service.persistEntitlement = (_) async => false;
      await service.initialize();
      await emit(transaction());
      expect(store.completed, ['purchase-1']);
      expect(successes, isEmpty);
    },
  );

  test('explicit restore rechecks a previously delivered purchase', () async {
    await service.initialize();
    await emit(transaction());
    store.restoredPurchases = [transaction(status: PurchaseStatus.restored)];
    await service.restore();
    expect(saved, hasLength(2));
  });

  test(
    'silent restore refreshes cached refunds without an unlock message',
    () async {
      var refreshes = 0;
      service.refreshEntitlement = () async {
        refreshes++;
      };
      store.restoredPurchases = [transaction(status: PurchaseStatus.restored)];
      await service.restore(silent: true);
      expect(refreshes, 1);
      expect(saved, hasLength(1));
      expect(successes, isEmpty);
    },
  );

  test('failed cached refresh still allows native restore recovery', () async {
    service.refreshEntitlement = () async {
      throw StateError('Offline');
    };
    store.restoredPurchases = [transaction(status: PurchaseStatus.restored)];
    await service.restore();
    expect(saved, hasLength(1));
    expect(store.completed, ['purchase-1']);
  });

  test('storage returning false leaves the transaction pending', () async {
    final storage = StorageService(RejectingPreferences());
    service.persistEntitlement = (id) async {
      await storage.savePremium(
        PremiumState(
          activeProductId: id.productID,
          activatedAt: DateTime.now(),
        ),
      );
      return true;
    };
    await service.initialize();
    await emit(transaction());
    expect(store.completed, isEmpty);
    expect(successes, isEmpty);
    expect(errors, hasLength(1));
  });

  test('one failed delivery does not block a later purchase', () async {
    service.persistEntitlement = (id) async {
      if (id.productID == IapProductIds.premiumYearly) {
        throw StateError('Write failed');
      }
      saved.add(id.productID);
      return true;
    };
    await service.initialize();
    store.updates.add([
      transaction(),
      transaction(id: 'purchase-2', productId: IapProductIds.premiumLifetime),
    ]);
    await pumpEventQueue();
    expect(store.completed, ['purchase-2']);
    expect(saved, [IapProductIds.premiumLifetime]);
    expect(errors, hasLength(1));
  });

  test(
    'serializes batches and delivers duplicate transactions only once',
    () async {
      final gate = Completer<void>();
      service.persistEntitlement = (id) async {
        saved.add(id.productID);
        await gate.future;
        return true;
      };
      await service.initialize();
      await emit(transaction());
      await emit(transaction(status: PurchaseStatus.restored));
      await emit(
        transaction(id: 'purchase-2', productId: IapProductIds.premiumLifetime),
      );
      expect(saved, [IapProductIds.premiumYearly]);
      gate.complete();
      await pumpEventQueue();
      expect(saved, [
        IapProductIds.premiumYearly,
        IapProductIds.premiumLifetime,
      ]);
      expect(store.completed, ['purchase-1', 'purchase-2']);
      expect(successes, hasLength(2));
    },
  );

  test('completion retry does not persist access a second time', () async {
    store.completeFails = true;
    await service.initialize();
    await emit(transaction());
    expect(saved, hasLength(1));
    expect(store.completed, isEmpty);
    store.completeFails = false;
    await emit(transaction(status: PurchaseStatus.restored));
    expect(saved, hasLength(1));
    expect(store.completed, ['purchase-1']);
    expect(successes, hasLength(1));
  });

  test('a throwing UI callback cannot block later transactions', () async {
    service.onPurchaseSuccess = (_) => throw StateError('Widget disposed');
    await service.initialize();
    await emit(transaction());
    await emit(transaction(id: 'purchase-2'));
    expect(store.completed, ['purchase-1', 'purchase-2']);
    expect(errors, isEmpty);
  });

  test('unknown products never grant access', () async {
    await service.initialize();
    await emit(transaction(productId: 'another_app_premium'));
    expect(saved, isEmpty);
    expect(store.completed, isEmpty);
    expect(errors.single, contains('unrecognized'));
  });

  test('pending and canceled events do not grant access', () async {
    await service.initialize();
    await emit(transaction(status: PurchaseStatus.pending));
    expect(store.completed, isEmpty);
    await emit(transaction(status: PurchaseStatus.canceled));
    expect(saved, isEmpty);
    expect(errors, isEmpty);
  });

  test(
    'simultaneous initialization shares a single store connection',
    () async {
      store.availabilityGate = Completer<bool>();
      final first = service.initialize();
      final second = service.loadProducts();
      store.availabilityGate!.complete(true);
      await Future.wait([first, second]);
      expect(store.availabilityChecks, 1);
      await emit(transaction());
      expect(saved, hasLength(1));
    },
  );

  test('unavailable store can recover on a later call', () async {
    store.available = false;
    await service.initialize();
    store.available = true;
    await service.initialize();
    await emit(transaction());
    expect(store.availabilityChecks, 2);
    expect(store.completed, ['purchase-1']);
  });

  test('disposing during connection does not attach a late listener', () async {
    store.availabilityGate = Completer<bool>();
    final initialization = service.initialize();
    service.dispose();
    store.availabilityGate!.complete(true);
    await initialization;
    expect(store.updates.hasListener, isFalse);
  });

  test('purchase query must return the exact selected product', () async {
    store.products = [product(IapProductIds.premiumLifetime)];
    await service.buy(IapProductIds.premiumYearly);
    expect(store.started, isEmpty);
    expect(errors, hasLength(1));
  });

  test('failed store launch is reported instead of silently ignored', () async {
    store.products = [product(IapProductIds.premiumYearly)];
    store.startsPurchase = false;
    await service.buy(IapProductIds.premiumYearly);
    expect(errors.single, contains('could not start'));
  });

  group('pending verification (verification outage)', () {
    late InMemoryPendingVerificationStore markers;
    late DateTime now;
    late List<String> pendings;
    late bool serverUp;
    late int verifyCalls;

    IapService build({required bool android, FakeStore? onStore}) {
      final s =
          IapService(
              store: onStore ?? store,
              pendingStore: markers,
              redeliverByRestore: android,
              clock: () => now,
            )
            ..persistEntitlement = (p) async {
              verifyCalls++;
              if (!serverUp) {
                throw StateError('Store verification is unavailable');
              }
              saved.add(p.productID);
              return true;
            }
            ..onPurchaseError = errors.add
            ..onPurchaseSuccess = successes.add
            ..onPurchasePending = pendings.add;
      addTearDown(s.dispose);
      return s;
    }

    setUp(() {
      markers = InMemoryPendingVerificationStore();
      now = DateTime.utc(2026, 11, 7, 12);
      pendings = [];
      serverUp = false;
      verifyCalls = 0;
    });

    PurchaseDetails fresh() => transaction(token: 'play-token-1');

    test(
      'a purchase whose verification fails is held and announced calmly',
      () async {
        service = build(android: true);
        await service.initialize();
        await emit(fresh());
        expect(store.completed, isEmpty, reason: 'never acknowledged');
        expect(errors, isEmpty, reason: 'no error for a received purchase');
        expect(pendings, [IapProductIds.premiumYearly]);
        expect(service.hasPendingVerification, isTrue);
        final marker = markers.loadPendingVerifications().single;
        expect(marker.credential, 'play-token-1');
        expect(marker.attempts, 1);
      },
    );

    test('a due retry verifies, acknowledges and clears the marker', () async {
      service = build(android: true);
      await service.initialize();
      await emit(fresh());
      serverUp = true;
      now = now.add(const Duration(seconds: 31));
      await service.retryPendingVerifications();
      expect(saved, [IapProductIds.premiumYearly]);
      expect(store.completed, ['purchase-1']);
      expect(successes, [IapProductIds.premiumYearly]);
      expect(service.hasPendingVerification, isFalse);
    });

    test('retries back off while the server stays down', () async {
      service = build(android: true);
      await service.initialize();
      await emit(fresh());
      expect(verifyCalls, 1);

      // Not due yet: the first retry waits 30 s.
      now = now.add(const Duration(seconds: 10));
      await service.retryPendingVerifications();
      expect(verifyCalls, 1);

      now = now.add(const Duration(seconds: 21));
      await service.retryPendingVerifications();
      expect(verifyCalls, 2);
      expect(markers.loadPendingVerifications().single.attempts, 2);

      // Second gap is a minute.
      now = now.add(const Duration(seconds: 40));
      await service.retryPendingVerifications();
      expect(verifyCalls, 2);
      now = now.add(const Duration(seconds: 21));
      await service.retryPendingVerifications();
      expect(verifyCalls, 3);
      expect(store.completed, isEmpty);
      expect(errors, isEmpty);
      expect(pendings, hasLength(1), reason: 'announced once, not per retry');
    });

    test(
      'launch/resume retries skip the backoff but keep a minimum gap',
      () async {
        service = build(android: true);
        await service.initialize();
        await emit(fresh());
        now = now.add(const Duration(seconds: 3));
        await service.retryPendingVerifications(force: true);
        expect(verifyCalls, 1, reason: 'inside the 10 s minimum gap');
        now = now.add(const Duration(seconds: 8));
        await service.retryPendingVerifications(force: true);
        expect(verifyCalls, 2);
      },
    );

    test(
      'Android relaunch re-delivers the unacknowledged purchase via queryPurchases',
      () async {
        // Session 1: purchase arrives during an outage, app is killed.
        service = build(android: true);
        await service.initialize();
        await emit(fresh());
        service.dispose();

        // Session 2: a new process with only the persisted marker.
        final relaunched = FakeStore()
          ..restoredPurchases = [
            transaction(status: PurchaseStatus.restored, token: 'play-token-1'),
          ];
        addTearDown(relaunched.updates.close);
        serverUp = true;
        now = now.add(const Duration(hours: 5));
        final next = build(android: true, onStore: relaunched);
        await next.initialize();
        await next.retryPendingVerifications(force: true);
        expect(relaunched.restoreCalls, 1);
        expect(relaunched.completed, ['purchase-1']);
        expect(next.hasPendingVerification, isFalse);
        expect(
          successes,
          [IapProductIds.premiumYearly],
          reason: 'a recovered purchase is announced even though silent',
        );
      },
    );

    test(
      'Android relaunch while the server is still down keeps the marker',
      () async {
        service = build(android: true);
        await service.initialize();
        await emit(fresh());
        service.dispose();

        final relaunched = FakeStore()
          ..restoredPurchases = [
            transaction(status: PurchaseStatus.restored, token: 'play-token-1'),
          ];
        addTearDown(relaunched.updates.close);
        now = now.add(const Duration(minutes: 3));
        final next = build(android: true, onStore: relaunched);
        await next.initialize();
        await next.retryPendingVerifications(force: true);
        expect(relaunched.completed, isEmpty);
        expect(errors, isEmpty);
        expect(markers.loadPendingVerifications().single.attempts, 2);
      },
    );

    test('iOS relaunch verifies the saved proof without a restore', () async {
      service = build(android: false);
      await service.initialize();
      await emit(fresh());
      service.dispose();

      final relaunched = FakeStore();
      addTearDown(relaunched.updates.close);
      final checked = <String>[];
      now = now.add(const Duration(minutes: 3));
      final next = build(android: false, onStore: relaunched)
        ..verifyPending = (marker) async {
          checked.add(marker.credential);
          return true;
        };
      await next.initialize();
      await next.retryPendingVerifications(force: true);
      expect(relaunched.restoreCalls, 0, reason: 'no Apple ID prompt');
      expect(checked, ['play-token-1']);
      expect(next.hasPendingVerification, isFalse);
      expect(successes, [IapProductIds.premiumYearly]);
    });

    test('markers older than the retry window are dropped', () async {
      service = build(android: true);
      await service.initialize();
      await emit(fresh());
      now = now.add(VerificationBackoff.maxAge + const Duration(minutes: 1));
      await service.retryPendingVerifications(force: true);
      expect(service.hasPendingVerification, isFalse);
    });

    test('markers survive a restart through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      final marker = PendingVerification(
        productId: IapProductIds.premiumMonthly,
        source: 'google_play',
        credential: 'token',
        purchaseId: 'GPA.1',
        firstSeen: now,
        attempts: 2,
        lastAttempt: now,
      );
      await storage.savePendingVerifications([marker]);
      final reread = StorageService(
        await SharedPreferences.getInstance(),
      ).loadPendingVerifications().single;
      expect(reread.key, marker.key);
      expect(reread.attempts, 2);
      expect(reread.firstSeen, now);
      await storage.savePendingVerifications([]);
      expect(storage.loadPendingVerifications(), isEmpty);
    });

    test(
      'funnel hooks: held once on failure, verified once on recovery',
      () async {
        final held = <String>[];
        final verified = <String>[];
        service = build(android: true)
          ..onVerificationHeld = held.add
          ..onPurchaseVerified = verified.add;
        await service.initialize();
        await emit(fresh());
        now = now.add(const Duration(seconds: 31));
        await service.retryPendingVerifications();
        expect(held, [IapProductIds.premiumYearly]);
        expect(verified, isEmpty);
        serverUp = true;
        now = now.add(const Duration(minutes: 2));
        await service.retryPendingVerifications();
        expect(verified, [IapProductIds.premiumYearly]);
        expect(held, hasLength(1));
      },
    );

    test('backoff grows to a 30 minute ceiling', () {
      expect(VerificationBackoff.delayAfter(0), Duration.zero);
      expect(VerificationBackoff.delayAfter(1), const Duration(seconds: 30));
      expect(VerificationBackoff.delayAfter(2), const Duration(minutes: 1));
      expect(VerificationBackoff.delayAfter(7), const Duration(minutes: 30));
      expect(VerificationBackoff.delayAfter(40), const Duration(minutes: 30));
    });

    test('corrupt marker storage reads as empty, bad rows are skipped', () {
      expect(PendingVerification.decodeAll('not json'), isEmpty);
      expect(
        PendingVerification.decodeAll(
          '[{"productId":"x"},{"productId":"a","source":"s","credential":"c",'
          '"firstSeen":"2026-11-07T00:00:00Z"}]',
        ).single.credential,
        'c',
      );
    });
  });

  group('access refresh at launch and resume', () {
    late _RecordingIap iap;
    PremiumState cached = const PremiumState();

    setUp(() {
      iap = _RecordingIap();
      cached = const PremiumState();
    });

    AccessRefresher refresher({required bool android}) => AccessRefresher(
      iap: iap,
      cachedPremium: () => cached,
      isAndroid: android,
    );

    test(
      'Android launch runs one silent restore even with nothing cached',
      () async {
        await refresher(android: true).onLaunch();
        expect(iap.calls, ['restore(silent)', 'retry(force)']);
      },
    );

    test('iOS launch with nothing cached never restores', () async {
      await refresher(android: false).onLaunch();
      expect(iap.calls, ['retry(force)']);
    });

    final verifiedYearly = PremiumState(
      activeProductId: IapProductIds.premiumYearly,
      verifiedAt: DateTime.now(),
      activatedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 200)),
      verifiedActive: true,
      verificationSource: 'app_store',
      verificationCredential: '2000000123',
    );

    test('iOS launch with a verified cache only refreshes the proof', () async {
      cached = verifiedYearly;
      await refresher(android: false).onLaunch();
      expect(iap.calls, ['refresh', 'retry(force)']);
    });

    test('iOS launch migrates a legacy cache through one restore', () async {
      cached = PremiumState(
        activeProductId: IapProductIds.premiumYearly,
        activatedAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      await refresher(android: false).onLaunch();
      expect(iap.calls, ['restore(silent)', 'retry(force)']);
    });

    test('iOS resume refreshes the cached expiry and never restores', () async {
      cached = verifiedYearly;
      final r = refresher(android: false);
      await r.onResume();
      await r.onResume();
      expect(iap.calls, [
        'foreground',
        'refresh',
        'retry(force)',
        'foreground',
        'retry(force)',
      ], reason: 'the second resume is inside the refresh throttle');
      expect(iap.calls.where((c) => c.startsWith('restore')), isEmpty);
    });

    test('Android resume queries purchases without a full restore', () async {
      final r = refresher(android: true);
      await r.onResume();
      expect(iap.calls, ['foreground', 'redeliver', 'retry(force)']);
    });

    test('going to the background stops foreground retries', () {
      refresher(android: true).onBackground();
      expect(iap.calls, ['background']);
    });
  });

  group('restore outcome', () {
    test('an active re-verified purchase is reported as restored', () async {
      store.restoredPurchases = [transaction(status: PurchaseStatus.restored)];
      expect(await service.restore(), RestoreOutcome.restored);
      expect(successes, isEmpty, reason: 'the outcome message covers it');
    });

    test('an empty store answer is nothing to restore', () async {
      expect(await service.restore(), RestoreOutcome.nothingToRestore);
    });

    test('a cached active entitlement counts as restored', () async {
      service.hasActiveEntitlement = () => true;
      expect(await service.restore(), RestoreOutcome.restored);
    });

    test('an expired purchase is reported as no longer active', () async {
      service.persistEntitlement = (_) async => false;
      store.restoredPurchases = [transaction(status: PurchaseStatus.restored)];
      expect(await service.restore(), RestoreOutcome.notActive);
    });

    test('a failed save is reported once, as a failure', () async {
      service.persistEntitlement = (_) async => throw StateError('Disk full');
      store.restoredPurchases = [transaction(status: PurchaseStatus.restored)];
      expect(await service.restore(), RestoreOutcome.failed);
      expect(errors, isEmpty, reason: 'no duplicate global snackbar');
    });

    test('a found purchase during an outage is confirming', () async {
      final android = IapService(store: store, redeliverByRestore: true)
        ..persistEntitlement = (_) async => throw StateError('503');
      addTearDown(android.dispose);
      store.restoredPurchases = [
        transaction(status: PurchaseStatus.restored, token: 'tok'),
      ];
      expect(await android.restore(), RestoreOutcome.confirming);
      expect(android.hasPendingVerification, isTrue);
    });

    test('an unavailable store says so', () async {
      store.available = false;
      expect(await service.restore(), RestoreOutcome.unavailable);
    });

    test('a throwing store restore is a failure, not an exception', () async {
      store.restoreThrows = true;
      expect(await service.restore(), RestoreOutcome.failed);
    });
  });
}

class _RecordingIap extends IapService {
  final calls = <String>[];

  @override
  Future<RestoreOutcome> restore({bool silent = false}) async {
    calls.add(silent ? 'restore(silent)' : 'restore');
    return RestoreOutcome.nothingToRestore;
  }

  @override
  Future<void> refreshCachedEntitlement() async => calls.add('refresh');

  @override
  Future<void> redeliverPurchases() async => calls.add('redeliver');

  @override
  Future<void> retryPendingVerifications({bool force = false}) async {
    calls.add(force ? 'retry(force)' : 'retry');
  }

  @override
  void setForeground(bool foreground) =>
      calls.add(foreground ? 'foreground' : 'background');
}
