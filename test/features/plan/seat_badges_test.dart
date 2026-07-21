// SPDX-License-Identifier: 0BSD
//
// Seat avatars show whether the occupant is checked in (a check badge) and
// online (a green presence dot) — a glance answers "who's actually here".
import 'dart:ui' as ui;

import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/reservations/domain/seat_state_logic.dart';
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
      rect: GridRect(x: 2, y: 2, w: 12, h: 4),
    ),
  ],
  seats: [
    Seat(
      id: 'seat-1',
      workspaceId: 'ws-1',
      deskId: 'desk-1',
      name: 'A1',
      x: 2,
      y: 2,
      orientation: SeatOrientation.n,
      chair: '',
      amenities: [],
    ),
  ],
);

FloorPlanPainter _painter({
  required SeatState state,
  Set<String> online = const {},
}) =>
    FloorPlanPainter(
      plan: _plan,
      cellSize: 14,
      colorScheme: const ColorScheme.light(),
      seatStates: {'seat-1': state},
      seatLabels: const {'seat-1': 'Flo'},
      onlineSeatIds: online,
    );

/// Rough count of green-ish pixels (the online dot) over the seat area.
Future<int> _greenPixels(FloorPlanPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(280, 280));
  final image = await recorder.endRecording().toImage(280, 280);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  var green = 0;
  for (var i = 0; i < data!.lengthInBytes; i += 4) {
    final r = data.getUint8(i);
    final g = data.getUint8(i + 1);
    final b = data.getUint8(i + 2);
    // Clearly green: dominant green channel.
    if (g > 110 && g > r + 30 && g > b + 30) green++;
  }
  return green;
}

void main() {
  test('an online occupant paints a green presence dot', () async {
    final offline = await _greenPixels(
      _painter(state: SeatState.occupied),
    );
    final online = await _greenPixels(
      _painter(state: SeatState.occupied, online: {'seat-1'}),
    );
    expect(online, greaterThan(offline + 20));
  });

  test('onlineSeatIds and state are part of the repaint contract', () {
    final base = _painter(state: SeatState.occupied);
    expect(
      _painter(state: SeatState.occupied, online: {'seat-1'})
          .shouldRepaint(base),
      isTrue,
    );
    expect(base.shouldRepaint(_painter(state: SeatState.reserved)), isTrue);
  });
}
