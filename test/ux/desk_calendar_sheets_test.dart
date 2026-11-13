// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — with SHEET=1, the desk calendar's sheets from the Demo
// at 390 and 1440, light and dark. Without it the cases do nothing.
import 'package:flutter_test/flutter_test.dart';

import 'desk_calendar_guard_cases.dart';
import 'experience_guards.dart';

void main() {
  setUpAll(() => loadSheetFonts(always: true));

  calendarSheetCases();
}
