// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in level_canvas_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/editor/presentation/screens/level_canvas_screen.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_accessory_repository.dart';
import '../fake_floor_plan_repository.dart';
import '../mock_providers.dart';
import '../navigation.dart';

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
    ProviderScope(overrides: overrides, child: const DeskiloApp()),
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
  final scale =
      (tester.getTopRight(finder).dx - topLeft.dx) /
      (GridCanvas.widthCells * GridCanvas.cellSize);
  return topLeft +
      Offset((x + 0.5) * GridCanvas.cellSize, (y + 0.5) * GridCanvas.cellSize) *
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
