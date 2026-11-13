// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the cases of the desk calendar's guards, shared by its
// three test files. Each case starts the whole Demo; one file holding all of
// them grew past the memory a single test process is allowed, so the files
// take a few cases each.
import 'dart:io';

import 'package:deskilo/app/desk_calendar/desk_booking_chip.dart';
import 'package:deskilo/app/desk_calendar/desk_grid_rows.dart';
import 'package:deskilo/app/desk_calendar/desk_month_grid.dart';
import 'package:deskilo/core/ui/kit/records_table_parts.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/screens/desk_calendar.dart';
import 'experience_guards.dart';

/// The desk calendar's pages: the screen's name and what the address adds.
const calendarGuardPages = [
  ('week', PageKind.dashboard, '?view=week'),
  ('day', PageKind.dashboard, '?view=day'),
  ('month', PageKind.dashboard, '?view=month'),
  ('bookings', PageKind.records, '?view=week&mode=table'),
];

String _query(String more) => '$more&day=${demoToday()}';

/// The desk guards on [pages] at 1024, 1440 and 1920.
void calendarGuardCases(List<(String, PageKind, String)> pages) {
  for (final (screen, kind, query) in pages) {
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
}

/// The desk guards on the week with a booking open beside it.
void calendarOpenCases() {
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
}

/// With SHEET=1, each page's sheet at 390 and 1440, light and dark, in
/// build/sheets/calendar/ (docs/testing/desk-guards.md).
void calendarSheetCases() {
  // The capture runs on the real clock, where the records table's read of
  // its saved columns needs a store to answer.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (screen, _, query) in calendarGuardPages) {
    for (final width in [390.0, 1440.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('calendar $screen sheet at ${width.toInt()}, '
            '${brightness.name}', (tester) async {
          // A sheet is a picture for a pull request: without SHEET=1 there
          // is nothing to write and no reason to start the Demo.
          if (Platform.environment['SHEET'] != '1') return;
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
          // The capture ran on the real clock: unmount and let the fake
          // one run out what the Demo scheduled meanwhile.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(minutes: 1));
        });
      }
    }
  }
}
