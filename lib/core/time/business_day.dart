// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3659 (i18n I13) -- "today" about a business fact is the business's day,
// never the device's. A person in Lisbon with an invoice from Zurich, or one
// travelling, reads the business's calendar. This file is the pure value
// (domain code reads it); `business_day_providers.dart` keeps it current.
// A zone that is missing or unknown answers
// [UnknownBusinessDay]: the source is incomplete, and neither the device's
// zone nor another business's stands in.
import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart' as tz;

import 'workspace_calendar.dart';

/// A business's calendar day, or why it cannot be known.
@immutable
sealed class BusinessToday {
  const BusinessToday();

  /// The day, or null when the business's calendar is unknown.
  DateTime? get date;
}

/// The business's calendar day [date] (date-only) in [timezone]; it ends at
/// [nextBoundary], the instant of the zone's next local midnight. Readers
/// use [BusinessToday.date]; the boundary is the provider's own.
final class KnownBusinessDay extends BusinessToday {
  const KnownBusinessDay({
    required this.date,
    required this.timezone,
    required this.nextBoundary,
  });

  @override
  final DateTime date;
  final String timezone;
  final DateTime nextBoundary;

  @override
  bool operator ==(Object other) =>
      other is KnownBusinessDay &&
      other.date == date &&
      other.timezone == timezone &&
      other.nextBoundary == nextBoundary;

  @override
  int get hashCode => Object.hash(date, timezone, nextBoundary);

  @override
  String toString() => 'KnownBusinessDay($date, $timezone)';
}

/// The business's calendar cannot be known: its zone is missing or unknown.
final class UnknownBusinessDay extends BusinessToday {
  const UnknownBusinessDay(this.reason);

  final String reason;

  @override
  DateTime? get date => null;

  @override
  bool operator ==(Object other) =>
      other is UnknownBusinessDay && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'UnknownBusinessDay($reason)';
}

/// The business day at [now] in [timezone] (an IANA name).
BusinessToday businessTodayAt(DateTime now, String? timezone) {
  final tz.Location location;
  try {
    location = workspaceLocationOf(timezone ?? '');
  } on WorkspaceCalendarUnavailable {
    // trace-exempt: the typed answer carries the reason to the reader.
    return UnknownBusinessDay((timezone ?? '').trim().isEmpty
        ? 'the business has no time zone'
        : 'unknown time zone "$timezone"');
  }
  final local = tz.TZDateTime.from(now, location);
  return KnownBusinessDay(
    date: DateTime(local.year, local.month, local.day),
    timezone: location.name,
    // The constructor normalises day + 1 across a month or a year, and the
    // zone's own rules place its midnight, so a 23- or 25-hour day is one day.
    nextBoundary: DateTime.fromMicrosecondsSinceEpoch(
      tz.TZDateTime(location, local.year, local.month, local.day + 1)
          .microsecondsSinceEpoch,
      isUtc: true,
    ),
  );
}

/// #3659 -- the business's zone, to name beside a day the device would read
/// differently: [timezone] when its offset at [now] is not the device's, null
/// when they agree or the zone is unknown. The same rule as a commitment's
/// card (`MyReservationEntry.foreignZone`).
String? zoneToNameAt(DateTime now, String? timezone) {
  final tz.Location location;
  try {
    location = workspaceLocationOf(timezone ?? '');
  } on WorkspaceCalendarUnavailable {
    // trace-exempt: an unknown zone is named nowhere; the day says unknown.
    return null;
  }
  final there = tz.TZDateTime.from(now, location).timeZoneOffset;
  return there == now.toLocal().timeZoneOffset ? null : location.name;
}
