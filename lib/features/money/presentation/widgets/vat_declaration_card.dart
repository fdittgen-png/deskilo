// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — one saved VAT declaration: its period and stage, its lines, its
// totals and balance, the filing reference, and the actions the screen
// passes in. Moved whole from vat_declarations_screen.dart.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/vat_declaration_rows.dart';
import '../../domain/vat_declaration.dart';
import '../vat_tax_point_labels.dart';

class VatDeclarationCard extends StatelessWidget {
  const VatDeclarationCard({
    super.key,
    required this.row,
    required this.statusLabel,
    required this.lineNote,
    required this.actions,
  });

  final VatDeclarationRow row;
  final String statusLabel;

  /// What a line is beside its rate (deductible VAT, a correction).
  final String Function(VatDeclarationLine line) lineNote;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();
    final declaration = row.declaration;
    return Card(
  key: ValueKey(
      'vat-decl-${declaration.id}'),
  child: Padding(
    padding: AppSpacing.lgAll,
    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${dateFormat.format(declaration.periodStart)}'
                ' – '
                '${dateFormat.format(declaration.periodEnd)}',
                style: theme
                    .textTheme.titleMedium,
              ),
            ),
            Chip(
              key: ValueKey(
                  'vat-decl-status-${declaration.id}'),
              label: Text(
                statusLabel,
              ),
              visualDensity:
                  VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final line in declaration.lines)
          Text(
            key: line.isCorrection
                ? ValueKey(
                    'vat-decl-correction-${declaration.id}-${line.corrects}')
                : null,
            '${VatDeclarationRow.hasNote(line) ? '${lineNote(line)} · ' : ''}'
            '${VatDeclarationRow.percentLabel(line.percent)}'
            '${line.category.isEmpty ? '' : ' ${line.category}'} · '
            '${l10n.vatDeclNet} '
            '${centsToMajor(line.netCents)} ${declaration.currency} · '
            '${l10n.vatDeclVat} '
            '${centsToMajor(line.vatCents)} ${declaration.currency}',
            style:
                theme.textTheme.bodySmall,
          ),
        if (row.hasCorrections)
          Text(
            vatWords(l10n).vatDeclCorrectionsNote,
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 4),
        Text(
          '${l10n.vatDeclTotals}: '
          '${centsToMajor(declaration.totalNetCents)} ${declaration.currency} · '
          '${l10n.vatDeclVat} '
          '${centsToMajor(declaration.totalVatCents)} ${declaration.currency} · '
          '${declaration.invoiceCount} '
          '${l10n.vatDeclInvoices}',
          style: theme.textTheme.bodyMedium
              ?.copyWith(
                  fontWeight:
                      FontWeight.w600),
        ),
        // #2357 — with deductible VAT, what is
        // left to pay, or to claim back.
        if (row.hasInputVat)
          Text(
            key: ValueKey(
                'vat-decl-balance-${declaration.id}'),
            '${row.payable ? vatWords(l10n).vatDeclPayable : vatWords(l10n).vatDeclCredit}: '
            '${centsToMajor(row.balanceCents)} ${declaration.currency}',
            style: theme.textTheme.bodyMedium,
          ),
        if (row.filedLine case final filed?)
          Text(
            filed,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: AppSpacing.sm),
        actions,
      ],
    ),
  ),
);
  }
}
