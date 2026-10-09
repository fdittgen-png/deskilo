// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Every new recorded step retains its own form through capture, storage and editing; missing references stop recording and cannot start a guide.
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/recording_edit.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/guide/guide_codec.dart';
import 'package:deskilo/features/task_recorder/guide/guide_compiler.dart';
import 'package:deskilo/features/task_recorder/guide/guide_session.dart';
import 'package:deskilo/features/task_recorder/guide/task_guide.dart';
import 'package:deskilo/features/task_recorder/presentation/guide_host/guide_step_text.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

void main() {
  late MemoryRecorderLogBackend backend;
  late RecorderController recorder;
  late StepClock clock;
  setUp(() {
    backend = MemoryRecorderLogBackend();
    clock = StepClock();
    recorder = fixtureController(
      RecorderStore(backend: backend, namespace: canaryNamespace),
      clock,
    );
  });
  tearDown(() => recorder.dispose());

  test(
    'manual gap deduplication never hides a form change or missing reference',
    () async {
      await recorder.start(scope: canaryScope);
      recorder.unrecorded();
      recorder.setPage('/me?tab=me');
      recorder.unrecorded();
      expect(recorder.snapshot!.steps.map((s) => s.page), [
        '/reserve',
        '/me?tab=me',
      ]);
      recorder.setPage(null);
      recorder.unrecorded();
      expect(recorder.status.endReason, RecordingEndReason.referenceMissing);
      expect(recorder.snapshot!.steps, hasLength(2));
    },
  );

  test(
    'every step kind has a page and late results keep their command page',
    () async {
      await recorder.start(scope: canaryScope);
      recorder.record(RecorderActions.openReserve);
      recorder.annotate('Choose the period');
      recorder.unrecorded();
      recorder.excluded(ProtectedSurface.authentication);
      final token = recorder.attempt(RecorderActions.confirmBooking);
      recorder.setPage('/me?tab=me');
      recorder.outcome(token, RecorderOutcomes.bookingConfirmed);
      recorder.annotate('Review account');
      final recording = (await recorder.stop())!;
      expect(recording.steps.map((s) => s.page), [
        '/reserve',
        '/reserve',
        '/reserve',
        '/reserve',
        '/reserve',
        '/reserve',
        '/me?tab=me',
      ]);
      expect(
        recording.steps.map((s) => s.kind).toSet(),
        StepKind.values.toSet(),
      );
      expect(
        decodeRecordingText(encodeRecordingText(recording)).runnable,
        isTrue,
      );
    },
  );

  test(
    'an unknown form stops before an unlinked step can be persisted',
    () async {
      await recorder.start(scope: canaryScope);
      recorder.annotate('Known form');
      recorder.setPage('/not-a-registered-page');
      recorder.annotate('This must not be recorded');
      final recording = (await recorder.stop())!;
      expect(recording.endReason, RecordingEndReason.referenceMissing);
      expect(recording.completeness, Completeness.partial);
      expect(recording.steps.single.note, 'Known form');
      final stored = recoverRecordingLog(
        '0123456789abcdef0123456789abcdef',
        backend.logs.values.single.toString(),
      );
      expect(stored.recording!.steps, recording.steps);
      expect(stored.recording!.endReason, RecordingEndReason.referenceMissing);
    },
  );

  test(
    'schema 3 refuses missing or unsafe references on any step kind',
    () async {
      await recorder.start(scope: canaryScope);
      recorder.record(RecorderActions.openReserve);
      recorder.annotate('Choose the period');
      recorder.unrecorded();
      recorder.excluded(ProtectedSurface.authentication);
      final token = recorder.attempt(RecorderActions.confirmBooking);
      recorder.outcome(token, RecorderOutcomes.bookingConfirmed);
      final recording = (await recorder.stop())!;
      for (var index = 0; index < recording.steps.length; index++) {
        for (final invalid in [
          null,
          '/member/private-id',
          'https://example.com',
          '/me?tab=unknown',
        ]) {
          final json = encodeRecording(recording);
          final steps = json['steps']! as List;
          final step = steps[index] as Map<String, Object?>;
          if (invalid == null) {
            step.remove('page');
          } else {
            step['page'] = invalid;
          }
          final result = decodeRecording(json);
          expect(
            result.accepted,
            isFalse,
            reason: 'step $index, page $invalid',
          );
          expect(
            result.issues.any((i) => i.path == 'steps[$index].page'),
            isTrue,
          );
        }
      }
    },
  );

  test(
    'editing out navigation retains each page through storage and guide export',
    () async {
      await recorder.start(scope: canaryScope, captureValues: true);
      recorder.setPage('/me?tab=me');
      recorder.record(
        RecorderActions.uiOpenScreen,
        target: '/me',
        page: '/me?tab=me',
      );
      clock.tick();
      recorder.record(RecorderActions.uiTap, target: 'me-profile-settings');
      recorder.setPage('/reserve');
      clock.tick();
      recorder.record(RecorderActions.changeBookingField, target: 'check_in');
      await recorder.stop();
      final stored = recoverRecordingLog(
        '0123456789abcdef0123456789abcdef',
        backend.logs.values.single.toString(),
      ).recording!;
      final edited = editedCopy(stored, {1});
      expect(edited.capturesValues, isTrue);
      final imported = decodeRecordingText(encodeRecordingText(edited))
          .recording!;
      final guide = decodeGuideText(encodeGuideText(compileGuide(imported)))
          .guide!;
      expect(guide.steps.map((s) => s.destination), ['/me?tab=me', '/reserve']);
      expect(guide.steps.last.target, 'check_in');
      expect(guideStepAnchor(guide.steps.last), 'booking-check-in-now');
    },
  );

  test('playback refuses an unresolved main or recovery step without replacing a run', () {
    final container = ProviderContainer(
      overrides: [
        recorderScopeProvider.overrideWithValue(canaryScope),
        taskRecorderAvailableProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(guideSessionProvider.notifier);
    TaskGuide guide(List<GuideStep> steps) =>
        TaskGuide(actionContractVersion: actionContractVersion, steps: steps);
    expect(
      session.start(
        guide(const [
          GuideStep(
            id: 'g1',
            kind: GuideStepKind.instruction,
            destination: '/me?tab=me',
          ),
        ]),
      ),
      isTrue,
    );
    final running = container.read(guideSessionProvider).run;
    for (final steps in [
      const [GuideStep(id: 'g1', kind: GuideStepKind.manual)],
      const [
        GuideStep(
          id: 'g1',
          kind: GuideStepKind.perform,
          action: RecorderActions.confirmBooking,
          destination: '/reserve',
          recovery: [
            GuideStep(
              id: 'g1r1',
              kind: GuideStepKind.instruction,
              destination: '/invalid',
            ),
          ],
        ),
      ],
    ]) {
      expect(session.start(guide(steps)), isFalse);
      expect(container.read(guideSessionProvider).run, same(running));
    }
  });
}
