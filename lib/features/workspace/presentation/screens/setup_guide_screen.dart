// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3282 — one saved readiness model: workspace, chosen goal, remaining
// work and a recommended action. Waiting and unavailable checks remain
// visible even when the owner cannot act. Other outcomes and optional work
// are disclosed separately; completion never removes the navigation entry.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/demo_link.dart';
import '../../../../core/demo/presentation/demo_entry_sheet.dart';
import '../../../../core/demo/presentation/demo_environment.dart';
import '../../../../core/demo/presentation/demo_setup_card.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/kit/page_bar.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/dictionary_labels.dart';
import '../../application/setup_step_actions.dart';
import '../../domain/setup_status.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';
import '../setup_step_words.dart';
import '../widgets/sample_data_card.dart';
import '../widgets/setup_advanced_settings.dart';
import '../widgets/setup_configuration_overview.dart';
import '../widgets/setup_guide_progress.dart';
import '../widgets/setup_no_invoicing_banner.dart';
import '../widgets/setup_return_bar.dart';

class SetupGuideScreen extends ConsumerWidget {
  const SetupGuideScreen({super.key, this.listBeside = false});

  /// #3629 — the steps are listed beside this page (the desk): it keeps
  /// where the space stands and the next step, not the step lists.
  final bool listBeside;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider);
    return Scaffold(
      appBar: pageBar(context, title: l10n.setupGuideTitle),
      body: switch (workspace) {
        AsyncData(:final value) when value != null => _SetupGuideBody(
          workspaceId: value.id,
          workspaceName: value.name,
          listBeside: listBeside,
        ),
        AsyncError() || AsyncData() => ListView(
          children: [
            InlineBanner(
              key: const ValueKey('setup-guide-workspace-unavailable'),
              icon: Icons.cloud_off_outlined,
              text: l10n.setupGuideUnavailable,
              actionLabel: MaterialLocalizations.of(context)
                  .refreshIndicatorSemanticLabel,
              onAction: () => ref.invalidate(currentWorkspaceProvider),
            ),
          ],
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _SetupGuideBody extends ConsumerWidget {
  const _SetupGuideBody({
    required this.workspaceId,
    required this.workspaceName,
    required this.listBeside,
  });
  final String workspaceId;
  final String workspaceName;
  final bool listBeside;

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
            SetupConfigurationOverview(
              workspaceName: workspaceName,
              status: value,
              onChoose: () => _openLevels(context, reload),
            ),
            const SizedBox(height: AppSpacing.md),
            if (value.nextMilestone case final next?
                when value.toDo.isNotEmpty &&
                    value.toDo.every(
                      (s) => s.state == SetupStepState.needsConfiguration,
                    )) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.setupGuideUntil(
                  value.toNextMilestone.low,
                  value.toNextMilestone.high,
                  l10n.setupMilestoneName(next.milestone),
                ),
                key: const ValueKey('setup-guide-until'),
              ),
            ],
            ..._sections(context, value, actions),
            ExpansionTile(
              key: const ValueKey('setup-outcome-details'),
              title: Text(l10n.setupOutcomeProgress),
              children: [SetupGuideMilestones(status: value)],
            ),
            const SetupAdvancedSettings(),
            SetupNoInvoicingBanner(reload: reload),
            // #2876 — check the answers and go live.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('setup-guide-launch'),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(l10n.setupLaunchLink),
                onPressed: () async {
                  await context.push('/setup/launch');
                  await reload();
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SampleDataCard(workspaceId: workspaceId),
            const DemoSetupCard(),
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
    if (status.nextMilestone == null && status.goal != null) {
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
        SetupGuideAddMore(
          steps: status.addable,
          onAdd: () => _openLevels(context, actions.reload),
        ),
      ];
    }
    return [
      if (next != null) ...[
        if (!status.toDo.contains(next) && status.toDo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(l10n.setupNextIndependent),
          ),
        _NextCard(step: next, actions: actions),
      ] else if (status.nextMilestone != null)
        InlineBanner(
          key: const ValueKey('setup-guide-waiting-summary'),
          icon: Icons.pending_actions,
          text: status.toDo.any((s) => s.state == SetupStepState.unknown)
              ? l10n.setupOverviewUnchecked
              : l10n.setupOverviewWaiting,
          actionLabel: MaterialLocalizations.of(context)
              .refreshIndicatorSemanticLabel,
          onAction: actions.reload,
        ),
      // #3629 — beside the steps on the desk, the lists are those steps.
      if (!listBeside) ..._lists(l10n, status, next, actions),
      SetupGuideAddMore(
        steps: status.addable,
        onAdd: () => _openLevels(context, actions.reload),
      ),
    ];
  }

  /// The steps by where they stand, the next one left out: what is to do,
  /// then folded what waits, comes later, could be added, is set aside, is
  /// done.
  List<Widget> _lists(
    AppLocalizations l10n,
    SetupStatus status,
    SetupStepStatus? next,
    _Actions actions,
  ) {
    final toDo = [
      for (final s in status.toDo)
        if (s != next) s,
    ];
    return [
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
      for (final (id, title, steps) in [
        ('later', l10n.setupGuideLater, status.later),
        ('optional', l10n.setupGuideOptional, status.optional),
        ('deferred', l10n.setupGuideDeferred, status.deferred),
        ('done', l10n.setupGuideDone, status.done),
      ])
        _Folded(
          id: id,
          title: title,
          steps: [
            for (final s in steps)
              if (s != next) s,
          ],
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
  final container = ProviderScope.containerOf(context, listen: false);
  final pending = container.read(setupReturnPendingProvider.notifier)
    ..set(open: true);
  container.read(setupOpenStepProvider.notifier).set(step.step);
  try {
    await context.push(step.route);
  } finally {
    pending.set(open: false);
  }
  await reload();
}

/// #2868 — the levels screen: what the space does decides which steps
/// there are. The guide reads again on the way back.
Future<void> _openLevels(
  BuildContext context,
  Future<void> Function() reload,
) async {
  await context.push('/setup/levels');
  await reload();
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
    // #3235 — and only where the demo is switched on.
    final demoOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.demoMode);
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
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.setupGuideEstimate(
                    step.estimate.low,
                    step.estimate.high,
                  ),
                  key: const ValueKey('setup-guide-estimate'),
                  style: theme.textTheme.bodySmall,
                ),
                if (!inDemo && demoOn)
                  TextButton(
                    key: ValueKey('setup-guide-demo-${step.step}'),
                    onPressed: () => offerDemoEntry(
                      context,
                      ref,
                      link: DemoLink.example(to: step.route),
                    ),
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
      leading: Icon(setupStepIcon(step.state)),
      title: Text(l10n.setupStepTitle(step.step)),
      subtitle: Text(
        [
          setupStepWord(l10n, step),
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
