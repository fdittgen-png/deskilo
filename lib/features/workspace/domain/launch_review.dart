// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2876 — the Launch review: the server's setup status read back as
// answers to check before going live. Every milestone is a server
// condition with the steps that are its evidence; a space goes live only
// when every milestone it chose is reached, and when it cannot, the
// review names the steps that stop it and where each is fixed.

import 'setup_status.dart';
import 'setup_steps.dart';

/// A milestone with the required steps that are its evidence.
class LaunchMilestone {
  const LaunchMilestone({required this.status, required this.evidence});

  final SetupMilestoneStatus status;
  final List<SetupStepStatus> evidence;
}

/// One group of the guide with its steps, in catalogue order.
class LaunchGroup {
  const LaunchGroup({required this.group, required this.steps});

  final SetupGroup group;
  final List<SetupStepStatus> steps;
}

class LaunchReview {
  const LaunchReview({
    required this.milestones,
    required this.groups,
    required this.blockers,
    required this.operatorTasks,
  });

  factory LaunchReview.from(SetupStatus status) {
    final applying = {
      for (final m in status.milestones)
        if (m.applies) m.milestone,
    };
    final groupOf = {for (final s in setupSteps) s.id: s.group};
    final shown = [
      for (final s in status.steps)
        if (s.state != SetupStepState.notApplicable) s,
    ];
    return LaunchReview(
      milestones: [
        for (final m in status.milestones)
          if (m.applies)
            LaunchMilestone(
              status: m,
              evidence: [
                for (final s in status.steps)
                  if (s.required && s.milestone == m.milestone) s,
              ],
            ),
      ],
      groups: [
        for (final g in SetupGroup.values)
          if (shown.where((s) => groupOf[s.step] == g).toList() case final steps
              when steps.isNotEmpty)
            LaunchGroup(group: g, steps: steps),
      ],
      blockers: [
        for (final s in status.steps)
          if (s.required && s.open && applying.contains(s.milestone)) s,
      ],
      operatorTasks: [
        for (final s in status.steps)
          if (s.state == SetupStepState.needsOperator) s,
      ],
    );
  }

  /// The milestones the space chose, in order, with their evidence.
  final List<LaunchMilestone> milestones;

  /// Every step the space uses, by group, for the Change links.
  final List<LaunchGroup> groups;

  /// The required steps still open in a milestone the space chose.
  final List<SetupStepStatus> blockers;

  /// What only the operator can do, to forward as text.
  final List<SetupStepStatus> operatorTasks;

  /// Every milestone the space chose is reached on the server.
  bool get canGoLive =>
      milestones.isNotEmpty &&
      blockers.isEmpty &&
      milestones.every((m) => m.status.reached);
}
