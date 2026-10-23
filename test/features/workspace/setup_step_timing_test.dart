// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2915 — the guide's observed times come from sessions on step pages: a
// step page opened, and the step found ready by the next reading of the
// setup status, is reported once with the time on the page; a page left
// with its step still open reports nothing, a page opened on a step that
// was already ready is a visit, and a workspace filming with invented
// people reports nothing at all. Time is the test clock's, never the wall
// clock's; the step page shell itself tells the recorder when it opens.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/privacy/recording_providers.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/workspace/application/setup_step_timing_recorder.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/domain/setup_step_timing.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:deskilo/features/workspace/providers/local_setup_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

/// A clock the test moves by hand.
final class _MovingClock implements Clock {
  _MovingClock(this.at);
  DateTime at;

  @override
  DateTime now() => at;
}

SetupStatus _status(String step, {required bool ready}) => SetupStatus.fromJson({
  'steps': [
    {
      'step': step,
      'milestone': 'bookable',
      'required': true,
      'state': ready ? 'ready' : 'needs_configuration',
      'route': '/setup/step/$step',
    },
  ],
  'milestones': [
    {
      'milestone': 'bookable',
      'applies': true,
      'required': 1,
      'ready': ready ? 1 : 0,
      'reached': ready,
    },
  ],
});

final _statusOf = workspaceSetupStatusProvider('ws-1');

({
  ProviderContainer container,
  SetupStepTimingRecorder recorder,
  _MovingClock clock,
})
_start(FakeLocalSetupRepository server, {bool filming = false}) {
  final clock = _MovingClock(kTestNow);
  final container = ProviderContainer(
    overrides: [
      localSetupRepositoryProvider.overrideWithValue(server),
      clockProvider.overrideWithValue(clock),
      recordingPrivacyProvider.overrideWithValue(filming),
    ],
  );
  return (
    container: container,
    recorder: container.read(setupStepTimingRecorderProvider.notifier),
    clock: clock,
  );
}

/// The guide reads the status again, as it does on the way back. A bare
/// container refreshes and disposes on zero timers, which run only when
/// the test's clock is pumped by a duration.
Future<void> _reread(WidgetTester tester, ProviderContainer container) async {
  container.invalidate(_statusOf);
  await tester.pump(Duration.zero);
  await container.read(_statusOf.future);
  await tester.pump(Duration.zero);
}

void main() {
  testWidgets('a step page opened and the step found ready reports one '
      'session with the time on the page', (tester) async {
    final server = FakeLocalSetupRepository(
      status: _status('places', ready: false),
    );
    final (:container, :recorder, :clock) = _start(server);
    addTearDown(container.dispose);
    await container.read(_statusOf.future);

    recorder.opened('ws-1', 'places');
    clock.at = kTestNow.add(const Duration(minutes: 7));
    recorder.closed('ws-1', 'places');
    server.status = _status('places', ready: true);
    await _reread(tester, container);

    final [observation] = server.recordedTimings;
    expect(observation.workspaceId, 'ws-1');
    expect(observation.step, 'places');
    expect(observation.openedAt, kTestNow);
    expect(observation.duration, const Duration(minutes: 7));

    await _reread(tester, container);
    expect(server.recordedTimings, hasLength(1), reason: 'reported once');
  });

  testWidgets('a step that turns ready while its page is open is reported '
      'at that reading', (tester) async {
    final server = FakeLocalSetupRepository(
      status: _status('places', ready: false),
    );
    final (:container, :recorder, :clock) = _start(server);
    addTearDown(container.dispose);
    await container.read(_statusOf.future);

    recorder.opened('ws-1', 'places');
    clock.at = kTestNow.add(const Duration(minutes: 2));
    server.status = _status('places', ready: true);
    await _reread(tester, container);

    expect(server.recordedTimings.single.duration, const Duration(minutes: 2));
  });

  testWidgets('a page left with its step still open reports nothing, also '
      'once the step is ready later', (tester) async {
    final server = FakeLocalSetupRepository(
      status: _status('places', ready: false),
    );
    final (:container, :recorder, :clock) = _start(server);
    addTearDown(container.dispose);
    await container.read(_statusOf.future);

    recorder.opened('ws-1', 'places');
    clock.at = kTestNow.add(const Duration(minutes: 3));
    recorder.closed('ws-1', 'places');
    await _reread(tester, container);
    expect(server.recordedTimings, isEmpty);

    server.status = _status('places', ready: true);
    await _reread(tester, container);
    expect(server.recordedTimings, isEmpty, reason: 'the session was over');
  });

  testWidgets('a page opened on a step already ready is a visit', (
    tester,
  ) async {
    final server = FakeLocalSetupRepository(
      status: _status('places', ready: true),
    );
    final (:container, :recorder, :clock) = _start(server);
    addTearDown(container.dispose);
    await container.read(_statusOf.future);

    recorder.opened('ws-1', 'places');
    clock.at = kTestNow.add(const Duration(minutes: 1));
    recorder.closed('ws-1', 'places');
    await _reread(tester, container);
    expect(server.recordedTimings, isEmpty);
  });

  testWidgets('the status not read yet: the first reading is the baseline', (
    tester,
  ) async {
    final server = FakeLocalSetupRepository(
      status: _status('places', ready: false),
    );
    final (:container, :recorder, :clock) = _start(server);
    addTearDown(container.dispose);

    recorder.opened('ws-1', 'places');
    await container.read(_statusOf.future);
    await tester.pump(Duration.zero);
    clock.at = kTestNow.add(const Duration(minutes: 4));
    server.status = _status('places', ready: true);
    await _reread(tester, container);

    expect(server.recordedTimings.single.duration, const Duration(minutes: 4));
  });

  testWidgets('a workspace filming with invented people reports nothing', (
    tester,
  ) async {
    final server = FakeLocalSetupRepository(
      status: _status('places', ready: false),
    );
    final (:container, :recorder, :clock) = _start(server, filming: true);
    addTearDown(container.dispose);
    await container.read(_statusOf.future);

    recorder.opened('ws-1', 'places');
    clock.at = kTestNow.add(const Duration(minutes: 7));
    recorder.closed('ws-1', 'places');
    server.status = _status('places', ready: true);
    await _reread(tester, container);
    expect(server.recordedTimings, isEmpty);
  });

  testWidgets('a report the server refuses is let go', (tester) async {
    final server = _RefusingSetupRepository(
      status: _status('places', ready: false),
    );
    final (:container, :recorder, :clock) = _start(server);
    addTearDown(container.dispose);
    await container.read(_statusOf.future);

    recorder.opened('ws-1', 'places');
    clock.at = kTestNow.add(const Duration(minutes: 1));
    server.status = _status('places', ready: true);
    await _reread(tester, container);
    expect(server.refused, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the step page shell opens the session itself', (tester) async {
    final repo = FakeWorkspaceRepository.withWorkspace();
    final workspaceId = repo.workspaces.first.id;
    final server = FakeLocalSetupRepository(
      status: _status('member_rights', ready: false),
    );
    final clock = _MovingClock(kTestNow);
    await pumpApp(
      tester,
      const SetupStepScreen(stepId: 'member_rights'),
      size: const Size(360, 1600),
      overrides: standardTestOverrides(
        workspace: repo,
        localSetup: server,
        clock: clock,
      ),
    );
    await tester.pump();
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SetupStepScreen)),
    );
    final statusOf = workspaceSetupStatusProvider(workspaceId);
    await container.read(statusOf.future);
    await tester.pump();

    clock.at = kTestNow.add(const Duration(minutes: 5));
    server.status = _status('member_rights', ready: true);
    container.invalidate(statusOf);
    await container.read(statusOf.future);
    await tester.pump();

    final [observation] = server.recordedTimings;
    expect(observation.workspaceId, workspaceId);
    expect(observation.step, 'member_rights');
    expect(observation.openedAt, kTestNow);
    expect(observation.duration, const Duration(minutes: 5));
  });
}

/// Refuses every report, as a server without the function would.
class _RefusingSetupRepository extends FakeLocalSetupRepository {
  _RefusingSetupRepository({required super.status});
  int refused = 0;

  @override
  Future<void> recordStepTiming(SetupStepObservation observation) async {
    refused++;
    throw StateError('function record_setup_step_timing does not exist');
  }
}
