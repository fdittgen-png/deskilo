// SPDX-License-Identifier: MIT
import 'package:deskilo/features/reservations/domain/check_in_reminders.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

Reservation reservation({
  String id = 'r1',
  String memberId = 'member-1',
  ReservationStatus status = ReservationStatus.reserved,
  required DateTime start,
}) =>
    Reservation(
      id: id,
      workspaceId: 'ws-1',
      seatId: 'seat-1',
      memberId: memberId,
      startsAt: start,
      endsAt: start.add(const Duration(hours: 4)),
      status: status,
    );

void main() {
  final now = DateTime.utc(2026, 7, 7, 8);

  List<ReminderRequest> derive(List<Reservation> reservations) =>
      upcomingCheckInReminders(
        reservations: reservations,
        myMemberId: 'member-1',
        now: now,
        targetNames: const {'seat-1': 'A1'},
        titleOf: (target, start) => 'Check in soon',
        bodyOf: (target, start) => '$target at $start',
      );

  test('reminds 15 minutes before an upcoming reserved booking', () {
    final start = now.add(const Duration(hours: 3));
    final reminders = derive([reservation(start: start)]);

    expect(reminders, hasLength(1));
    expect(
      reminders.single.remindAt,
      start.subtract(const Duration(minutes: 15)),
    );
    expect(reminders.single.body, contains('A1'));
  });

  test('skips other members, checked-in, past and beyond-lookahead bookings',
      () {
    final reminders = derive([
      reservation(id: 'other', memberId: 'member-2', start: now.add(const Duration(hours: 2))),
      reservation(
        id: 'checked',
        status: ReservationStatus.checkedIn,
        start: now.add(const Duration(hours: 2)),
      ),
      reservation(id: 'past', start: now.subtract(const Duration(hours: 1))),
      reservation(id: 'far', start: now.add(const Duration(days: 8))),
      // Starts in 10 minutes: the 15-min reminder would be in the past.
      reservation(id: 'soon', start: now.add(const Duration(minutes: 10))),
    ]);

    expect(reminders, isEmpty);
  });

  test('reminders come back sorted by remindAt', () {
    final reminders = derive([
      reservation(id: 'b', start: now.add(const Duration(days: 2))),
      reservation(id: 'a', start: now.add(const Duration(hours: 5))),
    ]);

    expect(reminders.map((r) => r.reservationId).toList(), ['a', 'b']);
  });
}
