// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the grids on their own, where the design review's two
// gaps are: a position in the day grid is exactly one instant (the day the
// clocks go back shows 02:00 twice and each click names its own instant; the
// day they go forward shows the missing hour as a marker), and fitting every
// opening hour never makes a short booking impossible to select — a usable
// hour is kept, the grid scrolls, and no two hit regions overlap, also at
// 200 % text.
import 'package:deskilo/app/desk_calendar/desk_booking_chip.dart';
import 'package:deskilo/app/desk_calendar/desk_calendar.dart';
import 'package:deskilo/app/desk_calendar/desk_day_grid.dart';
import 'package:deskilo/app/desk_calendar/desk_free_region.dart';
import 'package:deskilo/app/desk_calendar/desk_grid_rows.dart';
import 'package:deskilo/app/desk_calendar/desk_metrics.dart';
import 'package:deskilo/app/desk_calendar/desk_month_grid.dart';
import 'package:deskilo/core/time/day_axis.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../helpers/pump_app.dart';

const _seat = Seat(
  id: 's1',
  workspaceId: 'ws',
  deskId: 'd',
  name: 'Seat 1',
  x: 0,
  y: 0,
  orientation: SeatOrientation.n,
  chair: '',
  amenities: [],
);

const _place = DeskPlace(id: 's1', name: 'Seat 1', seat: _seat);

Reservation _booking(String id, DateTime from, DateTime to) => Reservation(
  id: id,
  workspaceId: 'ws',
  seatId: 's1',
  memberId: 'm1',
  startsAt: from,
  endsAt: to,
  status: ReservationStatus.reserved,
);

Future<void> _pumpGrid(
  WidgetTester tester,
  DayAxis axis, {
  List<Reservation> bookings = const [],
  ValueChanged<Reservation>? onOpen,
  void Function(DeskPlace, DateTime)? onFree,
  double width = 1300,
  double? textScale,
}) => pumpApp(
  tester,
  Scaffold(
    body: DeskDayGrid(
      axis: axis,
      entries: const [DeskGridEntry.place(_place)],
      bookings: bookings,
      names: const {'m1': 'Ana'},
      selectedId: null,
      zoom: 1,
      open: true,
      onOpen: onOpen ?? (_) {},
      onFree: onFree ?? (_, _) {},
    ),
  ),
  size: Size(width, 400),
  textScale: textScale,
);

/// Taps the free stretch of the row at [elapsed] minutes of the axis.
Future<void> _tapAt(WidgetTester tester, int elapsed, double ppm) async {
  final row = tester.getTopLeft(find.byKey(deskRowKey('s1')));
  await tester.tapAt(Offset(row.dx + elapsed * ppm, row.dy + 20));
  await tester.pump();
}

void main() {
  late tz.Location paris;
  setUpAll(() {
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
  });

  testWidgets('the day the clocks go back: 02:00 twice, each click its own '
      'instant', (tester) async {
    final axis = buildDayAxis(
      paris,
      DateTime(2026, 10, 25),
      startMinutes: 0,
      endMinutes: 24 * 60,
    );
    final chosen = <DateTime>[];
    await _pumpGrid(tester, axis, onFree: (_, at) => chosen.add(at));
    final scale = deskDayScale(
      room: 1300 - DeskCalendarMetrics.placeColumn,
      minutes: axis.minutes,
    );
    // The first 02:00 is hour 2 of the axis, the second hour 3.
    await _tapAt(tester, 2 * 60 + 30, scale.pixelsPerMinute);
    await _tapAt(tester, 3 * 60 + 30, scale.pixelsPerMinute);
    expect(chosen.map((i) => i.toUtc()), [
      DateTime.utc(2026, 10, 25),
      DateTime.utc(2026, 10, 25, 1),
    ]);
    // Both are 02:00 on the business's wall clock: the instant, not the
    // reading, is what the booking gets.
    expect(
      chosen.map((i) => tz.TZDateTime.from(i, paris).hour),
      [2, 2],
    );
  });

  testWidgets('the day the clocks go forward: the missing hour is a marker, '
      'never a booking at 02:30', (tester) async {
    final axis = buildDayAxis(
      paris,
      DateTime(2026, 3, 29),
      startMinutes: 0,
      endMinutes: 24 * 60,
    );
    final chosen = <DateTime>[];
    await _pumpGrid(tester, axis, onFree: (_, at) => chosen.add(at));
    // 01:00 is followed by 03:00: the marker stands before the third mark.
    expect(find.byKey(deskClockChangeKey(2)), findsOneWidget);
    final scale = deskDayScale(
      room: 1300 - DeskCalendarMetrics.placeColumn,
      minutes: axis.minutes,
    );
    await _tapAt(tester, 2 * 60 + 10, scale.pixelsPerMinute);
    expect(chosen.single.toUtc(), DateTime.utc(2026, 3, 29, 1)); // 03:00 Paris
    expect(tz.TZDateTime.from(chosen.single, paris).hour, 3);
  });

  testWidgets('a day without a change shows no marker', (tester) async {
    final axis = buildDayAxis(
      paris,
      DateTime(2026, 11, 12),
      startMinutes: 8 * 60,
      endMinutes: 17 * 60,
    );
    await _pumpGrid(tester, axis);
    expect(find.byKey(deskClockChangeKey(1)), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('24 open hours with short bookings side by side at '
        '${(scale * 100).toInt()} % text: each booking and each free stretch '
        'is its own target, none overlaps another', (tester) async {
      final axis = buildDayAxis(
        paris,
        DateTime(2026, 11, 12),
        startMinutes: 0,
        endMinutes: 24 * 60,
      );
      final nine = DateTime.utc(2026, 11, 12, 8); // 09:00 Paris
      final bookings = [
        for (var i = 0; i < 4; i++)
          _booking(
            'b$i',
            nine.add(Duration(minutes: 15 * i)),
            nine.add(Duration(minutes: 15 * (i + 1))),
          ),
      ];
      final opened = <String>[];
      final freed = <DateTime>[];
      await _pumpGrid(
        tester,
        axis,
        bookings: bookings,
        onOpen: (r) => opened.add(r.id),
        onFree: (_, at) => freed.add(at),
        textScale: scale,
      );
      // Fitting 24 hours in the room would squeeze an hour under a usable
      // width: the grid keeps the width and scrolls instead.
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(deskDayScrollKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      final chips = find.byType(DeskBookingChip);
      expect(chips, findsNWidgets(4));
      // Every hit region of the row, by its own rectangle.
      final rects = <Rect>[
        for (final f in find.byType(DeskFreeRegion).evaluate())
          tester.getRect(find.byWidget(f.widget)),
        for (var i = 0; i < 4; i++) tester.getRect(find.byKey(deskBookingKey('b$i'))),
      ];
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          final overlap = rects[i].intersect(rects[j]);
          expect(
            overlap.width <= 0.5 || overlap.height <= 0.5,
            isTrue,
            reason: 'hit regions $i and $j overlap: $overlap',
          );
        }
      }
      // Each short booking is selectable by a pointer without selecting its
      // neighbour.
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(deskBookingKey('b$i')));
        await tester.pump();
      }
      expect(opened, ['b0', 'b1', 'b2', 'b3']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a free stretch is reached by the keyboard too and opens at '
      'its start', (tester) async {
    final axis = buildDayAxis(
      paris,
      DateTime(2026, 11, 12),
      startMinutes: 8 * 60,
      endMinutes: 17 * 60,
    );
    final chosen = <DateTime>[];
    await _pumpGrid(tester, axis, onFree: (_, at) => chosen.add(at));
    final region = find.byType(DeskFreeRegion);
    expect(region, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(chosen.single, axis.start);
  });

  testWidgets('a month cell that cannot list every booking says how many '
      'more, and "more" opens exactly the bookings it left out', (tester) async {
    final day = DateTime(2026, 11, 12);
    final bookings = [
      for (var i = 0; i < 5; i++)
        _booking(
          'b$i',
          DateTime.utc(2026, 11, 12, 7 + i),
          DateTime.utc(2026, 11, 12, 8 + i),
        ),
    ];
    DateTime? moreDay;
    List<Reservation>? hidden;
    final opened = <String>[];
    await pumpApp(
      tester,
      Scaffold(
        body: DeskMonthGrid(
          month: day,
          weeks: deskMonthWeeks(day, DateTime.monday),
          bookings: bookings,
          names: const {'m1': 'Ana'},
          placeNames: const {'s1': 'Seat 1'},
          selectedId: null,
          today: day,
          isOpen: (_) => true,
          dayStart: (d) => DateTime.utc(d.year, d.month, d.day),
          onOpen: (r) => opened.add(r.id),
          onDay: (_) {},
          onMore: (d, h) {
            moreDay = d;
            hidden = h;
          },
        ),
      ),
      size: const Size(1300, 800),
    );
    final cell = find.byKey(deskMonthCellKey(day));
    final shown = find.descendant(
      of: cell,
      matching: find.byType(DeskBookingChip),
    );
    expect(shown, findsNWidgets(1));
    expect(find.byKey(deskMonthMoreKey(day)), findsOneWidget);
    await tester.tap(find.byKey(deskMonthMoreKey(day)));
    await tester.pump();
    expect(moreDay, day);
    final drawn = tester.widget<DeskBookingChip>(shown).booking.id;
    expect([drawn, ...hidden!.map((r) => r.id)], ['b0', 'b1', 'b2', 'b3', 'b4']);
    // A day with room for all of them lists them and has no "more".
    expect(find.byKey(deskMonthMoreKey(DateTime(2026, 11, 13))), findsNothing);
  });
}
