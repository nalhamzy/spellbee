import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/store_offers.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/paywall_screen.dart';

// ── Fake store product details ─────────────────────────────────────────

PricingPhaseWrapper phase(
  String price,
  int micros,
  String period, {
  int cycles = 0,
  RecurrenceMode mode = RecurrenceMode.infiniteRecurring,
}) => PricingPhaseWrapper(
  billingCycleCount: cycles,
  billingPeriod: period,
  formattedPrice: price,
  priceAmountMicros: micros,
  priceCurrencyCode: 'AED',
  recurrenceMode: mode,
);

final yearlyBase = SubscriptionOfferDetailsWrapper(
  basePlanId: 'yearly',
  offerTags: const [],
  offerIdToken: 'base-token',
  pricingPhases: [phase('AED 109.99', 109990000, 'P1Y')],
);

final yearlyTrial = SubscriptionOfferDetailsWrapper(
  basePlanId: 'yearly',
  offerId: 'trial-7d',
  offerTags: const [],
  offerIdToken: 'trial-token',
  pricingPhases: [
    phase('Free', 0, 'P1W', cycles: 1, mode: RecurrenceMode.finiteRecurring),
    phase('AED 109.99', 109990000, 'P1Y'),
  ],
);

List<GooglePlayProductDetails> playSubscription(
  String id,
  List<SubscriptionOfferDetailsWrapper> offers,
) => GooglePlayProductDetails.fromProductDetails(
  ProductDetailsWrapper(
    description: '',
    name: id,
    productId: id,
    productType: ProductType.subs,
    subscriptionOfferDetails: offers,
    title: id,
  ),
);

AppStoreProductDetails appStore(String id, {SKProductDiscountWrapper? intro}) =>
    AppStoreProductDetails.fromSKProduct(
      SKProductWrapper(
        productIdentifier: id,
        localizedTitle: id,
        localizedDescription: '',
        priceLocale: SKPriceLocaleWrapper(
          currencySymbol: r'$',
          currencyCode: 'USD',
          countryCode: 'US',
        ),
        price: '29.99',
        subscriptionPeriod: SKProductSubscriptionPeriodWrapper(
          numberOfUnits: 1,
          unit: SKSubscriptionPeriodUnit.year,
        ),
        introductoryPrice: intro,
      ),
    );

AppStoreProduct2Details appStore2(String id) =>
    AppStoreProduct2Details.fromSK2Product(
      SK2Product(
        id: id,
        displayName: id,
        displayPrice: r'$29.99',
        description: '',
        price: 29.99,
        type: SK2ProductType.autoRenewable,
        priceLocale: SK2PriceLocale(currencyCode: 'USD', currencySymbol: r'$'),
      ),
    );

SKProductDiscountWrapper appleIntro(
  SKProductDiscountPaymentMode mode, {
  int units = 1,
  SKSubscriptionPeriodUnit unit = SKSubscriptionPeriodUnit.week,
}) => SKProductDiscountWrapper(
  price: '0',
  priceLocale: SKPriceLocaleWrapper(
    currencySymbol: r'$',
    currencyCode: 'USD',
    countryCode: 'US',
  ),
  numberOfPeriods: 1,
  paymentMode: mode,
  subscriptionPeriod: SKProductSubscriptionPeriodWrapper(
    numberOfUnits: units,
    unit: unit,
  ),
  identifier: null,
  type: SKProductDiscountType.introductory,
);

class _OfferStore extends Fake implements InAppPurchase {
  _OfferStore(this.products);
  final List<ProductDetails> products;
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  ProductDetails? bought;

  @override
  Future<bool> isAvailable() async => true;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: products.where((p) => ids.contains(p.id)).toList(),
        notFoundIDs: const [],
      );
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought = purchaseParam.productDetails;
    return true;
  }
}

void main() {
  group('reading store intro offers', () {
    test('ISO periods', () {
      expect(parseIsoPeriod('P7D'), const FreeTrial(7, TrialUnit.day));
      expect(parseIsoPeriod('P1W')!.label, '7 days');
      expect(parseIsoPeriod('P1M')!.label, '1 month');
      expect(parseIsoPeriod('P3D')!.adjective, '3-day');
      expect(parseIsoPeriod('P1W', times: 2)!.label, '14 days');
      expect(parseIsoPeriod('nonsense'), isNull);
    });

    test('Play: a free first phase is a trial; the price is the base plan', () {
      final plans = collapseStorePlans(
        playSubscription(IapProductIds.premiumYearly, [
          yearlyBase,
          yearlyTrial,
        ]),
      );
      final yearly = plans.single;
      expect(yearly.freeTrial!.label, '7 days');
      expect(yearly.price, 'AED 109.99', reason: 'never the "Free" phase');
      final offer = yearly.purchaseDetails as GooglePlayProductDetails;
      expect(offer.offerToken, 'trial-token', reason: 'buy the trial offer');
    });

    test('Play without an offer: no trial, base plan bought', () {
      final yearly = collapseStorePlans(
        playSubscription(IapProductIds.premiumYearly, [yearlyBase]),
      ).single;
      expect(yearly.freeTrial, isNull);
      expect(yearly.price, 'AED 109.99');
      expect(
        (yearly.purchaseDetails as GooglePlayProductDetails).offerToken,
        'base-token',
      );
    });

    test('Play: a paid intro phase is not a free trial', () {
      final discounted = SubscriptionOfferDetailsWrapper(
        basePlanId: 'yearly',
        offerId: 'half-price',
        offerTags: const [],
        offerIdToken: 'discount-token',
        pricingPhases: [
          phase('AED 54.99', 54990000, 'P1Y', cycles: 1),
          phase('AED 109.99', 109990000, 'P1Y'),
        ],
      );
      final yearly = collapseStorePlans(
        playSubscription(IapProductIds.premiumYearly, [discounted, yearlyBase]),
      ).single;
      expect(yearly.freeTrial, isNull);
      expect(
        (yearly.purchaseDetails as GooglePlayProductDetails).offerToken,
        'base-token',
      );
    });

    test('App Store: free-trial intro shows only when eligible', () {
      final product = appStore(
        IapProductIds.premiumYearly,
        intro: appleIntro(SKProductDiscountPaymentMode.freeTrail),
      );
      expect(freeTrialOf(product)!.label, '7 days');
      expect(collapseStorePlans([product]).single.price, r'$29.99');
      expect(
        collapseStorePlans([
          product,
        ], trialEligible: (_) => false).single.freeTrial,
        isNull,
      );
    });

    test('App Store: no intro or a pay-as-you-go intro is not a trial', () {
      expect(freeTrialOf(appStore(IapProductIds.premiumYearly)), isNull);
      expect(
        freeTrialOf(
          appStore(
            IapProductIds.premiumYearly,
            intro: appleIntro(SKProductDiscountPaymentMode.payAsYouGo),
          ),
        ),
        isNull,
      );
    });
    test('App Store via StoreKit 2: the trial comes from the intro lookup', () {
      final product = appStore2(IapProductIds.premiumYearly);
      expect(freeTrialOf(product), isNull, reason: 'SK2 carries no intro');
      final trials = {
        IapProductIds.premiumYearly: freeTrialFromAppleIntro(
          appleIntro(SKProductDiscountPaymentMode.freeTrail),
        )!,
      };
      final yearly = collapseStorePlans([
        product,
      ], appStoreTrials: trials).single;
      expect(yearly.freeTrial!.label, '7 days');
      expect(yearly.price, r'$29.99');
      expect(yearly.purchaseDetails, same(product));
      expect(
        collapseStorePlans(
          [product],
          appStoreTrials: trials,
          trialEligible: (_) => false,
        ).single.freeTrial,
        isNull,
      );
    });

    test('Apple intro offers: only free trials count', () {
      expect(freeTrialFromAppleIntro(null), isNull);
      expect(
        freeTrialFromAppleIntro(
          appleIntro(SKProductDiscountPaymentMode.payUpFront),
        ),
        isNull,
      );
      expect(
        freeTrialFromAppleIntro(
          appleIntro(
            SKProductDiscountPaymentMode.freeTrail,
            unit: SKSubscriptionPeriodUnit.month,
          ),
        )!.label,
        '1 month',
      );
    });
  });

  group('IapService with offers', () {
    test(
      'loads one product per id with its trial and buys the trial offer',
      () async {
        final store = _OfferStore([
          ...playSubscription(IapProductIds.premiumYearly, [
            yearlyBase,
            yearlyTrial,
          ]),
        ]);
        addTearDown(store.updates.close);
        final iap = IapService(store: store, redeliverByRestore: true);
        addTearDown(iap.dispose);
        final products = await iap.loadProducts();
        expect(products, hasLength(1));
        expect(products.single.price, 'AED 109.99');
        expect(products.single.freeTrial!.label, '7 days');

        await iap.buy(IapProductIds.premiumYearly);
        expect(
          (store.bought as GooglePlayProductDetails).offerToken,
          'trial-token',
        );
      },
    );

    test('StoreKit 2 (iOS 15+): an eligible Apple ID sees the trial', () async {
      final store = _OfferStore([appStore2(IapProductIds.premiumYearly)]);
      addTearDown(store.updates.close);
      Set<String>? asked;
      final iap = IapService(store: store, redeliverByRestore: false)
        ..appStoreTrialLookup = (ids) async {
          asked = ids;
          return {
            IapProductIds.premiumYearly: const FreeTrial(1, TrialUnit.week),
          };
        }
        ..introOfferEligibility = (_) async => true;
      addTearDown(iap.dispose);
      final yearly = (await iap.loadProducts()).single;
      expect(asked, {IapProductIds.premiumYearly});
      expect(yearly.freeTrial!.label, '7 days');
      expect(yearly.price, r'$29.99');
      await iap.buy(IapProductIds.premiumYearly);
      expect(store.bought!.id, IapProductIds.premiumYearly);
    });

    test(
      'StoreKit 2: used trial, failed lookup or failed check hide it',
      () async {
        Future<FreeTrial?> trialWith({
          required Future<Map<String, FreeTrial>> Function(Set<String>) lookup,
          required Future<bool> Function(String) eligible,
        }) async {
          final store = _OfferStore([appStore2(IapProductIds.premiumYearly)]);
          addTearDown(store.updates.close);
          final iap = IapService(store: store, redeliverByRestore: false)
            ..appStoreTrialLookup = lookup
            ..introOfferEligibility = eligible;
          addTearDown(iap.dispose);
          return (await iap.loadProducts()).single.freeTrial;
        }

        final week = {
          IapProductIds.premiumYearly: const FreeTrial(1, TrialUnit.week),
        };
        expect(
          await trialWith(
            lookup: (_) async => week,
            eligible: (_) async => false,
          ),
          isNull,
        );
        expect(
          await trialWith(
            lookup: (_) async => throw StateError('no SK1'),
            eligible: (_) async => true,
          ),
          isNull,
        );
        expect(
          await trialWith(
            lookup: (_) async => week,
            eligible: (_) async => throw StateError('iOS 14'),
          ),
          isNull,
        );
        expect(
          await trialWith(
            lookup: (_) async => const {},
            eligible: (_) async => true,
          ),
          isNull,
          reason: 'no intro offer configured',
        );
      },
    );

    test('an Apple ID that used its trial sees the plain price', () async {
      final store = _OfferStore([
        appStore(
          IapProductIds.premiumYearly,
          intro: appleIntro(SKProductDiscountPaymentMode.freeTrail),
        ),
      ]);
      addTearDown(store.updates.close);
      final iap = IapService(store: store, redeliverByRestore: false)
        ..introOfferEligibility = (_) async => false;
      addTearDown(iap.dispose);
      expect((await iap.loadProducts()).single.freeTrial, isNull);
    });

    test('an eligibility check that fails hides the trial', () async {
      final store = _OfferStore([
        appStore(
          IapProductIds.premiumYearly,
          intro: appleIntro(SKProductDiscountPaymentMode.freeTrail),
        ),
      ]);
      addTearDown(store.updates.close);
      final iap = IapService(store: store, redeliverByRestore: false)
        ..introOfferEligibility = (_) async => throw StateError('iOS 14');
      addTearDown(iap.dispose);
      expect((await iap.loadProducts()).single.freeTrial, isNull);
    });
  });

  group('paywall trial copy', () {
    const trialYearly = IapProduct(
      id: IapProductIds.premiumYearly,
      title: 'Premium Yearly',
      price: 'AED 109.99',
      description: '',
      freeTrial: FreeTrial(7, TrialUnit.day),
    );

    test('shows length, price after the trial, charge and cancel terms', () {
      final ios = paywallTrialCopy(trialYearly, android: false)!;
      expect(ios.tileLine, '7 days free, then AED 109.99/year');
      expect(ios.cta, 'Start 7-day free trial');
      expect(ios.disclosure, contains('7 days free, then AED 109.99 per year'));
      expect(ios.disclosure, contains('Apple ID account is charged'));
      expect(ios.disclosure, contains('at least 24 hours before it ends'));
      expect(ios.disclosure, contains('renews yearly until cancelled'));
      final android = paywallTrialCopy(trialYearly, android: true)!;
      expect(android.disclosure, contains('Google Play account is charged'));
    });

    test('no store trial means no trial copy at all', () {
      const plain = IapProduct(
        id: IapProductIds.premiumYearly,
        title: 'Premium Yearly',
        price: 'AED 109.99',
        description: '',
      );
      expect(paywallTrialCopy(plain, android: false), isNull);
    });

    Future<void> mount(WidgetTester tester, List<IapProduct> products) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          isPremiumProvider.overrideWithValue(false),
          iapServiceProvider.overrideWithValue(IapService()),
          iapProductsProvider.overrideWith((ref) async => products),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light.copyWith(platform: TargetPlatform.iOS),
            home: const PaywallScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a store trial is shown with its full disclosure', (
      tester,
    ) async {
      await mount(tester, const [trialYearly]);
      expect(find.text('7 days free, then AED 109.99/year'), findsOneWidget);
      expect(find.text('Start 7-day free trial'), findsOneWidget);
      expect(
        find.textContaining('at least 24 hours before it ends'),
        findsOneWidget,
      );
    });

    testWidgets('without a store trial the paywall is unchanged', (
      tester,
    ) async {
      await mount(tester, const [
        IapProduct(
          id: IapProductIds.premiumYearly,
          title: 'Premium Yearly',
          price: 'AED 109.99',
          description: '',
        ),
      ]);
      expect(find.text('A full year of Premium'), findsOneWidget);
      expect(find.text('Continue with yearly'), findsOneWidget);
      expect(find.textContaining('free trial'), findsNothing);
      expect(find.textContaining('days free'), findsNothing);
      expect(
        find.text(
          'SpellBee Premium Yearly: AED 109.99 per year. Auto-renews yearly '
          'until cancelled.',
        ),
        findsOneWidget,
      );
    });
  });
}
