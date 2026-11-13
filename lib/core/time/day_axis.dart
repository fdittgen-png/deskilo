// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the opening hours of one business day as an axis of
// elapsed time. A day is not always 24 distinct wall-clock hours: the day the
// clocks go forward has an hour that does not exist, the day they go back has
// one that happens twice. The axis counts ELAPSED minutes from the instant the
// day opens, so a position on it is exactly one instant, and it says where the
// wall clock jumps (a gap) or repeats (a fold), so the grid can show it.
//
// Pure: the zone comes from the business's calendar, never the device.
import 'package:timezone/timezone.dart' as tz;

import 'wall_instant.dart';

/// One hour mark on a [DayAxis].
class AxisTick {
  const AxisTick({
    required this.instant,
    required this.wallMinutes,
    this.repeated = false,
    this.afterGap = false,
  });

  /// The instant of the mark.
  final DateTime instant;

  /// The wall clock at the mark, in minutes after the business's midnight.
  final int wallMinutes;

  /// The wall time of this mark already came once on the day: the second
  /// pass of the hour the clocks went back over.
  final bool repeated;

  /// The wall clock jumped forward just before this mark: the hour (or part
  /// of one) between the previous mark's reading and this one does not exist.
  final bool afterGap;
}

/// The opening hours of a business day, as elapsed time.
class DayAxis {
  const DayAxis({required this.start, required this.end, required this.ticks});

  /// The instant the day opens and the instant it closes.
  final DateTime start;
  final DateTime end;

  /// A mark every elapsed hour from [start].
  final List<AxisTick> ticks;

  /// Elapsed minutes from [start] to [end].
  int get minutes => end.difference(start).inMinutes;

  /// The instant [elapsed] minutes after the day opened.
  DateTime instantAt(int elapsed) => start.add(Duration(minutes: elapsed));

  /// Elapsed minutes from the opening to [instant], clamped to the day.
  int offsetOf(DateTime instant) =>
      instant.difference(start).inMinutes.clamp(0, minutes);

  /// Whether the day holds an hour that does not exist or happens twice.
  bool get hasClockChange => ticks.any((t) => t.repeated || t.afterGap);
}

DateTime _instantOf(WallResolution r, {required bool later}) => switch (r) {
      WallExact(:final instant) => instant,
      WallFold(:final first, :final second) => later ? second : first,
      WallGap(:final forward) => forward,
    };

/// The axis of [day] (a date-only value on the business's calendar) between
/// [startMinutes] and [endMinutes] after its midnight, in [location].
DayAxis buildDayAxis(
  tz.Location location,
  DateTime day, {
  required int startMinutes,
  required int endMinutes,
}) {
  WallResolution at(int minutes) => resolveWallTime(
        location,
        day.year,
        day.month,
        day.day,
        minutes ~/ 60,
        minutes % 60,
      );
  final start = _instantOf(at(startMinutes), later: false);
  final end = _instantOf(at(endMinutes), later: true);
  final length = end.difference(start).inMinutes;
  final ticks = <AxisTick>[];
  var previous = -1;
  for (var elapsed = 0; elapsed < length; elapsed += Duration.minutesPerHour) {
    final instant = start.add(Duration(minutes: elapsed));
    final wall = tz.TZDateTime.from(instant, location);
    final minutes = wall.hour * Duration.minutesPerHour + wall.minute;
    ticks.add(
      AxisTick(
        instant: instant,
        wallMinutes: minutes,
        repeated: previous >= 0 && minutes <= previous,
        afterGap: previous >= 0 && minutes - previous > Duration.minutesPerHour,
      ),
    );
    previous = minutes;
  }
  return DayAxis(start: start, end: end, ticks: ticks);
}
