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
//
// #1867 live guide: on a generic step (#2142) the control the person used
// (its recorded target — a string key, its pattern, a route pattern or a
// command's message) and the app message it showed travel with the step,
// so a reader is shown WHERE to act. An unnamed control ("unkeyed") is
// not a target: that step requires manual acknowledgement. A
// screen seam's own steps keep matching their action as before.

import '../domain/action_registry.dart';
import '../domain/task_recording.dart';
import '../domain/task_recording_codec.dart';
import 'task_guide.dart';
import 'guide_destination.dart';

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
  String? destination;
  for (final step in recording.steps) {
    if (step.page != null) {
      destination = step.page;
    } else if (step.action == RecorderActions.uiOpenScreen) {
      final tab = step.payload.values['me_tab'];
      destination =
          step.target == '/me' &&
              tab != null &&
              guideMeDestinations.contains('/me?tab=$tab')
          ? '/me?tab=$tab'
          : guidePageForTarget(step.target);
    } else {
      destination = guideSurfaceRoutes[step.surface] ?? destination;
    }
    switch (step.kind) {
      case StepKind.action:
        if (step.action == RecorderActions.uiOpenWindow ||
            step.action == RecorderActions.uiCloseWindow) {
          continue;
        }
        final spec = registry.action(step.action);
        if (spec == null ||
            (spec.softTargets &&
                (step.target == null ||
                    step.target == uiUnkeyed ||
                    step.target!.contains('{}')))) {
          steps.add(
            GuideStep(
              id: nextId(),
              kind: GuideStepKind.manual,
              destination: destination,
            ),
          );
          continue;
        }
        final id = nextId();
        // Retain both generic control keys and registered field identifiers.
        // The player maps registered fields to their real control keys.
        final target = step.target == uiUnkeyed ? null : step.target;
        final label = step.payload.values['label'];
        steps.add(
          GuideStep(
            id: id,
            kind: GuideStepKind.perform,
            destination: destination,
            action: spec.id,
            target: target,
            label: label != null && uiLabelKeys.contains(label) ? label : null,
            expectedOutcomes: spec.isCommand
                ? successOutcomes(spec, registry: registry)
                : const {},
            recovery: spec.isCommand
                ? [
                    GuideStep(
                      id: '${id}r1',
                      kind: GuideStepKind.instruction,
                      destination: destination,
                    ),
                  ]
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
            destination: destination,
          ),
        );
      case StepKind.excluded:
        steps.add(
          GuideStep(
            id: nextId(),
            kind: GuideStepKind.manual,
            manualCategory: step.protectedCategory,
            destination: destination,
          ),
        );
      case StepKind.unrecorded:
        steps.add(
          GuideStep(
            id: nextId(),
            kind: GuideStepKind.manual,
            destination: destination,
          ),
        );
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
