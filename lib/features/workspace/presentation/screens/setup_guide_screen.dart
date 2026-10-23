// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 (ADR 0047 §6) — the setup guide: one task list from creating the
// space to opening it. The milestones the owner chose come first, then the
// one next action, then what the next milestone still needs; what waits,
// what a later milestone needs, what more the space could use, what was set
// aside and what is done stay folded. Every state is a word, never only a
// colour or an icon. The status is the server's (0539); a step opens the
// screen where it is done, and the guide reads again on the way back.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/demo_link.dart';
import '../../../../core/demo/presentation/demo_workspace.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/setup_step_actions.dart';
import '../../domain/setup_status.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/setup_return_bar.dart';

class SetupGuideScreen extends ConsumerWidget {
  const SetupGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupGuideTitle)),
      body: workspaceId == null
          ? const LoadingView()
          : _SetupGuideBody(workspaceId: workspaceId),
    );
  }
}

class _SetupGuideBody extends ConsumerWidget {
  const _SetupGuideBody({required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(workspaceSetupStatusProvider(workspaceId));
    Future<void> reload() async =>
        ref.invalidate(workspaceSetupStatusProvider(workspaceId));
    // #2869 (0545) — Later, Mark as done and Undo, by the server's rules.
    Future<void> act(SetupStepStatus step) async {
      final actions = ref.read(setupStepActionsProvider);
      await runGuarded(
        context,
        domain: 'workspace',
        message: 'setup step action failed',
        errorText: l10n.readinessSetAsideFailed,
        action: () => actions.run(workspaceId, step),
      );
      await reload();
    }

    final actions = (reload: reload, act: act);
    return switch (status) {
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          key: const ValueKey('setup-guide-list'),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _Milestones(status: value),
            if (value.nextMilestone case final next?
                when value.minutesToNextMilestone > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.setupGuideUntil(
                  value.minutesToNextMilestone,
                  l10n.setupMilestoneName(next.milestone),
                ),
                key: const ValueKey('setup-guide-until'),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            ..._sections(context, value, actions),
          ],
        ),
      ),
      AsyncError() => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          InlineBanner(
            key: const ValueKey('setup-guide-unavailable'),
            icon: Icons.cloud_off_outlined,
            text: l10n.setupGuideUnavailable,
            actionLabel: MaterialLocalizations.of(context)
                .refreshIndicatorSemanticLabel,
            onAction: reload,
          ),
        ],
      ),
      _ => const LoadingView(),
    };
  }

  List<Widget> _sections(
    BuildContext context,
    SetupStatus status,
    _Actions actions,
  ) {
    final l10n = context.l10n;
    final next = status.nextStep;
    if (status.nextMilestone == null || next == null) {
      // Every milestone the owner chose is reached: say so, and keep what
      // more the space could use within reach.
      return [
        _AllDone(text: l10n.setupGuideAllDone),
        for (final (id, title, steps) in [
          ('optional', l10n.setupGuideOptional, status.optional),
          ('deferred', l10n.setupGuideDeferred, status.deferred),
          ('done', l10n.setupGuideDone, status.done),
        ])
          _Folded(id: id, title: title, steps: steps, actions: actions),
      ];
    }
    final toDo = [
      for (final s in status.toDo)
        if (s != next) s,
    ];
    return [
      _NextCard(step: next, actions: actions),
      if (toDo.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        _Header(text: l10n.setupGuideToDo),
        for (final s in toDo)
          _StepTile(step: s, status: status, actions: actions),
      ],
      _Folded(
        id: 'waiting',
        title: l10n.setupGuideWaiting,
        steps: status.waiting,
        status: status,
        actions: actions,
      ),
      _Folded(
        id: 'later',
        title: l10n.setupGuideLater,
        steps: [
          for (final s in status.later)
            if (s != next) s,
        ],
        actions: actions,
      ),
      _Folded(
        id: 'optional',
        title: l10n.setupGuideOptional,
        steps: [
          for (final s in status.optional)
            if (s != next) s,
        ],
        actions: actions,
      ),
      _Folded(
        id: 'deferred',
        title: l10n.setupGuideDeferred,
        steps: status.deferred,
        actions: actions,
      ),
      _Folded(
        id: 'done',
        title: l10n.setupGuideDone,
        steps: status.done,
        actions: actions,
      ),
    ];
  }
}

/// What a step's controls do: read the status again, and acknowledge a
/// step (or take the acknowledgement back).
typedef _Actions = ({
  Future<void> Function() reload,
  Future<void> Function(SetupStepStatus step) act,
});

/// Opens [step]'s screen and reads the status again on the way back.
Future<void> _open(
  BuildContext context,
  SetupStepStatus step,
  Future<void> Function() reload,
) async {
  // #2869 — the screen it opens carries the way back to the guide.
  final pending = ProviderScope.containerOf(context, listen: false)
      .read(setupReturnPendingProvider.notifier)
    ..set(open: true);
  try {
    await context.push(step.route);
  } finally {
    pending.set(open: false);
  }
  await reload();
}

/// The milestones the space chose, each with where it stands.
class _Milestones extends StatelessWidget {
  const _Milestones({required this.status});
  final SetupStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final next = status.nextMilestone;
    return Wrap(
      key: const ValueKey('setup-guide-milestones'),
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final m in status.milestones)
          if (m.applies)
            Chip(
              key: ValueKey('setup-milestone-${m.milestone}'),
              avatar: Icon(
                m.reached
                    ? Icons.check_circle
                    : m == next
                    ? Icons.adjust
                    : Icons.radio_button_unchecked,
                size: 18,
              ),
              label: Text(
                m.reached
                    ? '${l10n.setupMilestoneName(m.milestone)} · '
                          '${l10n.setupStateName('ready')}'
                    : '${l10n.setupMilestoneName(m.milestone)} · '
                          '${l10n.setupGuideProgress(m.ready, m.required)}',
              ),
            ),
      ],
    );
  }
}

class _NextCard extends ConsumerWidget {
  const _NextCard({required this.step, required this.actions});
  final SetupStepStatus step;
  final _Actions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // #2872 — see the step done in a space where it is set up; not from
    // inside the demo itself.
    final inDemo = DemoEnvironment.maybeOf(context) != null;
    return Card(
      key: const ValueKey('setup-guide-next'),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.setupGuideNext, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.setupStepTitle(step.step),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.setupStepHint(step.step)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  l10n.setupGuideEstimate(step.estimateMinutes),
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (!inDemo)
                  TextButton(
                    key: ValueKey('setup-guide-demo-${step.step}'),
                    onPressed: () =>
                        ref.read(linkLauncherProvider)(demoLinkUri(to: step.route)),
                    child: Text(l10n.setupGuideTryDemo),
                  ),
                FilledButton(
                  key: ValueKey('setup-guide-next-${step.step}'),
                  onPressed: () => _open(context, step, actions.reload),
                  child: Text(l10n.setupGuideResume),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

/// A folded group; nothing when it holds no step.
class _Folded extends StatelessWidget {
  const _Folded({
    required this.id,
    required this.title,
    required this.steps,
    required this.actions,
    this.status,
  });

  final String id;
  final String title;
  final List<SetupStepStatus> steps;
  final _Actions actions;
  final SetupStatus? status;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      key: ValueKey('setup-guide-$id'),
      tilePadding: EdgeInsets.zero,
      title: Text('$title (${steps.length})'),
      children: [
        for (final s in steps)
          _StepTile(step: s, status: status, actions: actions),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.actions, this.status});
  final SetupStepStatus step;
  final _Actions actions;
  final SetupStatus? status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final waitsFor = step.blockedBy.isEmpty
        ? null
        : l10n.setupGuideWaitsFor(
            step.blockedBy.map(l10n.setupStepTitle).join(', '),
          );
    return ListTile(
      key: ValueKey('setup-step-${step.step}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(_icon(step.state)),
      title: Text(l10n.setupStepTitle(step.step)),
      subtitle: Text(
        [
          _stateWord(l10n, step.state),
          ?waitsFor,
          if (step.state == SetupStepState.needsConfiguration)
            l10n.setupStepHint(step.step),
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?_stepAction(l10n, step, actions),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _open(context, step, actions.reload),
    );
  }
}

/// The button for what a step offers, if anything (0545).
Widget? _stepAction(
  AppLocalizations l10n,
  SetupStepStatus step,
  _Actions actions,
) {
  final offer = SetupStepActions.offerFor(step);
  if (offer == null) return null;
  return TextButton(
    key: ValueKey('setup-step-${offer.name}-${step.step}'),
    onPressed: () => actions.act(step),
    child: Text(switch (offer) {
      SetupStepOffer.later => l10n.readinessSetAsideAction,
      SetupStepOffer.done => l10n.setupGuideMarkDone,
      SetupStepOffer.undo => l10n.readinessSetAsideUndo,
    }),
  );
}

String _stateWord(AppLocalizations l10n, SetupStepState state) =>
    l10n.setupStateName(state.name);

IconData _icon(SetupStepState state) => switch (state) {
  SetupStepState.ready => Icons.check_circle_outline,
  SetupStepState.needsConfiguration => Icons.radio_button_unchecked,
  SetupStepState.blocked => Icons.hourglass_empty,
  SetupStepState.needsOperator => Icons.dns_outlined,
  SetupStepState.notApplicable => Icons.remove_circle_outline,
  SetupStepState.deferred => Icons.schedule,
  SetupStepState.unknown => Icons.help_outline,
};

class _AllDone extends StatelessWidget {
  const _AllDone({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('setup-guide-all-done'),
    child: ListTile(
      leading: const Icon(Icons.celebration_outlined),
      title: Text(text),
    ),
  );
}
