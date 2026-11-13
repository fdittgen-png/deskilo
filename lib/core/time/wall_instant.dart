// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — a wall-clock time on the business's calendar, turned into
// the instant it names, with the two days a calendar cannot hide: the hour
// that does not exist (the clocks go forward) and the hour that happens twice
// (the clocks go back). `WorkspaceCalendar.at` and `TZDateTime` normalise
// both silently; a grid that books by a clicked position must not.
//
// Pure: it reads the zone it is given, never the device's and never a clock.
import 'package:timezone/timezone.dart' as tz;

/// What a wall time on the business's calendar is.
sealed class WallResolution {
  const WallResolution();
}

/// The wall time names exactly one instant.
final class WallExact extends WallResolution {
  const WallExact(this.instant);
  final DateTime instant;
}

/// The wall time does not exist: the clocks went forward over it.
/// [forward] is the instant the time reads as with the offset from before the
/// change (02:30 reads as 03:30), [backward] with the offset after it
/// (02:30 reads as 01:30). Neither is chosen for the caller.
final class WallGap extends WallResolution {
  const WallGap({required this.forward, required this.backward});
  final DateTime forward;
  final DateTime backward;
}

/// The wall time happens twice: the clocks went back over it. [first] is the
/// earlier instant (before the change), [second] the later one.
final class WallFold extends WallResolution {
  const WallFold({required this.first, required this.second});
  final DateTime first;
  final DateTime second;
}

const int _msPerMinute = 60 * 1000;
const int _msPerDay = 24 * 60 * _msPerMinute;

/// [hour]:[minute] on [year]-[month]-[day] in [location], as the instant(s) it
/// names.
WallResolution resolveWallTime(
  tz.Location location,
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
]) {
  // The wall time read as if it were UTC: the offset is what separates it
  // from the instant.
  final wallMs = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
  ).millisecondsSinceEpoch;
  tz.TZDateTime at(int ms) =>
      tz.TZDateTime.fromMillisecondsSinceEpoch(location, ms);
  // The offsets in force a day before and a day after bracket any one change.
  final offsets = {
    location.timeZone(wallMs - _msPerDay).offset.inMilliseconds,
    location.timeZone(wallMs + _msPerDay).offset.inMilliseconds,
  };
  final valid = <int>[
    for (final off in offsets)
      if (location.timeZone(wallMs - off).offset.inMilliseconds == off)
        wallMs - off,
  ]..sort();
  if (valid.length == 1) return WallExact(at(valid.single));
  if (valid.length > 1) {
    return WallFold(first: at(valid.first), second: at(valid.last));
  }
  final sorted = offsets.toList()..sort();
  return WallGap(
    forward: at(wallMs - sorted.first),
    backward: at(wallMs - sorted.last),
  );
}
