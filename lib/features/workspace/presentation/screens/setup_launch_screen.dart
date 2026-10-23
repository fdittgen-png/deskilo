// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2876 — check the answers and go live. The milestones the space chose,
// each with the steps that are its evidence; every answer by group with a
// Change link; what is public; what only the operator can do, to forward;
// and going live: possible only when every milestone is reached, named
// step by step when it is not, and confirmed with its consequences before
// the deployment screen copies anything to the real twin.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/launch_review.dart';
import '../../domain/setup_status.dart';
import '../../domain/workspace.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';
import '../launch_report.dart';

class SetupLaunchScreen extends ConsumerWidget {
  const SetupLaunchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupLaunchTitle)),
      body: workspace == null
          ? const LoadingView()
          : _LaunchBody(workspace: workspace),
    );
  }
}

class _LaunchBody extends ConsumerWidget {
  const _LaunchBody({required this.workspace});
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(workspaceSetupStatusProvider(workspace.id));
    Future<void> open(String route) async {
      await context.push(route);
      ref.invalidate(workspaceSetupStatusProvider(workspace.id));
    }

    return switch (status) {
      AsyncData(:final value) => _review(
        context,
        LaunchReview.from(value),
        value,
        open,
      ),
      AsyncError() => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: InlineBanner(
          icon: Icons.error_outline,
          text: l10n.setupGuideUnavailable,
        ),
      ),
      _ => const LoadingView(),
    };
  }

  Widget _review(
    BuildContext context,
    LaunchReview review,
    SetupStatus status,
    Future<void> Function(String) open,
  ) {
    final l10n = context.l10n;
    final public = status.steps.any(
      (s) => s.step == 'public_page' && s.state == SetupStepState.ready,
    );
    return ListView(
      key: const ValueKey('setup-launch-list'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _GoLive(workspace: workspace, review: review, open: open),
        const SizedBox(height: AppSpacing.md),
        _Heading(l10n.setupLaunchMilestones),
        for (final m in review.milestones) _MilestoneTile(milestone: m),
        if (review.operatorTasks.isNotEmpty) _OperatorTasks(review: review),
        const SizedBox(height: AppSpacing.md),
        Text(
          public ? l10n.setupLaunchPublicOn : l10n.setupLaunchPublicOff,
          key: const ValueKey('setup-launch-public'),
        ),
        const SizedBox(height: AppSpacing.md),
        _Heading(l10n.setupLaunchAnswers),
        for (final g in review.groups) ...[
          Text(
            l10n.setupLaunchGroup(g.group.name),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final s in g.steps)
            _AnswerTile(
              step: s,
              actionLabel: l10n.setupLaunchChange,
              keyPrefix: 'setup-launch-change',
              open: open,
            ),
        ],
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('setup-launch-report'),
            icon: const Icon(Icons.copy),
            label: Text(l10n.setupLaunchReport),
            onPressed: () => _copy(context, launchReportText(l10n, review)),
          ),
        ),
      ],
    );
  }
}

Future<void> _copy(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.of(context);
  final copied = context.l10n.setupLaunchCopied;
  await Clipboard.setData(ClipboardData(text: text));
  messenger.showSnackBar(SnackBar(content: Text(copied)));
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Going live: the blockers when it cannot, the button when it can.
class _GoLive extends StatelessWidget {
  const _GoLive({
    required this.workspace,
    required this.review,
    required this.open,
  });

  final Workspace workspace;
  final LaunchReview review;
  final Future<void> Function(String) open;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!review.canGoLive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineBanner(
            key: const ValueKey('setup-launch-blocked'),
            icon: Icons.block,
            severity: InlineBannerSeverity.info,
            text: review.blockers.isEmpty
                ? l10n.setupLaunchCannot
                : l10n.setupLaunchBlockers,
          ),
          for (final s in review.blockers)
            _AnswerTile(
              step: s,
              actionLabel: l10n.setupLaunchFix,
              keyPrefix: 'setup-launch-fix',
              open: open,
            ),
        ],
      );
    }
    // A real space that reached every milestone is live already.
    if (!workspace.isDevelopment) {
      return Text(
        l10n.setupLaunchIsLive,
        key: const ValueKey('setup-launch-state'),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: FilledButton.icon(
        key: const ValueKey('setup-launch-go-live'),
        icon: const Icon(Icons.rocket_launch),
        label: Text(l10n.setupLaunchGoLive),
        onPressed: () async {
          if (await _confirmGoLive(context, l10n)) await open('/deployment');
        },
      ),
    );
  }
}

Future<bool> _confirmGoLive(
  BuildContext context,
  AppLocalizations l10n,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('setup-launch-confirm'),
        title: Text(l10n.setupLaunchGoLiveTitle),
        content: Text(l10n.setupLaunchGoLiveBody),
        actions: [
          TextButton(
            key: const ValueKey('setup-launch-confirm-no'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('setup-launch-confirm-yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.setupLaunchGoLiveConfirm),
          ),
        ],
      ),
    ) ??
    false;

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.milestone});
  final LaunchMilestone milestone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final m = milestone.status;
    return ListTile(
      key: ValueKey('setup-launch-milestone-${m.milestone}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(m.reached ? Icons.check_circle : Icons.pending_outlined),
      title: Text(
        '${l10n.setupMilestoneName(m.milestone)} — '
        '${m.reached ? l10n.setupLaunchReached : l10n.setupGuideProgress(m.ready, m.required)}',
      ),
      subtitle: Text(
        milestone.evidence
            .map(
              (s) =>
                  '${l10n.setupStepTitle(s.step)}: '
                  '${l10n.setupStateName(s.state.name)}',
            )
            .join('\n'),
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.step,
    required this.actionLabel,
    required this.keyPrefix,
    required this.open,
  });

  final SetupStepStatus step;
  final String actionLabel;
  final String keyPrefix;
  final Future<void> Function(String) open;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.setupStepTitle(step.step)),
      subtitle: Text(l10n.setupStateName(step.state.name)),
      trailing: TextButton(
        key: ValueKey('$keyPrefix-${step.step}'),
        onPressed: () => open(step.route),
        child: Text(actionLabel),
      ),
    );
  }
}

class _OperatorTasks extends StatelessWidget {
  const _OperatorTasks({required this.review});
  final LaunchReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = launchOperatorText(l10n, review);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(text, key: const ValueKey('setup-launch-operator')),
            TextButton.icon(
              key: const ValueKey('setup-launch-copy-operator'),
              icon: const Icon(Icons.copy),
              label: Text(l10n.setupLaunchCopyOperator),
              onPressed: () => _copy(context, text),
            ),
          ],
        ),
      ),
    );
  }
}
