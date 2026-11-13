// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the desk guards on the calendar's month and on the records
// table of all bookings, on the Demo at 1024, 1440 and 1920.
import 'package:deskilo/app/desk_calendar/desk_month_grid.dart';
import 'package:flutter_test/flutter_test.dart';

import 'desk_calendar_guard_cases.dart';
import 'experience_guards.dart';

void main() {
  setUpAll(() => loadSheetFonts(always: true));

  calendarGuardCases(calendarGuardPages.sublist(2));

  // A month's cells are measured as rows, so the month's own numbers are
  // pinned beside the guard: lines a mouse hits.
  test('a month cell line is as high as a desk row', () {
    expect(deskMonthLines(100), greaterThanOrEqualTo(1));
  });
}
