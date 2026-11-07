import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/services/daily_reminder.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/services/tts_service.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/settings_screen.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class FakeScheduler implements ReminderScheduler {
  bool grant = true;
  final calls = <String>[];

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return grant;
  }

  @override
  Future<void> scheduleDaily(int hour) async => calls.add('schedule $hour');

  @override
  Future<void> cancel() async => calls.add('cancel');
}

class _QuietTts extends TtsService {
  @override
  Future<void> stop() async {}
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('next reminder time', () {
    test('later today when the hour is still ahead', () {
      final ny = tz.getLocation('America/New_York');
      final next = nextReminderAt(tz.TZDateTime(ny, 2026, 11, 7, 9), 17);
      expect(next, tz.TZDateTime(ny, 2026, 11, 7, 17));
    });

    test(
      'tomorrow when the hour has passed, across midnight and month end',
      () {
        final jakarta = tz.getLocation('Asia/Jakarta');
        final next = nextReminderAt(
          tz.TZDateTime(jakarta, 2026, 11, 30, 17),
          17,
        );
        expect(next, tz.TZDateTime(jakarta, 2026, 12, 1, 17));
        expect(next.hour, 17);
      },
    );

    test('keeps the local hour across a daylight-saving change', () {
      final ny = tz.getLocation('America/New_York');
      // US DST starts 2027-03-14: 17:00 is 22:00 UTC before, 21:00 after.
      final before = nextReminderAt(tz.TZDateTime(ny, 2027, 3, 13, 18), 17);
      expect(before.hour, 17);
      expect(before.toUtc().hour, 21);
      final winter = nextReminderAt(tz.TZDateTime(ny, 2027, 3, 12, 18), 17);
      expect(winter.toUtc().hour, 22);
    });

    test('the same instant maps to each zone own wall clock', () {
      final instant = DateTime.utc(2026, 11, 7, 12);
      for (final (name, expectedDay) in [
        ('Asia/Kolkata', 7), // 17:30 local: 17:00 passed, next is tomorrow
        ('Asia/Manila', 7), // 20:00 local: tomorrow
        ('America/Los_Angeles', 7), // 04:00 local: today
      ]) {
        final zone = tz.getLocation(name);
        final next = nextReminderAt(tz.TZDateTime.from(instant, zone), 17);
        expect(next.hour, 17, reason: name);
        expect(next.isAfter(tz.TZDateTime.from(instant, zone)), isTrue);
        expect(next.day == expectedDay || next.day == expectedDay + 1, isTrue);
      }
    });
  });

  group('service', () {
    late SharedPreferences prefs;
    late FakeScheduler scheduler;
    late DailyReminderService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      scheduler = FakeScheduler();
      service = DailyReminderService(prefs, scheduler);
    });

    test('off by default; nothing is asked or scheduled', () async {
      expect(service.settings.enabled, isFalse);
      await service.rescheduleIfEnabled();
      expect(scheduler.calls, isEmpty);
    });

    test('turning on asks permission, then schedules and saves', () async {
      expect(await service.enable(18), ReminderChange.enabled);
      expect(scheduler.calls, ['permission', 'schedule 18']);
      expect(service.settings, const ReminderSettings(enabled: true, hour: 18));
    });

    test('a refused permission leaves it off', () async {
      scheduler.grant = false;
      expect(await service.enable(18), ReminderChange.permissionDenied);
      expect(scheduler.calls, ['permission']);
      expect(service.settings.enabled, isFalse);
    });

    test('turning off cancels; launch re-arms only when on', () async {
      await service.enable(7);
      scheduler.calls.clear();
      await service.rescheduleIfEnabled();
      expect(scheduler.calls, ['schedule 7'], reason: 'no permission prompt');
      await service.disable();
      expect(scheduler.calls.last, 'cancel');
      scheduler.calls.clear();
      await service.rescheduleIfEnabled();
      expect(scheduler.calls, isEmpty);
    });
  });

  group('settings tile', () {
    Future<FakeScheduler> mount(WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      final scheduler = FakeScheduler();
      final tts = _QuietTts();
      addTearDown(tts.dispose);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          iapServiceProvider.overrideWithValue(IapService()),
          ttsServiceProvider.overrideWithValue(tts),
          reminderSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
        ),
      );
      await tester.pumpAndSettle();
      return scheduler;
    }

    Future<void> answerGate(WidgetTester tester) async {
      final challenge = tester
          .widget<Text>(find.byKey(const Key('parent-challenge')))
          .data!;
      final n = RegExp(
        r'\d+',
      ).allMatches(challenge).map((m) => int.parse(m.group(0)!)).toList();
      await tester.enterText(
        find.byKey(const Key('parent-answer')),
        '${n[0] * n[1]}',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    testWidgets('only a grown-up can turn it on, and permission comes last', (
      tester,
    ) async {
      final scheduler = await mount(tester);
      expect(scheduler.calls, isEmpty, reason: 'no prompt on opening Settings');
      await tester.ensureVisible(find.byKey(const Key('reminder-switch')));
      await tester.tap(find.byKey(const Key('reminder-switch')));
      await tester.pumpAndSettle();
      expect(find.text('A moment for grown-ups'), findsOneWidget);
      expect(scheduler.calls, isEmpty);

      await answerGate(tester);
      await tester.tap(find.byKey(const Key('reminder-hour-18')));
      await tester.pumpAndSettle();
      expect(scheduler.calls, ['permission', 'schedule 18']);
      expect(find.textContaining('Reminder set for'), findsOneWidget);
      expect(find.textContaining("Today's word is ready"), findsOneWidget);
    });

    testWidgets('a failed gate changes nothing', (tester) async {
      final scheduler = await mount(tester);
      await tester.ensureVisible(find.byKey(const Key('reminder-switch')));
      await tester.tap(find.byKey(const Key('reminder-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(scheduler.calls, isEmpty);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('reminder-switch')))
            .value,
        isFalse,
      );
    });
  });
}
