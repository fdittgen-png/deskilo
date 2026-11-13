// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3627 (desk M8) — the payments received, at the desk: a records table
// (#3606) of the payments read so far — the day each was matched, its
// invoice, its customer, its reference and its amount — with the total per
// currency under the amount column. While more pages remain the table says
// it is partly read; the page reads the next one on request. A row opens its
// invoice at the invoice's own address.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../domain/recorded_payments.dart';
import '../invoicing/invoicing_customer_actions.dart' show invoicesPath;

/// The payments read so far as a table; [complete] once no page remains.
class RecordedPaymentsTable extends StatelessWidget {
  const RecordedPaymentsTable({
    super.key,
    required this.payments,
    required this.complete,
    required this.cardBuilder,
  });

  final List<RecordedPayment> payments;
  final bool complete;

  /// A payment on a phone: the list's own row.
  final Widget Function(BuildContext context, RecordedPayment payment)
  cardBuilder;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final dates = format.dates(DateShape.date);
    return RecordsTable<RecordedPayment>(
      tableId: 'recorded-payments',
      rows: payments,
      complete: complete,
      keyOf: (p) => p.id,
      searchText: (p) =>
          '${p.invoiceNumber ?? ''} ${p.payerName ?? ''} ${p.label ?? ''}',
      onOpen: (p) => context.go('$invoicesPath/${p.invoiceId}'),
      empty: Center(child: Text(l.recordedPaymentsEmpty)),
      initialQuery: const RecordsQuery(sortColumn: 'matched', ascending: false),
      amountOf: (p) => (currency: p.currency, minor: p.amountMinor),
      amountColumn: 'amount',
      formatAmount: (code, minor) => format.moneyIn(code).formatMinor(minor),
      columns: [
        RecordColumn(
          id: 'matched',
          label: l.recordedPaymentsColMatched,
          flex: 2,
          hideable: false,
          sortKey: (p) => p.matchedAt,
          cell: (_, p) => Text(dates.format(p.matchedAt)),
        ),
        RecordColumn(
          id: 'invoice',
          label: l.invoicingColInvoice,
          flex: 2,
          sortKey: (p) => p.invoiceNumber ?? '',
          cell: (_, p) => Text(p.invoiceNumber ?? ''),
        ),
        RecordColumn(
          id: 'customer',
          label: l.invoicingColCustomer,
          flex: 3,
          sortKey: (p) => (p.payerName ?? '').toLowerCase(),
          cell: (_, p) =>
              Text(p.payerName ?? '', overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'reference',
          label: l.dataReportColumnReference,
          flex: 3,
          staysBeside: false,
          cell: (_, p) => Text(p.label ?? '', overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'amount',
          label: l.registerPaymentAmount,
          flex: 2,
          numeric: true,
          sortKey: (p) => p.amountMinor,
          cell: (_, p) =>
              Text(format.moneyIn(p.currency).formatMinor(p.amountMinor)),
        ),
      ],
      cardBuilder: cardBuilder,
    );
  }
}
