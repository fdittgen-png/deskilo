// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2872 (ADR 0047 §9) — the demo's setup status, by the server's own rules
// (`workspace_setup_status`, 0539) over the shared step catalogue: a step
// applies when its feature is on, is ready when the space is said to have
// it, waits for a step it depends on, and a milestone is reached when its
// required steps and those of the milestones before it are. Pézenas has
// everything; Leipzig is a space created today, half way to its first
// booking, so a visitor can walk the guide.
import '../../../features/workspace/domain/setup_status.dart';
import '../../../features/workspace/domain/setup_steps.dart';

/// The status of a demo space whose features are [flags] and whose
/// [ready] steps are done.
SetupStatus demoSetupStatus(
  Map<String, Object?> flags, {
  required Set<String> ready,
}) {
  bool applies(SetupStep s) =>
      s.feature == null || flags[s.feature!.dbKey] == true;
  final byId = {for (final s in setupSteps) s.id: s};
  final steps = [
    for (final s in setupSteps)
      () {
        final blockedBy = [
          for (final d in s.dependsOn)
            if (applies(byId[d]!) && !ready.contains(d)) d,
        ];
        return SetupStepStatus(
          step: s.id,
          milestone: s.milestone.name,
          required: s.required,
          route: s.route,
          blockedBy: blockedBy,
          manual: s.evidence == 'manual',
          estimateMinutes: s.estimateMinutes,
          state: !applies(s)
              ? SetupStepState.notApplicable
              : ready.contains(s.id)
              ? SetupStepState.ready
              : blockedBy.isNotEmpty
              ? SetupStepState.blocked
              : s.actor == SetupActor.operator
              ? SetupStepState.needsOperator
              : SetupStepState.needsConfiguration,
        );
      }(),
  ];
  return SetupStatus(
    steps: steps,
    milestones: [
      for (final (rank, m) in SetupMilestone.values.indexed)
        () {
          final upTo = [
            for (final s in steps)
              if (SetupMilestone.values.byName(s.milestone).index <= rank) s,
          ];
          final required = [
            for (final s in upTo)
              if (s.required && s.state != SetupStepState.notApplicable) s,
          ];
          return SetupMilestoneStatus(
            milestone: m.name,
            applies: upTo.any(
              (s) =>
                  s.milestone == m.name &&
                  s.state != SetupStepState.notApplicable,
            ),
            required: required.length,
            ready: required
                .where((s) => s.state == SetupStepState.ready)
                .length,
            reached: required.every((s) => s.state == SetupStepState.ready),
          );
        }(),
    ],
  );
}

/// Leipzig's done steps: a name, its hours, a plan — and nobody invited
/// who may book yet.
const demoSecondSpaceReadySteps = {'basics', 'hours', 'places'};
