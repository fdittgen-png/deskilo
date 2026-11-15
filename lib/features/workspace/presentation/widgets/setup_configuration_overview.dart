// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The selected goal and the server's saved readiness stay together. A
// missing check or an external dependency is never presented as completion.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/dictionary_labels.dart';
import '../../domain/launch_review.dart';
import '../../domain/setup_status.dart';
import '../setup_step_words.dart';

/// #4074 — every step the space uses, as the rail beside the page numbers
/// them: the steps that apply, in the guide's order, and how many are done.
({int done, int total}) _stepsOfPlan(SetupStatus status) {
  final steps = [for (final g in LaunchReview.from(status).groups) ...g.steps];
  return (
    done: steps.where((s) => s.state == SetupStepState.ready).length,
    total: steps.length,
  );
}

/// #4074 — a step's place in the guide and its name, as the rail numbers
/// it ("Step 3 of 29 · Places on the plan"); null when the step is not one
/// the space uses or the status is not read yet.
String? setupStepPositionText(
  AppLocalizations l10n,
  SetupStatus? status,
  String stepId,
) {
  if (status == null) return null;
  final steps = [for (final g in LaunchReview.from(status).groups) ...g.steps];
  final at = steps.indexWhere((s) => s.step == stepId);
  if (at < 0) return null;
  return l10n.setupStepPosition(
    at + 1,
    steps.length,
    l10n.setupStepTitle(stepId),
  );
}

/// A count and what it is the count of, side by side with another.
class _Count extends StatelessWidget {
  const _Count({required this.count, required this.note, super.key});

  final String count;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count, style: theme.textTheme.titleMedium),
        Text(
          note,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

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
            const SizedBox(height: AppSpacing.sm),
            // #4074 — two counts, each named for what it counts.
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                if (goal != null)
                  _Count(
                    key: const ValueKey('setup-goal-count'),
                    count: l10n.setupGoalChecks(goal.ready, goal.required),
                    note: l10n.setupGoalLine(
                      l10n.setupMilestoneName(goal.milestone),
                    ),
                  ),
                _Count(
                  key: const ValueKey('setup-all-steps-count'),
                  count: l10n.setupAllSteps(
                    _stepsOfPlan(status).done,
                    _stepsOfPlan(status).total,
                  ),
                  note: l10n.setupAllStepsNote,
                ),
              ],
            ),
            if (goal != null) ...[
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
                      '${l10n.setupGoalChecks(goal.ready, goal.required)}',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
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
      // #4074 — with enlarged text the strip scrolls within a third of the
      // window, so the step's page below it keeps its room.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height / 3,
        ),
        child: SingleChildScrollView(
          padding: AppSpacing.mdAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // #3282 — where the owner is: workspace, configuration, task.
              Semantics(
                header: true,
                child: Text(
                  l10n.setupTaskBreadcrumb(
                    workspaceName,
                    l10n.setupStepTitle(stepId),
                  ),
                  key: const ValueKey('setup-task-breadcrumb'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (setupStepPositionText(l10n, status, stepId) case final place?)
                Text(place, key: const ValueKey('setup-task-position')),
              if (goal != null)
                Text(
                  l10n.setupGoalChecks(goal.ready, goal.required),
                  key: const ValueKey('setup-task-goal'),
                ),
              Text(
                step == null
                    ? l10n.setupOverviewUnchecked
                    : setupStepWord(l10n, step),
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
      ),
    );
  }
}
