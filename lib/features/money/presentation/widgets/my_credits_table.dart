// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3627 (desk M8) — the Payments face at the desk: what I paid and was
// credited, as a records table — the day, what it was, its month and its
// amount, the total per currency under the amount. The ledger's own credit
// lines, as the bill's "Payments & credits" card lists them for one month.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/ledger_entry.dart';

/// What a credit line is, as the bill names it when it has no description.
String _creditLabel(AppLocalizations l, LedgerEntry e) =>
    e.description.isNotEmpty
    ? e.description
    : switch (e.category) {
        LedgerCategory.expense => l.ledgerCategoryExpense,
        LedgerCategory.adjustment => l.ledgerCategoryAdjustment,
        _ => l.eventTypePayment,
      };

class MyCreditsTable extends StatelessWidget {
  const MyCreditsTable({
    super.key,
    required this.ledger,
    required this.memberId,
    required this.currencyCode,
  });

  final List<LedgerEntry> ledger;
  final String memberId;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final dates = format.dates(DateShape.date);
    final money = format.moneyIn(currencyCode);
    final credits = [
      for (final e in ledger)
        if (e.memberId == memberId && e.kind == LedgerKind.credit) e,
    ];
    return RecordsTable<LedgerEntry>(
      tableId: 'my-credits',
      rows: credits,
      keyOf: (e) => e.id,
      searchText: (e) => '${_creditLabel(l, e)} ${e.period}',
      onOpen: (_) {},
      cardBuilder: (context, e) => ListTile(
        title: Text(_creditLabel(l, e)),
        trailing: Text(money.formatMinor(e.amountCents)),
      ),
      empty: Center(child: Text(l.billPaymentsCredits)),
      initialQuery: const RecordsQuery(sortColumn: 'on', ascending: false),
      amountOf: (e) => (currency: currencyCode, minor: e.amountCents),
      amountColumn: 'amount',
      formatAmount: (code, minor) => format.moneyIn(code).formatMinor(minor),
      columns: [
        RecordColumn(
          id: 'on',
          label: l.purchasesPayDate,
          flex: 2,
          hideable: false,
          sortKey: (e) => e.on,
          cell: (_, e) => Text(dates.format(format.wall(e.on))),
        ),
        RecordColumn(
          id: 'what',
          label: l.statementDeskColLine,
          flex: 4,
          sortKey: (e) => _creditLabel(l, e).toLowerCase(),
          cell: (_, e) =>
              Text(_creditLabel(l, e), overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'period',
          label: l.invoiceRegisterPeriodColumn,
          flex: 2,
          sortKey: (e) => e.period,
          cell: (_, e) => Text(e.period),
        ),
        RecordColumn(
          id: 'amount',
          label: l.financesColumnAmount,
          flex: 2,
          numeric: true,
          sortKey: (e) => e.amountCents,
          cell: (_, e) => Text(money.formatMinor(e.amountCents)),
        ),
      ],
    );
  }
}
