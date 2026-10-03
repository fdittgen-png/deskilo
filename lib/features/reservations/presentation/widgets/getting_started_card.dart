// SPDX-License-Identifier: AGPL-3.0-or-later
// #1654: render the hub's facts and one optional action; never submit a task.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_arbiter.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/help/help_hint_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/local_setup_providers.dart';
import '../../application/getting_started_hint.dart';
import '../getting_started_copy.dart';

/// Restore only the dismissal for the immutable scope rendered by the hub.
VoidCallback? gettingStartedReopen(WidgetRef ref, String? key) {
  final dismissed = ref.watch(dismissedHelpHintsProvider).value;
  if (key == null || dismissed == null || !dismissed.contains(key)) return null;
  return () => ref.read(dismissedHelpHintsProvider.notifier).restore(key);
}

/// The hint the Get started card would show now, or null when it shows
/// nothing (flag off, dismissed, still loading, or no card for these
/// facts). The card and [ReserveHelpHost] ask the same question.
GettingStartedHint? visibleGettingStartedHint(
  WidgetRef ref, {
  required GettingStartedFacts facts,
  required String? seenKey,
  String? workspaceId,
}) {
  final dismissed = ref.watch(dismissedHelpHintsProvider).value;
  if (dismissed == null) return null;
  final standing = facts.membership.known ? facts.membership.value : null;
  // Only someone who may configure the space asks; a refusal reads as
  // no answer, and no answer guides nobody.
  final readiness = workspaceId != null &&
          (standing == MembershipStanding.owner ||
              standing == MembershipStanding.administrator)
      ? ref.watch(workspaceReadinessProvider(workspaceId)).value
      : null;
  final hint = chooseGettingStartedHint(facts,
      dismissed: seenKey == null || dismissed.contains(seenKey),
      ownerGuidance: readinessGuidance(readiness));
  return hint != null && hint.showsCard ? hint : null;
}

/// #1853 A — the Reserve hub's ONE help slot. The Get started card names
/// the current next step, so it outranks the generic tip carousel; the
/// carousel takes the slot only when there is no next step to show.
/// Each keeps its own flag and its own dismissal key — nothing is merged
/// or re-enabled — and the two never render together.
class ReserveHelpHost extends ConsumerWidget {
  const ReserveHelpHost({
    required this.facts,
    required this.seenKey,
    required this.onChooseTime,
    this.workspaceId,
    super.key,
  });

  final GettingStartedFacts facts;
  final String? seenKey;
  final VoidCallback onChooseTime;
  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = visibleGettingStartedHint(ref,
        facts: facts, seenKey: seenKey, workspaceId: workspaceId);
    if (next == null) return const HelpHint(HelpHintId.reserve);
    return GettingStartedCard(
      facts: facts,
      seenKey: seenKey,
      onChooseTime: onChooseTime,
      workspaceId: workspaceId,
    );
  }
}

class GettingStartedCard extends ConsumerWidget {
  const GettingStartedCard({
    required this.facts,
    required this.seenKey,
    required this.onChooseTime,
    this.workspaceId,
    super.key,
  });

  /// #1636 — whose readiness an owner or administrator is guided by.
  final String? workspaceId;

  final GettingStartedFacts facts;
  final String? seenKey;

  /// The hub's own date picker — the existing way to choose a time.
  final VoidCallback onChooseTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seenKey = this.seenKey;
    final hint = visibleGettingStartedHint(ref,
        facts: facts, seenKey: seenKey, workspaceId: workspaceId);
    if (hint == null) return const SizedBox.shrink();
    // #1867 — a guide step or a blocker outranks the next-step advice.
    if (ref.watch(helpSlotProvider) != HelpSlot.tips) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final title =
        l10n?.gettingStartedTitle(facts.workspaceName) ??
        'Get started in ${facts.workspaceName}';
    final environment = !facts.production
        ? (l10n?.gettingStartedEnvDev ?? 'Development workspace')
        : (l10n?.gettingStartedEnvProd ?? 'Production workspace');
    final lines = <String>[
      if (hint.standing != null) GettingStartedCopy.standing(l10n, hint.standing!),
      GettingStartedCopy.reason(l10n, hint),
      if (hint.allowance != null)
        l10n?.gettingStartedAllowance(hint.allowance!) ??
            'You may hold ${hint.allowance} bookings at a time.',
    ];
    final (String actionLabel, VoidCallback onAction) = switch (hint.action!) {
      GettingStartedAction.chooseTime => (
        hint.reason == GettingStartedReason.closedToday
            ? (l10n?.gettingStartedActionChooseDay ?? 'Choose another day')
            : (l10n?.gettingStartedActionChooseTime ?? 'Choose a time to book'),
        onChooseTime,
      ),
      GettingStartedAction.viewMembership => (
        l10n?.gettingStartedActionMembership ?? 'View my membership',
        () => context.push('/settings'),
      ),
      GettingStartedAction.finishSetup => (
        l10n?.gettingStartedActionFinishSetup ?? 'Finish setting up',
        () => context.push(hint.setupStep?.route ?? '/workspace-settings'),
      ),
      GettingStartedAction.openHelp => (
        l10n?.gettingStartedActionHelp ?? 'Help for this workspace',
        () => context.push(
          Uri(
            path: '/help',
            queryParameters: {'topic': helpHintTopic(l10n, HelpHintId.reserve)},
          ).toString(),
        ),
      ),
    };

    return Semantics(
      container: true,
      label:
          l10n?.gettingStartedSemantics ??
          'Get started: one suggested next step',
      child: Card(
        key: const ValueKey('getting-started-card'),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Semantics(
                      container: true,
                      header: true,
                      child: Text(
                        title,
                        key: const ValueKey('getting-started-title'),
                        style: textTheme.titleSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                environment,
                key: const ValueKey('getting-started-environment'),
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                lines.join(' '),
                key: const ValueKey('getting-started-text'),
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
              if (hint.booking != null)
                Text(
                  GettingStartedCopy.booking(l10n, hint.booking!),
                  key: const ValueKey('getting-started-booking'),
                  style: textTheme.bodySmall?.emphasised.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              // A Wrap, not a Row: at 360 dp with large text the two
              // buttons stack rather than overflow, and each keeps its
              // 48 dp target.
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                children: [
                  TextButton(
                    key: const ValueKey('getting-started-dismiss'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        kMinInteractiveDimension,
                        kMinInteractiveDimension,
                      ),
                    ),
                    onPressed: seenKey == null
                        ? null
                        : () => ref
                              .read(dismissedHelpHintsProvider.notifier)
                              .dismiss(seenKey),
                    child: Text(l10n?.gettingStartedNotNow ?? 'Not now'),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey('getting-started-primary'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(
                        kMinInteractiveDimension,
                        kMinInteractiveDimension,
                      ),
                    ),
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
