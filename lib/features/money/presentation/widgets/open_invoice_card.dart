// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/accounting_view.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';

/// #831 — one regrouped source under its settlement: number, period,
/// amount, where it went — and the ONE thing left to do with it, the
/// stamped PDF.
class FoldedSourceRow extends ConsumerWidget {
  const FoldedSourceRow({
    super.key,
    required this.source,
    required this.settlement,
    required this.full,
    required this.currency,
    this.keyPrefix = 'invoice-folded',
  });

  final SettledSource source;
  final Invoice settlement;

  /// The source as an invoice, when the list holds it (the PDF needs it).
  final Invoice? full;
  final MoneyFormat currency;
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    // How it stands THROUGH the settlement: paid once that one is.
    final settlementMatch =
        ref.watch(invoiceMatchesProvider).value?[settlement.id];
    final paid = full != null &&
        effectiveMatchOf(full!, settlement, settlementMatch) != null;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xl),
      child: Card(
        color: theme.colorScheme.surfaceContainerLow,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.subdirectory_arrow_right,
              color: theme.colorScheme.onSurfaceVariant),
          title: Text([
            source.number,
            if (source.period != null) source.period!,
            currency.formatMinor(source.totalCents),
          ].join(' · ')),
          subtitle: Text(
            paid
                ? (l10n.settlementPaidThrough(settlement.number))
                : (l10n.settlementFoldedIn(settlement.number)),
            key: ValueKey('$keyPrefix-status-${source.invoiceId}'),
            style: muted,
          ),
          trailing: full == null
              ? null
              : IconButton(
                  key: ValueKey('$keyPrefix-pdf-${source.invoiceId}'),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: l10n.settlementSourcePdf,
                  onPressed: () => downloadInvoicePdf(context, ref, full!),
                ),
        ),
      ),
    );
  }
}
