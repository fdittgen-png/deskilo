// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Every guide step retains a safe destination through compilation, editing and import; visiting steps preserves unfinished work.
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/guide/guide_codec.dart';
import 'package:deskilo/features/task_recorder/guide/guide_compiler.dart';
import 'package:deskilo/features/task_recorder/domain/safe_payload.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/guide/guide_runner.dart';
import 'package:deskilo/features/task_recorder/guide/task_guide.dart';
import 'package:flutter_test/flutter_test.dart';

TaskGuide guide(List<GuideStep> steps) =>
    TaskGuide(actionContractVersion: actionContractVersion, steps: steps);

void main() {
  test(
    'compilation carries the Me tab through controls, notes and manual gaps',
    () {
      final recording = TaskRecording(
        actionContractVersion: actionContractVersion,
        platform: RecordingPlatform.web,
        segments: const [RecordingSegment(index: 0, startMs: 0)],
        steps: [
          RecordedStep(
            seq: 1,
            segment: 0,
            elapsedMs: 10,
            kind: StepKind.action,
            surface: RecorderSurfaces.anyScreen,
            action: RecorderActions.uiOpenScreen,
            actionVersion: 1,
            target: '/me',
            payload: SafePayload.minimize({'me_tab'}, {'me_tab': 'me'}),
          ),
          const RecordedStep(
            seq: 2,
            segment: 0,
            elapsedMs: 20,
            kind: StepKind.action,
            surface: RecorderSurfaces.anyScreen,
            action: RecorderActions.uiTap,
            actionVersion: 1,
            target: 'me-profile-settings',
          ),
          const RecordedStep(
            seq: 3,
            segment: 0,
            elapsedMs: 30,
            kind: StepKind.annotation,
            note: 'Review your profile',
          ),
          const RecordedStep(
            seq: 4,
            segment: 0,
            elapsedMs: 40,
            kind: StepKind.unrecorded,
          ),
          const RecordedStep(
            seq: 5,
            segment: 0,
            elapsedMs: 50,
            kind: StepKind.action,
            surface: RecorderSurfaces.reserve,
            action: RecorderActions.selectDate,
            actionVersion: 1,
          ),
        ],
      );
      final decoded = decodeGuideText(encodeGuideText(compileGuide(recording)));
      expect(decoded.runnable, isTrue);
      expect(decoded.guide!.steps.map((step) => step.destination), [
        '/me?tab=me',
        '/me?tab=me',
        '/me?tab=me',
        '/me?tab=me',
        '/reserve',
      ]);
    },
  );

  test('destinations survive editing and import on every step kind', () {
    final source = guide([
      const GuideStep(
        id: 'g1',
        kind: GuideStepKind.instruction,
        destination: '/me?tab=me',
      ),
      const GuideStep(
        id: 'g2',
        kind: GuideStepKind.manual,
        destination: '/members',
      ),
      const GuideStep(
        id: 'g3',
        kind: GuideStepKind.perform,
        action: RecorderActions.selectDate,
        destination: '/reserve',
      ),
    ]);
    final decoded = decodeGuideText(encodeGuideText(source));
    expect(decoded.runnable, isTrue);
    expect(
      decoded.guide!.steps.map(
        (s) => s.copyWith(text: 'New words').destination,
      ),
      ['/me?tab=me', '/members', '/reserve'],
    );
  });

  test('destinations reject private identifiers, arbitrary queries and external links', () {
    for (final bad in [
      '/member/private-id',
      '/member/:memberId',
      '/me?tab=secret',
      '/reserve?token=secret',
      'https://example.com',
      '//example.com',
      '/me#secret',
    ]) {
      expect(
        decodeGuideText(
          encodeGuideText(
            guide([
              GuideStep(id: 'g1', kind: GuideStepKind.manual, destination: bad),
            ]),
          ),
        ).accepted,
        isFalse,
        reason: bad,
      );
    }
  });

  test('visiting a later step preserves unfinished work and returns to it', () {
    final run = GuideRun(
      guide([
        for (var i = 1; i <= 3; i++)
          GuideStep(id: 'g$i', kind: GuideStepKind.instruction),
      ]),
    );
    run.visit('g3');
    expect(run.statusOf('g1'), GuideStepStatus.pending);
    run.acknowledge();
    expect(run.state, GuideRunState.running);
    expect(run.current!.id, 'g1');
    run.acknowledge();
    run.acknowledge();
    expect(run.state, GuideRunState.completed);
  });

  test('visiting cannot abandon a command that is awaiting its result', () {
    final run = GuideRun(
      guide([
        const GuideStep(
          id: 'g1',
          kind: GuideStepKind.perform,
          action: RecorderActions.confirmBooking,
          expectedOutcomes: {RecorderOutcomes.bookingConfirmed},
        ),
        const GuideStep(id: 'g2', kind: GuideStepKind.manual),
      ]),
    );
    run.onAction(RecorderActions.confirmBooking);
    run.visit('g2');
    expect(run.current!.id, 'g1');
    expect(run.statusOf('g1'), GuideStepStatus.waiting);
  });
}
