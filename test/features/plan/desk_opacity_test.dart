// SPDX-License-Identifier: 0BSD
//
// Configurable desk transparency (0040): a lower deskOpacity fades the desk
// fill so a background photo shows through, and repaints when it changes.
import 'dart:ui' as ui;

import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _plan = FloorPlan(
  levelId: 'level-1',
  offices: [
    Office(
      id: 'office-1',
      workspaceId: 'ws-1',
      levelId: 'level-1',
      name: 'Room',
      color: 0,
      bookableAsWhole: false,
      rect: GridRect(x: 0, y: 0, w: 20, h: 20),
    ),
  ],
  desks: [
    Desk(
      id: 'desk-1',
      workspaceId: 'ws-1',
      officeId: 'office-1',
      name: 'Desk',
      rect: GridRect(x: 4, y: 4, w: 8, h: 6),
    ),
  ],
  seats: [],
);

FloorPlanPainter _painter(double opacity) => FloorPlanPainter(
      plan: _plan,
      cellSize: 14,
      colorScheme: const ColorScheme.light(),
      deskOpacity: opacity,
    );

/// Alpha (0..255) at the centre of desk-1 after painting on a transparent
/// surface.
Future<int> _deskCentreAlpha(double opacity) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _painter(opacity).paint(canvas, const Size(280, 280));
  final image = await recorder.endRecording().toImage(280, 280);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  // Desk centre: cell (8, 7) → px (112, 98); RGBA, 4 bytes per pixel.
  const int x = 112, y = 98;
  const offset = (y * 280 + x) * 4;
  return data!.getUint8(offset + 3);
}

void main() {
  test('a lower desk opacity paints a more transparent desk fill', () async {
    final solid = await _deskCentreAlpha(1.0);
    final faded = await _deskCentreAlpha(0.3);

    // Both draw a desk, but the faded one lets more of the (transparent)
    // background through — strictly lower alpha at the desk centre.
    expect(solid, greaterThan(faded));
    expect(faded, lessThan(255));
  });

  test('deskOpacity is part of the repaint contract', () {
    expect(_painter(0.3).shouldRepaint(_painter(1.0)), isTrue);
    expect(_painter(1.0).shouldRepaint(_painter(1.0)), isFalse);
  });
}
