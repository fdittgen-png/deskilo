// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the desk calendar without a widget: the address a view and
// a booking have, the days a view spans, the filter's rules, the rows a grid
// draws, how the opening hours are laid across the room, and what a month
// cell lists before it says "N more".
import 'package:deskilo/app/desk_calendar/bookings_csv.dart';
import 'package:deskilo/app/desk_calendar/desk_calendar.dart';
import 'package:deskilo/app/desk_calendar/desk_metrics.dart';
import 'package:deskilo/app/desk_calendar/desk_month_grid.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

Reservation _r(
  String id, {
  String? seatId,
  String? officeId,
  String? levelId,
  String member = 'm1',
  ReservationStatus status = ReservationStatus.reserved,
  int day = 12,
  int from = 9,
  int to = 11,
}) => Reservation(
  id: id,
  workspaceId: 'ws',
  seatId: seatId,
  officeId: officeId,
  levelId: levelId,
  memberId: member,
  startsAt: DateTime.utc(2026, 11, day, from),
  endsAt: DateTime.utc(2026, 11, day, to),
  status: status,
);

Seat _seat(String id, {ResourceKind kind = ResourceKind.seat}) => Seat(
  id: id,
  workspaceId: 'ws',
  deskId: 'd',
  name: 'Seat $id',
  x: 0,
  y: 0,
  orientation: SeatOrientation.n,
  chair: '',
  amenities: const [],
  resourceKind: kind,
);

void main() {
  final today = DateTime(2026, 11, 12);

  group('the address', () {
    test('names the view, the day, the mode and the open booking', () {
      final a = DeskCalendarAddress.parse(const {
        'view': 'month',
        'day': '2026-11-05',
        'mode': 'table',
        'res': 'r-7',
      }, today: today);
      expect(a.view, DeskView.month);
      expect(a.day, DateTime(2026, 11, 5));
      expect(a.mode, DeskMode.table);
      expect(a.reservationId, 'r-7');
      expect(
        DeskCalendarAddress.parse(
          Uri.parse(a.location).queryParameters,
          today: today,
        ).location,
        a.location,
      );
    });

    test('anything missing or malformed reads as a week around today', () {
      for (final q in [
        const <String, String>{},
        const {'view': 'year', 'day': '2026-02-30', 'mode': '?', 'res': ''},
      ]) {
        final a = DeskCalendarAddress.parse(q, today: today);
        expect((a.view, a.day, a.mode, a.reservationId), (
          DeskView.week,
          today,
          DeskMode.grid,
          null,
        ));
      }
    });

    test('the alerts address is the feed', () {
      expect(
        DeskCalendarAddress.parse(const {'view': 'alerts'}, today: today).mode,
        DeskMode.agenda,
      );
    });

    test('closing the booking leaves the rest of the address', () {
      final a = DeskCalendarAddress.parse(const {
        'view': 'day',
        'res': 'r-1',
      }, today: today).copyWith(closeReservation: true);
      expect(a.location, contains('view=day'));
      expect(a.location, isNot(contains('res=')));
    });
  });

  group('the span', () {
    test('a day, a week in the reader\'s week, a month', () {
      final d = DateTime(2026, 11, 12); // a Thursday
      expect(deskSpanOf(DeskView.day, d, DateTime.monday), (
        from: d,
        to: DateTime(2026, 11, 13),
      ));
      expect(deskSpanOf(DeskView.week, d, DateTime.monday).from, DateTime(2026, 11, 9));
      expect(deskSpanOf(DeskView.week, d, DateTime.sunday).from, DateTime(2026, 11, 8));
      expect(deskSpanOf(DeskView.month, d, DateTime.monday), (
        from: DateTime(2026, 11),
        to: DateTime(2026, 12),
      ));
    });

    test('the arrows step by the view; a month keeps the day or its last', () {
      expect(shiftDeskAnchor(DeskView.day, DateTime(2026, 11, 30), 1), DateTime(2026, 12));
      expect(shiftDeskAnchor(DeskView.week, DateTime(2026, 11, 12), -1), DateTime(2026, 11, 5));
      expect(shiftDeskAnchor(DeskView.month, DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('a month grid is whole weeks from the first to the last day', () {
      final weeks = deskMonthWeeks(DateTime(2026, 11, 12), DateTime.monday);
      expect(weeks.first.first, DateTime(2026, 10, 26));
      expect(weeks.last.last, DateTime(2026, 12, 6));
      expect(weeks.every((w) => w.length == 7), isTrue);
    });
  });

  group('the filter', () {
    final from = DateTime.utc(2026, 11, 12);
    final to = DateTime.utc(2026, 11, 13);
    final facts = (
      levelOf: {'s1': 'L1', 's2': 'L2', 'o1': 'L1'},
      kindOf: {'s1': ResourceKind.seat, 's2': ResourceKind.room},
    );
    final all = [
      _r('a', seatId: 's1'),
      _r('b', seatId: 's2', member: 'm2', status: ReservationStatus.completed),
      _r('c', officeId: 'o1', status: ReservationStatus.cancelled),
      _r('d', levelId: 'L2', from: 13, to: 15),
      _r('e', seatId: 's1', day: 14), // another day
    ];
    List<String> ids(DeskFilter f) => [
      for (final r in deskBookingsIn(all, f, from: from, to: to, facts: facts)) r.id,
    ];

    test('without a state, the bookings that held their place', () {
      expect(ids(const DeskFilter()), ['a', 'b', 'd']);
    });

    test('a state shows exactly that state', () {
      expect(ids(const DeskFilter(status: ReservationStatus.cancelled)), ['c']);
    });

    test('level, kind and member narrow it', () {
      expect(ids(const DeskFilter(levelId: 'L2')), ['b', 'd']);
      expect(ids(const DeskFilter(kind: ResourceKind.room)), ['b']);
      expect(ids(const DeskFilter(memberId: 'm2')), ['b']);
    });

    test('a booking is listed once, earliest first', () {
      final twice = [...all, _r('a', seatId: 's1')];
      expect(
        deskBookingsIn(twice, const DeskFilter(), from: from, to: to, facts: facts)
            .map((r) => r.id),
        ['a', 'b', 'd'],
      );
    });
  });

  test('a grid draws every seat, then a row for the other places once', () {
    final plan = FloorPlan(
      levelId: 'L1',
      offices: const [],
      desks: const [],
      seats: [_seat('s1'), _seat('s2', kind: ResourceKind.room)],
    );
    final bookings = [
      _r('a', seatId: 's1'),
      _r('c', officeId: 'o1'),
      _r('x', officeId: 'o1', from: 12, to: 13),
    ];
    final rows = deskPlaceRows(
      plans: [plan],
      filter: const DeskFilter(),
      bookings: bookings,
      names: const {'o1': 'Office 1'},
      levelOf: const {'o1': 'L1'},
    );
    expect(rows.map((p) => p.id), ['s1', 's2', 'o1']);
    expect(rows.last.name, 'Office 1');
    expect(rows.last.seat, isNull);
    expect(
      deskPlaceRows(
        plans: [plan],
        filter: const DeskFilter(kind: ResourceKind.room),
        bookings: const [],
        names: const {},
        levelOf: const {},
      ).map((p) => p.id),
      ['s2'],
    );
  });

  group('the opening hours across the room', () {
    const hour = DeskCalendarMetrics.minHourWidth;

    test('they fit the room by default, without a sideways scroll', () {
      final s = deskDayScale(room: 900, minutes: 9 * 60);
      expect(s.scrolls, isFalse);
      expect(s.width, closeTo(900, 0.01));
    });

    test('a day too long to fit keeps a usable hour and scrolls', () {
      final s = deskDayScale(room: 900, minutes: 24 * 60);
      expect(s.scrolls, isTrue);
      expect(s.pixelsPerMinute * 60, closeTo(hour, 0.01));
      expect(s.width, closeTo(hour * 24, 0.01));
    });

    test('zoom widens the hours and brings the scroll', () {
      final fit = deskDayScale(room: 900, minutes: 9 * 60);
      final zoomed = deskDayScale(room: 900, minutes: 9 * 60, zoom: 2);
      expect(zoomed.pixelsPerMinute, closeTo(fit.pixelsPerMinute * 2, 0.0001));
      expect(zoomed.scrolls, isTrue);
    });
  });

  test('a month cell lists what fits and keeps its last line for the rest', () {
    expect(deskMonthLines(DeskCalendarMetrics.monthCellMin), 1);
    expect(deskMonthSplit(1, 1), (shown: 1, hidden: 0));
    expect(deskMonthSplit(2, 1), (shown: 0, hidden: 2));
    expect(deskMonthSplit(5, 3), (shown: 2, hidden: 3));
    expect(deskMonthSplit(3, 3), (shown: 3, hidden: 0));
    expect(deskMonthSplit(4, 0), (shown: 0, hidden: 4));
  });

  test('the bookings file has the table\'s columns and guards a formula', () {
    final bytes = bookingsCsv(
      [_r('a', seatId: 's1')],
      header: (member: 'M', place: 'P', from: 'F', to: 'T', state: 'S'),
      who: (_) => '=cmd',
      place: (_) => 'Seat 1',
      at: (i) => i.toUtc().toIso8601String(),
      state: (_) => 'Reserved',
    );
    final text = String.fromCharCodes(bytes.sublist(3));
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(text.split('\r\n').first, '"M","P","F","T","S"');
    expect(text, isNot(contains(',=cmd')));
    expect(text, contains('2026-11-12T09:00:00.000Z'));
  });
}
