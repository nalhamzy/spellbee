import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The parent's choice. Off by default; only a grown-up (behind the parent
/// gate in Settings) can turn it on or change the hour.
@immutable
class ReminderSettings {
  final bool enabled;
  final int hour;

  const ReminderSettings({this.enabled = false, this.hour = defaultHour});

  /// After school, before dinner.
  static const defaultHour = 17;

  /// Hours offered in Settings.
  static const hours = [7, 8, 15, 16, 17, 18, 19, 20];

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled &&
      other.hour == hour;

  @override
  int get hashCode => Object.hash(enabled, hour);
}

/// The next time [hour]:00 happens on the wall clock of [now]'s location,
/// strictly after [now]. Built as a [tz.TZDateTime] in that location, so it
/// stays at the same local hour across daylight-saving changes.
tz.TZDateTime nextReminderAt(tz.TZDateTime now, int hour) {
  var at = tz.TZDateTime(now.location, now.year, now.month, now.day, hour);
  if (!at.isAfter(now)) {
    at = tz.TZDateTime(now.location, now.year, now.month, now.day + 1, hour);
  }
  return at;
}

/// Platform side of the reminder, swappable in tests.
abstract class ReminderScheduler {
  /// Asks the OS for permission (Android 13+ POST_NOTIFICATIONS, iOS alert
  /// permission). Only called when the parent turns the reminder on.
  Future<bool> requestPermission();
  Future<void> scheduleDaily(int hour);
  Future<void> cancel();
}

/// flutter_local_notifications + timezone. Uses inexact alarms, so no
/// SCHEDULE_EXACT_ALARM permission; a reminder a few minutes late is fine.
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const notificationId = 4101;
  static const channelId = 'spellbee_daily_practice';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  Future<void> _init() => _ready ??= _initOnce();

  Future<void> _initOnce() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone name: fall back to the device's current UTC offset so
      // the reminder still fires at the right local hour today.
      tz.setLocalLocation(_fixedOffsetLocation(DateTime.now().timeZoneOffset));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_honeycomb'),
        // Never prompt at start-up; permission is asked when a parent opts in.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  static tz.Location _fixedOffsetLocation(Duration offset) {
    final zone = tz.TimeZone(offset, isDst: false, abbreviation: 'LOCAL');
    return tz.Location('Local', <int>[], <int>[], [zone]);
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  @override
  Future<void> scheduleDaily(int hour) async {
    await _init();
    await _plugin.cancel(id: notificationId);
    await _plugin.zonedSchedule(
      id: notificationId,
      title: "Today's word is ready",
      body: 'A few minutes of SpellBee practice keeps the streak going.',
      scheduledDate: nextReminderAt(tz.TZDateTime.now(tz.local), hour),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Daily practice reminder',
          channelDescription: 'One gentle reminder a day, chosen by a parent.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Repeat every day at this local wall-clock time.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() async {
    await _init();
    await _plugin.cancel(id: notificationId);
  }
}

enum ReminderChange { enabled, permissionDenied, disabled, failed }

/// Stores the parent's choice and keeps the OS schedule in step with it.
class DailyReminderService {
  DailyReminderService(this._prefs, this._scheduler);

  static const _kEnabled = 'sb.reminder.enabled';
  static const _kHour = 'sb.reminder.hour';

  final SharedPreferences _prefs;
  final ReminderScheduler _scheduler;

  ReminderSettings get settings => ReminderSettings(
    enabled: _prefs.getBool(_kEnabled) ?? false,
    hour: _prefs.getInt(_kHour) ?? ReminderSettings.defaultHour,
  );

  /// Turns the reminder on at [hour], asking for permission first. Nothing
  /// is scheduled or saved as enabled when permission is refused.
  Future<ReminderChange> enable(int hour) async {
    try {
      if (!await _scheduler.requestPermission()) {
        return ReminderChange.permissionDenied;
      }
      await _scheduler.scheduleDaily(hour);
      await _prefs.setInt(_kHour, hour);
      await _prefs.setBool(_kEnabled, true);
      return ReminderChange.enabled;
    } catch (_) {
      return ReminderChange.failed;
    }
  }

  Future<ReminderChange> disable() async {
    await _prefs.setBool(_kEnabled, false);
    try {
      await _scheduler.cancel();
    } catch (_) {
      // The choice is saved; a stale OS entry is replaced on next enable.
    }
    return ReminderChange.disabled;
  }

  /// At launch: re-arm the schedule in the device's current time zone
  /// (travel, DST rule updates). Never prompts for permission.
  Future<void> rescheduleIfEnabled() async {
    final current = settings;
    if (!current.enabled) return;
    try {
      await _scheduler.scheduleDaily(current.hour);
    } catch (_) {
      // Permission revoked in system settings, or plugin unavailable.
    }
  }
}
