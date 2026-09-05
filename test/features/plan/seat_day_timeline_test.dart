// SPDX-License-Identifier: 0BSD
//
// #903 — a seat booked for PART of the day must look part-booked, and a
// seat several people share must say who has it and when. One
// derivation (seatDaySegments) feeds the divided fill on the plan and
// the day sheet behind the tap.
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/seat_state_logic.dart';
import 'package:deskilo/features/reservations/presentation/widgets/seat_day_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_clock.dart';
import 'plan_screen_test.dart' show pumpPlan;

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(kTestNow.year, kTestNow.month, kTestNow.day, hour, minute);

final _dayStart = _at(8);
final _dayEnd = _at(17);

const _seat = Seat(
  id: 'seat-1',
  workspaceId: 'ws-1',
  deskId: 'desk-1',
  name: 'A1',
  x: 2,
  y: 2,
  orientation: SeatOrientation.n,
  chair: 'standard',
  amenities: [],
);
const _plan = FloorPlan(
  levelId: 'level-1',
  offices: [],
  desks: [],
  seats: [_seat],
);

Reservation _booking(
  String id, {
  required int fromHour,
  required int toHour,
  String member = 'member-2',
  String? seatId = 'seat-1',
  String? deskId,
  ReservationStatus status = ReservationStatus.reserved,
}) =>
    Reservation(
      id: id,
      workspaceId: 'ws-1',
      seatId: seatId,
      deskId: deskId,
      memberId: member,
      startsAt: _at(fromHour),
      endsAt: _at(toHour),
      status: status,
    );

List<SeatDaySegment> _segments(List<Reservation> reservations,
        {String? me = 'member-1'}) =>
    seatDaySegments(
      plan: _plan,
      seat: _seat,
      reservations: reservations,
      myMemberId: me,
      dayStart: _dayStart,
      dayEnd: _dayEnd,
    );

void main() {
  group('the day, seat by seat', () {
    test('a booking held all day is ONE segment filling the seat', () {
      final segments = _segments([_booking('r', fromHour: 8, toHour: 17)]);
      expect(segments, hasLength(1));
      expect(segments.single.from, 0);
      expect(segments.single.to, 1);
      expect(seatDayIsPartial(segments), isFalse,
          reason: 'nothing to divide — the seat is taken all day');
    });

    test('a morning booking stops at midday, and the seat reads partial',
        () {
      final segments = _segments([_booking('r', fromHour: 8, toHour: 12)]);
      expect(segments.single.from, 0);
      expect(segments.single.to, closeTo(4 / 9, 0.001));
      expect(seatDayIsPartial(segments), isTrue);
    });

    test('two members sharing the seat are two segments, in clock order, '
        'each in its own state', () {
      final segments = _segments([
        _booking('afternoon', fromHour: 13, toHour: 17, member: 'member-3'),
        _booking('morning', fromHour: 8, toHour: 12, member: 'member-1'),
      ]);
      expect(segments.map((s) => s.reservationId), ['morning', 'afternoon']);
      expect(segments.first.state, SeatState.mine);
      expect(segments.last.state, SeatState.reserved);
      expect(seatDayIsPartial(segments), isTrue,
          reason: 'midday is still free');
    });

    test('a checked-in booking reads occupied; a whole-desk booking counts; '
        'a cancelled one does not', () {
      final checkedIn = _segments([
        _booking('r', fromHour: 9, toHour: 11,
            status: ReservationStatus.checkedIn),
      ]);
      expect(checkedIn.single.state, SeatState.occupied);
      final desk = _segments([
        _booking('d',
            fromHour: 9, toHour: 11, seatId: null, deskId: 'desk-1'),
      ]);
      expect(desk, hasLength(1), reason: 'a whole-desk booking takes the seat');
      final cancelled = _segments([
        _booking('c', fromHour: 9, toHour: 11,
            status: ReservationStatus.cancelled),
      ]);
      expect(cancelled, isEmpty);
    });

    test('a booking spilling past the opening hours is clamped to the day',
        () {
      final segments = _segments([_booking('r', fromHour: 6, toHour: 22)]);
      expect(segments.single.start, _dayStart);
      expect(segments.single.end, _dayEnd);
      expect(segments.single.from, 0);
      expect(segments.single.to, 1);
    });

    test('the free stretches are what the day has left', () {
      final gaps = seatDayGaps(
        segments: _segments([
          _booking('morning', fromHour: 8, toHour: 12),
          _booking('late', fromHour: 15, toHour: 17),
        ]),
        dayStart: _dayStart,
        dayEnd: _dayEnd,
      );
      expect(gaps, hasLength(1));
      expect(gaps.single.start, _at(12));
      expect(gaps.single.end, _at(15));
    });
  });

  testWidgets('the plan carries the day segments, so a half-booked seat is '
      'drawn half-filled', (tester) async {
    await pumpPlan(tester, seedReservations: (repo) {
      repo.reservations.add(Reservation(
        id: 'res-morning',
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        memberId: 'member-2',
        startsAt: _at(8),
        endsAt: _at(12),
        status: ReservationStatus.reserved,
      ));
    });
    final painter = tester
        .widget<CustomPaint>(find.byKey(const ValueKey('reserve-plan-canvas')))
        .painter! as FloorPlanPainter;
    final segments = painter.seatDaySegments['seat-4'] ?? const [];
    expect(segments, hasLength(1));
    expect(segments.single.from, 0);
    expect(segments.single.to, lessThan(0.6),
        reason: 'a morning booking must not fill the whole seat');
    expect(seatDayIsPartial(segments), isTrue);
  });

  group('the day sheet', () {
    Future<SeatDayGap?> open(WidgetTester tester,
        {required List<Reservation> reservations}) async {
      SeatDayGap? picked;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const ValueKey('open'),
                onPressed: () async => picked = await showSeatDaySheet(
                  context,
                  seat: _seat,
                  segments: _segments(reservations),
                  names: const {'member-2': 'Ana Lima', 'member-3': 'Bo'},
                  dayStart: _dayStart,
                  dayEnd: _dayEnd,
                  now: _at(13),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      return picked;
    }

    testWidgets('names who is on the seat, when, and how the day stands',
        (tester) async {
      await open(tester, reservations: [
        _booking('morning', fromHour: 8, toHour: 12, member: 'member-2'),
        _booking('mine', fromHour: 15, toHour: 17, member: 'member-1'),
      ]);
      expect(find.byKey(const ValueKey('seat-day-booking-morning')),
          findsOneWidget);
      expect(find.text('Ana Lima'), findsOneWidget);
      expect(find.text('You'), findsOneWidget, reason: 'my own booking');
      expect(find.text('Done'), findsOneWidget, reason: 'the morning passed');
      expect(find.text('Ahead'), findsOneWidget, reason: 'mine is still to come');
      // The free stretch between them is offered.
      expect(find.text('Free — book it'), findsOneWidget);
    });

    testWidgets('tapping a free stretch hands its window back', (tester) async {
      await open(tester, reservations: [
        _booking('morning', fromHour: 8, toHour: 12),
        _booking('late', fromHour: 15, toHour: 17),
      ]);
      await tester.tap(find.text('Free — book it'));
      await tester.pumpAndSettle();
      // The sheet closed on the choice.
      expect(find.text('Free — book it'), findsNothing);
    });
  });
}
