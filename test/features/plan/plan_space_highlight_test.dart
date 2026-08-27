// SPDX-License-Identifier: 0BSD
//
// #576: "Show on plan" highlights WHAT was selected — a table, an
// office or the whole floor get the same tertiary ring the seat jump
// always had. The focus carrier feeds the canvas; any interaction that
// moves the view clears it.
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/plan/providers/plan_focus_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plan_screen_test.dart' show pumpPlan;

FloorPlanPainter _livePainter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byKey(const ValueKey('reserve-plan-canvas')))
    .painter! as FloorPlanPainter;

Future<void> _focus(WidgetTester tester, PlanFocus focus) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('reserve-plan-canvas'))),
  );
  container.read(planFocusControllerProvider.notifier).setFocus(focus);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a table jump rings the DESK on the canvas', (tester) async {
    await pumpPlan(tester);
    await _focus(tester,
        const PlanFocus(levelId: 'level-1', deskId: 'desk-3'));

    final painter = _livePainter(tester);
    expect(painter.highlightedDeskId, 'desk-3');
    expect(painter.highlightedSeatId, isNull);
  });

  testWidgets('an office jump rings the OFFICE; a level jump rings the '
      'whole floor', (tester) async {
    await pumpPlan(tester);
    await _focus(tester,
        const PlanFocus(levelId: 'level-1', officeId: 'office-2'));
    expect(_livePainter(tester).highlightedOfficeId, 'office-2');

    await _focus(tester,
        const PlanFocus(levelId: 'level-1', wholeLevel: true));
    final painter = _livePainter(tester);
    expect(painter.highlightLevel, isTrue);
    expect(painter.highlightedOfficeId, isNull,
        reason: 'a new jump replaces the previous highlight');
  });
}
