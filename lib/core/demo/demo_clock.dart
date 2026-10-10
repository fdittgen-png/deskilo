// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2327 — the demo's clock is the space's clock.
//
// The demo space keeps Europe/Paris and the app shows bookings on the
// workspace clock, but the seeds used to build wall-clock hours on the
// DEVICE clock: a visitor on US Pacific time saw Bruno's afternoon as
// 22:00–03:00 and "now" at 19:00, after closing. Every seeded instant
// that names an hour goes through [demoAt], and the demo's "now" is
// 10:00 in Paris on the fixture day, whatever the device's zone.
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'data/fixture_clock.dart';

/// The demo space's IANA zone (its workspace row says the same).
const demoTimezone = 'Europe/Paris';

tz.Location? _zone;

tz.Location get _demoZone {
  final zone = _zone;
  if (zone != null) return zone;
  tzdata.initializeTimeZones();
  return _zone = tz.getLocation(demoTimezone);
}

/// [hour]:[minute] on [year]-[month]-[day] in the demo space, as a UTC
/// instant — the shape a server row has. Overflowing [day] normalizes.
DateTime demoAt(int year, int month, int day, [int hour = 0, int minute = 0]) {
  final wall = tz.TZDateTime(_demoZone, year, month, day, hour, minute);
  return DateTime.fromMillisecondsSinceEpoch(
    wall.millisecondsSinceEpoch,
    isUtc: true,
  );
}

/// The demo space's calendar date of [instant], as a plain date.
DateTime demoDateOf(DateTime instant) {
  final wall = tz.TZDateTime.from(instant, _demoZone);
  return DateTime(wall.year, wall.month, wall.day);
}

/// The instant the demo believes it is: [kTestNow]'s date and hour, read
/// on the demo space's clock rather than the device's.
DateTime get demoSeedNow =>
    demoAt(kTestNow.year, kTestNow.month, kTestNow.day, kTestNow.hour);
