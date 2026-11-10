// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3548 -- a reservation becomes a PersonalCommitment: every status and place
// kind maps, an unknown place kind keeps its row (as `other`) instead of
// throwing, and a check-in is offered only inside the existing window.
import 'package:deskilo/features/me/application/personal_commitments.dart';
import 'package:deskilo/features/me/domain/personal_commitment.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

MyReservationItem _item({
  ReservationStatus status = ReservationStatus.reserved,
  MyReservationPlaceKind kind = MyReservationPlaceKind.desk,
  DateTime? start,
}) {
  final from = start ?? DateTime.utc(2026, 11, 10, 9);
  return MyReservationItem(
    id: 'r1',
    workspaceId: 'ws-1',
    workspaceName: 'Atelier Nord',
    placeKind: kind,
    placeId: 'p1',
    placeLabel: 'D12',
    startsAt: from,
    endsAt: from.add(const Duration(hours: 2)),
    status: status,
    checkedInAt: null,
    checkedOutAt: null,
  );
}

void main() {
  final now = DateTime.utc(2026, 11, 10, 8);

  test('every status maps to a commitment state', () {
    const expected = {
      ReservationStatus.reserved: CommitmentState.upcoming,
      ReservationStatus.checkedIn: CommitmentState.ongoing,
      ReservationStatus.completed: CommitmentState.done,
      ReservationStatus.cancelled: CommitmentState.cancelled,
      ReservationStatus.released: CommitmentState.cancelled,
    };
    for (final s in ReservationStatus.values) {
      expect(
        commitmentOfReservation(_item(status: s), now: now).state,
        expected[s],
        reason: '$s',
      );
    }
  });

  test('every place kind maps, and an unknown wire value keeps its row', () {
    for (final k in MyReservationPlaceKind.values) {
      final c = commitmentOfReservation(_item(kind: k), now: now);
      expect(c.kind, CommitmentKind.place);
      expect(c.label, 'D12');
      expect(c.businessName, 'Atelier Nord');
    }
    expect(
      MyReservationPlaceKind.fromWire('massage_room', context: 'test'),
      MyReservationPlaceKind.other,
    );
    expect(
      commitmentOfReservation(
        _item(kind: MyReservationPlaceKind.other),
        now: now,
      ).place,
      CommitmentPlace.other,
    );
  });

  test('check-in is offered only inside the existing window', () {
    bool open(DateTime at, {ReservationStatus s = ReservationStatus.reserved}) =>
        commitmentOfReservation(_item(status: s), now: at).canCheckIn;
    final start = DateTime.utc(2026, 11, 10, 9);
    expect(open(start.subtract(const Duration(hours: 3))), isFalse);
    expect(open(start.subtract(Reservation.checkInLeeway)), isTrue);
    expect(open(start), isTrue);
    expect(open(start.add(const Duration(hours: 2))), isFalse);
    expect(open(start, s: ReservationStatus.checkedIn), isFalse);
    expect(open(start, s: ReservationStatus.cancelled), isFalse);
  });
}
