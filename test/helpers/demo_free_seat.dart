// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — a seat and a first day the Demo's seeded bookings leave free for a
// pass: [days] consecutive days of the same local window, from [from] on.
// Derived from the fixture, so a test does not depend on the day it runs.
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';

({String seatId, DateTime day}) freeSeatForPass(
  List<Seat> seats,
  List<Reservation> bookings,
  DateTime from, {
  int days = 1,
  required int startMinutes,
  required int endMinutes,
}) {
  bool taken(String seat, DateTime day) {
    final start = DateTime(day.year, day.month, day.day, 0, startMinutes);
    final end = DateTime(day.year, day.month, day.day, 0, endMinutes);
    return bookings.any((r) =>
        r.seatId == seat &&
        r.status != ReservationStatus.cancelled &&
        r.status != ReservationStatus.released &&
        r.startsAt.isBefore(end) &&
        r.endsAt.isAfter(start));
  }

  for (var offset = 0; offset < 120; offset++) {
    final day = DateTime(from.year, from.month, from.day + offset);
    for (final s in seats) {
      if (List.generate(days, (d) => DateTime(day.year, day.month, day.day + d)).every((d) => !taken(s.id, d))) {
        return (seatId: s.id, day: day);
      }
    }
  }
  throw StateError('no seat free for $days days from $from');
}
