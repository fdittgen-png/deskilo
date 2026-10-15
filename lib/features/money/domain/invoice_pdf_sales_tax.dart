// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- the totals block of a sales-tax invoice (a seller in the United
// States): the subtotal at net prices, then each jurisdiction's tax on its
// own line under its own name -- no VAT wording -- the customer's exemption
// certificate when one took lines out of the tax, the payments and the total.
import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/text/number_text.dart';
import 'invoice.dart';
import 'invoice_pdf.dart' show InvoicePdfStrings;
import 'vat_rate.dart';

/// The tax of [invoice] per jurisdiction, in the order it was frozen: the
/// components of every taxed total, those of one name added together.
@visibleForTesting
List<({String name, double percent, int taxCents})> salesTaxByJurisdiction(
  List<InvoiceVatTotal> totals,
) {
  final byName = <String, ({double percent, int taxCents})>{};
  for (final total in totals) {
    for (final c in total.components) {
      final seen = byName[c.name];
      byName[c.name] = (
        percent: c.percent,
        taxCents: (seen?.taxCents ?? 0) + c.taxCents,
      );
    }
  }
  return [
    for (final e in byName.entries)
      (name: e.key, percent: e.value.percent, taxCents: e.value.taxCents),
  ];
}

/// The certificate every exempt-by-certificate total cites, once each.
@visibleForTesting
List<String> exemptionCertificateLines(
  List<InvoiceVatTotal> totals,
  String caption,
) {
  final seen = <String>{};
  for (final total in totals) {
    if (total.exemptionBasis != 'certificate') continue;
    final number = '${total.certificate['number'] ?? ''}'.trim();
    if (number.isEmpty) continue;
    final state = '${total.certificate['state'] ?? ''}'.trim();
    seen.add('$caption $number${state.isEmpty ? '' : ' ($state)'}');
  }
  return seen.toList();
}

/// The block the invoice sheet prints in place of the VAT one.
pw.Widget salesTaxTotals({
  required Invoice invoice,
  required InvoicePdfStrings strings,
  required String Function(int cents) money,
  required int paymentsCents,
  required ({PdfColor ink, PdfColor muted, PdfColor accent}) palette,
}) {
  final (:ink, :muted, :accent) = palette;
  pw.Widget row(String caption, String amount, {double top = 0}) => pw.Padding(
    padding: pw.EdgeInsets.only(top: top),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(
            caption,
            style: pw.TextStyle(fontSize: 9, color: muted),
          ),
        ),
        pw.Text(amount, style: pw.TextStyle(fontSize: 9, color: muted)),
      ],
    ),
  );
  final bold = pw.TextStyle(
    fontSize: 12,
    fontWeight: pw.FontWeight.bold,
    color: ink,
  );
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.SizedBox(
        width: 220,
        child: pw.Column(
          children: [
            row(
              strings.subtotal.isNotEmpty ? strings.subtotal : strings.net,
              money(invoice.netCents),
            ),
            for (final t in salesTaxByJurisdiction(invoice.vatTotals))
              row(
                '${t.name} ${percentText(t.percent)} %',
                money(t.taxCents),
                top: 2,
              ),
            for (final line in exemptionCertificateLines(
              invoice.vatTotals,
              strings.exemptCertificate,
            ))
              row(line, '', top: 2),
            if (paymentsCents != 0)
              row(strings.payments, money(paymentsCents), top: 2),
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 5),
              height: 1.5,
              color: accent,
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(strings.total, style: bold),
                pw.Text(money(invoice.totalCents), style: bold),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
