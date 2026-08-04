// SPDX-License-Identifier: 0BSD
import '../../plan/domain/half_day_windows.dart';
import '../../workspace/domain/booking_granularity.dart';

/// The window an on-the-spot action books (kiosk badge flow and the
/// space-QR scan flow share it): the canonical full working day under
/// day-based granularity, now → the end of the working day under
/// `hours` (#446 — the sheet lets the user adjust it), else now → a
/// default 4h stay capped at the day's last slot. After the working day
/// has ended, day-based walk-ups run to the next local midnight — the
/// server allows exactly that overtime end (0087).
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
  final last = DateTime(now.year, now.month, now.day, 23, 45);
  if (end.isAfter(last)) end = last;
  if (!end.isAfter(now)) end = now.add(const Duration(minutes: 15));
  return (start: now, end: end);
}
