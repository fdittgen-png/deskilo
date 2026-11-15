// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4059 — below desk width, what the invoicing home sums up is one compact
// block: the amount due, the part of it to confirm, the part overdue, and
// what is to do, each with its count and its amounts side by side per
// currency (never added across currencies). The first records then start in
// the first view. Amount due clears the filter, To confirm and Overdue
// choose theirs, To do opens the to-do list under the strip. Where four
// cells do not fit one row they wrap to two rows of two: no text shrinks
// and no label is cut. Not by the window's height: a layout that follows the
// height would change while the list loads.
import 'package:flutter/material.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../application/receivables.dart';
import '../../application/receivables_answers.dart';
import 'invoicing_list.dart';
import 'invoicing_words.dart';

/// The narrowest a cell is laid out at: a label and an amount on a line.
// content-fit: "Amount due" and a five-figure amount at text 1.0
const double _cellMin = 150;

class InvoicingSummaryStrip extends StatefulWidget {
  const InvoicingSummaryStrip({
    required this.owed,
    required this.toDo,
    required this.filter,
    required this.onFilter,
    required this.toDoCard,
    required this.monthFigures,
    super.key,
  });

  /// The month's figures (invoiced, and received when it was read), as the
  /// debt card says them: one plain line under the cells.
  final List<({String label, List<String> values})> monthFigures;

  /// What is owed, one entry per currency.
  final List<OwedInCurrency> owed;

  /// The to-dos waiting, counted.
  final int toDo;

  /// The list's filter now: its cell is marked.
  final InvoicingFilter filter;
  final ValueChanged<InvoicingFilter> onFilter;

  /// The to-do list, shown under the strip while its cell is open.
  final Widget toDoCard;

  @override
  State<InvoicingSummaryStrip> createState() => _InvoicingSummaryStripState();
}

class _InvoicingSummaryStripState extends State<InvoicingSummaryStrip> {
  /// Whether the to-do list is open under the strip.
  bool _toDoOpen = false;

  List<OwedInCurrency> get owed => widget.owed;

  Tally _tally(OwedBucket? bucket) => Tally(
    owed.fold(
      0,
      (sum, o) =>
          sum +
          (bucket == null
              ? o.buckets.values.fold(0, (s, b) => s + b.count)
              : o.buckets[bucket]?.count ?? 0),
    ),
    {
      for (final o in owed)
        if (bucket == null ? o.totalMinor : o.buckets[bucket]?.minor ?? 0
            case final minor when minor != 0)
          o.currency: minor,
    },
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context);
    Widget money(String key, String label, OwedBucket? bucket) {
      final tally = _tally(bucket);
      final own = bucket == null
          ? InvoicingFilter.open
          : InvoicingFilter.of(bucket);
      return _Cell(
        key: ValueKey('invoicing-summary-$key'),
        id: key,
        label: label,
        count: l.invoicingInvoiceCount(tally.count),
        countKey: ValueKey('invoicing-summary-$key-count-${tally.count}'),
        amounts: amountsOf(format, tally),
        selected: widget.filter == own,
        onTap: () => widget.onFilter(own),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KitCard(
          key: const ValueKey('invoicing-summary'),
          child: LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 4 * _cellMin + 3 * AppSpacing.sm
                  ? 4
                  : 2;
              final width =
                  (box.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
              final cells = Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final cell in [
                    money('due', l.invoicingOwed, null),
                    money(
                      'confirm',
                      l.journeyStageConfirm,
                      OwedBucket.toConfirm,
                    ),
                    money(
                      'overdue',
                      l.invoicingOwedOverdue,
                      OwedBucket.overdue,
                    ),
                    _Cell(
                      key: const ValueKey('invoicing-summary-review'),
                      id: 'review',
                      label: l.invoicingTodo,
                      count: l.invoicingSummaryToReview(widget.toDo),
                      selected: _toDoOpen,
                      onTap: widget.toDo == 0
                          ? null
                          : () => setState(() => _toDoOpen = !_toDoOpen),
                    ),
                  ])
                    SizedBox(width: width, child: cell),
                ],
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cells,
                  const SizedBox(height: AppSpacing.sm),
                  _MonthLine(figures: widget.monthFigures),
                ],
              );
            },
          ),
        ),
        if (_toDoOpen) ...[
          const SizedBox(height: AppSpacing.sm),
          widget.toDoCard,
        ],
      ],
    );
  }
}

/// The month's figures on one line that wraps rather than cuts, read by a
/// screen reader as one sentence; not a control.
class _MonthLine extends StatelessWidget {
  const _MonthLine({required this.figures});

  final List<({String label, List<String> values})> figures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Wrap(
        key: const ValueKey('invoicing-summary-month'),
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final f in figures) ...[
            Text(f.label, style: theme.textTheme.bodySmall),
            Text(f.values.join(' · '), style: theme.textTheme.labelLarge),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.id,
    required this.label,
    required this.count,
    required this.selected,
    this.countKey,
    this.amounts = '',
    this.onTap,
    super.key,
  });

  /// Names the cell (`invoicing-summary-<id>`) and its tap.
  final String id;
  final String label;
  final String count;

  /// The count's key, which names the number it says.
  final Key? countKey;
  final String amounts;

  /// Marked by a check and a border, and announced as selected.
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: Material(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('invoicing-summary-$id-tap'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(label, style: theme.textTheme.labelMedium),
                      ),
                      if (selected) const Icon(Icons.check, size: 18),
                    ],
                  ),
                  if (amounts.isNotEmpty)
                    Text(amounts, style: theme.textTheme.titleSmall),
                  Text(count, key: countKey, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
