// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3074 — the invariant: a drawn symbol is a plan image without a photo. It
// is created once whatever the retries, turns a quarter at a time by
// swapping its footprint about its centre, and every kind paints at every
// turn without throwing.
import 'dart:ui' as ui;

import 'package:deskilo/features/editor/application/level_canvas_edits.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/plan_image.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_decor_paint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';

void main() {
  test('a symbol is created once per id and has no photo', () async {
    final repo = FakeFloorPlanRepository();
    const rect = GridRect(x: 2, y: 3, w: 12, h: 1);
    final a = await repo.createPlanDecor(
      workspaceId: 'ws-1',
      levelId: 'level-1',
      rect: rect,
      kind: PlanDecorKind.wall,
      imageId: 'd1',
    );
    await repo.createPlanDecor(
      workspaceId: 'ws-1',
      levelId: 'level-1',
      rect: rect,
      kind: PlanDecorKind.wall,
      imageId: 'd1',
    );
    expect(repo.planImages, hasLength(1));
    expect(a.kind, PlanDecorKind.wall);
    expect(a.storagePath, isNull);
    expect(await repo.fetchPlanImageBytes('d1'), isNull);
  });

  test('rotating swaps the footprint about its centre and counts turns',
      () async {
    final repo = FakeFloorPlanRepository();
    final image = await repo.createPlanDecor(
      workspaceId: 'ws-1',
      levelId: 'level-1',
      rect: const GridRect(x: 10, y: 10, w: 8, h: 4),
      kind: PlanDecorKind.table,
      imageId: 'd2',
    );
    await LevelCanvasEdits(repo, levelId: 'level-1').rotateDecor(image, cells: 120);
    final turned = repo.planImages.single;
    expect(turned.rect, const GridRect(x: 12, y: 8, w: 4, h: 8));
    expect(turned.quarterTurns, 1);
  });

  test('turning a long wall at the right edge keeps it on the grid', () async {
    final repo = FakeFloorPlanRepository();
    final image = await repo.createPlanDecor(
      workspaceId: 'ws-1',
      levelId: 'level-1',
      rect: const GridRect(x: 108, y: 0, w: 12, h: 1),
      kind: PlanDecorKind.wall,
      imageId: 'd3',
    );
    await LevelCanvasEdits(repo, levelId: 'level-1')
        .rotateDecor(image, cells: 120);
    final turned = repo.planImages.single.rect;
    expect(turned.x + turned.w, lessThanOrEqualTo(120));
    expect(turned.y, greaterThanOrEqualTo(0));
  });

  test('every kind paints at every turn', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    for (final kind in PlanDecorKind.values) {
      for (var turns = 0; turns < 4; turns++) {
        final recorder = ui.PictureRecorder();
        paintPlanDecor(
          Canvas(recorder),
          const Rect.fromLTWH(10, 10, 80, 40),
          kind,
          turns,
          scheme,
        );
        recorder.endRecording().dispose();
      }
    }
  });

  test('the wire names are the server kinds', () {
    expect(
      PlanDecorKind.values.map((k) => k.name),
      ['wall', 'door', 'window', 'pillar', 'table', 'couch', 'wc', 'kitchen'],
    );
    expect(PlanDecorKind.fromWire('wc'), PlanDecorKind.wc);
    expect(PlanDecorKind.fromWire('sofa'), isNull);
  });
}
