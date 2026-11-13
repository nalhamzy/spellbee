import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/plan_savings.dart';
import 'package:spellbee/core/services/store_offers.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/paywall_screen.dart';

IapProduct monthly([double raw = 4.99, String price = r'$4.99']) => IapProduct(
  id: IapProductIds.premiumMonthly,
  title: 'm',
  price: price,
  rawPrice: raw,
  currencyCode: 'USD',
  description: '',
);

IapProduct yearly({
  double raw = 29.99,
  String price = r'$29.99',
  FreeTrial? trial,
}) => IapProduct(
  id: IapProductIds.premiumYearly,
  title: 'y',
  price: price,
  rawPrice: raw,
  currencyCode: 'USD',
  description: '',
  freeTrial: trial,
);

const lifetime = IapProduct(
  id: IapProductIds.premiumLifetime,
  title: 'l',
  price: r'$49.99',
  rawPrice: 49.99,
  currencyCode: 'USD',
  description: '',
);

void main() {
  group('saving maths', () {
    YearlySaving? save(
      double? m,
      double? y, {
      String price = r'$29.99',
      String? mc = 'USD',
      String? yc = 'USD',
    }) => yearlySaving(
      monthlyRaw: m,
      yearlyRaw: y,
      yearlyPrice: price,
      monthlyCurrency: mc,
      yearlyCurrency: yc,
    );

    test('percent and per-month come from the raw prices', () {
      final s = save(4.99, 29.99)!;
      expect(s.percent, 50);
      expect(s.perMonth, r'$2.50');
      expect(save(10, 60)!.percent, 50);
      expect(save(10, 90)!.percent, 25);
    });

    test('hidden when a price is missing or not positive', () {
      expect(save(null, 29.99), isNull);
      expect(save(4.99, null), isNull);
      expect(save(0, 29.99), isNull);
      expect(save(4.99, 0), isNull);
      expect(save(-1, 29.99), isNull);
      expect(save(double.nan, 29.99), isNull);
    });

    test('hidden under 5% and shown at exactly 5%', () {
      expect(save(10, 120), isNull, reason: '0%');
      expect(save(10, 115), isNull, reason: '4% (4.17 rounds to 4)');
      expect(save(10, 114)!.percent, 5);
      expect(save(10, 130), isNull, reason: 'yearly dearer than 12 months');
    });

    test('hidden when the two plans use different currencies', () {
      expect(save(4.99, 29.99, mc: 'USD', yc: 'EUR'), isNull);
    });

    test('per-month follows the store price style', () {
      String? like(String t, double v) => formatLike(t, v);
      expect(like(r'$29.99', 2.4992), r'$2.50');
      expect(like('29,99 €', 2.4992), '2,50 €');
      expect(like('AED 109.99', 9.1658), 'AED 9.17');
      expect(like('₹2,999.00', 249.9167), '₹249.92');
      expect(like('1.234,56 €', 102.88), '102,88 €');
      expect(like('Rp 299.000', 24916.67), 'Rp 24.917');
      expect(like('¥3,000', 250), '¥250');
      expect(like('Rp 1.299.000', 108250), 'Rp 108.250');
    });

    test('per-month is dropped rather than guessed', () {
      expect(formatLike('free', 2.5), isNull);
      expect(formatLike(r'$30', 2.5), isNull, reason: 'no fraction digits');
      expect(save(4.99, 29.99, price: 'free')!.perMonth, isNull);
    });
  });

  group('paywall layout and copy', () {
    Future<void> mount(
      WidgetTester tester,
      List<IapProduct> products, {
      Size size = const Size(360, 640),
      double textScale = 1,
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      tester.view.physicalSize = size;
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
            theme: AppTheme.light.copyWith(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const PaywallScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    void expectOnScreen(WidgetTester tester, Finder f, double height) {
      expect(f, findsOneWidget);
      final rect = tester.getRect(f);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(height));
    }

    for (final trial in [null, const FreeTrial(7, TrialUnit.day)]) {
      testWidgets('Restore, Privacy and Terms are visible on 360x640 '
          '(${trial == null ? 'no trial' : 'with trial'})', (tester) async {
        await mount(tester, [monthly(), yearly(trial: trial), lifetime]);
        expectOnScreen(tester, find.text('Restore'), 640);
        expectOnScreen(tester, find.text('Privacy Policy'), 640);
        expectOnScreen(tester, find.text('Terms of Use (EULA)'), 640);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('legal links stay visible at larger text and on iOS', (
      tester,
    ) async {
      await mount(
        tester,
        [monthly(), yearly(), lifetime],
        textScale: 1.3,
        platform: TargetPlatform.iOS,
      );
      expectOnScreen(tester, find.text('Privacy Policy'), 640);
      expectOnScreen(tester, find.text('Terms of Use (EULA)'), 640);
    });

    testWidgets(
      'the plans come before the perks, so they show on a small phone',
      (tester) async {
        await mount(tester, [monthly(), yearly(), lifetime]);
        final cta = tester.getRect(find.text('Continue with yearly'));
        final tile = tester.getRect(find.text('Premium Yearly'));
        expect(tile.bottom, lessThan(cta.top));
        expect(tile.top, greaterThanOrEqualTo(0));
      },
    );

    testWidgets('yearly is preselected', (tester) async {
      await mount(tester, [monthly(), yearly(), lifetime]);
      expect(find.text('Continue with yearly'), findsOneWidget);
    });

    testWidgets('yearly shows the saving and per-month from store numbers', (
      tester,
    ) async {
      await mount(tester, [monthly(), yearly(), lifetime]);
      expect(find.text('SAVE 50%'), findsOneWidget);
      expect(find.text("That's about \$2.50 a month"), findsOneWidget);
    });

    testWidgets('saving follows other prices and currencies', (tester) async {
      await mount(tester, [
        monthly(99, '€99'),
        yearly(raw: 594, price: '€594'),
      ]);
      expect(find.text('SAVE 50%'), findsOneWidget);
      expect(
        find.byKey(const Key('per-month-note')),
        findsNothing,
        reason: 'a whole-euro style is not guessed at for small amounts',
      );
    });

    testWidgets('no saving without a monthly product', (tester) async {
      await mount(tester, [yearly(), lifetime]);
      expect(find.byKey(const Key('save-badge')), findsNothing);
      expect(find.byKey(const Key('per-month-note')), findsNothing);
    });

    testWidgets('no saving when it is under 5%', (tester) async {
      await mount(tester, [monthly(), yearly(raw: 58, price: r'$58')]);
      expect(find.byKey(const Key('save-badge')), findsNothing);
      expect(find.byKey(const Key('per-month-note')), findsNothing);
    });

    testWidgets('a store trial is named on the button and in the terms', (
      tester,
    ) async {
      await mount(tester, [
        monthly(),
        yearly(trial: const FreeTrial(7, TrialUnit.day)),
        lifetime,
      ]);
      expect(find.text('Start 7-day free trial'), findsOneWidget);
      expect(
        find.textContaining('7 days free, then \$29.99/year'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '7 days free, then \$29.99 per year. Your Google Play account is '
          'charged \$29.99 when the free trial ends unless you cancel at '
          'least 24 hours before it ends. The subscription then renews '
          'yearly until cancelled.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no store trial means no trial wording anywhere', (
      tester,
    ) async {
      await mount(tester, [monthly(), yearly(), lifetime]);
      expect(
        find.textContaining(RegExp('trial', caseSensitive: false)),
        findsNothing,
      );
      expect(find.textContaining('days free'), findsNothing);
      await tester.ensureVisible(find.text('Prefer monthly? See plan'));
      await tester.tap(find.text('Prefer monthly? See plan'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(RegExp('trial', caseSensitive: false)),
        findsNothing,
      );
    });
  });
}
