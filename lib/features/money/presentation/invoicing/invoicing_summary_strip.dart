// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4059 — below desk width, what the invoicing home sums up is one compact
// block: the amount due, the part of it overdue, and what is to review,
// each with its count and its amounts side by side per currency (never
// added across currencies). The first records then start in the first view.
// Overdue chooses the overdue filter; To review opens the to-do list.
import 'package:flutter/material.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../application/receivables.dart';
import '../../application/receivables_answers.dart';
import 'invoicing_words.dart';

class InvoicingSummaryStrip extends StatelessWidget {
  const InvoicingSummaryStrip({
    required this.owed,
    required this.toReview,
    required this.onOverdue,
    required this.onToReview,
    required this.toReviewOpen,
    super.key,
  });

  /// What is owed, one entry per currency.
  final List<OwedInCurrency> owed;

  /// The to-dos waiting, counted.
  final int toReview;
  final VoidCallback onOverdue;
  final VoidCallback onToReview;

  /// Whether the to-do list is open under the strip.
  final bool toReviewOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context);
    Tally tally(
      int Function(OwedInCurrency o) minor,
      int Function(OwedInCurrency o) count,
    ) => Tally(owed.fold(0, (sum, o) => sum + count(o)), {
      for (final o in owed)
        if (minor(o) != 0) o.currency: minor(o),
    });
    final due = tally(
      (o) => o.totalMinor,
      (o) => o.buckets.values.fold(0, (sum, b) => sum + b.count),
    );
    final overdue = tally(
      (o) => o.buckets[OwedBucket.overdue]?.minor ?? 0,
      (o) => o.buckets[OwedBucket.overdue]?.count ?? 0,
    );
    return KitCard(
      key: const ValueKey('invoicing-summary'),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          _Cell(
            key: const ValueKey('invoicing-summary-due'),
            label: l.invoicingOwed,
            count: l.invoicingInvoiceCount(due.count),
            amounts: amountsOf(format, due),
          ),
          _Cell(
            key: const ValueKey('invoicing-summary-overdue'),
            label: l.invoicingOwedOverdue,
            count: l.invoicingInvoiceCount(overdue.count),
            amounts: amountsOf(format, overdue),
            onTap: overdue.count == 0 ? null : onOverdue,
          ),
          _Cell(
            key: const ValueKey('invoicing-summary-review'),
            label: l.invoicingTodo,
            count: l.invoicingSummaryToReview(toReview),
            onTap: toReview == 0 ? null : onToReview,
            open: toReviewOpen,
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.count,
    this.amounts = '',
    this.onTap,
    this.open,
    super.key,
  });

  final String label;
  final String count;
  final String amounts;
  final VoidCallback? onTap;

  /// For a cell that opens something below: whether it is open.
  final bool? open;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          if (amounts.isNotEmpty)
            Text(amounts, style: theme.textTheme.titleSmall),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(count, style: theme.textTheme.bodySmall),
              if (open case final isOpen?)
                Icon(isOpen ? Icons.expand_less : Icons.expand_more, size: 18),
            ],
          ),
        ],
      ),
    );
    final tap = onTap;
    return tap == null
        ? body
        : InkWell(
            onTap: tap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: body,
            ),
          );
  }
}
