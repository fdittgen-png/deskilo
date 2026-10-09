// SPDX-License-Identifier: AGPL-3.0-or-later
// #2307 — accessible names, direction and actions update without repainting
// unchanged geometry or colours; a disabled seat loses its tap action.
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('semantic-only changes replace labels, direction and actions', (tester) async {
    final semantics = tester.ensureSemantics();
    const seat = Seat(id: 'seat', workspaceId: 'ws', deskId: 'desk',
      name: 'A1', x: 1, y: 1, orientation: SeatOrientation.n,
      chair: 'standard', amenities: []);
    const plan = FloorPlan(levelId: 'floor', offices: [], desks: [], seats: [seat]);
    var taps = 0;
    void tap(Seat _) => taps++;
    FloorPlanPainter painter(String label, TextDirection direction, {bool enabled = true}) =>
      FloorPlanPainter(plan: plan, cellSize: 24, colorScheme: const ColorScheme.light(),
        semanticLabels: {'seat': label}, semanticsDirection: direction,
        onSeatSemanticTap: enabled ? tap : null);
    Future<void> show(FloorPlanPainter delegate) => tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr,
        child: CustomPaint(painter: delegate, size: const Size(120, 120))));
    final first = painter('A1 · reserved', TextDirection.ltr);
    await show(first);
    tester.semantics.tap(find.semantics.byLabel('A1 · reserved'));
    expect(taps, 1);
    final renamed = painter('A1 · checked in', TextDirection.rtl);
    expect(renamed.shouldRepaint(first), isFalse);
    await show(renamed);
    expect(find.semantics.byLabel('A1 · reserved'), findsNothing);
    final current = find.semantics.byLabel('A1 · checked in');
    expect(current.evaluate().single.getSemanticsData().textDirection, TextDirection.rtl);
    tester.semantics.tap(current);
    expect(taps, 2);
    await show(painter('A1 · checked in', TextDirection.rtl, enabled: false));
    expect(current.evaluate().single.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });
}
