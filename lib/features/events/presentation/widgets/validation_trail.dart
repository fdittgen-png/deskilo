// SPDX-License-Identifier: 0BSD
//
// #841 — who decided, in what order, and when.
//
// Decisions were recorded from the start and shown in exactly one place:
// the alerts feed, as unlabelled rows with no position and no cap. A
// member looking at an invoice could not see who released it, and a
// reader of two rows could not tell which came first.
//
// This is the one trail, used wherever the question is asked. It numbers
// each decision in the order it happened, names the person, says what
// they decided and when, and — while the event is still pending — says
// how many validations are still awaited. A rule that asks for them one
// after another (#840) labels the steps instead of numbering a list.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/event_decision.dart';

/// The ordered decision trail of one event.
class ValidationTrail extends StatelessWidget {
  const ValidationTrail({
    super.key,
    required this.decisions,
    required this.names,
    this.requiredCount = 1,
    this.pending = false,
    this.sequential = false,
    this.title,
  });

  /// In the order they happened. The repository already reads them
  /// `order('decided_at')`, and this widget sorts again rather than
  /// trust a caller that assembled them another way.
  final List<EventDecision> decisions;
  final Map<String, String> names;

  /// From the governing policy, so the trail can say what is still owed.
  final int requiredCount;
  final bool pending;

  /// #840 — a chained rule asks one step at a time, so the entries read
  /// as steps rather than as a numbered list of peers.
  final bool sequential;

  /// Set on a document, where the trail needs saying what it is. The
  /// feed omits it: the row above already says which event this is.
  final String? title;

  /// How many accepts are still owed before the event can confirm.
  int get _outstanding {
    final accepts = decisions.where((d) => d.accept).length;
    return (requiredCount - accepts).clamp(0, requiredCount);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ordered = [...decisions]
      ..sort((a, b) => a.decidedAt.compareTo(b.decidedAt));
    final awaiting = pending && _outstanding > 0;

    if (ordered.isEmpty && !awaiting) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              title!,
              style: theme.textTheme.titleSmall,
            ),
          ),
        for (final (index, decision) in ordered.indexed)
          _TrailEntry(
            key: ValueKey('validation-trail-${decision.id}'),
            decision: decision,
            order: index + 1,
            names: names,
            sequential: sequential,
          ),
        if (ordered.isEmpty)
          Text(
            l10n?.validationTrailNone ?? 'No decision yet.',
            key: const Key('validation-trail-none'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        if (awaiting)
          Padding(
            padding: EdgeInsets.only(top: ordered.isEmpty ? 0 : 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hourglass_top,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l10n?.validationTrailAwaiting(_outstanding) ??
                        'Awaiting $_outstanding more validation'
                            '${_outstanding == 1 ? '' : 's'}.',
                    key: const Key('validation-trail-awaiting'),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrailEntry extends StatelessWidget {
  const _TrailEntry({
    super.key,
    required this.decision,
    required this.order,
    required this.names,
    required this.sequential,
  });

  final EventDecision decision;
  final int order;
  final Map<String, String> names;
  final bool sequential;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = decision.memberId == null || decision.decidedBySystem
        ? (l10n?.eventSystemDecider ?? 'System')
        : (names[decision.memberId] ?? '');
    final when =
        DateFormat.MMMd().add_Hm().format(decision.decidedAt.toLocal());
    final color = decision.accept
        ? AppStatusColors.successOf(theme.brightness)
        : theme.colorScheme.error;
    final what = decision.accept
        ? (l10n?.eventValidatedBy(name, when) ?? 'Validated by $name · $when')
        : (l10n?.eventRejectedBy(name, when) ?? 'Declined by $name · $when');
    final lead = sequential
        ? (l10n?.validationTrailStep(order) ?? 'Step $order')
        : '$order.';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            lead,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          decision.accept ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(child: Text(what, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}
