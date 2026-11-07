/// One day boundary for the whole app: the device's local midnight.
///
/// A day key is the number of days from 1970-01-01 to a calendar date. It is
/// computed from the date's year/month/day, so it does not depend on the
/// time of day, the UTC offset or daylight-saving changes. The daily word,
/// its streak, the quests, review history, adventure rounds and the daily
/// counters all roll over together at local midnight.
library;

/// Day key of [date]'s own calendar date (its year/month/day fields).
int dayKeyOf(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Day key of the local calendar date at [now] (defaults to the clock).
int localDayKey([DateTime? now]) => dayKeyOf((now ?? DateTime.now()).toLocal());

/// Day key of [instant] on a wall clock [utcOffset] away from UTC. Used to
/// reason about (and test) other time zones without changing the device's.
int dayKeyAtOffset(DateTime instant, Duration utcOffset) =>
    dayKeyOf(instant.toUtc().add(utcOffset));

/// The pre-1.4.0 key: whole days since the epoch, i.e. the UTC date. In the
/// US it flipped at 16:00-19:00 local, in Jakarta and Manila at 07:00-08:00.
int legacyUtcDayKey(DateTime instant) =>
    instant.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

/// Converts a stored legacy (UTC) day to the local scheme without changing
/// how far it is from today: "done today" stays today, "yesterday" stays
/// yesterday. The UTC and local dates differ by at most one day, so the
/// shift is -1, 0 or +1, and an existing streak can never break on upgrade.
int migrateLegacyDay(
  int legacyUtcDay, {
  required DateTime now,
  int Function(DateTime instant)? localDayOf,
}) {
  final today = localDayOf != null ? localDayOf(now) : localDayKey(now);
  return legacyUtcDay + (today - legacyUtcDayKey(now));
}
