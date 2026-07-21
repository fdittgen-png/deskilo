// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/editor/presentation/screens/level_canvas_screen.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_accessory_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

/// Seeds a level (and whatever [seed] adds) BEFORE navigating into the
/// canvas — the plan provider fetches on entry, so all fixtures must exist
/// beforehand. Pass [accessories] to seed the workspace accessory catalog
/// consumed by the seat sheet (#168).
Future<FakeFloorPlanRepository> pumpCanvas(
  WidgetTester tester, {
  Future<void> Function(FakeFloorPlanRepository plans, String levelId)? seed,
  FakeAccessoryRepository? accessories,
  void Function(List<Override> overrides, FakeFloorPlanRepository plans)?
      override,
}) async {
  final plans = FakeFloorPlanRepository();
  final level = await plans.createLevel('ws-1', 'Ground floor', 0);
  await seed?.call(plans, level.id);
  final overrides = standardTestOverrides(
    floorPlan: plans,
    accessories: accessories,
  );
  override?.call(overrides, plans);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  // The editor icon lives on the Plan tab's app bar; the app now boots
  // on the Reserve hub.
  await switchToPlanTab(tester);
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
  // Transform-aware: the canvas auto-fits (zooms) to the plan on open, so a
  // cell's on-screen position is the content origin plus its offset scaled
  // by the actual rendered scale (top-right minus top-left over content px).
  final finder = find.byKey(const ValueKey('level-canvas'));
  final topLeft = tester.getTopLeft(finder);
  final scale = (tester.getTopRight(finder).dx - topLeft.dx) /
      (GridCanvas.widthCells * GridCanvas.cellSize);
  return topLeft +
      Offset(
            (x + 0.5) * GridCanvas.cellSize,
            (y + 0.5) * GridCanvas.cellSize,
          ) *
          scale;
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

  testWidgets('erase tool deletes MANY elements in a row (not just the first)',
      (tester) async {
    final plans = await pumpCanvas(
      tester,
      seed: (plans, levelId) async {
        await seedOffice(plans, levelId);
        final officeId = plans.offices.single.id;
        for (var i = 0; i < 3; i++) {
          await plans.createDesk(
            workspaceId: 'ws-1',
            officeId: officeId,
            name: 'Desk $i',
            rect: GridRect(x: 2 + i * 8, y: 4, w: 6, h: 4),
          );
        }
      },
    );

    await tester.tap(find.text('Erase'));
    await tester.pumpAndSettle();

    // Delete all three desks one after another. Each tap → confirm → gone.
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(cellCenter(tester, 4 + i * 8, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(plans.desks, hasLength(2 - i),
          reason: 'desk ${i + 1} should be deleted too');
    }

    expect(plans.desks, isEmpty);
  });

  testWidgets(
      "a delete keeps the canvas's pan/zoom (persistent transform, not reset)",
      (tester) async {
    // The regression: each edit invalidates floorPlanProvider, which drops
    // its value (AsyncLoading, hasValue=false). If the body only rendered
    // AsyncData it swapped in a spinner, tearing down the InteractiveViewer;
    // on remount it built a FRESH internal transform, so pan/zoom jumped back
    // to the origin and the next tap missed — only the first delete worked.
    // The fix owns the TransformationController in the State and keeps the
    // canvas mounted, so the SAME controller survives every delete.
    final plans = await pumpCanvas(
      tester,
      seed: (plans, levelId) async {
        await seedOffice(plans, levelId);
        for (var i = 0; i < 2; i++) {
          await plans.createDesk(
            workspaceId: 'ws-1',
            officeId: plans.offices.single.id,
            name: 'Desk $i',
            rect: GridRect(x: 4 + i * 8, y: 4, w: 6, h: 4),
          );
        }
      },
    );

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController;
    // The fix passes a State-owned controller (was null → internal before).
    expect(controller, isNotNull);

    await tester.tap(find.text('Erase'));
    await tester.pumpAndSettle();
    await tester.tapAt(cellCenter(tester, 6, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // After a full delete cycle the canvas is still the same InteractiveViewer
    // instance with the same controller — the view never reset.
    expect(plans.desks, hasLength(1));
    expect(
      tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController,
      same(controller),
    );

    // And the second delete still works (it missed before the fix).
    await tester.tapAt(cellCenter(tester, 14, 5));
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
