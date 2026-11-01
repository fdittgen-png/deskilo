// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3074 — a drawn symbol is edited like any plan element: selected by a tap,
// moved by dragging its middle, resized by dragging its edge, and deleted
// from the selection bar behind a confirmation.
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/plan_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/screens/level_canvas.dart';

Future<FakeFloorPlanRepository> _pumpWithTable(WidgetTester tester) {
  return pumpCanvas(
    tester,
    seed: (plans, levelId) async {
      await plans.createPlanDecor(
        workspaceId: 'ws-1',
        levelId: levelId,
        rect: const GridRect(x: 10, y: 10, w: 16, h: 8),
        kind: PlanDecorKind.table,
        imageId: 'table-1',
      );
    },
  );
}

Future<void> _select(WidgetTester tester) async {
  await tester.tapAt(cellCenter(tester, 17, 13));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('editor-selection-name')), findsOneWidget);
}

void main() {
  testWidgets('dragging the middle of a symbol moves it', (tester) async {
    final plans = await _pumpWithTable(tester);
    await _select(tester);
    await dragCells(tester, (x: 17, y: 13), (x: 22, y: 16));
    expect(
      plans.planImages.single.rect,
      const GridRect(x: 15, y: 13, w: 16, h: 8),
    );
    expect(plans.planImages.single.kind, PlanDecorKind.table);
  });

  testWidgets('dragging the right edge of a symbol resizes it', (tester) async {
    final plans = await _pumpWithTable(tester);
    await _select(tester);
    // Cell 25 sits within the edge tolerance of the border at x = 26.
    await dragCells(tester, (x: 25, y: 13), (x: 29, y: 13));
    expect(
      plans.planImages.single.rect,
      const GridRect(x: 10, y: 10, w: 20, h: 8),
    );
  });

  testWidgets('delete asks first: cancel keeps the symbol, confirm removes it', (
    tester,
  ) async {
    final plans = await _pumpWithTable(tester);
    await _select(tester);
    await tester.tap(find.byKey(const ValueKey('editor-selection-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('level-canvas-cancel')));
    await tester.pumpAndSettle();
    expect(plans.planImages, hasLength(1));

    await _select(tester);
    await tester.tap(find.byKey(const ValueKey('editor-selection-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('level-canvas-delete')));
    await tester.pumpAndSettle();
    expect(plans.planImages, isEmpty);
  });
}
