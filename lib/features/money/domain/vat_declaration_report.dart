// SPDX-License-Identifier: AGPL-3.0-or-later
// VAT preparation sheets use the same editable report engine as invoices.
import 'invoice_pdf_template.dart';
import 'vat_declaration.dart';

/// The localized labels the declaration PDF prints (#534) — passed in so
/// the domain builder stays l10n-free like the other PDF seams.
class VatDeclarationPdfStrings {
  const VatDeclarationPdfStrings({
    required this.title,
    required this.period,
    required this.vatIdLabel,
    required this.colRate,
    required this.colNet,
    required this.colVat,
    required this.colInvoices,
    required this.totals,
    required this.boxesTitle,
    required this.colBox,
    required this.statusLabel,
  });

  final String title;
  final String period;
  final String vatIdLabel;
  final String colRate;
  final String colNet;
  final String colVat;
  final String colInvoices;
  final String totals;
  final String boxesTitle;
  final String colBox;
  final String statusLabel;
}

ReportBands defaultVatDeclarationBands(
  VatDeclarationPdfStrings s,
) => ReportBands(
  header:
      '# ${s.title}\n{{ workspace }}\n'
      '> ${s.vatIdLabel}: {{ seller_vat_id }}\n'
      '> ${s.period}: {{ period }}\n'
      '> ${s.statusLabel}: {{ declaration_status }}',
  body:
      '= ${s.colRate} | ${s.colNet} | ${s.colVat} | ${s.colInvoices}\n'
      '{% for row in vat_rate_totals %}{{ row.rate }} | {{ row.net }} | {{ row.vat }} | {{ row.count }}\n{% endfor %}'
      '= ${s.totals} | {{ vat_period_net }} | {{ vat_period_vat }} | {{ declaration_invoice_count }}\n\n'
      '## ${s.boxesTitle}\n'
      '= ${s.colBox} | ${s.colNet} | ${s.colVat}\n'
      '{% for box in vat_form_boxes %}{{ box.code }} — {{ box.label }} | {{ box.net }} | {{ box.vat }}\n{% endfor %}',
  footer: '> {{ declaration_note }}',
);

Map<String, Object?> vatDeclarationReportData({
  required VatDeclaration declaration,
  required String workspaceName,
  required String vatId,
  required String countryCode,
  required String disclaimer,
  required String statusLabel,
  required String Function(double) rate,
  required String Function(int) money,
  required String Function(DateTime) date,
}) => {
  'workspace': workspaceName,
  'seller_vat_id': vatId,
  'country': countryCode,
  'period': '${date(declaration.periodStart)} – ${date(declaration.periodEnd)}',
  'declaration_status': statusLabel,
  'declaration_note': disclaimer,
  'issued': declaration.submittedAt == null
      ? ''
      : date(declaration.submittedAt!),
  'declaration_invoice_count': '${declaration.invoiceCount}',
  'vat_period_net': money(declaration.totalNetCents),
  'vat_period_vat': money(declaration.totalVatCents),
  'vat_rate_totals': [
    for (final line in declaration.lines)
      {
        'rate': rate(line.percent),
        'net': money(line.netCents),
        'vat': money(line.vatCents),
        'count': '${line.invoiceCount}',
      },
  ],
  'vat_form_boxes': [
    for (final box in vatFormBoxes(countryCode, declaration.lines))
      {
        'code': box.code,
        'label': box.label,
        'net': money(box.netCents),
        'vat': money(box.vatCents),
      },
  ],
};
