// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3817 — the rules behind the pocket at 320 px: a person's booking later
// today opens from its seat; a seat's touch area reaches 48 dp at any zoom
// while its drawing stays; the Week grid in a pocket fits whole day columns
// of at least 54, stacks its halves at 48 each, opens on the selected day,
// and names every half.
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/upcoming_on_seat.dart';
import 'package:deskilo/features/reservations/presentation/widgets/week_grid_pocket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 5, 13, 10);

Reservation _r(
  String id, {
  String seat = 'seat-4',
  String member = 'member-1',
  required DateTime from,
  ReservationStatus status = ReservationStatus.reserved,
}) => Reservation(
  id: id,
  workspaceId: 'ws-1',
  seatId: seat,
  memberId: member,
  startsAt: from,
  endsAt: from.add(const Duration(hours: 2)),
  status: status,
);

void main() {
  group('myUpcomingOnSeat', () {
    Reservation? pick(List<Reservation> rs, {String? member = 'member-1'}) =>
        myUpcomingOnSeat(
          rs,
          seatId: 'seat-4',
          memberId: member,
          now: _now,
          dateOf: DateUtils.dateOnly,
        );

    test('the earliest of my own active bookings of the seat later today', () {
      final later = _r('later', from: _now.add(const Duration(hours: 4)));
      final next = _r('next', from: _now.add(const Duration(minutes: 30)));
      expect(pick([later, next])?.id, 'next');
    });

    test('never another person\'s, another seat\'s, a cancelled one, one '
        'already started, one tomorrow, or with no person', () {
      final soon = _now.add(const Duration(hours: 1));
      expect(pick([_r('x', member: 'member-2', from: soon)]), isNull);
      expect(pick([_r('x', seat: 'seat-5', from: soon)]), isNull);
      expect(
        pick([_r('x', from: soon, status: ReservationStatus.cancelled)]),
        isNull,
      );
      expect(
        pick([_r('x', from: _now.subtract(const Duration(minutes: 5)))]),
        isNull,
      );
      expect(pick([_r('x', from: _now.add(const Duration(days: 1)))]), isNull);
      expect(pick([_r('x', from: soon)], member: null), isNull);
    });
  });

  test('a seat\'s touch area grows to the side, the drawing does not move', () {
    const drawn = Rect.fromLTWH(10, 10, 84, 30);
    final area = seatTouchRect(drawn, 69);
    expect(area.center, drawn.center);
    expect(area.size, const Size(84, 69));
    expect(seatTouchRect(drawn, 0), drawn);
  });

  group('the Week grid in a pocket', () {
    test('whole day columns of at least 54; the desk as it was', () {
      const pocket = WeekGridShape.pocket;
      // 320 px: 208 beside the seat names, three whole columns.
      expect(pocket.dayWidth(208), closeTo(208 / 3, 1e-9));
      // 390 px: 278, five whole columns.
      expect(pocket.dayWidth(278), closeTo(278 / 5, 1e-9));
      expect(pocket.dayWidth(700), 100, reason: 'seven fit: fitted');
      expect(pocket.minDayWidth, greaterThanOrEqualTo(54));
      expect(WeekGridShape.desk.dayWidth(208), WeekGridShape.desk.minDayWidth);
    });

    test('each stacked half is at least 48 × 48', () {
      const s = WeekGridShape.pocket;
      expect(s.stacked, isTrue);
      expect(s.headerHeight - 6, greaterThanOrEqualTo(48));
      expect((s.rowHeight - 6 - 2) / 2, greaterThanOrEqualTo(48));
    });

    test('it opens on the selected day', () {
      final days = [for (var i = 0; i < 7; i++) DateTime(2026, 5, 11 + i)];
      expect(weekDayIndex(days, DateTime(2026, 5, 13, 15)), 2);
      expect(weekDayIndex(days, DateTime(2026, 6, 2)), 0);
    });

    test('a half is named by who holds it, or why nobody can', () {
      WeekHalfState of({
        bool mine = false,
        bool covered = false,
        bool filled = false,
        bool open = true,
      }) => weekHalfStateOf(
        mine: mine,
        covered: covered,
        filled: filled,
        open: open,
      );
      expect(of(), WeekHalfState.free);
      expect(of(covered: true, filled: true, mine: true), WeekHalfState.mine);
      expect(of(covered: true, filled: true), WeekHalfState.taken);
      expect(of(filled: true), WeekHalfState.blocked);
      expect(of(filled: true, open: false), WeekHalfState.closed);
    });
  });
}
