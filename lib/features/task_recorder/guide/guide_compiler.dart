// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — a recording becomes a DRAFT guide.
//
// What the person did becomes what the reader will do; what the server
// answered becomes what the step waits for — the command's successful
// outcomes, as an expectation. An observed refusal is NOT turned into
// proof of success: observations are dropped, and every command step
// gets a recovery instruction for the refusal a reader may meet. A note
// becomes an instruction the author can edit; a protected or unknown
// screen becomes a manual step that is acknowledged, never verified.
// The source recording is named by its digest and is never changed.

import '../domain/action_registry.dart';
import '../domain/task_recording.dart';
import '../domain/task_recording_codec.dart';
import 'task_guide.dart';

/// The outcomes of [action] that complete a guided command step.
Set<String> successOutcomes(
  ActionSpec action, {
  ActionRegistry registry = recorderRegistry,
}) => {
  for (final id in action.outcomes)
    if (registry.outcome(id)?.state
        case ObservationState.confirmed || ObservationState.pending)
      id,
};

/// Compiles [recording] into a draft guide.
TaskGuide compileGuide(
  TaskRecording recording, {
  ActionRegistry registry = recorderRegistry,
}) {
  final steps = <GuideStep>[];
  String nextId() => 'g${steps.length + 1}';
  for (final step in recording.steps) {
    switch (step.kind) {
      case StepKind.action:
        final spec = registry.action(step.action);
        if (spec == null) {
          steps.add(GuideStep(id: nextId(), kind: GuideStepKind.manual));
          continue;
        }
        final id = nextId();
        steps.add(
          GuideStep(
            id: id,
            kind: GuideStepKind.perform,
            action: spec.id,
            expectedOutcomes: spec.isCommand
                ? successOutcomes(spec, registry: registry)
                : const {},
            recovery: spec.isCommand
                ? [GuideStep(id: '${id}r1', kind: GuideStepKind.instruction)]
                : const [],
          ),
        );
      case StepKind.observation:
        // What the server answered then is not what it will answer now.
        break;
      case StepKind.annotation:
        steps.add(
          GuideStep(
            id: nextId(),
            kind: GuideStepKind.instruction,
            text: step.note,
          ),
        );
      case StepKind.excluded:
        steps.add(
          GuideStep(
            id: nextId(),
            kind: GuideStepKind.manual,
            manualCategory: step.protectedCategory,
          ),
        );
      case StepKind.unrecorded:
        steps.add(GuideStep(id: nextId(), kind: GuideStepKind.manual));
    }
  }
  return TaskGuide(
    actionContractVersion: recording.actionContractVersion,
    title: recording.title,
    sourceDigest: recording.kind == RecordingKind.edited
        ? recording.sourceDigest
        : recordingDigest(recording),
    steps: steps,
  );
}
