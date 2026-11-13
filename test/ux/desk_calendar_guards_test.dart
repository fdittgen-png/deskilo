// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the desk guards on the desk calendar, through the app's
// builder on the Demo at 1024, 1440 and 1920: the week and the day, and the
// week with a booking open beside it.
import 'package:flutter_test/flutter_test.dart';

import 'desk_calendar_guard_cases.dart';
import 'experience_guards.dart';

void main() {
  setUpAll(() => loadSheetFonts(always: true));

  calendarGuardCases(calendarGuardPages.sublist(0, 2));
  calendarOpenCases();
}
