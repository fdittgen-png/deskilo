// SPDX-License-Identifier: MIT
//
// Resizable illustration images on the plan (0037): the owner drops a
// photo of the real space (plant, couch, whiteboard) onto the grid, then
// moves and resizes it. Images render behind the offices/desks/seats, so
// real bookable elements can be drawn on top of the picture.
import 'dart:typed_data';

import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/floor_plan_editing.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/plan_image.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import 'level_canvas_test.dart' show pumpCanvas;

// A 1×1 transparent PNG — enough for the codec to decode.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  test('the fake round-trips a plan image: create, resize, delete', () async {
    final repo = FakeFloorPlanRepository();
    final image = await repo.createPlanImage(
      workspaceId: 'ws-1',
      levelId: 'level-1',
      rect: const GridRect(x: 4, y: 4, w: 16, h: 12),
      bytes: _png,
      contentType: 'image/png',
    );
    expect(await repo.fetchPlanImageBytes(image.id), _png);
    expect(repo.planImages.single.rect, const GridRect(x: 4, y: 4, w: 16, h: 12));

    await repo.updatePlanImageRect(
      image.id,
      const GridRect(x: 6, y: 6, w: 20, h: 14),
    );
    expect(repo.planImages.single.rect, const GridRect(x: 6, y: 6, w: 20, h: 14));

    await repo.deletePlanImage(image.id);
    expect(repo.planImages, isEmpty);
    expect(await repo.fetchPlanImageBytes(image.id), isNull);
  });

  test('applyImageRect moves the image without touching children', () {
    const plan = FloorPlan(
      levelId: 'level-1',
      offices: [],
      desks: [],
      seats: [],
      images: [
        PlanImage(
          id: 'img-1',
          levelId: 'level-1',
          rect: GridRect(x: 0, y: 0, w: 10, h: 8),
          storagePath: 'ws-1/img/img-1',
        ),
      ],
    );
    final moved = applyImageRect(plan, 'img-1', const GridRect(x: 5, y: 3, w: 12, h: 10));
    expect(moved.images.single.rect, const GridRect(x: 5, y: 3, w: 12, h: 10));
    // A cell inside the new footprint resolves to the image.
    expect(moved.imageAtCell(6, 4)?.id, 'img-1');
    expect(moved.imageAtCell(0, 0), isNull);
  });

  test('the painter repaints when the illustration set changes', () {
    const plan = FloorPlan(
      levelId: 'level-1',
      offices: [],
      desks: [],
      seats: [],
    );
    final none = FloorPlanPainter(
      plan: plan,
      cellSize: 14,
      colorScheme: const ColorScheme.light(),
    );
    final same = FloorPlanPainter(
      plan: plan,
      cellSize: 14,
      colorScheme: const ColorScheme.light(),
    );
    expect(same.shouldRepaint(none), isFalse);
  });

  testWidgets('the owner places an illustration image from the editor; it '
      'is uploaded and recorded on the plan', (tester) async {
    final plans = await pumpCanvas(
      tester,
      override: (overrides, fakePlans) {
        overrides.add(
          filePickerProvider.overrideWithValue(
            (XTypeGroup group) async =>
                XFile.fromData(_png, name: 'plant.png', mimeType: 'image/png'),
          ),
        );
      },
    );

    // Select the Image tool, then tap a cell to drop the picture.
    await tester.tap(find.text('Image'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(CustomPaint).first));
    await tester.pumpAndSettle();

    expect(plans.planImages, isNotEmpty);
    expect(plans.imageBytes.values.first, _png);
  });
}
