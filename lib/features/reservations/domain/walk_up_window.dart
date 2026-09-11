// SPDX-License-Identifier: 0BSD
import '../../plan/domain/half_day_windows.dart';
import '../../workspace/domain/booking_granularity.dart';
import '../../../core/time/workspace_time.dart';

/// The window an on-the-spot action books (kiosk badge flow and the
/// space-QR scan flow share it): the canonical full working day under
/// day-based granularity, now → the end of the working day under
/// `hours` (#446 — the sheet lets the user adjust it), else now → a
/// default 4h stay capped at the day's last slot. After the working day
/// has ended, day-based walk-ups run to the next local midnight — the
/// server allows exactly that overtime end (0087). No window ever
/// crosses midnight: a booking ends on the day it starts (#644).
({DateTime start, DateTime end}) walkUpWindow(
  BookingGranularity granularity,
  DateTime now,
) {
  if (granularity.isDayBased) {
    final window = HalfDayWindows.fullDay(now);
    if (window.end.isAfter(now)) {
      return (start: window.start, end: window.end);
    }
    return (start: now, end: HalfDayWindows.windowForNow(now).end);
  }
  if (granularity == BookingGranularity.hours) {
    final dayEnd = HalfDayWindows.fullDay(now).end;
    if (dayEnd.isAfter(now)) return (start: now, end: dayEnd);
  }
  var end = now.add(const Duration(hours: 4));
  // #1143 — the day's bounds in the WORKSPACE zone, like the branches
  // above and like the server's "a booking ends on the day it starts".
  // A bare DateTime here was the device's day: a Paris space booked from
  // Los Angeles at 14:00 local is Paris 23:00, and the clamp never fired.
  final day = WorkspaceTime.dateOf(now);
  final last = WorkspaceTime.at(day.year, day.month, day.day, 23, 45);
  if (end.isAfter(last)) end = last;
  // #644: a booking ends on the day it starts. Arriving after the last
  // slot, the 15-minute floor would have crossed midnight — clamp it to
  // the day's own end instead, which is where the server draws the line.
  if (!end.isAfter(now)) {
    final next = day.add(const Duration(days: 1));
    final midnight = WorkspaceTime.at(next.year, next.month, next.day);
    final floor = now.add(const Duration(minutes: 15));
    end = floor.isAfter(midnight) ? midnight : floor;
  }
  return (start: now, end: end);
}
