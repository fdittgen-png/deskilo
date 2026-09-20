// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/decide_event.dart';
import '../../domain/event_decision.dart';
import '../../domain/validation_policy.dart';
import '../../domain/workspace_event.dart';
import '../../providers/event_providers.dart';
import '../event_lines.dart';
import 'validation_trail.dart';

/// "Waiting for your confirmation": the decisions pinned for this member,
/// one compact row each, deciding in one tap (#440).
///
/// #1306 — extracted from the events face so the calendar can carry the
/// same section when a workspace switches the events bell off: the
/// decision signal must survive the bell, and one row layout means one
/// wording and one decide path wherever the question is asked.
class PendingDecisionsSection extends ConsumerWidget {
  const PendingDecisionsSection({super.key, required this.pending});

  /// The events this member is asked to decide, in the caller's order.
  final List<WorkspaceEvent> pending;

  Future<void> _decide(BuildContext context, WidgetRef ref,
      WorkspaceEvent event, bool accept) async {
    final l10n = AppLocalizations.of(context);
    final reason = await decideEvent(ref, event.id, accept: accept);
    if (reason == null || !context.mounted) return;
    final base = l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.';
    AppSnack.error(context, reason.isEmpty ? base : '$base\n$reason');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final targets = ref.watch(targetNamesProvider).value ?? const {};
    final decisions = ref.watch(eventDecisionsProvider).value ??
        const <String, List<EventDecision>>{};
    final policies =
        ref.watch(validationPoliciesProvider).value ?? const <ValidationPolicy>[];
    final currency = moneyFormat(
        ref.watch(currentWorkspaceProvider).value?.currencyCode ?? 'EUR');
    final format = ref.watch(appFormatProvider);
    return Column(
      key: const ValueKey('pending-decisions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Text(
          l10n?.eventsPendingHeader ??
              'Waiting for your confirmation',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      // #440: one COMPACT row per pending decision — message,
      // one metadata line (time · quorum), actions inline on
      // the trailing edge. The old layout spent ~300px per
      // card on a full-width button row of dead space.
      for (final event in pending)
        Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventLine(l10n, event, names, targets, currency),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        switch (eventQuorumProgress(
                          l10n,
                          event,
                          decisions[event.id] ?? const [],
                          policies,
                        )) {
                          final progress? =>
                            '${eventWhen(event, format)} · $progress',
                          null => eventWhen(event, format),
                        },
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                      // #841 — one ordered, numbered trail
                      // everywhere the question is asked.
                      // The quorum line still says how many
                      // are owed, so the trail does not
                      // repeat it here.
                      ValidationTrail(
                        decisions:
                            decisions[event.id] ?? const [],
                        names: names,
                        sequential: policyFor(
                                event.type.dbName, policies)
                            .sequential,
                      ),
                    ],
                  ),
                ),
                // #196 semantic colors kept: decline red,
                // accept green. Decline is an icon (48dp,
                // tooltip); Accept keeps its word — a money
                // decision deserves a labeled button.
                IconButton(
                  tooltip: l10n?.eventReject ?? 'Decline',
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () => _decide(context, ref, event, false),
                  icon: const Icon(Icons.close),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppStatusColors.successOf(
                      Theme.of(context).brightness,
                    ),
                    foregroundColor:
                        AppStatusColors.onSuccessOf(
                      Theme.of(context).brightness,
                    ),
                  ),
                  onPressed: () => _decide(context, ref, event, true),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(l10n?.eventAccept ?? 'Accept'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
