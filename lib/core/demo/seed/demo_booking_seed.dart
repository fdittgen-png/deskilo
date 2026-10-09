// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the bookings beyond the three the plan story needs: a weekly
// series, half-days, a whole meeting room, a cancellation and the past
// weeks that give the usage and the statements something to count.
// Placed relative to the seeded instant; never on the plan's first seat
// at "now", so a visitor can always book there.
import '../../../features/reservations/domain/reservation.dart';
import '../data/floor_plan_repository.dart';
import '../data/reservation_repository.dart';
import 'demo_space_seed.dart';

/// Adds the extra bookings to [reservations] around [now].
void seedDemoBookings(
  FakeReservationRepository reservations,
  FakeFloorPlanRepository plan,
  DateTime now,
) {
  // The window seat: the plan's first, whatever id the plan gave it.
  final window = plan.seats.first.id;
  final day = DateTime(now.year, now.month, now.day);
  DateTime at(int dayOffset, int hour) =>
      day.add(Duration(days: dayOffset, hours: hour));
  Reservation booking(
    String id,
    String member,
    int dayOffset,
    int from,
    int to, {
    String? seat,
    String? office,
    ReservationStatus status = ReservationStatus.reserved,
    String? series,
  }) {
    final starts = at(dayOffset, from);
    final ends = at(dayOffset, to);
    final past = !ends.isAfter(now);
    return Reservation(
      id: id,
      workspaceId: 'ws-1',
      seatId: seat,
      officeId: office,
      memberId: member,
      startsAt: starts,
      endsAt: ends,
      status: status,
      seriesId: series,
      seriesPattern: series == null ? null : 'weekly',
      checkedInAt: status == ReservationStatus.completed && past
          ? starts
          : null,
      checkedOutAt: status == ReservationStatus.completed && past ? ends : null,
    );
  }

  // The weekday of "now" decides where the series falls: every week on
  // the same day, four weeks ahead.
  reservations.reservations.addAll([
    // Bruno this afternoon: a half-day that leaves the morning free.
    booking('demo-bruno-afternoon', 'member-2', 0, 13, 18, seat: 'demo-seat-2'),
    // Ada tomorrow morning, on the window seat.
    booking('demo-ada-tomorrow', 'member-1', 1, 9, 13, seat: window),
    // Bruno's weekly studio seat for the coming month.
    for (var w = 1; w <= 4; w++)
      booking(
        'demo-series-bruno-$w',
        'member-2',
        7 * w,
        9,
        18,
        seat: DemoSpace.studioSeats.first,
        series: 'demo-series-bruno',
      ),
    // The meeting room, booked as a whole by Chiara the day after.
    booking(
      'demo-meeting-room',
      'member-3',
      2,
      14,
      16,
      office: DemoSpace.meetingRoom,
    ),
    // A booking Chiara cancelled.
    booking(
      'demo-cancelled',
      'member-3',
      3,
      9,
      13,
      seat: 'demo-seat-1',
      status: ReservationStatus.cancelled,
    ),
    // The past weeks: what the usage, the statements and the reports
    // count. Weekdays only, so no booking falls on a closed weekend.
    for (var d = 2; d <= 20; d++)
      if (day.subtract(Duration(days: d)).weekday <= DateTime.friday) ...[
        booking(
          'demo-history-ada-$d',
          'member-1',
          -d,
          9,
          18,
          seat: window,
          status: ReservationStatus.completed,
        ),
        if (d.isEven)
          booking(
            'demo-history-bruno-$d',
            'member-2',
            -d,
            9,
            13,
            seat: 'demo-seat-1',
            status: ReservationStatus.completed,
          ),
        if (d % 3 == 0)
          booking(
            'demo-history-chiara-$d',
            'member-3',
            -d,
            13,
            18,
            seat: DemoSpace.studioSeats.last,
            status: ReservationStatus.completed,
          ),
      ],
  ]);
}
