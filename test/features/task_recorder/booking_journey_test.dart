// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the real Reserve hub and the real booking command, recorded:
// entering the form, choosing a place on the plan or in the list,
// reviewing, cancelling, confirming, and the server's genuine answer
// (booked, refused, no answer) land in order, as an attempt BEFORE the
// command and an outcome after it. The booking itself is exactly the
// same with the recorder on as off — one create call, the same rows —
// and a recorder whose store fails never touches it.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/recording_sink.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../reservations/reserve_hub_test.dart' show seatCenter;
import 'fixtures/recording_fixtures.dart';

/// The booking command answers with a refusal, worded with private
/// detail the recording must never carry.
class _RefusingRepository extends FakeReservationRepository {
  @override
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
    String? requestId,
  }) async {
    createCalls++;
    throw const PostgrestException(
        message: 'overlap with the booking of $kCanaryMemberName');
  }
}

/// The connection drops: nobody knows whether the booking exists.
class _OfflineRepository extends FakeReservationRepository {
  @override
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
    String? requestId,
  }) async {
    createCalls++;
    throw const SocketException('Failed host lookup: canary.invalid');
  }
}

/// A sink whose every write fails.
class _BrokenSink implements RecordingSink, RecordingWriter {
  @override
  Future<RecordingWriter> begin(RecordingHeader header) async => this;
  @override
  Future<void> segment(RecordingSegment segment) => throw StateError('full');
  @override
  Future<void> step(RecordedStep step) => throw StateError('full');
  @override
  Future<void> end(RecordingEndReason r, Completeness c) =>
      throw StateError('full');
  @override
  Future<void> discard() async {}
}

Future<({ProviderContainer container, FakeReservationRepository repo})>
    _pumpHub(
  WidgetTester tester, {
  FakeReservationRepository? repo,
  RecorderController? controller,
  bool record = true,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final reservations = repo ?? FakeReservationRepository();
  final store = RecorderStore(
      backend: MemoryRecorderLogBackend(), namespace: canaryNamespace);
  final container = ProviderContainer(overrides: [
    ...standardTestOverrides(
      floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
      reservations: reservations,
      workspace: FakeWorkspaceRepository.withWorkspace()
        ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
        ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7],
    ),
    recorderStoreProvider.overrideWithValue(store),
    recorderScopeProvider.overrideWithValue(canaryScope),
    if (controller != null)
      recorderControllerProvider.overrideWithValue(controller),
  ]);
  // The task starts before the app does, so entering the form is in it.
  if (record) {
    expect(
        await container
            .read(recorderControllerProvider)
            .start(scope: canaryScope),
        isTrue);
  }
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  return (container: container, repo: reservations);
}

/// Unmounts the app and disposes the container inside the test, so no
/// app timer outlives it.
Future<void> _done(WidgetTester tester, ProviderContainer c) async {
  await tester.pumpWidget(const SizedBox());
  c.dispose();
}

RecorderController _recorder(ProviderContainer c) =>
    c.read(recorderControllerProvider);

Future<void> _openReserve(WidgetTester tester) async {
  await tester.tap(find.byType(ShellCenterButton));
  await tester.pumpAndSettle();
}

Future<void> _bookA1(WidgetTester tester) async {
  await tester.tapAt(seatCenter(tester));
  await tester.pumpAndSettle();
  expect(find.byType(BookingSheet), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('booking-confirm')));
  await tester.pumpAndSettle();
}

List<String?> _ids(TaskRecording r) =>
    [for (final s in r.steps) s.action ?? s.outcome ?? s.kind.wire];

void main() {
  testWidgets('plan: enter, choose, confirm, booked — attempt before outcome',
      (tester) async {
    final hub = await _pumpHub(tester);
    final controller = _recorder(hub.container);
    await _openReserve(tester);
    await _bookA1(tester);
    final r = (await controller.stop())!;

    expect(hub.repo.reservations, hasLength(1));
    expect(hub.repo.createCalls, 1);
    final ids = _ids(r);
    expect(ids.first, RecorderActions.openReserve);
    final select = ids.indexOf(RecorderActions.selectResource);
    final attempt = ids.indexOf(RecorderActions.confirmBooking);
    final outcome = ids.indexOf(RecorderOutcomes.bookingConfirmed);
    expect(select, greaterThan(0));
    expect(attempt, greaterThan(select));
    expect(outcome, attempt + 1);
    expect(r.steps[select].payload.values['view_mode'], 'plan');
    expect(r.steps[outcome].op, r.steps[attempt].op);
    expect(r.completeness, Completeness.complete);
    final text = encodeRecordingText(r);
    for (final c in privateCanaries) {
      expect(text.contains(c), isFalse, reason: c);
    }
    expect(text, isNot(contains(hub.repo.reservations.single.id)));
    await _done(tester, hub.container);
  });

  testWidgets('a cancelled review records the cancel and books nothing',
      (tester) async {
    final hub = await _pumpHub(tester);
    final controller = _recorder(hub.container);
    await _openReserve(tester);
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    // The member closes the sheet without booking.
    Navigator.of(tester.element(find.byType(BookingSheet))).pop();
    await tester.pumpAndSettle();
    final r = (await controller.stop())!;
    expect(hub.repo.createCalls, 0);
    expect(_ids(r), contains(RecorderActions.cancelReview));
    expect(r.steps.where((s) => s.isAttempt), isEmpty);
    await _done(tester, hub.container);
  });

  testWidgets('a refusal is recorded as refused, by category only',
      (tester) async {
    final hub = await _pumpHub(tester, repo: _RefusingRepository());
    final controller = _recorder(hub.container);
    await _openReserve(tester);
    await _bookA1(tester);
    final r = (await controller.stop())!;
    expect(hub.repo.createCalls, 1);
    final last = r.steps.lastWhere((s) => s.kind == StepKind.observation);
    expect(last.outcome, RecorderOutcomes.bookingRefused);
    expect(last.payload.values, {'refusal': 'conflict'});
    expect(encodeRecordingText(r), isNot(contains(kCanaryMemberName)));
    await _done(tester, hub.container);
  });

  testWidgets('a lost connection is an outcome nobody can vouch for',
      (tester) async {
    final hub = await _pumpHub(tester, repo: _OfflineRepository());
    final controller = _recorder(hub.container);
    await _openReserve(tester);
    await _bookA1(tester);
    final r = (await controller.stop())!;
    expect(r.steps.last.outcome, RecorderOutcomes.bookingUnknown);
    expect(r.steps.last.state, ObservationState.outcomeUnknown);
    await _done(tester, hub.container);
  });

  testWidgets('the same booking with the recorder on, off and broken',
      (tester) async {
    Future<List<String>> book({required bool record, bool broken = false}) async {
      final controller = broken
          ? RecorderController(
              sink: _BrokenSink(), platform: RecordingPlatform.unknown)
          : null;
      final hub =
          await _pumpHub(tester, controller: controller, record: record);
      await _openReserve(tester);
      await _bookA1(tester);
      expect(hub.repo.createCalls, 1);
      final rows = [
        for (final r in hub.repo.reservations)
          '${r.seatId} ${r.startsAt.toIso8601String()} '
              '${r.endsAt.toIso8601String()} ${r.status}',
      ];
      await _done(tester, hub.container);
      return rows;
    }

    final off = await book(record: false);
    final on = await book(record: true);
    final broken = await book(record: true, broken: true);
    expect(on, off);
    expect(broken, off);
  });
}
