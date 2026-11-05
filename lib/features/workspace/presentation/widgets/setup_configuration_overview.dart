// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The selected goal and the server's saved readiness stay together. A
// missing check or an external dependency is never presented as completion.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/setup_status.dart';

class SetupConfigurationOverview extends StatelessWidget {
  const SetupConfigurationOverview({
    super.key,
    required this.workspaceName,
    required this.status,
    required this.onChoose,
  });

  final String workspaceName;
  final SetupStatus status;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final goal = status.goal;
    return Card(
      key: const ValueKey('setup-configuration-overview'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.setupOverviewTitle, style: theme.textTheme.labelLarge),
            Text(workspaceName, style: theme.textTheme.titleLarge),
            if (goal != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.setupGoalLine(l10n.setupMilestoneName(goal.milestone))),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                container: true,
                child: LinearProgressIndicator(
                  key: const ValueKey('setup-goal-progress-bar'),
                  value: goal.required == 0
                      ? (goal.reached ? 1 : 0)
                      : (goal.ready / goal.required).clamp(0, 1),
                  semanticsLabel:
                      '${l10n.setupMilestoneName(goal.milestone)} · '
                      '${l10n.setupGuideProgress(goal.ready, goal.required)}',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.setupGuideProgress(goal.ready, goal.required)),
            ],
            Semantics(
              container: true,
              liveRegion: true,
              child: Text(_explanation(context)),
            ),
            Text(l10n.setupTaskSaved, style: theme.textTheme.bodySmall),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('setup-guide-levels'),
                icon: const Icon(Icons.tune),
                label: Text(l10n.setupGuideLevelsLink),
                onPressed: onChoose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _explanation(BuildContext context) {
    final l10n = context.l10n;
    final goal = status.goal;
    if (goal == null) return l10n.setupOverviewChoose;
    if (status.steps.any(
      (s) => s.required && s.state == SetupStepState.unknown,
    )) {
      return l10n.setupOverviewUnchecked;
    }
    if (goal.reached) return l10n.setupOverviewReady;
    return l10n.setupOverviewRemaining(
      (goal.required - goal.ready).clamp(0, goal.required),
    );
  }
}

/// A compact orientation strip on every task, including a direct deep link.
class SetupTaskContext extends StatelessWidget {
  const SetupTaskContext({
    super.key,
    required this.workspaceName,
    required this.stepId,
    required this.status,
  });

  final String workspaceName;
  final String stepId;
  final SetupStatus? status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final step = status?.steps.where((s) => s.step == stepId).firstOrNull;
    final goal = status?.goal;
    return Material(
      key: const ValueKey('setup-task-context'),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(workspaceName, style: Theme.of(context).textTheme.titleSmall),
            if (goal != null)
              Text(
                '${l10n.setupMilestoneName(goal.milestone)} · '
                '${l10n.setupGuideProgress(goal.ready, goal.required)}',
              ),
            Text(
              step == null
                  ? l10n.setupOverviewUnchecked
                  : l10n.setupStateName(step.state.name),
            ),
            if (step != null && step.blockedBy.isNotEmpty)
              Text(
                l10n.setupGuideWaitsFor(
                  step.blockedBy.map(l10n.setupStepTitle).join(', '),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
