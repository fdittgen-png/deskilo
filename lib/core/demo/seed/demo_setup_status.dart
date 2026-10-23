// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The demo's setup status (ADR 0047 §9), by the server's own rules
// (`workspace_setup_status`, 0539, with the acknowledgements of 0545) over
// the shared step catalogue: a step applies when its feature is on, is
// ready when the space holds what its evidence names (a manual step when
// the owner marked it done), waits for a step it depends on, and an
// optional step the owner set aside reads deferred. A milestone is reached
// when its required steps and those of the milestones before it are. What
// each demo space holds is read from its fixture
// (`data/demo_setup_repository.dart`).
import '../../../features/workspace/domain/setup_status.dart';
import '../../../features/workspace/domain/setup_steps.dart';

/// The status of a demo space whose features are [flags], whose [ready]
/// steps hold their evidence, and whose [acknowledged] steps the owner set
/// aside or marked done.
SetupStatus demoSetupStatus(
  Map<String, Object?> flags, {
  required Set<String> ready,
  Set<String> acknowledged = const {},
}) {
  bool applies(SetupStep s) =>
      s.feature == null || flags[s.feature!.dbKey] == true;
  bool done(SetupStep s) => s.evidence == 'manual'
      ? acknowledged.contains(s.id)
      : ready.contains(s.id);
  final byId = {for (final s in setupSteps) s.id: s};
  final steps = [
    for (final s in setupSteps)
      _stepStatus(
        s,
        applies: applies(s),
        done: done(s),
        acknowledged: acknowledged.contains(s.id),
        blockedBy: [
          for (final d in s.dependsOn)
            if (applies(byId[d]!) && !done(byId[d]!)) d,
        ],
      ),
  ];
  return SetupStatus(
    steps: steps,
    milestones: [
      for (final (rank, m) in SetupMilestone.values.indexed)
        _milestoneStatus(m, [
          for (final s in steps)
            if (SetupMilestone.values.byName(s.milestone).index <= rank) s,
        ]),
    ],
  );
}

SetupStepStatus _stepStatus(
  SetupStep s, {
  required bool applies,
  required bool done,
  required bool acknowledged,
  required List<String> blockedBy,
}) {
  // An approval rule nobody can satisfy holds requests forever: required
  // until it is fixed (0399).
  final required = s.required || (s.id == 'approvals' && !done);
  return SetupStepStatus(
    step: s.id,
    milestone: s.milestone.name,
    required: required,
    route: s.route,
    blockedBy: blockedBy,
    manual: s.evidence == 'manual',
    estimateMinutes: s.estimateMinutes,
    state: !applies
        ? SetupStepState.notApplicable
        : done
        ? SetupStepState.ready
        : blockedBy.isNotEmpty
        ? SetupStepState.blocked
        : !required && acknowledged
        ? SetupStepState.deferred
        : s.actor == SetupActor.operator
        ? SetupStepState.needsOperator
        : SetupStepState.needsConfiguration,
  );
}

/// [m] over [upTo], the steps of it and of the milestones before it.
SetupMilestoneStatus _milestoneStatus(
  SetupMilestone m,
  List<SetupStepStatus> upTo,
) {
  final required = [
    for (final s in upTo)
      if (s.required && s.state != SetupStepState.notApplicable) s,
  ];
  return SetupMilestoneStatus(
    milestone: m.name,
    applies: upTo.any(
      (s) => s.milestone == m.name && s.state != SetupStepState.notApplicable,
    ),
    required: required.length,
    ready: required.where((s) => s.state == SetupStepState.ready).length,
    reached: required.every((s) => s.state == SetupStepState.ready),
  );
}
