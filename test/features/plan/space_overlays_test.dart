// SPDX-License-Identifier: 0BSD
//
// #462: whole-space reservations must mark the ROOM/TABLE itself, with
// the occupant's name, for every user — not only the seats.
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/presentation/seat_occupancy.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/seat_state_logic.dart';
import 'package:flutter_test/flutter_test.dart';

const _plan = FloorPlan(
  levelId: 'level-1',
  offices: [
    Office(
      id: 'office-1',
      workspaceId: 'ws-1',
      levelId: 'level-1',
      name: 'Bureau 2',
      color: 0,
      bookableAsWhole: true,
      rect: GridRect(x: 0, y: 0, w: 10, h: 6),
    ),
  ],
  desks: [
    Desk(
      id: 'desk-1',
      workspaceId: 'ws-1',
      officeId: 'office-1',
      name: '',
      rect: GridRect(x: 1, y: 1, w: 6, h: 4),
    ),
  ],
  seats: [],
);

Reservation _r({
  String? officeId,
  String? deskId,
  String? levelId,
  ReservationStatus status = ReservationStatus.reserved,
}) =>
    Reservation(
      id: 'res-1',
      workspaceId: 'ws-1',
      seatId: null,
      officeId: officeId,
      deskId: deskId,
      levelId: levelId,
      memberId: 'member-2',
      startsAt: DateTime.utc(2026, 8, 6, 6),
      endsAt: DateTime.utc(2026, 8, 6, 15),
      status: status,
    );

void main() {
  final names = {'member-2': 'Florian D'};
  final from = DateTime.utc(2026, 8, 6, 6);
  final to = DateTime.utc(2026, 8, 6, 15);

  test('a whole-office reservation overlays the office with state and '
      'first name', () {
    final overlays = spaceOverlaysFor(
      plan: _plan,
      reservations: [_r(officeId: 'office-1')],
      names: names,
      myMemberId: 'member-1',
      from: from,
      to: to,
    );
    expect(overlays['office-1']?.state, SeatState.reserved);
    expect(overlays['office-1']?.label, 'Florian');
    expect(overlays.containsKey('desk-1'), isFalse);
  });

  test('mine and checked-in map to their own tones', () {
    expect(
      spaceOverlaysFor(
        plan: _plan,
        reservations: [_r(officeId: 'office-1')],
        names: names,
        myMemberId: 'member-2',
        from: from,
        to: to,
      )['office-1']
          ?.state,
      SeatState.mine,
    );
    expect(
      spaceOverlaysFor(
        plan: _plan,
        reservations: [
          _r(officeId: 'office-1', status: ReservationStatus.checkedIn),
        ],
        names: names,
        myMemberId: 'member-1',
        from: from,
        to: to,
      )['office-1']
          ?.state,
      SeatState.occupied,
    );
  });

  test('a whole-desk reservation overlays the desk only', () {
    final overlays = spaceOverlaysFor(
      plan: _plan,
      reservations: [_r(deskId: 'desk-1')],
      names: names,
      myMemberId: 'member-1',
      from: from,
      to: to,
    );
    expect(overlays['desk-1']?.state, SeatState.reserved);
    expect(overlays.containsKey('office-1'), isFalse);
  });

  test('a whole-level reservation covers every office and desk', () {
    final overlays = spaceOverlaysFor(
      plan: _plan,
      reservations: [_r(levelId: 'level-1')],
      names: names,
      myMemberId: 'member-1',
      from: from,
      to: to,
    );
    expect(overlays['office-1']?.state, SeatState.reserved);
    expect(overlays['desk-1']?.state, SeatState.reserved);
  });

  test('outside the browsed window nothing overlays — the Bureau 2 '
      'field case: an Aug 6 series shows nothing on Aug 5', () {
    final overlays = spaceOverlaysFor(
      plan: _plan,
      reservations: [_r(officeId: 'office-1')],
      names: names,
      myMemberId: 'member-1',
      from: DateTime.utc(2026, 8, 5, 6),
      to: DateTime.utc(2026, 8, 5, 15),
    );
    expect(overlays, isEmpty);
  });
}
