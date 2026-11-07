import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/providers/providers.dart';

class _FlakyStore extends IapService {
  int calls = 0;
  int failuresLeft;
  _FlakyStore({this.failuresLeft = 0});

  @override
  Future<List<IapProduct>> loadProducts() async {
    calls++;
    if (failuresLeft > 0) {
      failuresLeft--;
      throw StateError('Billing service not bound yet');
    }
    return const [
      IapProduct(
        id: IapProductIds.premiumYearly,
        title: 'Premium Yearly',
        price: 'AED 109.99',
        description: '',
      ),
    ];
  }
}

void main() {
  setUp(() => iapProductsRetryDelay = Duration.zero);

  ProviderContainer containerFor(IapService iap) {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [iapServiceProvider.overrideWithValue(iap)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a transient store failure is retried once automatically', () async {
    final store = _FlakyStore(failuresLeft: 1);
    final c = containerFor(store);
    final sub = c.listen(iapProductsProvider.future, (_, _) {});
    expect(await sub.read(), hasLength(1));
    expect(store.calls, 2);
  });

  test('a failure is not cached once the paywall is closed', () async {
    final store = _FlakyStore(failuresLeft: 2);
    final c = containerFor(store);
    var sub = c.listen(iapProductsProvider.future, (_, _) {});
    expect(await sub.read(), isEmpty, reason: 'both attempts failed');
    sub.close();
    await Future<void>.delayed(Duration.zero); // auto-dispose runs

    sub = c.listen(iapProductsProvider.future, (_, _) {});
    expect(await sub.read(), hasLength(1), reason: 'reopening asks again');
    expect(store.calls, 3);
  });
}
