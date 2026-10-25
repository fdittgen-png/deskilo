// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the space sheet's decision, as a table: which seats it lists,
// whether the space is offered whole, what blocks it and which booking
// is my own.
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/space_bookability.dart';
import 'package:deskilo/features/reservations/domain/space_code.dart';
import 'package:flutter_test/flutter_test.dart';

const _rect = GridRect(x: 0, y: 0, w: 2, h: 2);

const _level = Level(
  id: 'l1',
  workspaceId: 'ws-1',
  name: 'Ground floor',
  sortOrder: 0,
  bookableAsWhole: true,
  priceCents: 900,
);

const _office = Office(
  id: 'o1',
  workspaceId: 'ws-1',
  levelId: 'l1',
  name: 'Atelier',
  color: 0,
  bookableAsWhole: true,
  priceCents: 500,
  rect: _rect,
);

const _desk = Desk(
  id: 'd1',
  workspaceId: 'ws-1',
  officeId: 'o1',
  name: 'Long table',
  rect: _rect,
  bookableAsWhole: true,
  priceCents: 300,
);

const _otherDesk = Desk(
  id: 'd2',
  workspaceId: 'ws-1',
  officeId: 'o2',
  name: 'Elsewhere',
  rect: _rect,
);

Seat _seat(String id, String deskId) => Seat(
  id: id,
  workspaceId: 'ws-1',
  deskId: deskId,
  name: id,
  x: 0,
  y: 0,
  orientation: SeatOrientation.n,
  chair: 'standard',
  amenities: const [],
);

final _plan = FloorPlan(
  levelId: 'l1',
  offices: [_office],
  desks: const [_desk, _otherDesk],
  seats: [_seat('s1', 'd1'), _seat('s2', 'd1'), _seat('s3', 'd2')],
);

final _window = (
  start: DateTime.utc(2026, 5, 13, 8),
  end: DateTime.utc(2026, 5, 13, 12),
);

Reservation _res(
  String id, {
  String memberId = 'm-2',
  String? seatId,
  String? deskId,
  String? officeId,
  String? levelId,
  ReservationStatus status = ReservationStatus.reserved,
}) => Reservation(
  id: id,
  workspaceId: 'ws-1',
  memberId: memberId,
  seatId: seatId,
  deskId: deskId,
  officeId: officeId,
  levelId: levelId,
  startsAt: _window.start,
  endsAt: _window.end,
  status: status,
);

const SpaceRights _all = (granted: true, canAssign: false, featureOn: true);

SpaceBookability _of(
  SpaceKind kind, {
  List<Reservation> reservations = const [],
  String? me = 'm-1',
  SpaceRights rights = _all,
  Seat? seat,
}) => SpaceBookability.of(
  kind: kind,
  space: (
    level: _level,
    office: kind == SpaceKind.level ? null : _office,
    desk: kind == SpaceKind.desk || kind == SpaceKind.seat ? _desk : null,
    seat: seat,
    plan: _plan,
  ),
  reservations: reservations,
  window: _window,
  myMemberId: me,
  rights: rights,
);

void main() {
  group('the seats listed and the whole target, by kind', () {
    final cases = <(SpaceKind, List<String>, WholeTarget?, WholeSpaceIds)>[
      (
        SpaceKind.seat,
        ['s1'],
        null,
        (deskId: null, officeId: null, levelId: null),
      ),
      (
        SpaceKind.desk,
        ['s1', 's2'],
        (bookable: true, priceCents: 300),
        (deskId: 'd1', officeId: null, levelId: null),
      ),
      (
        SpaceKind.office,
        ['s1', 's2'],
        (bookable: true, priceCents: 500),
        (deskId: null, officeId: 'o1', levelId: null),
      ),
      (
        SpaceKind.level,
        <String>[],
        (bookable: true, priceCents: 900),
        (deskId: null, officeId: null, levelId: 'l1'),
      ),
    ];
    for (final (kind, seats, target, ids) in cases) {
      test(kind.name, () {
        final b = _of(kind, seat: _seat('s1', 'd1'));
        expect(b.seats.map((s) => s.id), seats);
        expect(b.wholeTarget, target);
        expect(b.ids, ids);
      });
    }
  });

  group('offered whole', () {
    final cases = <(String, SpaceRights, bool)>[
      ('with the grant', _all, true),
      (
        'with the roster alone',
        (granted: false, canAssign: true, featureOn: true),
        true,
      ),
      (
        'with neither',
        (granted: false, canAssign: false, featureOn: true),
        false,
      ),
      (
        'never with the feature off',
        (granted: true, canAssign: true, featureOn: false),
        false,
      ),
    ];
    for (final (name, rights, allowed) in cases) {
      test(name, () {
        expect(_of(SpaceKind.office, rights: rights).allowed, allowed);
      });
    }

    test('never a seat', () {
      expect(_of(SpaceKind.seat, seat: _seat('s1', 'd1')).allowed, isFalse);
    });
  });

  group('what blocks it, and my own booking', () {
    test('a taken seat of the desk blocks the desk and is listed taken', () {
      final b = _of(SpaceKind.desk, reservations: [_res('r1', seatId: 's1')]);
      expect(b.blocking?.id, 'r1');
      expect(b.seatTaken(_seat('s1', 'd1')), isTrue);
      expect(b.seatTaken(_seat('s2', 'd1')), isFalse);
      expect(b.myWholeReservation, isNull);
    });

    test('a seat of another office does not block this office', () {
      final b = _of(SpaceKind.office, reservations: [_res('r1', seatId: 's3')]);
      expect(b.blocking, isNull);
    });

    test('my checked-in level is mine, not a dead end', () {
      final mine = _res(
        'r1',
        memberId: 'm-1',
        levelId: 'l1',
        status: ReservationStatus.checkedIn,
      );
      final b = _of(SpaceKind.level, reservations: [mine]);
      expect(b.myWholeReservation?.id, 'r1');
      expect(b.blocking?.id, 'r1');
    });

    test('someone else\'s level booking is not mine', () {
      final b = _of(SpaceKind.level, reservations: [_res('r1', levelId: 'l1')]);
      expect(b.myWholeReservation, isNull);
      expect(b.blocking?.memberId, 'm-2');
    });

    test('before the member is known nothing is mine', () {
      final b = _of(
        SpaceKind.level,
        me: null,
        reservations: [_res('r1', memberId: 'm-1', levelId: 'l1')],
      );
      expect(b.myWholeReservation, isNull);
    });
  });
}
