// SPDX-License-Identifier: 0BSD
//
// #611 — seat fill colours ANIMATE on a state change: the canvas host
// detects the diff, runs one finite lerp and passes it to the (pure)
// painter. The final painted state is always exact after settle, the
// animation only runs when a state actually changed, and motion off
// (uiAnimations flag) paints the new state on the very next frame.
import 'package:deskilo/core/motion/motion.dart';
import 'package:deskilo/core/theme/seat_state_colors.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
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
  seats: [
    Seat(
      id: 'seat-1',
      workspaceId: 'ws-1',
      deskId: 'desk-1',
      name: 'A1',
      x: 6,
      y: 3,
      orientation: SeatOrientation.n,
      chair: 'standard',
      amenities: [],
    ),
  ],
);

Widget _host(Map<String, SeatState> states, {bool? motion}) {
  Widget canvas = Scaffold(
    body: PlanCanvas(
      paintKey: const ValueKey('motion-test-canvas'),
      plan: _plan,
      seatStates: states,
      seatLabels: const {},
      onSeatTap: (_) {},
    ),
  );
  if (motion != null) {
    canvas = MotionSettings(animationsEnabled: motion, child: canvas);
  }
  return MaterialApp(home: canvas);
}

FloorPlanPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byKey(const ValueKey('motion-test-canvas')))
    .painter! as FloorPlanPainter;

void main() {
  testWidgets(
      'a state change lerps the colour mid-flight and settles on the '
      'exact final state', (tester) async {
    await tester.pumpWidget(_host(const {'seat-1': SeatState.free}));
    await tester.pumpAndSettle();
    expect(_painter(tester).seatStateLerp, 1.0);

    await tester
        .pumpWidget(_host(const {'seat-1': SeatState.occupied}));
    await tester.pump(const Duration(milliseconds: 100));

    final mid = _painter(tester);
    expect(mid.previousSeatStates, {'seat-1': SeatState.free});
    expect(mid.seatStateLerp, greaterThan(0.0));
    expect(mid.seatStateLerp, lessThan(1.0));

    await tester.pumpAndSettle();
    final done = _painter(tester);
    expect(done.seatStateLerp, 1.0);
    expect(done.seatStates, {'seat-1': SeatState.occupied});
  });

  testWidgets('no diff, no animation: an identical rebuild stays at rest',
      (tester) async {
    await tester.pumpWidget(_host(const {'seat-1': SeatState.free}));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(const {'seat-1': SeatState.free}));
    await tester.pump();
    expect(_painter(tester).seatStateLerp, 1.0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
      'motion OFF (uiAnimations flag) paints the new state on the next '
      'frame — no lerp, no settle needed', (tester) async {
    await tester.pumpWidget(
        _host(const {'seat-1': SeatState.free}, motion: false));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
        _host(const {'seat-1': SeatState.occupied}, motion: false));
    await tester.pump();

    final painter = _painter(tester);
    expect(painter.seatStateLerp, 1.0);
    expect(painter.previousSeatStates, isNull);
    expect(painter.seatStates, {'seat-1': SeatState.occupied});
  });

  test('the painter lerp math lands exactly on the target colour at 1', () {
    const from = SeatState.free;
    const to = SeatState.occupied;
    final lerped = Color.lerp(
      SeatStateColors.of(from, brightness: Brightness.light),
      SeatStateColors.of(to, brightness: Brightness.light),
      1,
    );
    expect(lerped, SeatStateColors.of(to, brightness: Brightness.light));
  });
}
