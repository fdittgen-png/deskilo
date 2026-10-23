// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 — a setup step's draft is saved once the person pauses, and
// "saved" only after the server answered. A save whose answer was lost is
// sent again under the same request id (the server answers it without a
// second version); newer edits follow under a new id. A draft another
// configurer moved is reported with their answers, never written over;
// "keep mine" writes against their version. A discard leaves no draft, and
// leaving sends what is still pending. Each case reads the fake server's
// stored draft, not only the state. Time is the test zone's: the debounce
// runs on `tester.pump`, never on the wall clock.
import 'dart:async';

import 'package:deskilo/core/demo/data/fixture_clock.dart';
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/ui/app_durations.dart';
import 'package:deskilo/features/workspace/application/setup_draft_autosave.dart';
import 'package:deskilo/features/workspace/domain/setup_step_draft.dart';
import 'package:deskilo/features/workspace/providers/local_setup_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Holds every save until [open] is completed.
class _GatedSetupRepository extends FakeLocalSetupRepository {
  final open = Completer<void>();

  @override
  Future<SetupDraftWrite> saveStepDraft(
    String workspaceId,
    String step, {
    required Map<String, Object?> payload,
    required int? expectedVersion,
    required String requestId,
  }) async {
    await open.future;
    return super.saveStepDraft(
      workspaceId,
      step,
      payload: payload,
      expectedVersion: expectedVersion,
      requestId: requestId,
    );
  }
}

final _draft = setupDraftAutosaveProvider('ws-1', 'basics');

({ProviderContainer container, SetupDraftAutosave notifier}) _start(
  FakeLocalSetupRepository server,
) {
  final container = ProviderContainer(
    overrides: [localSetupRepositoryProvider.overrideWithValue(server)],
  )..listen(_draft, (_, _) {});
  return (container: container, notifier: container.read(_draft.notifier));
}

Future<SetupStepDraft?> _stored(FakeLocalSetupRepository server) =>
    server.stepDraft('ws-1', 'basics');

Future<void> _pause(WidgetTester tester) =>
    tester.pump(AppDurations.draftAutosave);

void main() {
  testWidgets('saves the last answers once the person pauses', (tester) async {
    final server = FakeLocalSetupRepository();
    final (:container, :notifier) = _start(server);
    addTearDown(container.dispose);

    notifier.changed({'language': 'fr'});
    await tester.pump(AppDurations.draftAutosave ~/ 2);
    notifier.changed({'language': 'it'});
    await tester.pump(AppDurations.draftAutosave ~/ 2);
    expect(server.draftSaveRequests, isEmpty, reason: 'still typing');

    await _pause(tester);
    expect(server.draftSaveRequests, hasLength(1));
    final stored = await _stored(server);
    expect(stored?.payload, {'language': 'it'});
    expect(stored?.version, 1);
    expect(container.read(_draft), isA<SetupDraftSaved>());
    expect((container.read(_draft) as SetupDraftSaved).at, kTestNow);
  });

  testWidgets('"saved" only once the server answered', (tester) async {
    final server = _GatedSetupRepository();
    final (:container, :notifier) = _start(server);
    addTearDown(container.dispose);

    notifier.changed({'language': 'fr'});
    await _pause(tester);
    expect(container.read(_draft), isA<SetupDraftSaving>());
    expect(await _stored(server), isNull);

    server.open.complete();
    await tester.pump();
    expect(container.read(_draft), isA<SetupDraftSaved>());
    expect((await _stored(server))?.payload, {'language': 'fr'});
  });

  testWidgets('a save whose answer was lost is retried under the same '
      'request id, and the server counts it once', (tester) async {
    final server = FakeLocalSetupRepository()
      ..failDraftSaves = 1
      ..draftAnswerLost = true;
    final (:container, :notifier) = _start(server);
    addTearDown(container.dispose);

    notifier.changed({'language': 'fr'});
    await _pause(tester);
    expect(container.read(_draft), isA<SetupDraftFailed>());

    await notifier.retry();
    expect(server.draftSaveRequests, hasLength(2));
    expect(server.draftSaveRequests.toSet(), hasLength(1));
    expect(container.read(_draft), isA<SetupDraftSaved>());
    expect((await _stored(server))?.version, 1);
  });

  testWidgets('after a failed save, a new edit sends the failed one first, '
      'then the new answers under a new id', (tester) async {
    final server = FakeLocalSetupRepository()..failDraftSaves = 1;
    final (:container, :notifier) = _start(server);
    addTearDown(container.dispose);

    notifier.changed({'language': 'fr'});
    await _pause(tester);
    expect(container.read(_draft), isA<SetupDraftFailed>());
    expect(await _stored(server), isNull);

    notifier.changed({'language': 'it'});
    await _pause(tester);
    final [first, retried, next] = server.draftSaveRequests;
    expect(retried, first);
    expect(next, isNot(first));
    final stored = await _stored(server);
    expect(stored?.payload, {'language': 'it'});
    expect(stored?.version, 2);
  });

  testWidgets('a draft another configurer moved is reported with their '
      'answers and kept; keep mine writes against their version', (
    tester,
  ) async {
    final server = FakeLocalSetupRepository();
    final (:container, :notifier) = _start(server);
    addTearDown(container.dispose);
    expect(await notifier.load(), isNull);

    await server.saveStepDraft(
      'ws-1',
      'basics',
      payload: {'language': 'de'},
      expectedVersion: null,
      requestId: 'other',
    );
    notifier.changed({'language': 'fr'});
    await _pause(tester);

    final state = container.read(_draft);
    expect(state, isA<SetupDraftConflicted>());
    expect((state as SetupDraftConflicted).theirs?.payload, {'language': 'de'});
    expect((await _stored(server))?.payload, {'language': 'de'});

    notifier.changed({'language': 'es'});
    await _pause(tester);
    expect((await _stored(server))?.payload, {
      'language': 'de',
    }, reason: 'nothing is sent until the person chooses');

    await notifier.keepMine();
    final stored = await _stored(server);
    expect(stored?.payload, {'language': 'es'});
    expect(stored?.version, 2);
    expect(container.read(_draft), isA<SetupDraftSaved>());
  });

  testWidgets('reload takes their version for the next save', (tester) async {
    final server = FakeLocalSetupRepository();
    final (:container, :notifier) = _start(server);
    addTearDown(container.dispose);
    await server.saveStepDraft(
      'ws-1',
      'basics',
      payload: {'language': 'de'},
      expectedVersion: null,
      requestId: 'other',
    );
    notifier.changed({'language': 'fr'});
    await _pause(tester);
    notifier.reloaded();
    expect(container.read(_draft), isA<SetupDraftIdle>());

    notifier.changed({'language': 'it'});
    await _pause(tester);
    final stored = await _stored(server);
    expect(stored?.payload, {'language': 'it'});
    expect(stored?.version, 2);
  });

  testWidgets('a discard leaves no draft', (tester) async {
    final server = FakeLocalSetupRepository();
    final (:container, :notifier) = _start(server);
    addTearDown(container.dispose);
    notifier.changed({'language': 'fr'});
    await _pause(tester);
    expect(await _stored(server), isNotNull);

    expect(await notifier.discard(), isTrue);
    expect(await _stored(server), isNull);
    expect(container.read(_draft), isA<SetupDraftIdle>());
  });

  testWidgets('leaving sends what is still pending', (tester) async {
    final server = FakeLocalSetupRepository();
    final (:container, :notifier) = _start(server);
    notifier.changed({'language': 'fr'});
    container.dispose();
    await tester.pump();
    expect((await _stored(server))?.payload, {'language': 'fr'});
  });
}
