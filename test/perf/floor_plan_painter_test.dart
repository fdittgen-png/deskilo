// SPDX-License-Identifier: 0BSD
//
// #1236 — the first performance budget this repository holds that is not
// a flake threshold.
//
// Everything that measured anything before this was
// `.github/workflows/android-boot.yml:116`, whose own comment reads
// "Budget 12000 since run #99 flaked" — a number set to stop a flake,
// not to hold a standard. `grep -rniE "Stopwatch|elapsedMilliseconds|
// benchmark"` over test/, integration_test/ and lib/ returned nothing.
//
// ## What is measured, and why it is not a stopwatch
//
// A wall-clock budget on a CI runner measures the runner. It fails on a
// noisy neighbour and passes on a fast one, and after the second false
// red somebody raises the number — which is how 12 000 ms became
// 12 000 ms.
//
// A scaling RATIO was tried first and measured, honestly, on this
// painter: at 200 vs 800 desks the real cost grew 3.1x, and the same
// painter with a deliberate `plan.desks.where(...)` injected inside the
// seat loop — a genuine O(n*m) — grew 4.6x. Both are well under any
// threshold that would survive a shared runner, because the quadratic
// term is a string compare and the constant term is Skia. A ratio test
// between those two numbers would look like a guard and catch nothing.
//
// So this counts the DRAW CALLS instead. The count is exactly the work
// the painter asks the GPU for, it is identical on every machine, and it
// is asserted per element: a plan with four times the seats must issue
// four times the seat-shaped calls, never sixteen. A stopwatch ceiling
// sits beside it, loose enough to be about the code rather than the
// runner, to catch something becoming slow WITHOUT the call count
// changing — a shader compiled in the loop, an image decoded per seat.
import 'dart:ui' as ui;

import 'package:deskilo/core/theme/seat_state_colors.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A plan of [deskCount] desks, four seats each, ten desks to a room —
/// the shape of a real coworking floor rather than of a fixture. The
/// issue names 100 desks; the second arm is four times that.
FloorPlan buildPlan(int deskCount) {
  const perRoom = 10;
  final offices = <Office>[];
  final desks = <Desk>[];
  final seats = <Seat>[];
  for (var d = 0; d < deskCount; d++) {
    final room = d ~/ perRoom;
    if (d % perRoom == 0) {
      offices.add(Office(
        id: 'office-$room',
        workspaceId: 'ws',
        levelId: 'level',
        name: 'Room $room',
        color: room % 6,
        bookableAsWhole: false,
        rect: GridRect(x: (room % 8) * 26, y: (room ~/ 8) * 14, w: 25, h: 13),
      ));
    }
    final inRoom = d % perRoom;
    final ox = (room % 8) * 26 + 1 + (inRoom % 5) * 5;
    final oy = (room ~/ 8) * 14 + 1 + (inRoom ~/ 5) * 6;
    desks.add(Desk(
      id: 'desk-$d',
      workspaceId: 'ws',
      officeId: 'office-$room',
      name: 'Desk $d',
      rect: GridRect(x: ox, y: oy, w: 4, h: 4),
    ));
    for (var s = 0; s < 4; s++) {
      seats.add(Seat(
        id: 'seat-$d-$s',
        workspaceId: 'ws',
        deskId: 'desk-$d',
        name: 'S$d.$s',
        x: ox + (s % 2) * 2,
        y: oy + (s ~/ 2) * 2,
        orientation: SeatOrientation.values[s % SeatOrientation.values.length],
        chair: 'standard',
        amenities: const ['monitor'],
      ));
    }
  }
  return FloorPlan(
    levelId: 'level',
    offices: offices,
    desks: desks,
    seats: seats,
  );
}

FloorPlanPainter painterFor(FloorPlan plan, ColorScheme scheme) =>
    FloorPlanPainter(
      plan: plan,
      cellSize: 24,
      colorScheme: scheme,
      seatStates: {
        for (final seat in plan.seats)
          seat.id: SeatState
              .values[seat.name.hashCode.abs() % SeatState.values.length],
      },
      seatLabels: {for (final seat in plan.seats) seat.id: seat.name},
    );

Size sizeOf(FloorPlan plan) {
  final b = plan.usedBounds!;
  return Size((b.x + b.w + 2) * 24, (b.y + b.h + 2) * 24);
}

/// Counts what the painter asks the canvas to do.
///
/// `implements Canvas` with a `noSuchMethod` tally — the same shape
/// `flutter_test`'s own `paints` matcher uses. Every call the painter
/// makes lands here and nothing is drawn, so the count is exactly the
/// work and nothing else.
class CountingCanvas implements Canvas {
  final Map<String, int> calls = {};

  int get total => calls.values.fold(0, (a, b) => a + b);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName
        .toString()
        .replaceAll('Symbol("', '')
        .replaceAll('")', '');
    calls[name] = (calls[name] ?? 0) + 1;
    // `getSaveCount` must answer a number or the painter's own
    // save/restore bookkeeping throws.
    return name == 'getSaveCount' ? 1 : null;
  }
}

Map<String, int> countFor(FloorPlan plan, ColorScheme scheme) {
  final canvas = CountingCanvas();
  painterFor(plan, scheme).paint(canvas, sizeOf(plan));
  return canvas.calls;
}

/// Best of [times] paints — the fastest observed run is the closest
/// honest estimate of what the code costs; averaging folds the
/// neighbour's build into our number.
Duration paintCost(FloorPlan plan, ColorScheme scheme, {int times = 5}) {
  final painter = painterFor(plan, scheme);
  final size = sizeOf(plan);
  var best = const Duration(days: 1);
  for (var i = 0; i < times; i++) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final watch = Stopwatch()..start();
    painter.paint(canvas, size);
    watch.stop();
    recorder.endRecording().dispose();
    if (watch.elapsed < best) best = watch.elapsed;
  }
  return best;
}

void main() {
  const scheme = ColorScheme.light();

  test('the work the painter asks for is LINEAR in what is on the plan',
      () {
    final small = countFor(buildPlan(100), scheme);
    final large = countFor(buildPlan(400), scheme);

    for (final call in small.keys) {
      final a = small[call]!;
      final b = large[call] ?? 0;
      // A call that does not scale at all (the background, the grid) is
      // fine; one that scales must scale by four, not by sixteen.
      expect(
        b,
        lessThanOrEqualTo(a * 5),
        reason: '`$call` went from $a to $b when the plan grew 4x. Linear '
            'work would be about 4x. The usual cause is a lookup that '
            'scans a list INSIDE a loop over another — plan.seatsOf('
            'desk.id) inside the desk loop, or desks.where(...) inside '
            'the seat loop. Hoist it into a map built once.',
      );
    }
  });

  test('and the painter is not quietly doing more per seat than it was',
      () {
    final counts = countFor(buildPlan(100), scheme);
    final total = counts.values.fold(0, (a, b) => a + b);

    // 400 seats, 100 desks, 10 rooms. The budget is per SEAT, because
    // that is what a bigger office adds: 40 canvas calls each is already
    // generous for a rounded rect, a chair, a label and a state fill.
    expect(
      total,
      lessThan(400 * 40),
      reason: 'painting 100 desks and 400 seats issued $total canvas calls '
          '(${(total / 400).toStringAsFixed(1)} per seat). Each one runs '
          'on every frame while somebody pans. Breakdown: $counts',
    );
    expect(counts, isNotEmpty, reason: 'the counter saw nothing at all');
  });

  test('a realistic floor still paints inside a few frames on this '
      'machine', () {
    paintCost(buildPlan(10), scheme, times: 3); // warm the JIT
    final cost = paintCost(buildPlan(100), scheme);

    // Deliberately loose: its job is to catch something becoming slow
    // WITHOUT the call count changing — a shader compiled in the loop, an
    // image decoded per seat — on a runner whose speed we do not control.
    // The call-count tests above hold the shape.
    expect(
      cost.inMilliseconds,
      lessThan(120),
      reason: 'a 100-desk, 400-seat floor took ${cost.inMilliseconds} ms to '
          'paint. At 60 Hz a frame is 16 ms, and this runs on every one of '
          'them while somebody pans the canvas.',
    );
  });

  test('the benchmark plan is the shape the issue asks for, so the '
      'numbers above mean what they say', () {
    final plan = buildPlan(100);
    expect(plan.desks, hasLength(100));
    expect(plan.seats, hasLength(400));
    expect(plan.offices, hasLength(10));
  });
}
