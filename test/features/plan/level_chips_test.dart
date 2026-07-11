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
  return (plans: plans, store: store);
}

/// The level currently painted on the live plan canvas.
String canvasLevelId(WidgetTester tester) {
  final paint = tester
      .widget<CustomPaint>(find.byKey(const ValueKey('live-plan-canvas')));
  return (paint.painter! as FloorPlanPainter).plan.levelId;
}

bool chipSelected(WidgetTester tester, String name) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, name)).selected;

void main() {
  testWidgets('tapping a level chip switches the plan and persists it',
      (tester) async {
    final env = await pumpTwoLevelPlan(tester);

    // Both levels are chips; the first level is selected by default.
    expect(chipSelected(tester, 'Ground floor'), isTrue);
    expect(chipSelected(tester, 'First floor'), isFalse);
    expect(canvasLevelId(tester), 'level-1');

    await tester.tap(find.widgetWithText(ChoiceChip, 'First floor'));
    await tester.pumpAndSettle();

    expect(chipSelected(tester, 'First floor'), isTrue);
    expect(chipSelected(tester, 'Ground floor'), isFalse);
    expect(canvasLevelId(tester), 'level-upper');
    expect(env.store.values['ws-1'], 'level-upper');
  });

  testWidgets('the stored default level is preselected on load',
      (tester) async {
    await pumpTwoLevelPlan(tester, storedLevelId: 'level-upper');

    expect(chipSelected(tester, 'First floor'), isTrue);
    expect(canvasLevelId(tester), 'level-upper');
  });

  testWidgets('a stale stored level falls back to the first level',
      (tester) async {
    await pumpTwoLevelPlan(tester, storedLevelId: 'level-gone');

    expect(chipSelected(tester, 'Ground floor'), isTrue);
    expect(canvasLevelId(tester), 'level-1');
  });

  testWidgets('a single level renders no chips', (tester) async {
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(floorPlan: plans),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNothing);
    expect(canvasLevelId(tester), 'level-1');
  });
}
