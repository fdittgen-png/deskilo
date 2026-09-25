// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1456 — the journey benchmark: what this repository can honestly
// measure about latency WITHOUT a device, run on the controlled
// workload of `workload.dart` and written out as evidence.
//
//   flutter test tool/bench                       # the recipe
//   bash scripts/perf_gate.sh report/perf.psv     # the gate
//
// It is NOT in the pull-request path. The code job is already 1 466 s
// p50 (docs/ci/CI_BASELINE.md) and this adds a minute of wall clock for
// numbers that are a trend, not a merge decision. It runs nightly and
// on demand, and the two commands above reproduce it by hand.
//
// ## What a number from here IS evidence about
//
// A headless Dart VM with no compositor and an in-memory backend. That
// is not a phone, not a network and not 60 fps. What it holds is the
// SHAPE of each journey — how many round trips, how many elements, how
// many frames — which is machine-independent, exact, and the thing that
// actually turns a 200 ms network into a 2 s wait. The wall clock is
// recorded beside it and gated by nothing: it measures this host.
//
// Cold start on real hardware, screen-transition milliseconds and API
// p95 remain UNMEASURED. They are declared as such in the record itself
// (`unheld|` rows) so the gate fails if the declaration is ever quietly
// dropped — see docs/domain/PERFORMANCE.md.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/core/data/retry.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers/mock_providers.dart';
import '../../test/helpers/reserve_view.dart';
import 'workload.dart';
import '../../test/features/workspace/onboarding_flow_test.dart' show pumpWithoutWorkspace;

/// Runs per journey. p95 over nine is the slowest of nine — a spread,
/// not a distribution, and the record says so.
const _samples = int.fromEnvironment('BENCH_SAMPLES', defaultValue: 9);

/// The scale every journey below runs at.
const _scale = WorkloadScale.large;

const _canvasKey = ValueKey('reserve-plan-canvas');

final _rows = <String>[];
void _measure(String journey, String metric, num value) =>
    _rows.add('measure|$journey|$metric|$value');

/// One journey's wall clock: p50 and the slowest sample, in ms.
void _wall(String journey, List<int> ms) {
  ms.sort();
  _measure(journey, 'wall_p50_ms', ms[ms.length ~/ 2]);
  _measure(journey, 'wall_p95_ms', ms.last);
  _measure(journey, 'samples', ms.length);
}

/// The hub, on the seeded workload: the frames it took, and the backend
/// that answered it — which the booking journey then reads to prove the
/// booking actually landed.
Future<({int frames, MeteredReservations backend})> _pumpHub(
  WidgetTester tester,
  BackendMeter meter, {
  MeteredPlans? plans,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final planRepo = plans ?? MeteredPlans(meter);
  seedPlan(planRepo, _scale);
  final reservations = MeteredReservations(meter);
  seedReservations(reservations, _scale);
  meter.reset();
  var frames = 0;
  // Every sample is a fresh MOUNT. `pumpWidget` of the same widget type
  // REBUILDS the existing element tree, so without this the second
  // sample measured a warm rebuild and inherited the first one's
  // overlays — a snackbar left over the booking sheet's confirm button,
  // which made the second booking silently not happen.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(
      floorPlan: planRepo,
      reservations: reservations,
      workspace: FakeWorkspaceRepository.withWorkspace()
        ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7],
    ),
    child: const DeskiloApp(),
  ));
  frames += await tester.pumpAndSettle();
  await tester.tap(find.byType(ShellCenterButton));
  frames += await tester.pumpAndSettle();
  return (frames: frames, backend: reservations);
}

/// Centre of the first seat of the first desk, transform-aware.
Offset _firstSeat(WidgetTester tester) {
  final topLeft = tester.getTopLeft(find.byKey(_canvasKey));
  final scale = (tester.getTopRight(find.byKey(_canvasKey)).dx - topLeft.dx) /
      (PlanCanvasMetrics.cells * PlanCanvasMetrics.cellSize);
  return topLeft +
      const Offset(2 * PlanCanvasMetrics.cellSize,
              2 * PlanCanvasMetrics.cellSize) *
          scale;
}

void main() {
  testWidgets('onboarding navigation keeps draft without sending a command', (tester) async {
    final repo = await pumpWithoutWorkspace(tester);
    await tester.enterText(find.byKey(const ValueKey('onboarding-name')), 'Benchmark');
    await tester.tap(find.byKey(const ValueKey('wizard-next')));
    var frames = await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wizard-back')));
    frames += await tester.pumpAndSettle();
    expect(find.text('Benchmark'), findsOneWidget);
    expect(repo.createRequests, isEmpty);
    _measure('onboarding', 'transition_frames', frames);
    _measure('onboarding', 'create_requests', repo.createRequests.length);
  });
  tearDownAll(() {
    final sha = Process.runSync('git', ['rev-parse', 'HEAD']).stdout as String;
    final head = [
      'condition|sha|${sha.trim()}',
      'condition|build_mode|flutter test — Dart VM, headless, no compositor',
      'condition|host|${Platform.operatingSystem} '
          '${Platform.operatingSystemVersion} '
          '${Platform.numberOfProcessors} cores',
      'condition|dataset|${_scale.label}',
      'condition|backend|in-memory demo repositories, no network, no cache',
      'condition|samples|$_samples',
      // Every journey the record must still refuse to claim. The gate
      // fails when one of these disappears: it would mean the honest
      // "not measured" was dropped, which is how 2.5 s became a target
      // nobody held.
      'unheld|cold_start_device|no real device in this environment; the '
          '12 000 ms in android-boot.yml is an EMULATOR ceiling, not a '
          'device startup promise',
      'unheld|frame_timing_device|no compositor here, so jank and 60 fps '
          'are unmeasured; the draw-call budget is an algorithmic control, '
          'not a frame rate',
      'unheld|transition_ms_device|frames are counted, milliseconds are not',
      'unheld|api_p95|needs production request timing this project does '
          'not collect (PRIVACY.md)',
      'unheld|server_ms|the backend here is in memory; round trips are '
          'counted, server milliseconds are not measured',
    ];
    Directory('report').createSync(recursive: true);
    File('report/perf.psv').writeAsStringSync('${[...head, ..._rows].join('\n')}\n');
  });

  testWidgets('reserve_first_usable — boot to a usable Reserve hub',
      (tester) async {
    final meter = BackendMeter();
    final ms = <int>[];
    var frames = 0;
    for (var i = 0; i < _samples; i++) {
      final watch = Stopwatch()..start();
      frames = (await _pumpHub(tester, meter)).frames;
      ms.add(watch.elapsedMilliseconds);
      expect(find.byKey(_canvasKey), findsOneWidget);
      if (i == 0) {
        _measure('reserve_first_usable', 'trips', meter.trips);
        _measure('reserve_first_usable', 'elements', tester.allElements.length);
      }
      meter.reset();
    }
    _measure('reserve_first_usable', 'frames', frames);
    _wall('reserve_first_usable', ms);
  });

  testWidgets('reserve_transition — plan to month, a representative move',
      (tester) async {
    final meter = BackendMeter();
    final ms = <int>[];
    var frames = 0;
    for (var i = 0; i < _samples; i++) {
      await _pumpHub(tester, meter);
      meter.reset();
      final watch = Stopwatch()..start();
      await pickReserveView(tester, 'month');
      frames = await tester.pumpAndSettle();
      ms.add(watch.elapsedMilliseconds);
      if (i == 0) {
        _measure('reserve_transition', 'trips', meter.trips);
        _measure('reserve_transition', 'elements', tester.allElements.length);
      }
    }
    _measure('reserve_transition', 'frames', frames);
    _wall('reserve_transition', ms);
  });

  testWidgets('booking_commit — tap to an authoritative answer',
      (tester) async {
    final meter = BackendMeter();
    final ms = <int>[];
    var sheetFrames = 0;
    var commitFrames = 0;
    for (var i = 0; i < _samples; i++) {
      final backend = (await _pumpHub(tester, meter)).backend;
      final booked = backend.reservations.length;
      meter.reset();
      final watch = Stopwatch()..start();
      // Immediate feedback: the sheet is local, and owes the member
      // nothing from the backend.
      await tester.tapAt(_firstSeat(tester));
      sheetFrames = await tester.pumpAndSettle();
      expect(find.byType(BookingSheet), findsOneWidget);
      final sheetTrips = meter.trips;
      // The authoritative answer: the write, and the hub that reflects
      // it. warnIfMissed is off because the sheet's confirm sits under
      // the shell's raised centre button at this viewport and the hit
      // test warns although the button does receive the tap — which is
      // why the assertion below is the row, not the tap: a journey that
      // measures a tap hitting nothing measures nothing (#1339/#1446).
      await tester.tap(find.byKey(const ValueKey('booking-confirm')),
          warnIfMissed: false);
      commitFrames = await tester.pumpAndSettle();
      ms.add(watch.elapsedMilliseconds);
      expect(backend.reservations.length, booked + 1,
          reason: 'the booking journey did not commit a booking');
      expect(meter.calls['reservations.create'], 1);
      if (i == 0) {
        _measure('booking_commit', 'sheet_trips', sheetTrips);
        _measure('booking_commit', 'trips', meter.trips - sheetTrips);
        _measure('booking_commit', 'elements', tester.allElements.length);
      }
    }
    _measure('booking_commit', 'sheet_frames', sheetFrames);
    _measure('booking_commit', 'frames', commitFrames);
    // The retry component, read from the policy the app actually runs
    // (#1241): the worst case a member waits before being told they are
    // offline. It moves when kRetryDelays moves, and nothing else.
    _measure('booking_commit', 'retry_attempts_max', kRetryDelays.length + 1);
    _measure('booking_commit', 'retry_budget_ms',
        kRetryDelays.fold<int>(0, (a, d) => a + d.inMilliseconds));
    _wall('booking_commit', ms);
  });

  testWidgets('the trip count catches an N+1 the frame count cannot',
      (tester) async {
    // The red control: a repository that resolves each seat's context
    // one call at a time — the regression this measurement exists for.
    // It changes nothing on screen, so no widget test and no draw-call
    // budget sees it; the trip count moves by two orders of magnitude.
    final meter = BackendMeter();
    await _pumpHub(tester, meter, plans: _NPlusOnePlans(meter));
    expect(find.byKey(_canvasKey), findsOneWidget);
    expect(meter.trips, greaterThan(_maxTripsFirstUsable),
        reason: 'an N+1 over ${_scale.seats} seats must exceed the budget '
            'the gate holds, or the budget is not a guard');
  });
}

/// Mirrors `scripts/perf_gate.sh`'s ceiling for the first-usable journey.
const _maxTripsFirstUsable = 12;

class _NPlusOnePlans extends MeteredPlans {
  _NPlusOnePlans(super.meter);

  @override
  Future<FloorPlan> fetchPlan(String levelId) async {
    final plan = await super.fetchPlan(levelId);
    for (final seat in plan.seats) {
      await meter.trip('plan.fetchSeatContext', () async => seat.id);
    }
    return plan;
  }
}
