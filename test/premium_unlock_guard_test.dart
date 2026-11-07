import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/providers/providers.dart';

void main() {
  test('Premium follows the verified entitlement, not a build flag', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    final c = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(c.dispose);
    expect(kForcePremiumUnlock, isFalse);
    expect(c.read(isPremiumProvider), isFalse);
  });

  test('FORCE_PREMIUM_UNLOCK is only ever read behind kDebugMode', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      final uses = RegExp(
        r"bool\.fromEnvironment\(\s*'FORCE_PREMIUM_UNLOCK'",
      ).allMatches(source);
      for (final use in uses) {
        final before = source.substring(
          (use.start - 40).clamp(0, use.start),
          use.start,
        );
        if (!before.contains('kDebugMode &&')) offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
