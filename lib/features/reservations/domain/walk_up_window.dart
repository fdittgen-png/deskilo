// SPDX-License-Identifier: 0BSD
import '../../plan/domain/half_day_windows.dart';
import '../../workspace/domain/booking_granularity.dart';

/// The window an on-the-spot action books (kiosk badge flow and the
/// space-QR scan flow share it): the canonical full day under day-based
/// granularity, else now → a default 4h stay capped at the day's last
/// slot.
({DateTime start, DateTime end}) walkUpWindow(
  BookingGranularity granularity,
  DateTime now,
) {
  if (granularity.isDayBased) {
    final window = HalfDayWindows.fullDay(now);
    return (start: window.start, end: window.end);
  }
  var end = now.add(const Duration(hours: 4));
  final last = DateTime(now.year, now.month, now.day, 23, 45);
  if (end.isAfter(last)) end = last;
  if (!end.isAfter(now)) end = now.add(const Duration(minutes: 15));
  return (start: now, end: end);
}
