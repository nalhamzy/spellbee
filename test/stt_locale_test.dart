import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:spellbee/core/services/stt_service.dart';

void main() {
  const androidIds = ['en_AU', 'en_GB', 'en_IN', 'en_US', 'hi_IN', 'id_ID'];

  String pick(String? region, [List<String> available = androidIds]) =>
      SttService.pickEnglishLocale(deviceRegion: region, available: available);

  group('English recognizer locale', () {
    test('device region picks its English variant when offered', () {
      expect(pick('US'), 'en_US');
      expect(pick('GB'), 'en_GB');
      expect(pick('IN'), 'en_IN');
      expect(pick('AU'), 'en_AU');
    });

    test('a region whose variant is missing falls back to en_US', () {
      expect(pick('PH'), 'en_US', reason: 'en_PH not on this recognizer');
      expect(pick('PH', [...androidIds, 'en_PH']), 'en_PH');
    });

    test('regions without an English variant use en_US, never the '
        'device language', () {
      expect(pick('ID'), 'en_US');
      expect(pick('BR'), 'en_US');
      expect(pick(null), 'en_US');
    });

    test('matching ignores separator and case and keeps the recognizer id', () {
      const ios = ['en-GB', 'en-IN', 'en-US', 'id-ID'];
      expect(pick('in', ios), 'en-IN');
      expect(pick('ID', ios), 'en-US');
    });

    test('an empty or English-less locale list still asks for en_US', () {
      expect(pick('IN', const []), 'en_US');
      expect(pick('GB', const ['fr_FR', 'id_ID']), 'en_US');
    });

    test('device region comes from the first preferred locale with one', () {
      expect(
        SttService.deviceRegion(const [
          Locale('hi'),
          Locale('hi', 'IN'),
          Locale('en', 'US'),
        ]),
        'IN',
      );
      expect(SttService.deviceRegion(const [Locale('fil', 'ph')]), 'PH');
      expect(SttService.deviceRegion(const [Locale('id')]), isNull);
      expect(
        pick(SttService.deviceRegion(const [Locale('fil', 'PH')])),
        'en_US',
      );
    });
  });
}
