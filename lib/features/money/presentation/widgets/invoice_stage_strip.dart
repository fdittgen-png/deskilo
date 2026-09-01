// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../domain/dunning.dart';
import '../../providers/money_providers.dart';
import '../invoice_journey.dart';
import '../invoice_status.dart';

/// #812 — the issuers' process at a glance: the four stages of the
/// journey as tiles with live counts. Each tile is one tap from the tab
/// that holds its work: To issue → the To-invoice tab, To collect and To
/// confirm → the Open tab, Closed → the archive.
class InvoiceStageStrip extends ConsumerWidget {
  const InvoiceStageStrip({
    super.key,
    required this.currency,
    required this.onStage,
  });

  final MoneyFormat currency;

  /// Jumps to the hub tab (0 to invoice, 1 open, 2 archive).
  final void Function(int tab) onStage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(invoicingOverviewProvider).value;
    final invoices = ref.watch(invoicesProvider).value;
    if (overview == null || invoices == null) return const SizedBox.shrink();
    final matches = ref.watch(invoiceMatchesProvider).value ?? const {};
    final reminders = ref.watch(invoiceRemindersProvider).value ?? const {};
    final rules = ref.watch(dunningRulesProvider).value ?? DunningRules.defaults;
    final events = ref.watch(eventsProvider).value ?? const [];
    final now = ref.watch(clockProvider).now();
    final journeys = [
      for (final entry in overview.open)
        InvoiceJourney.of(
          invoice: entry.invoice,
          match: matches[entry.invoice.id],
          reminder: reminders[entry.invoice.id],
          rules: rules,
          now: now,
          facts: journeyFactsOf(entry.invoice, matches[entry.invoice.id], events),
        ),
    ];
    var closed = 0;
    for (final invoice in invoices) {
      if (switch (invoiceLifecycleOf(invoice, matches[invoice.id])) {
        InvoiceLifecycle.paid ||
        InvoiceLifecycle.remainderCancelled ||
        InvoiceLifecycle.refunded ||
        InvoiceLifecycle.erroneous =>
          true,
        _ => false,
      }) {
        closed++;
      }
    }
    final counts = stageCountsOf(
      toIssue: overview.toInvoice.length,
      open: journeys,
      closed: closed,
    );
    final tiles = [
      _StageTile(
        key: const ValueKey('invoice-stage-issue'),
        index: 1,
        label: l10n?.journeyStageIssue ?? 'To issue',
        count: counts.toIssue,
        onTap: () => onStage(0),
      ),
      _StageTile(
        key: const ValueKey('invoice-stage-collect'),
        index: 2,
        label: l10n?.journeyStageCollect ?? 'To collect',
        count: counts.toCollect,
        detail: counts.toCollect == 0
            ? null
            : (l10n?.journeyOutstanding(
                    currency.formatMinor(counts.toCollectCents)) ??
                '${currency.formatMinor(counts.toCollectCents)} outstanding'),
        alert: counts.overdue == 0
            ? null
            : (l10n?.journeyOverdueCount(counts.overdue) ??
                '${counts.overdue} overdue'),
        onTap: () => onStage(1),
      ),
      _StageTile(
        key: const ValueKey('invoice-stage-confirm'),
        index: 3,
        label: l10n?.journeyStageConfirm ?? 'To confirm',
        count: counts.toConfirm,
        onTap: () => onStage(1),
      ),
      _StageTile(
        key: const ValueKey('invoice-stage-closed'),
        index: 4,
        label: l10n?.journeyStageClosed ?? 'Closed',
        count: counts.closed,
        onTap: () => onStage(2),
      ),
    ];
    return Semantics(
      label: l10n?.journeyStageStripLabel ??
          'The invoicing process: issue, collect, confirm, close',
      child: Padding(
        key: const ValueKey('invoicing-summary'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
        child: Row(children: [
          for (final (i, tile) in tiles.indexed) ...[
            if (i > 0)
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            Expanded(child: tile),
          ],
        ]),
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({
    super.key,
    required this.index,
    required this.label,
    required this.count,
    required this.onTap,
    this.detail,
    this.alert,
  });

  final int index;
  final String label;
  final int count;
  final String? detail;

  /// The red line (overdue) — it also tints the tile.
  final String? alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = count > 0;
    final background = alert != null
        ? scheme.errorContainer
        : active
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest;
    final foreground = alert != null
        ? scheme.onErrorContainer
        : active
            ? scheme.onSecondaryContainer
            : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.mdAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$index · $label',
              style: theme.textTheme.labelSmall?.copyWith(color: foreground),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$count',
              style: theme.textTheme.titleMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (detail != null)
              Text(
                detail!,
                style: theme.textTheme.labelSmall?.copyWith(color: foreground),
                overflow: TextOverflow.ellipsis,
              ),
            if (alert != null)
              Text(
                alert!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
