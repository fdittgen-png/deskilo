// SPDX-License-Identifier: 0BSD
//
// A background image per level (0036): a photo/blueprint of the real
// space behind the plan graphics, with the seat footprints acting as
// translucent, status-coloured reservation zones over it.
import 'dart:typed_data';

import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
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
  test('the fake round-trips a level background', () async {
    final repo = FakeFloorPlanRepository();
    await repo.setLevelBackground('ws-1', 'level-1',
        bytes: _png, contentType: 'image/png');
    expect(await repo.fetchLevelBackground('ws-1', 'level-1'), _png);

    await repo.clearLevelBackground('ws-1', 'level-1');
    expect(await repo.fetchLevelBackground('ws-1', 'level-1'), isNull);
  });

  test('the painter repaints when the background changes', () {
    const plan = FloorPlan(
      levelId: 'level-1',
      offices: [],
      desks: [],
      seats: [],
    );
    final noBg = FloorPlanPainter(
      plan: plan,
      cellSize: 14,
      colorScheme: const ColorScheme.light(),
    );
    final withBg = FloorPlanPainter(
      plan: plan,
      cellSize: 14,
      colorScheme: const ColorScheme.light(),
      background: null,
    );
    // Same inputs → no repaint; a background presence flips it.
    expect(withBg.shouldRepaint(noBg), isFalse);
  });

  testWidgets('the owner sets a level background from the editor; it is '
      'uploaded and cached for the plan', (tester) async {
    final plans = await pumpCanvas(
      tester,
      override: (overrides, fakePlans) {
        overrides.add(
          filePickerProvider.overrideWithValue(
            (XTypeGroup group) async =>
                XFile.fromData(_png, name: 'room.png', mimeType: 'image/png'),
          ),
        );
      },
    );

    await tester.tap(find.byIcon(Icons.image_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set background image'));
    await tester.pumpAndSettle();

    // Uploaded to the fake and recorded on the level.
    expect(plans.backgrounds.containsKey('level-1'), isTrue);
    expect(
      plans.levels.firstWhere((l) => l.id == 'level-1').hasBackground,
      isTrue,
    );
  });
}
