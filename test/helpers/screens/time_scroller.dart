// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in time_scroller_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Taps the header time chip [chipKey] ('reserve-from-chip'/'reserve-to-chip'),
/// switches the Material time picker to keyboard input mode (the reliable
/// widget-test path — dragging the clock dial is not) and enters the time.
/// [hour] is 24-hour; the dialog runs in 12-hour AM/PM mode under
/// flutter_test (the pumped tree's View resolves the real platform
/// dispatcher, so `alwaysUse24HourFormatTestValue` never reaches it) —
/// the helper converts and taps the meridiem button.
Future<void> pickChipTime(
  WidgetTester tester,
  String chipKey, {
  required String hour,
  required String minute,
}) async {
  await tester.tap(find.byKey(ValueKey(chipKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final h24 = int.parse(hour);
  final isPm = h24 >= 12;
  var h12 = h24 % 12;
  if (h12 == 0) h12 = 12;
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.first, '$h12');
  await tester.enterText(fields.last, minute);
  await tester.tap(find.text(isPm ? 'PM' : 'AM'));
  await tester.pump();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// The painter of the live plan canvas.
FloorPlanPainter planPainter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(const ValueKey('reserve-plan-canvas')),
  );
  return paint.painter! as FloorPlanPainter;
}
