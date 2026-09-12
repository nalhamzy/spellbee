import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/models/premium_state.dart';
import 'package:spellbee/core/services/purchase_verification_service.dart';
import 'package:spellbee/core/services/storage_service.dart';

void main() {
  const monthly = IapProductIds.premiumMonthly;
  const lifetime = IapProductIds.premiumLifetime;
  final now = DateTime.now().toUtc();
  late StorageService storage;
  late PurchaseVerificationService verifier;
  late Map<String, dynamic> verdict;
  late List<Map<String, dynamic>> requests;
  var status = 200;
  PurchaseDetails purchase({
    String product = monthly,
    String source = 'google_play',
    String token = 'purchase-token',
    String id = '123456',
  }) => PurchaseDetails(
    purchaseID: id,
    productID: product,
    transactionDate: '0',
    status: PurchaseStatus.restored,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: token,
      source: source,
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    requests = [];
    status = 200;
    verdict = {
      'productId': monthly,
      'active': true,
      'expiresAt': now.add(const Duration(days: 3)).toIso8601String(),
      'verifiedAt': now.toIso8601String(),
      'environment': 'Production',
    };
    verifier = PurchaseVerificationService(
      storage,
      client: MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode(verdict), status);
      }),
    );
  });

  test(
    'restored subscription uses actual expiry, never restore time plus a month',
    () async {
      expect(await verifier.verify(purchase()), isTrue);
      final cached = storage.loadPremium();
      expect(cached.expiresAt, now.add(const Duration(days: 3)));
      expect(cached.isPremiumAt(now.add(const Duration(days: 4))), isFalse);
      expect(requests.single['credential'], 'purchase-token');
      await verifier.verify(purchase());
      expect(storage.loadPremium().expiresAt, cached.expiresAt);
    },
  );

  test(
    'Apple sends native transaction ID and ignores untrusted client receipt dates',
    () async {
      await verifier.verify(
        purchase(source: 'app_store', token: 'fake-jws', id: '987654'),
      );
      expect(requests.single['credential'], '987654');
      expect(
        requests.single.keys,
        unorderedEquals(['productId', 'source', 'credential']),
      );
    },
  );

  test(
    'provider outage does not grant new access or overwrite a paid cache',
    () async {
      status = 503;
      await expectLater(verifier.verify(purchase()), throwsStateError);
      expect(storage.loadPremium().isPremium, isFalse);
      final original = PremiumState(
        activeProductId: monthly,
        activatedAt: now.subtract(const Duration(days: 5)),
      );
      await storage.savePremium(original);
      await expectLater(verifier.verify(purchase()), throwsStateError);
      expect(storage.loadPremium(), original);
    },
  );

  test(
    'legacy lifetime remains supported offline and migrates on verified restore',
    () async {
      await storage.savePremium(const PremiumState(activeProductId: lifetime));
      await verifier.refresh();
      expect(requests, isEmpty);
      expect(storage.loadPremium().isPremium, isTrue);
      verdict = {...verdict, 'productId': lifetime, 'expiresAt': null};
      await verifier.verify(purchase(product: lifetime));
      expect(storage.loadPremium().canRefresh, isTrue);
      expect(storage.loadPremium().isLifetime, isTrue);
    },
  );

  test(
    'refund is applied from cached proof even when native restore omits it',
    () async {
      verdict = {...verdict, 'productId': lifetime, 'expiresAt': null};
      await verifier.verify(purchase(product: lifetime));
      verdict['active'] = false;
      await verifier.refresh();
      expect(storage.loadPremium().isPremium, isFalse);
      expect(storage.loadPremium().canRefresh, isTrue);
      expect(requests, hasLength(2));
    },
  );

  test(
    'historical expired subscription cannot replace active lifetime in either order',
    () async {
      verdict['active'] = false;
      await verifier.verify(purchase());
      verdict = {
        ...verdict,
        'productId': lifetime,
        'active': true,
        'expiresAt': null,
      };
      await verifier.verify(
        purchase(product: lifetime, token: 'lifetime-token'),
      );
      verdict = {...verdict, 'productId': monthly, 'active': false};
      await verifier.verify(purchase());
      expect(storage.loadPremium().isLifetime, isTrue);
      expect(storage.loadPremium().isPremium, isTrue);
      expect(storage.loadPremium().verificationCredential, 'lifetime-token');
    },
  );

  test(
    'active monthly historical restore also cannot downgrade lifetime',
    () async {
      await storage.savePremium(const PremiumState(activeProductId: lifetime));
      await verifier.verify(purchase());
      expect(storage.loadPremium().isLifetime, isTrue);
    },
  );

  test(
    'revoked legacy monthly replaces its original access on migration',
    () async {
      await storage.savePremium(
        PremiumState(activeProductId: monthly, activatedAt: now),
      );
      verdict['active'] = false;
      await verifier.verify(purchase());
      expect(storage.loadPremium().isPremium, isFalse);
    },
  );

  test(
    'same purchase renewal can extend only to a newer server expiry',
    () async {
      await verifier.verify(purchase());
      final renewed = now.add(const Duration(days: 33));
      verdict['expiresAt'] = renewed.toIso8601String();
      await verifier.refresh();
      expect(storage.loadPremium().expiresAt, renewed);
    },
  );

  test(
    'malformed active subscription response never grants lifetime-like access',
    () async {
      verdict['expiresAt'] = null;
      await expectLater(verifier.verify(purchase()), throwsStateError);
      expect(storage.loadPremium().isPremium, isFalse);
    },
  );

  test('support export redacts the bearer purchase credential', () async {
    await verifier.verify(purchase());
    expect(storage.exportAll(), isNot(contains('purchase-token')));
    expect(storage.loadPremium().verificationCredential, 'purchase-token');
  });

  test('legacy validity and unknown product migration are bounded', () {
    final old = PremiumState(activeProductId: monthly, activatedAt: now);
    expect(old.isPremiumAt(now.add(const Duration(days: 34))), isTrue);
    expect(old.isPremiumAt(now.add(const Duration(days: 35))), isFalse);
    expect(
      PremiumState(activeProductId: 'unknown', activatedAt: now).isPremium,
      isFalse,
    );
  });
}
