// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_xlsx/deskilo_xlsx.dart';

/// The Invoices sheet of the workbook: one row per invoice, with what it froze
/// at issue (#3850, #3852): its document language, its format locale and its
/// paper, empty for an invoice issued before they were recorded (#3989).
/// [major] writes an amount in the workspace currency's major units, [at] an
/// instant at the workspace's wall clock and [day] a calendar day, as every
/// sheet of the workbook does.
XlsxSheet workspaceInvoicesSheet({
  required List<Invoice> invoices,
  required Map<String, String> memberName,
  required Map<String, DateTime> transmissionsByInvoice,
  required XlsxAmount Function(int cents) major,
  required DateTime? Function(DateTime? instant) at,
  required XlsxDate? Function(DateTime? day) day,
}) {
  return XlsxSheet(
    name: 'Invoices',
    totals: 'total',
    rows: [
      [
        'number', 'member', 'period', 'issued_at', 'total', 'currency',
        'voided_at', 'replaces', 'detailed', 'last_sent_at', 'kind', 'title',
        'net', 'vat', 'vat_by_rate', 'due_on', 'issued_by',
        'document_language', 'format_locale', 'paper',
      ],
      for (final i in invoices)
        [
          i.number, memberName[i.memberId], i.period, at(i.issuedAt),
          major(i.totalCents), i.currency, at(i.voidedAt),
          if (i.replacesNumber.isEmpty) null else i.replacesNumber, i.detailed,
          at(transmissionsByInvoice[i.id]),
          i.kind.name, i.title, major(i.netCents), major(i.vatCents),
          [
            for (final t in i.vatTotals)
              '${t.percent}%: ${major(t.vatCents).value.toStringAsFixed(2)}',
          ].join('; '),
          day(i.dueOn), i.issuerName,
          i.documentLanguage, i.formatLocale, i.paper,
        ],
    ],
  );
}
