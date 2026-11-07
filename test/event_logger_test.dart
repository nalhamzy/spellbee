import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spellbee/core/constants/app_version.dart';
import 'package:spellbee/core/services/event_logger.dart';

void main() {
  final url = Uri.parse('https://events.example.test/ingest');

  test('unset EVENTS_URL is a no-op logger', () {
    final logger = EventLogger.fromEnvironment();
    expect(logger.enabled, isFalse, reason: 'tests build without the define');
    var calls = 0;
    EventLogger(
      client: MockClient((_) async {
        calls++;
        return http.Response('', 204);
      }),
    ).log(FunnelEvent.paywallView, {'source': 'general'});
    expect(calls, 0);
  });

  test(
    'payload is exactly {app, event, props, app_version, platform, locale}',
    () {
      final logger = EventLogger(
        endpoint: url,
        platform: 'android',
        locale: 'id-ID',
        appVersion: '1.4.0',
      );
      expect(
        logger.payload(FunnelEvent.checkoutStart, {
          'product': 'spellbee_premium_yearly',
        }),
        {
          'app': 'spellbee',
          'event': 'checkout_start',
          'props': {'product': 'spellbee_premium_yearly'},
          'app_version': '1.4.0',
          'platform': 'android',
          'locale': 'id-ID',
        },
      );
    },
  );

  test('unknown events, unknown props and free text are never sent', () {
    final logger = EventLogger(endpoint: url, platform: 'ios', locale: 'en-US');
    expect(logger.payload('user_signed_in'), isNull);
    final body = logger.payload(FunnelEvent.restoreResult, {
      'outcome': 'nothingToRestore',
      'email': 'parent@example.com',
      'device_id': 'abc',
      'source': 'Child typed: my name is Sam',
    })!;
    expect(body['props'], {'outcome': 'nothingtorestore'});
    expect(jsonEncode(body), isNot(contains('example.com')));
  });

  test(
    'every funnel event posts once as JSON and errors are swallowed',
    () async {
      final posted = <Map<String, dynamic>>[];
      final logger = EventLogger(
        endpoint: url,
        platform: 'android',
        locale: 'en-IN',
        client: MockClient((request) async {
          expect(
            request.headers['Content-Type'],
            startsWith('application/json'),
          );
          posted.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('', 204);
        }),
      );
      for (final event in FunnelEvent.all) {
        logger.log(event);
      }
      await pumpEventQueue();
      expect(posted.map((p) => p['event']).toSet(), FunnelEvent.all);
      expect(posted.every((p) => p['app'] == 'spellbee'), isTrue);

      final failing = EventLogger(
        endpoint: url,
        client: MockClient((_) async => throw const SocketException('offline')),
      );
      failing.log(FunnelEvent.paywallView); // must not throw
      await pumpEventQueue();
    },
  );

  test('app version constant matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([0-9.]+)\+',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(kAppVersion, version);
  });
}
