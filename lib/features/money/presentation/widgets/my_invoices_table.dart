// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3627 (desk M8) — the Invoices face at the desk: my invoices as a records
// table — number, period, issued, status and amount, the total per currency
// under the amount — each opening the detail sheet the list opens. The same
// invoices as the phone's list (`myInvoicesOf`), the same reads.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/money_providers.dart';
import '../invoice_status.dart';
import '../period_label.dart';
import 'my_invoices_list.dart';

class MyInvoicesTable extends ConsumerWidget {
  const MyInvoicesTable({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final invoicesAsync = ref.watch(invoicesProvider);
    final matchesAsync = ref.watch(invoiceMatchesProvider);
    final standIn = ReadsAnswer.of([invoicesAsync, matchesAsync]).standIn(
      onRetry: () => ref
        ..invalidate(invoicesProvider)
        ..invalidate(invoiceMatchesProvider),
    );
    if (standIn != null) return standIn;
    final fold = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.settlementFold);
    final invoices = myInvoicesOf(
      invoicesAsync.requireValue,
      memberId,
      fold: fold,
    );
    final matches = matchesAsync.requireValue;
    final format = appFormatOf(context);
    final dates = format.dates(DateShape.date);
    String status(Invoice i) =>
        invoiceLifecycleLabel(l, invoiceLifecycleOf(i, matches[i.id]));
    return RecordsTable<Invoice>(
      tableId: 'my-invoices',
      rows: invoices,
      keyOf: (i) => i.id,
      searchText: (i) => '${i.number} ${invoicePeriodLabel(context, i)}',
      onOpen: (i) => openMyInvoice(context, ref, i, matches[i.id]),
      cardBuilder: (context, i) => ListTile(
        title: Text(i.number),
        trailing: Text(format.moneyIn(i.currency).formatMinor(i.totalCents)),
      ),
      empty: Center(child: Text(l.moneyNoInvoicesYet)),
      initialQuery: const RecordsQuery(sortColumn: 'issued', ascending: false),
      amountOf: (i) => (currency: i.currency, minor: i.totalCents),
      amountColumn: 'amount',
      formatAmount: (code, minor) => format.moneyIn(code).formatMinor(minor),
      columns: [
        RecordColumn(
          id: 'number',
          label: l.invoicingColInvoice,
          flex: 2,
          hideable: false,
          sortKey: (i) => i.number,
          cell: (_, i) => Text(i.number),
        ),
        RecordColumn(
          id: 'period',
          label: l.invoiceRegisterPeriodColumn,
          flex: 2,
          sortKey: (i) => i.period ?? '',
          cell: (context, i) => Text(invoicePeriodLabel(context, i)),
        ),
        RecordColumn(
          id: 'issued',
          label: l.invoiceMonthIssued,
          flex: 2,
          sortKey: (i) => i.issuedAt,
          cell: (_, i) => Text(dates.format(i.issuedAt)),
        ),
        RecordColumn(
          id: 'status',
          label: l.invoicingColStatus,
          flex: 2,
          sortKey: status,
          cell: (_, i) => Text(status(i)),
        ),
        RecordColumn(
          id: 'amount',
          label: l.financesColumnAmount,
          flex: 2,
          numeric: true,
          sortKey: (i) => i.totalCents,
          cell: (_, i) =>
              Text(format.moneyIn(i.currency).formatMinor(i.totalCents)),
        ),
      ],
    );
  }
}
