// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/in_memory_default_level_store.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

/// Pumps the app on the Plan tab with two levels in ws-1: 'level-1'
/// (Ground floor, seeded plan) and 'level-upper' (First floor, empty).
Future<
    ({
      FakeFloorPlanRepository plans,
      InMemoryDefaultLevelStore store,
    })> pumpTwoLevelPlan(
  WidgetTester tester, {
  String? storedLevelId,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  plans.levels.add(
    const Level(
      id: 'level-upper',
      workspaceId: 'ws-1',
      name: 'First floor',
      sortOrder: 1,
    ),
  );
  final store = InMemoryDefaultLevelStore();
  if (storedLevelId != null) store.values['ws-1'] = storedLevelId;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(floorPlan: plans, defaultLevel: store),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await switchToPlanTab(tester);
  return (plans: plans, store: store);
}

/// The level currently painted on the live plan canvas.
String canvasLevelId(WidgetTester tester) {
  final paint = tester
      .widget<CustomPaint>(find.byKey(const ValueKey('live-plan-canvas')));
  return (paint.painter! as FloorPlanPainter).plan.levelId;
}

void main() {
  testWidgets('the level dropdown switches the plan and persists it',
      (tester) async {
    final env = await pumpTwoLevelPlan(tester);

    // The picker shows the current level; the first is selected by default.
    expect(find.text('Ground floor'), findsOneWidget);
    expect(canvasLevelId(tester), 'level-1');

    // Open the menu and pick the other floor.
    await tester.tap(find.byKey(const ValueKey('plan-level-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First floor').last);
    await tester.pumpAndSettle();

    expect(find.text('First floor'), findsOneWidget);
    expect(canvasLevelId(tester), 'level-upper');
    expect(env.store.values['ws-1'], 'level-upper');
  });

  testWidgets('the stored default level is preselected on load',
      (tester) async {
    await pumpTwoLevelPlan(tester, storedLevelId: 'level-upper');

    expect(find.text('First floor'), findsOneWidget);
    expect(canvasLevelId(tester), 'level-upper');
  });

  testWidgets('a stale stored level falls back to the first level',
      (tester) async {
    await pumpTwoLevelPlan(tester, storedLevelId: 'level-gone');

    expect(find.text('Ground floor'), findsOneWidget);
    expect(canvasLevelId(tester), 'level-1');
  });

  testWidgets('a single level renders no level picker', (tester) async {
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(floorPlan: plans),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await switchToPlanTab(tester);

    expect(find.byKey(const ValueKey('plan-level-menu')), findsNothing);
    expect(canvasLevelId(tester), 'level-1');
  });

  testWidgets(
      'landscape splits controls into a side panel so the level fills the '
      'rest (phone-landscape width, no overflow)', (tester) async {
    // A phone in landscape: narrow enough to exercise the side panel and
    // catch any overflow (a RenderFlex overflow fails the test).
    tester.view.physicalSize = const Size(760, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpTwoLevelPlan(tester);

    // Split engaged: a vertical divider separates controls from the level,
    // and the plan canvas still renders (and its controls are reachable).
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.byKey(const ValueKey('live-plan-canvas')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-level-menu')), findsOneWidget);
  });

  testWidgets('portrait keeps the single-column layout (no split)',
      (tester) async {
    tester.view.physicalSize = const Size(700, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpTwoLevelPlan(tester);

    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.byKey(const ValueKey('live-plan-canvas')), findsOneWidget);
  });
}
