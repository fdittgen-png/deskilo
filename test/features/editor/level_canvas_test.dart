// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/editor/presentation/screens/level_canvas_screen.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';

/// Seeds a level (and whatever [seed] adds) BEFORE navigating into the
/// canvas — the plan provider fetches on entry, so all fixtures must exist
/// beforehand.
Future<FakeFloorPlanRepository> pumpCanvas(
  WidgetTester tester, {
  Future<void> Function(FakeFloorPlanRepository plans, String levelId)? seed,
}) async {
  final plans = FakeFloorPlanRepository();
  final level = await plans.createLevel('ws-1', 'Ground floor', 0);
  await seed?.call(plans, level.id);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(floorPlan: plans),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.design_services_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ground floor'));
  await tester.pumpAndSettle();
  return plans;
}

Future<void> seedOffice(
  FakeFloorPlanRepository plans,
  String levelId, {
  GridRect rect = const GridRect(x: 0, y: 0, w: 40, h: 30),
  String name = 'Main room',
}) async {
  await plans.createOffice(
    workspaceId: 'ws-1',
    levelId: levelId,
    name: name,
    color: 0,
    bookableAsWhole: false,
    rect: rect,
  );
}

Offset cellCenter(WidgetTester tester, int x, int y) {
  final canvas =
      tester.getTopLeft(find.byKey(const ValueKey('level-canvas')));
  return canvas +
      Offset(
        (x + 0.5) * GridCanvas.cellSize,
        (y + 0.5) * GridCanvas.cellSize,
      );
}

Future<void> dragCells(
  WidgetTester tester,
  ({int x, int y}) from,
  ({int x, int y}) to,
) async {
  final start = cellCenter(tester, from.x, from.y);
  final end = cellCenter(tester, to.x, to.y);
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 20));
  await gesture.moveTo(Offset.lerp(start, end, 0.5)!);
  await tester.pump(const Duration(milliseconds: 20));
  await gesture.moveTo(end);
  await tester.pump(const Duration(milliseconds: 20));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('drawing an office creates it after naming', (tester) async {
    final plans = await pumpCanvas(tester);

    await tester.tap(find.text('Office'));
    await tester.pumpAndSettle();
    await dragCells(tester, (x: 1, y: 1), (x: 20, y: 15));

    expect(find.text('New office'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(plans.offices, hasLength(1));
    expect(
      plans.offices.single.rect,
      const GridRect(x: 1, y: 1, w: 20, h: 15),
    );
  });

  testWidgets('a desk outside any office is rejected with a snackbar',
      (tester) async {
    final plans = await pumpCanvas(tester);

    await tester.tap(find.text('Desk'));
    await tester.pumpAndSettle();
    await dragCells(tester, (x: 2, y: 2), (x: 8, y: 5));

    expect(plans.desks, isEmpty);
    expect(find.text('Must be fully inside an office.'), findsOneWidget);
  });

  testWidgets('a desk inside an office is created', (tester) async {
    final plans = await pumpCanvas(tester, seed: seedOffice);

    await tester.tap(find.text('Desk'));
    await tester.pumpAndSettle();
    await dragCells(tester, (x: 4, y: 4), (x: 15, y: 7));

    expect(plans.desks, hasLength(1));
    expect(plans.desks.single.rect, const GridRect(x: 4, y: 4, w: 12, h: 4));
  });

  testWidgets('overlapping offices are rejected', (tester) async {
    final plans = await pumpCanvas(
      tester,
      seed: (plans, levelId) => seedOffice(
        plans,
        levelId,
        rect: const GridRect(x: 0, y: 0, w: 15, h: 15),
        name: 'Existing',
      ),
    );

    await tester.tap(find.text('Office'));
    await tester.pumpAndSettle();
    await dragCells(tester, (x: 10, y: 10), (x: 25, y: 20));

    expect(plans.offices, hasLength(1));
    expect(find.text('Overlaps an existing element.'), findsOneWidget);
  });

  testWidgets('erase tool deletes a desk after confirmation', (tester) async {
    final plans = await pumpCanvas(
      tester,
      seed: (plans, levelId) async {
        await seedOffice(plans, levelId);
        await plans.createDesk(
          workspaceId: 'ws-1',
          officeId: plans.offices.single.id,
          name: 'Doomed desk',
          rect: const GridRect(x: 4, y: 4, w: 6, h: 4),
        );
      },
    );

    await tester.tap(find.text('Erase'));
    await tester.pumpAndSettle();
    await tester.tapAt(cellCenter(tester, 5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(plans.desks, isEmpty);
  });

  testWidgets('select tool toggles bookable-as-whole on an office',
      (tester) async {
    final plans = await pumpCanvas(
      tester,
      seed: (plans, levelId) => seedOffice(
        plans,
        levelId,
        rect: const GridRect(x: 0, y: 0, w: 20, h: 20),
        name: 'Meeting room',
      ),
    );

    await tester.tapAt(cellCenter(tester, 10, 10)); // select (#101)
    await tester.pumpAndSettle();
    await tester.tapAt(cellCenter(tester, 10, 10)); // open properties
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(plans.offices.single.bookableAsWhole, isTrue);
  });
}
