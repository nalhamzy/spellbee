import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/models/premium_state.dart';
import 'package:spellbee/core/services/iap_service.dart';
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

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
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
}) => PurchaseDetails(
  purchaseID: id,
  productID: productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: '',
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
}
