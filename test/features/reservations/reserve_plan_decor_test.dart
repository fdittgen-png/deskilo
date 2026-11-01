// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3074 — the drawn room is for everyone who books in it: the Reserve hub
// shows the symbols of the level to a plain member, who has no editor.
import 'dart:ui' as ui;

import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/plan_image.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_paint_helpers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/screens/reserve_hub.dart' show pumpHub;

const _canvasKey = ValueKey('reserve-plan-canvas');

/// The pixels of [painter] inside [area] — the rest of the plan may shift
/// with the painter's fit, the symbol's own footprint may not.
Future<List<int>> _pixelsIn(FloorPlanPainter painter, Rect area) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(420, 280));
  final image = await recorder.endRecording().toImage(420, 280);
  final data = (await image.toByteData())!;
  final out = <int>[];
  for (var y = area.top.floor(); y < area.bottom.ceil(); y++) {
    for (var x = area.left.floor(); x < area.right.ceil(); x++) {
      final at = (y * 420 + x) * 4;
      for (var c = 0; c < 4; c++) {
        out.add(data.getUint8(at + c));
      }
    }
  }
  return out;
}

void main() {
  testWidgets('a plain member sees the drawn symbols on the Reserve plan', (
    tester,
  ) async {
    final plans = FakeFloorPlanRepository();
    // seedSmallPlan (run by the hub helper) makes the first level 'level-1'.
    plans.planImages.add(
      const PlanImage(
        id: 'couch-1',
        levelId: 'level-1',
        rect: GridRect(x: 16, y: 8, w: 10, h: 6),
        kind: PlanDecorKind.couch,
      ),
    );
    await pumpHub(
      tester,
      floorPlans: plans,
      configureWorkspace: (workspace) => workspace.myMember = const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      ),
    );

    // The member has no editor ...
    expect(find.byKey(const ValueKey('shell-editor-button')), findsNothing);
    // ... and still gets the room: the plan carries the symbol and the
    // painter puts it on the canvas.
    final painter =
        tester.widget<CustomPaint>(find.byKey(_canvasKey)).painter!
            as FloorPlanPainter;
    expect(painter.plan.images.map((i) => i.id), ['couch-1']);
    expect(painter.plan.images.single.kind, PlanDecorKind.couch);
    await tester.runAsync(() async {
      final bare = FloorPlanPainter(
        plan: painter.plan.copyWith(images: const []),
        cellSize: painter.cellSize,
        colorScheme: painter.colorScheme,
      );
      final area = gridRectToPx(painter.plan.images.single.rect, painter.cellSize);
      expect(
        await _pixelsIn(painter, area),
        isNot(equals(await _pixelsIn(bare, area))),
      );
    });
  });
}
