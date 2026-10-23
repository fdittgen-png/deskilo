// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L4 -- the calendar a workspace operation runs on, as one immutable
// value captured into the `WorkspaceContext`: the workspace's IANA zone
// (validated, never the device's in its place), the days it opens, its
// working day and its closures (public holidays are imported as closures).
// The ambient `WorkspaceTime` / `WorkHours` statics stay a legacy adapter
// fed from this value while #2564 moves their readers; new code takes the
// calendar from the context.
import 'package:meta/meta.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../cache/cache_scope.dart';
import '../data/system_columns.dart';
import 'date_text.dart' as date_text;
import 'work_hours.dart';

/// The workspace's calendar cannot be built from what its installation
/// holds: an unknown zone name, for instance. A configuration failure,
/// typed, so no caller substitutes the device clock or another workspace's.
class WorkspaceCalendarUnavailable implements Exception {
  const WorkspaceCalendarUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'WorkspaceCalendarUnavailable: $reason';
}

/// One whole-day closure of the workspace, on its own calendar: [day] is a
/// date-only value (no time component).
@immutable
class CalendarClosure {
  const CalendarClosure({
    required this.id,
    required this.day,
    required this.reason,
    this.system = SystemColumns.none,
  });

  final String id;
  final DateTime day;
  final String reason;

  /// The server's stamp on the row, carried for the screens that show it.
  final SystemColumns system;

  String get isoDay => date_text.isoDay(day);

  @override
  bool operator ==(Object other) =>
      other is CalendarClosure &&
      other.id == id &&
      other.day == day &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(id, day, reason);
}

bool _tzReady = false;

/// The IANA [name] as a location, or the typed failure.
tz.Location _workspaceLocation(String name) {
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    throw const WorkspaceCalendarUnavailable('the workspace has no time zone');
  }
  try {
    return tz.getLocation(trimmed);
  } on Object {
    // trace-exempt: answered as the typed failure the context carries.
    throw WorkspaceCalendarUnavailable('unknown time zone "$trimmed"');
  }
}

/// The workspace's calendar at the moment its context was captured.
@immutable
class WorkspaceCalendar {
  WorkspaceCalendar({
    required String timezone,
    required List<int> openWeekdays,
    required this.workHours,
    required List<CalendarClosure> closures,
  })  : timezone = timezone.trim(),
        location = _workspaceLocation(timezone),
        openWeekdays = List<int>.unmodifiable(openWeekdays),
        closures = List<CalendarClosure>.unmodifiable(
          <CalendarClosure>[...closures]..sort((a, b) => a.day.compareTo(b.day)),
        ) {
    for (final d in this.openWeekdays) {
      if (d < 1 || d > 7) {
        throw WorkspaceCalendarUnavailable('weekday $d is not 1..7');
      }
    }
  }

  /// The IANA zone, as stored.
  final String timezone;

  /// [timezone] resolved; never the device's.
  final tz.Location location;

  /// ISO weekdays (1 = Monday .. 7 = Sunday) the workspace opens on.
  final List<int> openWeekdays;

  final WorkHours workHours;

  /// Closure days, ordered by day.
  final List<CalendarClosure> closures;

  /// What the calendar says, as one short text: equal revisions are the
  /// same calendar.
  late final String revision = cacheDigest('workspace-calendar', [
    timezone,
    openWeekdays.join(','),
    '${workHours.startMinutes}/${workHours.halfBoundaryMinutes}/'
        '${workHours.endMinutes}/${workHours.halfDayHours}/'
        '${workHours.fullDayHours}',
    for (final c in closures) '${c.id}|${c.isoDay}|${c.reason}',
  ], 24);

  /// [hour]:[minute] on [year]-[month]-[day] on the workspace clock.
  tz.TZDateTime at(int year, int month, int day,
          [int hour = 0, int minute = 0]) =>
      tz.TZDateTime(location, year, month, day, hour, minute);

  /// The workspace-local calendar date of [instant] (date-only).
  DateTime dateOf(DateTime instant) {
    final local = tz.TZDateTime.from(instant, location);
    return DateTime(local.year, local.month, local.day);
  }

  /// [instant] as the workspace's naive wall-clock time.
  DateTime wall(DateTime instant) {
    final local = tz.TZDateTime.from(instant, location);
    return DateTime(local.year, local.month, local.day, local.hour,
        local.minute, local.second);
  }

  /// Whether the workspace is closed all day on [date] (a calendar date).
  bool isClosedOn(DateTime date) {
    final iso = date_text.isoDay(date);
    return closures.any((c) => c.isoDay == iso);
  }

  /// Whether [date] is a day the workspace opens on and not a closure.
  bool isOpenOn(DateTime date) =>
      openWeekdays.contains(date.weekday) && !isClosedOn(date);

  @override
  bool operator ==(Object other) =>
      other is WorkspaceCalendar && other.revision == revision;

  @override
  int get hashCode => revision.hashCode;

  @override
  String toString() => 'WorkspaceCalendar($timezone, $revision)';
}
