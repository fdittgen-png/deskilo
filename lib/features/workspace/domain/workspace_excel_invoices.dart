// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_excel.dart';

/// The Invoices sheet of the workbook: one row per invoice, with what it froze
/// at issue (#3850, #3852: its document language, its format locale and its
/// paper, empty for an invoice issued before they were recorded; #3989).
extension _InvoicesSheet on _ExcelExport {
  XlsxSheet invoicesSheet() =>
      XlsxSheet(name: 'Invoices', totals: 'total', rows: [
    [
      'number', 'member', 'period', 'issued_at', 'total', 'currency',
      'voided_at', 'replaces', 'detailed', 'last_sent_at', 'kind', 'title',
      'net', 'vat', 'vat_by_rate', 'due_on', 'issued_by',
      'document_language', 'format_locale', 'paper',
    ],
    for (final i in invoices)
      [
        i.number, memberName[i.memberId], i.period, _at(i.issuedAt),
        major(i.totalCents), i.currency, _at(i.voidedAt),
        if (i.replacesNumber.isEmpty) null else i.replacesNumber, i.detailed,
        _at(transmissionsByInvoice[i.id]),
        i.kind.name, i.title, major(i.netCents), major(i.vatCents),
        [
          for (final t in i.vatTotals)
            '${t.percent}%: ${major(t.vatCents).value.toStringAsFixed(2)}',
        ].join('; '),
        _day(i.dueOn), i.issuerName,
        i.documentLanguage, i.formatLocale, i.paper,
      ],
  ]);
}
