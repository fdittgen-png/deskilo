// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the calendar at the desk, on the Demo's own composition at
// 1440 px: the week, the day and the month fill the work area; the whole
// opening hours of the day fit without a sideways scroll; the bookings drawn
// are the bookings of the records table of the same period; the keys T, ← →,
// D / W / M and N come from the registry; a click on a booking opens it beside
// the grid (the address names it) and a click on a free cell opens New booking
// as a side panel with the place and the time filled in.
//
// test-inventory: structure is the invariant — what a grid draws (its chips,
// rows, cells and scrollers) is what a person sees and reaches.
import 'package:deskilo/app/desk_calendar/desk_booking_chip.dart';
import 'package:deskilo/app/desk_calendar/desk_booking_pane.dart';
import 'package:deskilo/app/desk_calendar/desk_calendar_page.dart';
import 'package:deskilo/app/desk_calendar/desk_day_grid.dart';
import 'package:deskilo/app/desk_calendar/desk_filter_row.dart';
import 'package:deskilo/app/desk_calendar/desk_free_region.dart';
import 'package:deskilo/app/desk_calendar/desk_grid_rows.dart';
import 'package:deskilo/app/desk_calendar/desk_new_booking.dart';
import 'package:deskilo/app/desk_calendar/desk_week_grid.dart';
import 'package:deskilo/core/demo/demo_clock.dart';
import 'package:deskilo/core/ui/kit/records_table_parts.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/desk_calendar.dart';

Iterable<DeskBookingChip> _chips(WidgetTester tester) =>
    tester.widgetList<DeskBookingChip>(find.byType(DeskBookingChip));

void main() {
  testWidgets('the week at 1440: places down, days across, no sideways '
      'scroll', (tester) async {
    await pumpDeskCalendar(tester, query: '?view=week&day=${demoToday()}');
    expect(find.byType(DeskCalendarPage), findsOneWidget);
    expect(find.byType(DeskWeekGrid), findsOneWidget);
    expect(hScrollExtent(tester, deskWeekScrollKey), 0);
    expect(find.byType(DeskBookingChip), findsWidgets);
  });

  testWidgets('the day at 1440 shows the whole opening hours without a '
      'sideways scroll', (tester) async {
    await pumpDeskCalendar(tester, query: '?view=day&day=${demoToday()}');
    expect(find.byType(DeskDayGrid), findsOneWidget);
    expect(hScrollExtent(tester, deskDayScrollKey), 0);
  });

  testWidgets('the bookings of the grid are the bookings of the table of the '
      'same period: same count, same names', (tester) async {
    // Tall, so the table builds every row it has.
    await pumpDeskCalendar(
      tester,
      size: const Size(1440, 2400),
      query: '?view=week&day=${demoToday()}',
    );
    final ids = {for (final c in _chips(tester)) c.booking.id};
    final who = [for (final c in _chips(tester)) c.who]..sort();
    final count = _chips(tester).length;
    expect(ids, isNotEmpty);
    expect(who.every((w) => w.isNotEmpty), isTrue);

    await goTo(tester, '/calendar?view=week&day=${demoToday()}&mode=table');
    final rows = tester.widgetList<RecordRow<Reservation>>(
      find.byType(RecordRow<Reservation>),
    );
    expect({for (final r in rows) r.row.id}, ids);
    expect(rows.length, count);
    expect(tester.widget<RecordsFooter>(find.byType(RecordsFooter)).shown, count);
    // The member's name stands in the table as many times as in the grid.
    for (final name in who.toSet()) {
      expect(
        find.descendant(
          of: find.byType(RecordRow<Reservation>),
          matching: find.text(name),
        ),
        findsNWidgets(who.where((w) => w == name).length),
        reason: name,
      );
    }
  });

  testWidgets('the month lists bookings by name then says how many more; '
      'what it lists and counts is the table', (tester) async {
    await pumpDeskCalendar(
      tester,
      size: const Size(1440, 2400),
      query: '?view=month&day=${demoToday()}',
    );
    final listed = _chips(tester).length;
    var more = 0;
    for (final e in find
        .byWidgetPredicate(
          (w) => w is TextButton && '${w.key}'.contains('desk-month-more'),
        )
        .evaluate()) {
      final text = ((e.widget as TextButton).child! as Text).data!;
      more += int.parse(RegExp(r'\d+').firstMatch(text)!.group(0)!);
    }
    await goTo(tester, '/calendar?view=month&day=${demoToday()}&mode=table');
    expect(
      tester.widget<RecordsFooter>(find.byType(RecordsFooter)).shown,
      listed + more,
    );
  });

  testWidgets('the keys: T today, arrows the period, D W M the view', (
    tester,
  ) async {
    await pumpDeskCalendar(tester, query: '?view=week&day=2026-03-04');
    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    await press(LogicalKeyboardKey.arrowRight);
    expect(locationOf(tester), contains('day=2026-03-11'));
    await press(LogicalKeyboardKey.arrowLeft);
    await press(LogicalKeyboardKey.arrowLeft);
    expect(locationOf(tester), contains('day=2026-02-25'));
    await press(LogicalKeyboardKey.keyD);
    expect(locationOf(tester), contains('view=day'));
    expect(find.byType(DeskDayGrid), findsOneWidget);
    await press(LogicalKeyboardKey.arrowRight);
    expect(locationOf(tester), contains('day=2026-02-26'));
    await press(LogicalKeyboardKey.keyM);
    expect(locationOf(tester), contains('view=month'));
    await press(LogicalKeyboardKey.keyW);
    expect(locationOf(tester), contains('view=week'));
    expect(find.byType(DeskWeekGrid), findsOneWidget);
    await press(LogicalKeyboardKey.keyT);
    expect(locationOf(tester), contains('day=${demoToday()}'));
  });

  testWidgets('N opens New booking as a side panel', (tester) async {
    await pumpDeskCalendar(tester, query: '?view=week&day=${demoToday()}');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(find.byKey(deskNewBookingKey), findsOneWidget);
    expect(find.byType(BookingSheet), findsOneWidget);
  });

  testWidgets('a click on a booking opens it beside the grid, the address '
      'names it, Escape closes it', (tester) async {
    await pumpDeskCalendar(tester, query: '?view=week&day=${demoToday()}');
    final id = _chips(tester).first.booking.id;
    await tester.tap(find.byKey(deskBookingKey(id)));
    await tester.pumpAndSettle();
    expect(locationOf(tester), contains('res=$id'));
    expect(find.byType(DeskBookingPane), findsOneWidget);
    // Beside the grid: the grid is still on screen.
    expect(find.byType(DeskWeekGrid), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(DeskBookingPane), findsNothing);
    expect(locationOf(tester), isNot(contains('res=')));
  });

  testWidgets('the address alone opens the same booking (a reload, a link)', (
    tester,
  ) async {
    await pumpDeskCalendar(tester, query: '?view=week&day=${demoToday()}');
    final id = _chips(tester).first.booking.id;
    await goTo(tester, '/calendar?view=week&day=${demoToday()}&res=$id');
    expect(find.byType(DeskBookingPane), findsOneWidget);
  });

  testWidgets('a click on a free cell of the day opens New booking with the '
      'place and the time filled in', (tester) async {
    await pumpDeskCalendar(tester, query: '?view=day&day=${demoToday()}');
    final region = find.byType(DeskFreeRegion).first;
    final row = tester.widget<DeskGridRow>(
      find.ancestor(of: region, matching: find.byType(DeskGridRow)).first,
    );
    await tester.tap(region);
    await tester.pumpAndSettle();
    expect(find.byKey(deskNewBookingKey), findsOneWidget);
    final sheet = tester.widget<BookingSheet>(find.byType(BookingSheet));
    expect(sheet.seatId, row.placeId);
    expect(
      demoDateOf(sheet.start),
      demoDateOf(demoSeedNow),
      reason: 'the day of the cell',
    );
  });

  testWidgets('a click on a free cell of the week opens New booking for that '
      'place', (tester) async {
    await pumpDeskCalendar(tester, query: '?view=week&day=${demoToday()}');
    final region = find.byType(DeskFreeRegion).first;
    final key =
        tester
                .widget<InkWell>(
                  find.descendant(of: region, matching: find.byType(InkWell)),
                )
                .key!
            as ValueKey<String>;
    await tester.tap(region);
    await tester.pumpAndSettle();
    final sheet = tester.widget<BookingSheet>(find.byType(BookingSheet));
    expect(key.value, contains(sheet.seatId));
  });

  testWidgets('the filter row narrows what the grid shows', (tester) async {
    await pumpDeskCalendar(tester, query: '?view=week&day=${demoToday()}');
    final before = _chips(tester).length;
    final who = _chips(tester).first.booking.memberId;
    await tester.tap(
      find.descendant(
        of: find.byKey(deskFilterKey('member')),
        matching: find.byType(DropdownButtonFormField<String?>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('desk-filter-member-$who')).last);
    await tester.pumpAndSettle();
    expect(_chips(tester), isNotEmpty);
    expect(_chips(tester).every((c) => c.booking.memberId == who), isTrue);
    expect(_chips(tester).length, lessThanOrEqualTo(before));
  });
}
