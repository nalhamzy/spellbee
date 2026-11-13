import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/services/event_logger.dart';
import 'package:spellbee/core/services/promo_config.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/widgets/whykeeper_card.dart';

const _apple = 'https://apps.apple.com/app/whykeeper/id6831539167';
const _play =
    'https://play.google.com/store/apps/details?id=com.idealai.whykeeper';

String _body({String ios = _apple, String android = _play}) =>
    '{"whykeeper": {"ios": "$ios", "android": "$android"}}';

void main() {
  late SharedPreferences prefs;
  late DateTime now;
  late List<Uri> requests;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 11, 14, 10);
    requests = [];
  });

  PromoConfigService service(
    http.Client client, {
    String platform = 'android',
    bool web = false,
  }) => PromoConfigService(
    prefs,
    client: client,
    clock: () => now,
    platform: platform,
    isWeb: web,
  );

  MockClient reply(int status, String body) => MockClient((request) async {
    requests.add(request.url);
    return http.Response(body, status);
  });

  group('promo switch', () {
    test('valid URL shows on the matching platform', () async {
      expect(await service(reply(200, _body())).whykeeperUrl(), _play);
      prefs.clear();
      expect(
        await service(reply(200, _body()), platform: 'ios').whykeeperUrl(),
        _apple,
      );
    });

    test('the request is a plain GET of the studio file, no query', () async {
      await service(reply(200, _body())).whykeeperUrl();
      expect(
        requests.single.toString(),
        PromoConfigService.defaultSource.toString(),
      );
      expect(requests.single.hasQuery, isFalse);
    });

    test('404 (file not published yet) hides the card', () async {
      expect(await service(reply(404, 'Not Found')).whykeeperUrl(), isNull);
    });

    test('empty URL, bad JSON and wrong shapes hide the card', () async {
      for (final body in [
        _body(android: ''),
        'not json',
        '[]',
        '{"whykeeper": "x"}',
        '{}',
        '{"whykeeper": {"android": 5}}',
      ]) {
        await prefs.clear();
        expect(
          await service(reply(200, body)).whykeeperUrl(),
          isNull,
          reason: body,
        );
      }
    });

    test('only the exact store host over https is accepted', () async {
      for (final bad in [
        'http://play.google.com/store/apps/details?id=x',
        'https://play.google.com.evil.com/store',
        'https://evil.com/play.google.com',
        'https://evil.com@play.google.com/x',
        'https://play.google.com@evil.com/x',
        'https://play.google.com:8443/x',
        'https://apps.apple.com/app/id1',
        'market://details?id=x',
        'javascript:alert(1)',
      ]) {
        await prefs.clear();
        expect(
          await service(reply(200, _body(android: bad))).whykeeperUrl(),
          isNull,
          reason: bad,
        );
      }
    });

    test('an iOS URL is ignored on Android and the other way round', () async {
      await prefs.clear();
      expect(
        await service(reply(200, _body(android: _apple))).whykeeperUrl(),
        isNull,
      );
      await prefs.clear();
      expect(
        await service(
          reply(200, _body(ios: _play)),
          platform: 'ios',
        ).whykeeperUrl(),
        isNull,
      );
    });

    test('web and unknown platforms never fetch', () async {
      expect(
        await service(reply(200, _body()), web: true).whykeeperUrl(),
        isNull,
      );
      expect(
        await service(reply(200, _body()), platform: 'other').whykeeperUrl(),
        isNull,
      );
      expect(requests, isEmpty);
    });

    test(
      'network errors and timeouts hide the card',
      () async {
        final failing = MockClient(
          (_) async => throw http.ClientException('x'),
        );
        expect(await service(failing).whykeeperUrl(), isNull);
        await prefs.clear();
        final hanging = MockClient((_) => Completer<http.Response>().future);
        final result = await Future.any([
          service(hanging).whykeeperUrl(),
          Future<String?>.delayed(const Duration(seconds: 8), () => 'late'),
        ]);
        expect(result, isNull);
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test('fetches once per local day, then again the next day', () async {
      final client = reply(200, _body());
      expect(await service(client).whykeeperUrl(), _play);
      expect(await service(client).whykeeperUrl(), _play);
      now = DateTime(2026, 11, 14, 23, 59);
      expect(await service(client).whykeeperUrl(), _play);
      expect(requests.length, 1, reason: 'cached for the local day');
      now = DateTime(2026, 11, 15, 0, 1);
      expect(await service(client).whykeeperUrl(), _play);
      expect(requests.length, 2, reason: 'new local day');
    });

    test('concurrent callers share one request', () async {
      final s = service(reply(200, _body()));
      final results = await Future.wait([s.whykeeperUrl(), s.whykeeperUrl()]);
      expect(results, [_play, _play]);
      expect(requests.length, 1);
    });

    test('a failed fetch hides today without retrying, not tomorrow', () async {
      expect(await service(reply(404, '')).whykeeperUrl(), isNull);
      expect(await service(reply(200, _body())).whykeeperUrl(), isNull);
      expect(requests.length, 1, reason: 'no retry the same day');
      now = DateTime(2026, 11, 15, 9);
      expect(await service(reply(200, _body())).whykeeperUrl(), _play);
    });
  });

  group('card', () {
    Future<void> mount(WidgetTester tester, String? url) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [whykeeperPromoProvider.overrideWith((ref) async => url)],
          child: const MaterialApp(
            home: Scaffold(body: WhykeeperCard(source: 'stats')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('hidden without a URL', (tester) async {
      await mount(tester, null);
      expect(find.text('Homework help for grown-ups'), findsNothing);
    });

    testWidgets('shown with the approved copy', (tester) async {
      await mount(tester, _play);
      expect(find.text('FOR GROWN-UPS'), findsOneWidget);
      expect(find.text('Homework help for grown-ups'), findsOneWidget);
      expect(find.text('See Whykeeper'), findsOneWidget);
      expect(
        find.textContaining('From the makers of SpellBee.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping asks the parent gate first', (tester) async {
      await mount(tester, _play);
      await tester.tap(find.text('See Whykeeper'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  test('promo_open is an allowed funnel event with a source prop', () {
    final logger = EventLogger(platform: 'android', locale: 'en-US');
    final payload = logger.payload(FunnelEvent.promoOpen, {'source': 'stats'});
    expect(payload, isNotNull);
    expect((payload!['props'] as Map)['source'], 'stats');
  });
}
