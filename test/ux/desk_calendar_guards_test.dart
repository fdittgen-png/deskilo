// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the desk guards on the desk calendar, through the app's
// builder on the Demo at 1024, 1440 and 1920: the week, the day, the month, the
// records table of all bookings and the week with a booking open beside it.
// With SHEET=1 each writes its sheet at 390 and 1440, light and dark, to
// build/sheets/calendar/ (docs/testing/desk-guards.md).
import 'package:deskilo/app/desk_calendar/desk_booking_chip.dart';
import 'package:deskilo/app/desk_calendar/desk_grid_rows.dart';
import 'package:deskilo/app/desk_calendar/desk_month_grid.dart';
import 'package:deskilo/core/ui/kit/records_table_parts.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/desk_calendar.dart';
import 'experience_guards.dart';

/// The desk calendar's pages: the screen's name and what the address adds.
const _pages = [
  ('week', PageKind.dashboard, '?view=week'),
  ('day', PageKind.dashboard, '?view=day'),
  ('month', PageKind.dashboard, '?view=month'),
  ('bookings', PageKind.records, '?view=week&mode=table'),
];

String _query(String more) => '$more&day=${demoToday()}';

void main() {
  setUpAll(() => loadSheetFonts(always: true));

  for (final (screen, kind, query) in _pages) {
    for (final size in deskGuardSizes) {
      testWidgets('calendar $screen at ${size.width.toInt()}: the desk guards '
          'hold', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpDeskCalendar(tester, size: size, query: _query(query));
        final details = <String>[];
        expect(
          deskGuardProblems(
            details: details,
            tester,
            kind: kind,
            size: size,
            rowTypes: const [
              DeskGridRow,
              DeskMonthCell,
              RecordRow<Reservation>,
              RecordsHeader<Reservation>,
            ],
            tableTypes: const [RecordsHeader<Reservation>],
          ),
          isEmpty,
          reason: details.join('\n'),
        );
        expect(await keyboardProblems(tester), isEmpty);
        semantics.dispose();
      });
    }
  }

  for (final size in deskGuardSizes) {
    testWidgets('calendar with a booking open at ${size.width.toInt()}: the '
        'desk guards hold', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDeskCalendar(tester, size: size, query: _query('?view=week'));
      final id = tester
          .widgetList<DeskBookingChip>(find.byType(DeskBookingChip))
          .first
          .booking
          .id;
      await goTo(tester, '/calendar${_query('?view=week')}&res=$id');
      final details = <String>[];
      expect(
        deskGuardProblems(
          details: details,
          tester,
          kind: PageKind.dashboard,
          size: size,
          rowTypes: const [DeskGridRow, DeskMonthCell],
        ),
        isEmpty,
        reason: details.join('\n'),
      );
      semantics.dispose();
    });
  }

  for (final (screen, _, query) in _pages) {
    for (final width in [390.0, 1440.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('calendar $screen sheet at ${width.toInt()}, '
            '${brightness.name}', (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await pumpDeskCalendar(
            tester,
            size: Size(width, 900),
            query: _query(query),
          );
          await writeDeskSheet(
            tester,
            module: 'calendar',
            screen: screen,
            width: width,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  // A month's cells are measured as rows, so the month's own numbers are
  // pinned beside the guard: lines a mouse hits.
  test('a month cell line is as high as a desk row', () {
    expect(deskMonthLines(100), greaterThanOrEqualTo(1));
  });
}
