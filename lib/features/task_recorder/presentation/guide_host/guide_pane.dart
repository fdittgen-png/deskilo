// SPDX-License-Identifier: AGPL-3.0-or-later
// The guide's localized step pane and clickable contents.
part of 'guide_host.dart';

class _Pane extends ConsumerWidget {
  const _Pane({
    required this.session,
    required this.run,
    required this.blocked,
    required this.targetMissing,
    required this.showSteps,
    required this.onToggleSteps,
    required this.onShowMe,
    required this.onOpenStep,
    required this.canOpenPage,
    required this.onMinimize,
  });

  final GuideSessionState session;
  final GuideRun run;
  final bool blocked;
  final bool targetMissing;
  final bool showSteps;
  final VoidCallback onToggleSteps;
  final VoidCallback? onShowMe;
  final ValueChanged<GuideStep> onOpenStep;
  final bool canOpenPage;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final text = Theme.of(context).textTheme;
    final notifier = ref.read(guideSessionProvider.notifier);
    final guide = run.guide;
    final steps = guide.steps;
    final step = run.current;
    final mainIndex = step == null
        ? steps.length
        : steps.indexWhere(
            (s) => s.id == step.id || s.recovery.any((r) => r.id == step.id),
          );
    final ended =
        run.state == GuideRunState.completed ||
        run.state == GuideRunState.stopped;
    final waiting =
        step != null && run.statusOf(step.id) == GuideStepStatus.waiting;
    final inRecovery = step != null && step.id.contains('r');

    final notices = <Widget>[
      if (ended)
        _Notice(
          'guide-host-${run.state.name}',
          run.state == GuideRunState.completed
              ? (l10n.guideHostCompleted)
              : (l10n.guideHostStopped),
        )
      else if (run.state == GuideRunState.paused)
        _Notice(
          'guide-host-paused-${session.pauseReason?.name ?? 'other'}',
          session.pauseReason == GuidePauseReason.featureOff
              ? (l10n.guideHostPausedFeature)
              : (l10n.guideHostPausedScope),
        )
      else if (blocked)
        _Notice('guide-host-blocked', l10n.guideHostBlocked),
      if (!ended && run.state == GuideRunState.running && !blocked) ...[
        if (step != null &&
            guideStepRoute(steps, step) == null &&
            onShowMe != null)
          _Notice(
            'guide-host-no-destination',
            l10n.guideHostDestinationMissing,
          ),
        if (inRecovery) _Notice('guide-host-recovery', l10n.guideHostRecovery),
        if (run.uncertain)
          _Notice('guide-host-uncertain', l10n.guideHostUncertain),
        if (waiting) _Notice('guide-host-waiting', l10n.guideHostWaiting),
        if (targetMissing && !waiting)
          _Notice('guide-host-not-on-screen', l10n.guideHostNotOnScreen),
      ],
    ];

    return Material(
      key: const ValueKey('guide-host'),
      elevation: 6,
      borderRadius: AppRadius.xlAll,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      guide.title ?? (l10n.guideHostTitle),
                      style: text.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (!ended)
                  IconButton(
                    key: const ValueKey('guide-host-minimize'),
                    tooltip: l10n.guideHostMinimize,
                    icon: const Icon(Icons.minimize_rounded),
                    onPressed: onMinimize,
                  ),
                if (ended)
                  IconButton(
                    key: const ValueKey('guide-host-close'),
                    tooltip: l10n.guideHostClose,
                    icon: const Icon(Icons.close),
                    onPressed: notifier.close,
                  )
                else
                  IconButton(
                    key: const ValueKey('guide-host-stop'),
                    tooltip: l10n.guideHostStop,
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: notifier.stop,
                  ),
              ],
            ),
            Row(
              children: [
                if (!ended)
                  Text(
                    l10n.guideHostStepOf(
                          (mainIndex + 1).clamp(1, steps.length),
                          steps.length,
                        ),
                    key: const ValueKey('guide-host-progress'),
                    style: text.labelMedium,
                  ),
                const Spacer(),
                TextButton.icon(
                  key: const ValueKey('guide-host-steps'),
                  onPressed: onToggleSteps,
                  icon: Icon(showSteps ? Icons.expand_less : Icons.list),
                  label: Text(l10n.guideHostSteps),
                ),
              ],
            ),
            if (step != null && !ended) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  guideStepText(l10n, step),
                  key: ValueKey('guide-host-step-${step.id}'),
                  style: text.bodyLarge,
                ),
              ),
            ],
            if (step != null &&
                !ended &&
                canOpenPage &&
                guideStepRoute(steps, step) != null)
              TextButton.icon(
                key: const ValueKey('guide-host-go-to-page'),
                onPressed: blocked || run.state != GuideRunState.running
                    ? null
                    : () => onOpenStep(step),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  guideDestinationLabel(l10n, guideStepRoute(steps, step)!),
                ),
              ),
            for (final n in notices) ...[
              const SizedBox(height: AppSpacing.xs),
              n,
            ],
            if (!ended) ...[
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: steps.isEmpty
                    ? 0
                    : steps
                              .where(
                                (s) =>
                                    run.statusOf(s.id) ==
                                        GuideStepStatus.done ||
                                    run.statusOf(s.id) ==
                                        GuideStepStatus.acknowledged,
                              )
                              .length /
                          steps.length,
              ),
            ],
            if (showSteps)
              _StepList(
                run: run,
                onOpen:
                    run.state == GuideRunState.running && !waiting && !blocked
                    ? onOpenStep
                    : null,
              ),
            if (!ended) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.end,
                children: [
                  if (run.state == GuideRunState.paused)
                    FilledButton(
                      key: const ValueKey('guide-host-resume'),
                      onPressed: notifier.resume,
                      child: Text(l10n.guideHostResume),
                    )
                  else ...[
                    TextButton(
                      key: const ValueKey('guide-host-back'),
                      onPressed: mainIndex > 0 && !waiting
                          ? notifier.back
                          : null,
                      child: Text(l10n.guideHostBack),
                    ),
                    if (step != null && !waiting)
                      TextButton(
                        key: const ValueKey('guide-host-skip'),
                        onPressed: notifier.skip,
                        child: Text(l10n.guideHostSkip),
                      ),
                    if (!blocked)
                      FilledButton.icon(
                        key: const ValueKey('guide-host-show-me'),
                        onPressed: onShowMe,
                        icon: const Icon(Icons.near_me_outlined),
                        label: Text(l10n.guideHostShowMe),
                      ),
                    if (step != null && step.kind != GuideStepKind.perform)
                      FilledButton(
                        key: const ValueKey('guide-host-done'),
                        onPressed: notifier.acknowledge,
                        child: Text(l10n.guideHostDone),
                      ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.id, this.text);

  final String id;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: ValueKey(id),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
      ),
    );
  }
}

/// Every step and its status, readable by a screen reader.
class _StepList extends StatelessWidget {
  const _StepList({required this.run, this.onOpen});

  final GuideRun run;
  final ValueChanged<GuideStep>? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    String status(GuideStepStatus s) => switch (s) {
      GuideStepStatus.pending => l10n.guideHostStatusPending,
      GuideStepStatus.waiting => l10n.guideHostStatusWaiting,
      GuideStepStatus.done => l10n.guideHostStatusDone,
      GuideStepStatus.acknowledged => l10n.guideHostStatusAcknowledged,
      GuideStepStatus.skipped => l10n.guideHostStatusSkipped,
    };
    final current = run.current?.id;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView(
        key: const ValueKey('guide-host-step-list'),
        shrinkWrap: true,
        children: [
          for (final s in run.guide.steps)
            ListTile(
              key: ValueKey('guide-host-list-${s.id}'),
              dense: true,
              onTap: onOpen == null ? null : () => onOpen!(s),
              leading: CircleAvatar(
                radius: 14,
                child: Text('${run.guide.steps.indexOf(s) + 1}'),
              ),
              subtitle: Text(
                (guideStepRoute(run.guide.steps, s) == null
                        ? null
                        : guideDestinationLabel(
                            l10n,
                            guideStepRoute(run.guide.steps, s)!,
                          )) ??
                    (l10n.guideHostDestinationMissing),
              ),
              selected: s.id == current,
              title: Text(
                guideStepText(l10n, s),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Tooltip(
                message: status(run.statusOf(s.id)),
                child: Icon(
                  run.statusOf(s.id) == GuideStepStatus.done ||
                          run.statusOf(s.id) == GuideStepStatus.acknowledged
                      ? Icons.check_circle_outline
                      : Icons.open_in_new,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
