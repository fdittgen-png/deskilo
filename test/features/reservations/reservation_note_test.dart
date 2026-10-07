// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A reservation's details explain why it is not an upcoming booking:
// recorded after its period ended, completed with its check-out time, or
// over without a check-in — and say nothing for an ordinary booking.
import 'package:deskilo/core/data/system_columns.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 10, 7, 7);
  final end = DateTime.utc(2026, 10, 7, 19);
  final evening = DateTime.utc(2026, 10, 7, 21, 16);
  final morning = DateTime.utc(2026, 10, 7, 6);

  Reservation booking(
    ReservationStatus status, {
    DateTime? created,
    DateTime? checkedOut,
  }) => Reservation(
    id: 'r1',
    workspaceId: 'ws',
    seatId: 's13',
    memberId: 'm1',
    startsAt: start,
    endsAt: end,
    status: status,
    checkedOutAt: checkedOut,
    system: SystemColumns(createdAt: created),
  );

  test('booked after its period ended: recorded, whatever the sweep did', () {
    for (final status in [
      ReservationStatus.completed,
      ReservationStatus.reserved,
    ]) {
      expect(
        reservationNoteOf(
          booking(status, created: evening, checkedOut: end),
          evening,
        ),
        ReservationNote.recordedAfterEnd,
        reason: '$status',
      );
    }
  });

  test('a stay completed in time names its check-out', () {
    expect(
      reservationNoteOf(
        booking(
          ReservationStatus.completed,
          created: morning,
          checkedOut: DateTime.utc(2026, 10, 7, 17),
        ),
        evening,
      ),
      ReservationNote.checkedOut,
    );
  });

  test('over without a check-in says so', () {
    expect(
      reservationNoteOf(
        booking(ReservationStatus.reserved, created: morning),
        evening,
      ),
      ReservationNote.overNotCheckedIn,
    );
  });

  test('an upcoming or running booking needs no note', () {
    expect(
      reservationNoteOf(
        booking(ReservationStatus.reserved, created: morning),
        morning,
      ),
      isNull,
    );
    expect(
      reservationNoteOf(
        booking(ReservationStatus.checkedIn, created: morning),
        evening,
      ),
      isNull,
    );
    expect(
      reservationNoteOf(booking(ReservationStatus.cancelled), evening),
      isNull,
    );
  });
}
