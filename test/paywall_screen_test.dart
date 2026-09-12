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
    double width = 430,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
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
          home: PaywallScreen(screenshotMode: screenshot),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> buy(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

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
      await buy(tester, 'Start Premium');
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
    await buy(tester, 'Pay Once & Unlock');
    expect(service.bought, [IapProductIds.premiumLifetime]);
  });

  testWidgets('empty response disables purchase and retry can recover', (
    tester,
  ) async {
    final container = await mount(tester);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start Premium'),
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
    await buy(tester, 'Start Premium');
    expect(service.bought, [IapProductIds.premiumYearly]);
  });

  testWidgets('selection follows refreshed available products', (tester) async {
    products = [plan(IapProductIds.premiumYearly, 'AED 109.99')];
    final container = await mount(tester);
    products = [plan(IapProductIds.premiumMonthly, 'AED 18.99')];
    container.invalidate(iapProductsProvider);
    await tester.pumpAndSettle();
    expect(find.text('Premium Yearly'), findsNothing);
    await buy(tester, 'Start Premium');
    expect(service.bought, [IapProductIds.premiumMonthly]);
  });

  testWidgets('store launch disables repeat taps until it finishes', (
    tester,
  ) async {
    products = [plan(IapProductIds.premiumYearly, 'AED 109.99')];
    service.buyGate = Completer<void>();
    await mount(tester);
    await buy(tester, 'Start Premium');
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
            find.widgetWithText(FilledButton, 'Start Premium'),
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
    await buy(tester, 'Pay Once & Unlock');
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
            find.widgetWithText(FilledButton, 'Start Premium'),
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
