import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/paywall_screen.dart';

class RecordingIapService extends IapService {
  final bought = <String>[];
  Completer<void>? buyGate;
  bool restoreFails = false;

  @override
  Future<void> buy(String productId) async {
    bought.add(productId);
    await buyGate?.future;
  }

  @override
  Future<void> restore({bool silent = false}) async {
    if (restoreFails) throw StateError('Offline');
  }
}

IapProduct plan(String id, String price) =>
    IapProduct(id: id, title: id, price: price, description: '');

void main() {
  late RecordingIapService service;
  late List<IapProduct> products;

  setUp(() {
    service = RecordingIapService();
    products = [];
  });

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    bool screenshot = false,
    bool premium = false,
    double width = 430,
    double textScale = 1,
    PaywallSource source = PaywallSource.general,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        isPremiumProvider.overrideWithValue(premium),
        iapServiceProvider.overrideWithValue(service),
        iapProductsProvider.overrideWith((ref) async => products),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light.copyWith(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: PaywallScreen(screenshotMode: screenshot, source: source),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> approveParent(WidgetTester tester) async {
    final challenge = tester
        .widget<Text>(find.byKey(const Key('parent-challenge')))
        .data!;
    final numbers = RegExp(
      r'\d+',
    ).allMatches(challenge).map((m) => int.parse(m.group(0)!)).toList();
    await tester.enterText(
      find.byKey(const Key('parent-answer')),
      '${numbers[0] * numbers[1]}',
    );
    await tester.tap(find.text('Continue to store'));
    await tester.pumpAndSettle();
  }

  Future<void> buy(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await approveParent(tester);
  }

  testWidgets('verified access replaces the purchase controls', (tester) async {
    products = [plan(IapProductIds.premiumYearly, 'AED 109.99')];
    final container = await mount(tester);
    container.updateOverrides([
      isPremiumProvider.overrideWithValue(true),
      iapServiceProvider.overrideWithValue(service),
      iapProductsProvider.overrideWith((ref) async => products),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Premium is ready'), findsOneWidget);
    expect(find.text('Continue with yearly'), findsNothing);
    expect(service.bought, isEmpty);
  });

  testWidgets('an existing subscriber is not offered a second purchase', (
    tester,
  ) async {
    await mount(tester, premium: true);
    expect(find.text('Premium is ready'), findsOneWidget);
    expect(find.text('Continue with yearly'), findsNothing);
  });

  testWidgets('a delayed restore during parent approval cannot buy again', (
    tester,
  ) async {
    products = [plan(IapProductIds.premiumYearly, 'AED 109.99')];
    final container = await mount(tester);
    final button = find.widgetWithText(FilledButton, 'Continue with yearly');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    container.updateOverrides([
      isPremiumProvider.overrideWithValue(true),
      iapServiceProvider.overrideWithValue(service),
      iapProductsProvider.overrideWith((ref) async => products),
    ]);
    await tester.pumpAndSettle();
    await approveParent(tester);
    expect(service.bought, isEmpty);
    expect(find.text('Premium is ready'), findsOneWidget);
  });

  testWidgets('a child cannot launch the store without parent approval', (
    tester,
  ) async {
    products = [plan(IapProductIds.premiumYearly, 'AED 109.99')];
    await mount(tester);
    final button = find.widgetWithText(FilledButton, 'Continue with yearly');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(service.bought, isEmpty);
    await tester.enterText(find.byKey(const Key('parent-answer')), '0');
    await tester.tap(find.text('Continue to store'));
    await tester.pumpAndSettle();
    expect(service.bought, isEmpty);
    expect(find.text('Please ask a grown-up to help.'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(service.bought, isEmpty);
    await buy(tester, 'Continue with yearly');
    expect(service.bought, [IapProductIds.premiumYearly]);
  });

  testWidgets('annual is primary and monthly is an accessible secondary plan', (
    tester,
  ) async {
    products = [
      plan(IapProductIds.premiumYearly, 'AED 109.99'),
      plan(IapProductIds.premiumLifetime, 'AED 179.99'),
      plan(IapProductIds.premiumMonthly, 'AED 18.99'),
    ];
    await mount(tester);
    expect(find.text('Premium Monthly'), findsNothing);
    expect(find.textContaining('AED 109.99 per year'), findsOneWidget);
    await tester.ensureVisible(find.text('Prefer monthly? See plan'));
    await tester.tap(find.text('Prefer monthly? See plan'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Premium Monthly'));
    await tester.tap(find.text('Premium Monthly'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AED 18.99 per month'), findsOneWidget);
    await buy(tester, 'Continue with monthly');
    expect(service.bought, [IapProductIds.premiumMonthly]);
  });

  testWidgets('adventure context preserves the honest free core', (
    tester,
  ) async {
    await mount(tester, source: PaywallSource.adventures);
    expect(find.textContaining('Keep exploring together'), findsOneWidget);
    expect(find.textContaining('All three Bee Adventures'), findsOneWidget);
    expect(find.textContaining('Always included free:'), findsOneWidget);
    expect(find.text('POPULAR'), findsNothing);
    expect(find.textContaining('free trial'), findsNothing);
  });

  testWidgets('unrecognized products cannot become purchase options', (
    tester,
  ) async {
    products = [plan('another_app_yearly', 'AED 1.99')];
    await mount(tester);
    expect(find.text('AED 1.99'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continue with yearly'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('three incorrect parent answers dismiss without buying', (
    tester,
  ) async {
    products = [plan(IapProductIds.premiumYearly, 'AED 109.99')];
    await mount(tester);
    final button = find.widgetWithText(FilledButton, 'Continue with yearly');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.enterText(find.byKey(const Key('parent-answer')), '0');
      await tester.tap(find.text('Continue to store'));
      await tester.pumpAndSettle();
    }
    expect(find.text('A moment for grown-ups'), findsNothing);
    expect(service.bought, isEmpty);
  });

  testWidgets(
    'monthly-only response hides missing plans and buys the shown plan',
    (tester) async {
      products = [plan(IapProductIds.premiumMonthly, 'AED 18.99')];
      await mount(tester);
      expect(find.text('Premium Yearly'), findsNothing);
      expect(find.text('Premium Lifetime'), findsNothing);
      expect(find.text('AED 18.99'), findsOneWidget);
      expect(find.textContaining('AED 18.99 per month'), findsOneWidget);
      expect(find.textContaining('Google Play'), findsOneWidget);
      await buy(tester, 'Continue with monthly');
      expect(service.bought, [IapProductIds.premiumMonthly]);
    },
  );

  testWidgets('lifetime-only response has one-time disclosure and action', (
    tester,
  ) async {
    products = [plan(IapProductIds.premiumLifetime, 'AED 179.99')];
    await mount(tester);
    expect(find.text('Premium Yearly'), findsNothing);
    expect(find.textContaining('AED 179.99 one-time purchase'), findsOneWidget);
    await buy(tester, 'Unlock with one payment');
    expect(service.bought, [IapProductIds.premiumLifetime]);
  });

  testWidgets('empty response disables purchase and retry can recover', (
    tester,
  ) async {
    final container = await mount(tester);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continue with yearly'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.textContaining('auto-renews', findRichText: true),
      findsNothing,
    );
    products = [plan(IapProductIds.premiumYearly, 'AED 109.99')];
    container.invalidate(iapProductsProvider);
    await tester.pumpAndSettle();
    await buy(tester, 'Continue with yearly');
    expect(service.bought, [IapProductIds.premiumYearly]);
  });

  testWidgets('selection follows refreshed available products', (tester) async {
    products = [plan(IapProductIds.premiumYearly, 'AED 109.99')];
    final container = await mount(tester);
    products = [plan(IapProductIds.premiumMonthly, 'AED 18.99')];
    container.invalidate(iapProductsProvider);
    await tester.pumpAndSettle();
    expect(find.text('Premium Yearly'), findsNothing);
    await buy(tester, 'Continue with monthly');
    expect(service.bought, [IapProductIds.premiumMonthly]);
  });

  testWidgets('store launch disables repeat taps until it finishes', (
    tester,
  ) async {
    products = [plan(IapProductIds.premiumYearly, 'AED 109.99')];
    service.buyGate = Completer<void>();
    await mount(tester);
    await buy(tester, 'Continue with yearly');
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Opening store…'),
          )
          .onPressed,
      isNull,
    );
    expect(service.bought, hasLength(1));
    service.buyGate!.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continue with yearly'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('restore failure is recoverable and shown to the user', (
    tester,
  ) async {
    service.restoreFails = true;
    await mount(tester);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not restore purchases. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Restore'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('available alternative selection updates checkout and terms', (
    tester,
  ) async {
    products = [
      plan(IapProductIds.premiumYearly, 'AED 109.99'),
      plan(IapProductIds.premiumLifetime, 'AED 179.99'),
    ];
    await mount(tester);
    expect(find.textContaining('AED 109.99 per year'), findsOneWidget);
    await tester.ensureVisible(find.text('Premium Lifetime'));
    await tester.tap(find.text('Premium Lifetime'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AED 179.99 one-time purchase'), findsOneWidget);
    await buy(tester, 'Unlock with one payment');
    expect(service.bought, [IapProductIds.premiumLifetime]);
  });

  testWidgets('long localized prices and large text fit a narrow phone', (
    tester,
  ) async {
    products = [
      plan(IapProductIds.premiumYearly, 'KWD 1,234.567'),
      plan(IapProductIds.premiumMonthly, 'AED 18.99'),
    ];
    await mount(tester, width: 360, textScale: 1.5);
    expect(tester.takeException(), isNull);
    expect(find.text('KWD 1,234.567'), findsOneWidget);
  });

  testWidgets('screenshot prices cannot trigger a real purchase', (
    tester,
  ) async {
    await mount(tester, screenshot: true);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continue with yearly'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Restore'))
          .onPressed,
      isNull,
    );
  });
}
