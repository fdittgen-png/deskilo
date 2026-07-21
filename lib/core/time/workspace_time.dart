// SPDX-License-Identifier: 0BSD
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../trace/trace_logger.dart';

/// The active workspace's wall clock. Day-based booking windows must
/// anchor to the WORKSPACE timezone — the server enforces canonical
/// windows in it — never to the device's: a Pacific-time laptop booking
/// a Paris workspace otherwise builds "full days" running 09:00–09:00
/// Paris time, which `enforce_booking_rules` rightly rejects.
///
/// Ambient by design: the `HalfDayWindows` builders travel as function
/// references through the booking surface, so threading a Location into
/// every call would churn all of it. The shell installs the active
/// workspace's zone on connect (and on profile switch); null — tests,
/// pre-connect boot — means device-local, preserving the co-located
/// behavior.
abstract final class WorkspaceTime {
  static tz.Location? _location;
  static bool _tzReady = false;

  /// Installs [timezoneName] (IANA) as the ambient workspace clock.
  /// Null or unknown names fall back to device-local.
  static void install(String? timezoneName) {
    if (timezoneName == null) {
      _location = null;
      return;
    }
    if (!_tzReady) {
      tzdata.initializeTimeZones();
      _tzReady = true;
    }
    try {
      _location = tz.getLocation(timezoneName);
    } catch (e, st) {
      TraceLogger.instance.warn(
        'time',
        'unknown workspace timezone $timezoneName — using device-local',
        error: e,
        stackTrace: st,
      );
      _location = null;
    }
  }

  /// Back to device-local (tests).
  static void reset() => _location = null;

  /// [hour] o'clock on the calendar date [year]-[month]-[day], on the
  /// workspace clock. Overflowing [day] (e.g. day+1) normalizes through
  /// the constructors, keeping the maths DST-agnostic (wall-clock
  /// times, not fixed durations).
  static DateTime at(int year, int month, int day,
      [int hour = 0, int minute = 0]) {
    final location = _location;
    return location == null
        ? DateTime(year, month, day, hour, minute)
        : tz.TZDateTime(location, year, month, day, hour, minute);
  }

  /// The workspace-local hour of [instant] (walk-up half derivation).
  static int hourOf(DateTime instant) {
    final location = _location;
    return location == null
        ? instant.toLocal().hour
        : tz.TZDateTime.from(instant, location).hour;
  }

  /// [instant] for DISPLAY. Zone-carrying values (workspace-anchored
  /// windows are [tz.TZDateTime]s) already read in their own wall clock
  /// — a "Morning until 13:00" says 13:00 on a device hours away — and
  /// pass through; bare instants (UTC reservation rows, device-built
  /// flexible windows) convert to device-local as before.
  static DateTime display(DateTime instant) =>
      instant is tz.TZDateTime ? instant : instant.toLocal();

  /// The workspace-local calendar date of [instant], as a plain
  /// date-only [DateTime] carrier.
  static DateTime dateOf(DateTime instant) {
    final location = _location;
    final local = location == null
        ? instant.toLocal()
        : tz.TZDateTime.from(instant, location);
    return DateTime(local.year, local.month, local.day);
  }
}
