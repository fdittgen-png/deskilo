// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 live guide — the model and runner parts the host stands on:
// a step names its control (schema 2), a schema-1 guide still reads, an
// unknown soft target is dropped not refused, a strict action refuses a
// target it does not list, the compiler carries the recorded control and
// its app message, a tap elsewhere does not complete a step that names
// its control, and a command completes only on its real outcome.
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/safe_payload.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/guide/guide_codec.dart';
import 'package:deskilo/features/task_recorder/guide/guide_compiler.dart';
import 'package:deskilo/features/task_recorder/guide/guide_runner.dart';
import 'package:deskilo/features/task_recorder/guide/task_guide.dart';
import 'package:flutter_test/flutter_test.dart';

final String _key = uiKeys.first;
final String _label = uiLabelKeys.first;

TaskGuide _guide(List<GuideStep> steps) =>
    TaskGuide(actionContractVersion: actionContractVersion, steps: steps);

String _text(Map<String, Object?> json) =>
    encodeGuideText(_guide(const []))
        .replaceFirst('"steps": []', '"steps": [${_json(json)}]');

String _json(Map<String, Object?> m) => m.entries
    .map((e) => '"${e.key}": ${e.value is String ? '"${e.value}"' : e.value}')
    .join(', ')
    .replaceAllMapped(RegExp(r'^'), (_) => '{')
    .replaceAllMapped(RegExp(r'$'), (_) => '}');

void main() {
  group('schema 2: a step names its control', () {
    test('target and label round-trip', () {
      final g = _guide([
        GuideStep(
          id: 'g1',
          kind: GuideStepKind.perform,
          action: RecorderActions.uiTap,
          target: _key,
          label: _label,
        ),
      ]);
      final text = encodeGuideText(g);
      expect(text, contains('"schema_version": 2'));
      final back = decodeGuideText(text);
      expect(back.runnable, isTrue);
      expect(back.guide!.steps.single.target, _key);
      expect(back.guide!.steps.single.label, _label);
    });

    test('a schema-1 guide reads unchanged, with no target', () {
      final text = encodeGuideText(
        _guide(const [
          GuideStep(
            id: 'g1',
            kind: GuideStepKind.perform,
            action: RecorderActions.selectDate,
          ),
        ]),
      ).replaceFirst('"schema_version": 2', '"schema_version": 1');
      final back = decodeGuideText(text);
      expect(back.runnable, isTrue);
      expect(back.guide!.steps.single.target, isNull);
    });

    test('an unknown soft target is dropped, the step matches anywhere', () {
      final back = decodeGuideText(
        _text({
          'id': 'g1',
          'kind': 'perform',
          'action': RecorderActions.uiTap,
          'target': 'no-such-key-in-this-build',
        }),
      );
      expect(back.accepted, isTrue);
      expect(back.guide!.steps.single.target, isNull);
    });

    test('a strict action refuses a target it does not list', () {
      final back = decodeGuideText(
        _text({
          'id': 'g1',
          'kind': 'perform',
          'action': RecorderActions.selectDate,
          'target': 'anything',
        }),
      );
      expect(back.accepted, isFalse);
      expect(back.issues.single.code, GuideIssueCode.inconsistent);
    });

    test('an instruction carries no target', () {
      final back = decodeGuideText(
        _text({'id': 'g1', 'kind': 'instruction', 'target': _key}),
      );
      expect(back.accepted, isFalse);
    });

    test('a label that is not an app message key is dropped', () {
      final back = decodeGuideText(
        _text({
          'id': 'g1',
          'kind': 'perform',
          'action': RecorderActions.uiTap,
          'label': 'Delete everything',
        }),
      );
      expect(back.guide!.steps.single.label, isNull);
    });
  });

  group('the compiler carries the recorded control', () {
    RecordedStep tap(int seq, String target, {String? label}) => RecordedStep(
      seq: seq,
      segment: 0,
      elapsedMs: seq * 10,
      kind: StepKind.action,
      surface: RecorderSurfaces.anyScreen,
      action: RecorderActions.uiTap,
      actionVersion: 1,
      target: target,
      payload: SafePayload.minimize({'label'}, {'label': ?label}),
    );

    test('a keyed tap keeps its key and label; an unkeyed one does not', () {
      final r = TaskRecording(
        actionContractVersion: actionContractVersion,
        platform: RecordingPlatform.web,
        segments: const [RecordingSegment(index: 0, startMs: 0)],
        steps: [
          tap(1, _key, label: _label),
          tap(2, uiUnkeyed),
        ],
      );
      final g = compileGuide(r);
      expect(g.steps[0].target, _key);
      expect(g.steps[1].target, isNull);
    });
  });

  group('the runner', () {
    test('a tap on another control does not complete the step', () {
      final run = GuideRun(
        _guide([
          GuideStep(
            id: 'g1',
            kind: GuideStepKind.perform,
            action: RecorderActions.uiTap,
            target: _key,
          ),
        ]),
      );
      run.onAction(RecorderActions.uiTap, target: 'another-control');
      expect(run.statusOf('g1'), GuideStepStatus.pending);
      run.onAction(RecorderActions.uiTap, target: _key);
      expect(run.statusOf('g1'), GuideStepStatus.done);
      expect(run.state, GuideRunState.completed);
    });

    test('a command completes only on its outcome, never on the tap', () {
      final run = GuideRun(
        _guide(const [
          GuideStep(
            id: 'g1',
            kind: GuideStepKind.perform,
            action: RecorderActions.uiCommand,
            expectedOutcomes: {RecorderOutcomes.commandDone},
          ),
        ]),
      );
      run.onAction(RecorderActions.uiCommand);
      expect(run.statusOf('g1'), GuideStepStatus.waiting);
      expect(run.state, GuideRunState.running);
      run.onOutcome(RecorderOutcomes.commandUnknown);
      expect(run.uncertain, isTrue);
      expect(run.statusOf('g1'), GuideStepStatus.pending);
      run.onAction(RecorderActions.uiCommand);
      run.onOutcome(RecorderOutcomes.commandDone);
      expect(run.statusOf('g1'), GuideStepStatus.done);
    });
  });
}
