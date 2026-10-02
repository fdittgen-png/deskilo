// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 B — the table and the chart of one result. Both take the same
// rows and the same formatter, so they cannot disagree: the chart is a
// picture of the table, every bar carries the table's text, and the
// table is always one tap away as the accessible alternative.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_result.dart';
import '../../domain/kpi_contract.dart';

String biRowLabel(BiRow row, AppLocalizations? l10n) => row.isTotal
    ? l10n?.biTotal ?? 'Total'
    : row.isRemainder
    ? l10n?.biRemainder ?? 'Not in a current group'
    : row.label ?? row.key;

class BiRows extends StatelessWidget {
  const BiRows({
    super.key,
    required this.rows,
    required this.view,
    required this.aggregation,
    required this.format,
    required this.change,
    this.comparedLabel,
    this.groupHeader,
  });

  /// The groups, then the total, in display order.
  final List<BiRow> rows;
  final BiView view;
  final KpiAggregation aggregation;
  final String Function(num? value) format;
  final String Function(BiRow row) change;

  /// The compared period's name, or null when nothing is compared.
  final String? comparedLabel;

  /// The grouping's name, or null when not grouped.
  final String? groupHeader;

  @override
  Widget build(BuildContext context) =>
      view == BiView.chart ? _chart(context) : _table(context);

  Widget _table(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bold = Theme.of(context).textTheme.labelLarge;
    Widget cell(String text, {Key? key, TextStyle? style}) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Text(text, key: key, style: style),
    );
    final compared = comparedLabel;
    return SingleChildScrollView(
      key: const ValueKey('bi-table'),
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          TableRow(
            children: [
              cell(groupHeader ?? '', style: bold),
              cell(l10n?.biColumnValue ?? 'Value', style: bold),
              if (compared != null) ...[
                cell(compared, style: bold),
                cell(l10n?.biColumnChange ?? 'Change', style: bold),
              ],
            ],
          ),
          for (final row in rows)
            TableRow(
              children: [
                cell(biRowLabel(row, l10n), style: row.isTotal ? bold : null),
                cell(
                  format(row.current.value(aggregation)),
                  key: ValueKey('bi-table-${row.key}'),
                  style: row.isTotal ? bold : null,
                ),
                if (compared != null) ...[
                  cell(format(row.compared?.value(aggregation))),
                  cell(change(row), key: ValueKey('bi-change-${row.key}')),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final values = [
      for (final r in rows) ...[
        r.current.value(aggregation),
        r.compared?.value(aggregation),
      ],
    ].whereType<num>().map((v) => v.abs());
    // Ratios share a 0–100 % axis; amounts scale to the largest bar.
    final top = aggregation == KpiAggregation.ratioOfSums
        ? values.fold<num>(1, (a, b) => a > b ? a : b)
        : values.fold<num>(0, (a, b) => a > b ? a : b);
    Widget bar(num? v, Color color, double height) => v == null || top == 0
        ? const SizedBox.shrink()
        : FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: (v.abs() / top).clamp(0, 1).toDouble(),
            child: Container(height: height, color: color),
          );
    return Column(
      key: const ValueKey('bi-chart'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Semantics(
            container: true,
            label: [
              biRowLabel(row, l10n),
              format(row.current.value(aggregation)),
              if (comparedLabel != null) ...[
                '$comparedLabel ${format(row.compared?.value(aggregation))}',
                change(row),
              ],
            ].join(', '),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text first: the value never depends on colour alone.
                  Text(
                    '${biRowLabel(row, l10n)}: '
                    '${format(row.current.value(aggregation))}'
                    '${comparedLabel == null ? '' : ' · $comparedLabel '
                              '${format(row.compared?.value(aggregation))} '
                              '(${change(row)})'}',
                    key: ValueKey('bi-chart-${row.key}'),
                  ),
                  bar(row.current.value(aggregation), scheme.primary, 12),
                  if (comparedLabel != null)
                    bar(row.compared?.value(aggregation), scheme.outline, 6),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
