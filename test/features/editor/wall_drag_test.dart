// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A wall drag saves one grid-aligned segment; Undo removes only that segment,
// and retries after lost or refused answers preserve its identity.
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/plan_image.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/screens/level_canvas.dart';

Future<void> _armWall(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('editor-tool-decor')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Wall'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('drag draws a horizontal wall on the grid and Undo removes it', (
    tester,
  ) async {
    final plans = await pumpCanvas(
      tester,
      seed: (plans, levelId) async {
        await seedOffice(plans, levelId);
        await plans.createPlanDecor(
          workspaceId: 'ws-1',
          levelId: levelId,
          rect: const GridRect(x: 30, y: 2, w: 1, h: 8),
          kind: PlanDecorKind.wall,
          imageId: 'existing',
        );
      },
    );
    await _armWall(tester);
    await dragCells(tester, (x: 3, y: 5), (x: 18, y: 7));
    expect(plans.planImages, hasLength(2));
    expect(plans.planImages.last.kind, PlanDecorKind.wall);
    expect(plans.planImages.last.rect, const GridRect(x: 3, y: 5, w: 16, h: 1));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(plans.planImages.single.id, 'existing');
  });

  testWidgets('upward drag draws a vertical wall at the starting column', (
    tester,
  ) async {
    final plans = await pumpCanvas(tester, seed: seedOffice);
    await _armWall(tester);
    await dragCells(tester, (x: 8, y: 20), (x: 6, y: 4));
    expect(plans.planImages, hasLength(1));
    expect(
      plans.planImages.single.rect,
      const GridRect(x: 8, y: 4, w: 1, h: 17),
    );
  });

  testWidgets('cancelling the wall tool leaves the plan untouched', (
    tester,
  ) async {
    final plans = await pumpCanvas(tester, seed: seedOffice);
    await _armWall(tester);
    final done = tester.getRect(
      find.byKey(const ValueKey('editor-tool-hint-done')),
    );
    await tester.tapAt(done.centerLeft + const Offset(8, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-tool-hint')), findsNothing);
    await dragCells(tester, (x: 3, y: 5), (x: 18, y: 5));
    expect(plans.planImages, isEmpty);
  });

  testWidgets('a wall tap keeps the default footprint', (tester) async {
    final plans = await pumpCanvas(tester, seed: seedOffice);
    await _armWall(tester);
    await tester.tapAt(cellCenter(tester, 3, 5));
    await tester.pumpAndSettle();
    final size = PlanDecorKind.wall.defaultSize;
    expect(
      plans.planImages.single.rect,
      GridRect(x: 3, y: 5, w: size.w, h: size.h),
    );
  });

  testWidgets('planDecor off hides the wall tool', (tester) async {
    final plans = await pumpCanvas(
      tester,
      seed: seedOffice,
      workspace: FakeWorkspaceRepository.withWorkspace(
        featureFlags: const {'planDecor': false},
      ),
    );
    expect(find.byKey(const ValueKey('editor-tool-decor')), findsNothing);
    await dragCells(tester, (x: 3, y: 5), (x: 18, y: 5));
    expect(plans.planImages, isEmpty);
  });

  testWidgets('lost save answer retries the same wall; failed Undo can retry', (
    tester,
  ) async {
    late _FaultyWalls repo;
    await pumpCanvas(
      tester,
      seed: seedOffice,
      override: (overrides, plans) {
        repo = _FaultyWalls()
          ..levels.addAll(plans.levels)
          ..offices.addAll(plans.offices);
        overrides.removeWhere(
          (entry) => entry.origin == floorPlanRepositoryProvider,
        );
        overrides.add(floorPlanRepositoryProvider.overrideWithValue(repo));
      },
    );
    await _armWall(tester);
    await dragCells(tester, (x: 18, y: 5), (x: 3, y: 5));
    expect(repo.planImages, hasLength(1));
    expect(find.text('Undo'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('plan-media-retry')));
    await tester.pumpAndSettle();
    expect(repo.ids, hasLength(2));
    expect(repo.ids.first, repo.ids.last);
    expect(
      repo.planImages.single.rect,
      const GridRect(x: 3, y: 5, w: 16, h: 1),
    );
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.planImages, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('plan-media-retry')));
    await tester.pumpAndSettle();
    expect(repo.planImages, isEmpty);
  });
}

class _FaultyWalls extends FakeFloorPlanRepository {
  final ids = <String?>[];
  bool loseAnswer = true;
  bool refuseUndo = true;

  @override
  Future<PlanImage> createPlanDecor({
    required String workspaceId,
    required String levelId,
    required GridRect rect,
    required PlanDecorKind kind,
    String? imageId,
  }) async {
    ids.add(imageId);
    final image = await super.createPlanDecor(
      workspaceId: workspaceId,
      levelId: levelId,
      rect: rect,
      kind: kind,
      imageId: imageId,
    );
    if (loseAnswer) {
      loseAnswer = false;
      throw StateError('saved, answer lost');
    }
    return image;
  }

  @override
  Future<void> deletePlanImage(String imageId) async {
    if (refuseUndo) {
      refuseUndo = false;
      throw StateError('delete refused');
    }
    await super.deletePlanImage(imageId);
  }
}
