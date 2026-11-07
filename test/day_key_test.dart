import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/models/learning_history.dart';
import 'package:spellbee/core/models/player_stats.dart';
import 'package:spellbee/core/models/progression.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/utils/day_key.dart';

void main() {
  // 2026-11-07 is day key 20399.
  final nov7 = dayKeyOf(DateTime.utc(2026, 11, 7));

  group('local day key', () {
    test('is the calendar date, whatever the time of day', () {
      expect(dayKeyOf(DateTime(2026, 11, 7, 0, 0)), nov7);
      expect(dayKeyOf(DateTime(2026, 11, 7, 12, 30)), nov7);
      expect(dayKeyOf(DateTime(2026, 11, 7, 23, 59, 59)), nov7);
    });

    test('rolls over exactly at local midnight', () {
      final beforeMidnight = DateTime(2026, 11, 7, 23, 59, 59, 999);
      final afterMidnight = beforeMidnight.add(const Duration(milliseconds: 1));
      expect(dayKeyOf(afterMidnight) - dayKeyOf(beforeMidnight), 1);
      expect(localDayKey(afterMidnight) - localDayKey(beforeMidnight), 1);
    });

    test('DST transition days still count as one day each', () {
      // US DST ends 2026-11-01 and starts 2027-03-14: 25 h and 23 h days.
      expect(
        dayKeyOf(DateTime(2026, 11, 2)) - dayKeyOf(DateTime(2026, 11, 1)),
        1,
      );
      expect(
        dayKeyOf(DateTime(2027, 3, 15)) - dayKeyOf(DateTime(2027, 3, 14)),
        1,
      );
    });

    test('follows the local date across time zones, unlike the UTC key', () {
      // 18:00 in New York (UTC-5) on Nov 7 is already Nov 8 in UTC.
      final nyEvening = DateTime.utc(2026, 11, 7, 23);
      expect(dayKeyAtOffset(nyEvening, const Duration(hours: -5)), nov7);
      expect(legacyUtcDayKey(nyEvening), nov7);
      final nyLateEvening = DateTime.utc(2026, 11, 8, 1); // 20:00 local
      expect(dayKeyAtOffset(nyLateEvening, const Duration(hours: -5)), nov7);
      expect(legacyUtcDayKey(nyLateEvening), nov7 + 1, reason: 'old bug');

      // 06:30 in Jakarta (UTC+7) on Nov 8 is still Nov 7 in UTC.
      final jakartaMorning = DateTime.utc(2026, 11, 7, 23, 30);
      expect(
        dayKeyAtOffset(jakartaMorning, const Duration(hours: 7)),
        nov7 + 1,
      );
      expect(legacyUtcDayKey(jakartaMorning), nov7, reason: 'old bug');

      // Half-hour zone: 23:45 UTC is 05:15 next day in India (UTC+5:30).
      expect(
        dayKeyAtOffset(
          DateTime.utc(2026, 11, 7, 23, 45),
          const Duration(hours: 5, minutes: 30),
        ),
        nov7 + 1,
      );
    });

    test('review history uses the same key', () {
      expect(learningDay(DateTime(2026, 11, 7, 21)), nov7);
    });
  });

  group('migration from the UTC day', () {
    int Function(DateTime) zone(Duration offset) =>
        (instant) => dayKeyAtOffset(instant, offset);

    test('New York evening: done today stays done today', () {
      final now = DateTime.utc(2026, 11, 8, 1); // Nov 7, 20:00 local
      final local = zone(const Duration(hours: -5));
      // Old app stored the UTC day (Nov 8) when the word was done at 19:30.
      final migrated = migrateLegacyDay(nov7 + 1, now: now, localDayOf: local);
      expect(migrated, local(now), reason: 'still done today');
    });

    test('Jakarta early morning: yesterday stays yesterday', () {
      final now = DateTime.utc(2026, 11, 7, 23); // Nov 8, 06:00 local
      final local = zone(const Duration(hours: 7));
      // Old app: today (UTC) = Nov 7, streak last counted Nov 6 = yesterday.
      final migrated = migrateLegacyDay(nov7 - 1, now: now, localDayOf: local);
      expect(local(now) - migrated, 1, reason: 'streak is not broken');
    });

    test('UTC and same-day zones are unchanged', () {
      final now = DateTime.utc(2026, 11, 7, 12);
      expect(
        migrateLegacyDay(nov7 - 1, now: now, localDayOf: zone(Duration.zero)),
        nov7 - 1,
      );
      expect(
        migrateLegacyDay(
          nov7,
          now: now,
          localDayOf: zone(const Duration(hours: 4)),
        ),
        nov7,
      );
    });

    test(
      'storage migrates streak and quest day once, keeping the streak',
      () async {
        SharedPreferences.setMockInitialValues({});
        final storage = StorageService(await SharedPreferences.getInstance());
        final now = DateTime.utc(2026, 11, 7, 23); // Jakarta Nov 8, 06:00
        final local = zone(const Duration(hours: 7));
        await storage.saveStats(
          PlayerStats(lastDailyEpochDay: nov7 - 1, dailyStreak: 12),
        );
        await storage.saveProgression(
          Progression(questDay: nov7, questProgress: const {'correctWords': 6}),
        );

        expect(
          await storage.migrateToLocalDayKeys(now: now, localDayOf: local),
          isTrue,
        );
        final stats = storage.loadStats();
        expect(stats.dailyStreak, 12);
        expect(local(now) - stats.lastDailyEpochDay!, 1);
        final progress = storage.loadProgression();
        expect(progress.questDay, local(now), reason: "today's quests kept");
        expect(progress.questProgress, {'correctWords': 6});

        // Runs once: a second launch must not shift the values again.
        expect(
          await storage.migrateToLocalDayKeys(now: now, localDayOf: local),
          isFalse,
        );
        expect(storage.loadStats().lastDailyEpochDay, stats.lastDailyEpochDay);
      },
    );

    test('a fresh install has nothing to migrate', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      expect(await storage.migrateToLocalDayKeys(), isFalse);
      expect(storage.loadStats().lastDailyEpochDay, isNull);
    });
  });
}
