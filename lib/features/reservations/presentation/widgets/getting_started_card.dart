// SPDX-License-Identifier: AGPL-3.0-or-later
// #1654: render the hub's facts and one optional action; never submit a task.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_hint_providers.dart';
import '../../../../core/help/help_tips.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/getting_started_hint.dart';
import '../getting_started_copy.dart';

/// Restore only the dismissal for the immutable scope rendered by the hub.
VoidCallback? gettingStartedReopen(WidgetRef ref, String? key) {
  final dismissed = ref.watch(dismissedHelpHintsProvider).value;
  if (key == null || dismissed == null || !dismissed.contains(key)) return null;
  return () => ref.read(dismissedHelpHintsProvider.notifier).restore(key);
}

class GettingStartedCard extends ConsumerWidget {
  const GettingStartedCard({
    required this.facts,
    required this.seenKey,
    required this.onChooseTime,
    super.key,
  });

  final GettingStartedFacts facts;
  final String? seenKey;

  /// The hub's own date picker — the existing way to choose a time.
  final VoidCallback onChooseTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seenKey = this.seenKey;
    final dismissed = ref.watch(dismissedHelpHintsProvider).value;
    if (dismissed == null) return const SizedBox.shrink();
    final hint = chooseGettingStartedHint(facts,
      dismissed: seenKey == null || dismissed.contains(seenKey));
    if (hint == null || !hint.showsCard) return const SizedBox.shrink();

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
