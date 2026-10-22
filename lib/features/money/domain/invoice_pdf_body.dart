// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2492 — the body of an invoice sheet without a report design: billed-to,
// positions, totals and the annex, one method per section.
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'invoice.dart';
import 'invoice_pdf.dart';
import 'invoice_pdf_sales_tax.dart';
import 'invoice_pdf_sheet.dart';
import 'invoice_pdf_style.dart';
import 'invoice_sales_tax.dart';
import 'vat_rate.dart';

/// The sections [InvoiceSheet] lays out under its identification.
class InvoiceSheetBody {
  InvoiceSheetBody(this.sheet);

  final InvoiceSheet sheet;

  Invoice get invoice => sheet.invoice;
  InvoicePdfStrings get strings => sheet.strings;
  String Function(int cents) get money => sheet.money;
  String Function(InvoiceLine line) get lineText => sheet.lineText;
  String Function(InvoiceDetailEntry entry) get activityText =>
      sheet.activityText;
  bool get windowOn => sheet.windowOn;
  String get periodLabel => sheet.periodLabel;
  bool get showRates => sheet.showRates;
  bool get showVat => sheet.showVat;
  List<InvoiceVatTotal> get vatTotals => sheet.vatTotals;
  int get chargesCents => sheet.chargesCents;
  int get paymentsCents => sheet.paymentsCents;
  String ratePercent(double percent) => sheet.ratePercent(percent);

    pw.Widget label(String text) => pw.Text(text,
        style: pw.TextStyle(
            fontSize: 8,
            color: pdfMuted,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.2));

    pw.Widget amountCell(int cents, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          child: pw.Text(money(cents),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 10,
                  color: cents < 0 ? pdfAccent : pdfInk,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

  /// ── Billed to + invoiced month ──
  pw.Widget billedTo() =>
pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // #869 — the window already shows the recipient; repeating
              // it here would print the address twice.
              if (windowOn)
                pw.Spacer()
              else
                pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: pdfZebra,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      label(strings.billedTo.toUpperCase()),
                      pw.SizedBox(height: 4),
                      pw.Text(invoice.clientName,
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfInk)),
                      if (invoice.memberAddress.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(invoice.memberAddress,
                              style: const pw.TextStyle(
                                  fontSize: 9, color: pdfMuted)),
                        ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pdfHairline),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                    periodLabel.isEmpty ? invoice.title : periodLabel,
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: pdfInk)),
              ),
            ],
          );

  /// ── Positions ──
  pw.Widget positions() =>
pw.Table(
            columnWidths: showRates
                ? const {
                    0: pw.FlexColumnWidth(4),
                    1: pw.FlexColumnWidth(0.8),
                    2: pw.FlexColumnWidth(1.2),
                  }
                : const {
                    0: pw.FlexColumnWidth(4),
                    1: pw.FlexColumnWidth(1.2),
                  },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: pdfInk),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5, horizontal: 8),
                    child: pw.Text(strings.description,
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  if (showRates)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 5, horizontal: 8),
                      child: pw.Text(strings.vat,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5, horizontal: 8),
                    child: pw.Text(strings.total,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              for (final (i, line) in invoice.lines.indexed) ...[
                // #831 — a settlement groups its lines under the source
                // invoice they came from.
                if (line.sourceNumber.isNotEmpty &&
                    (i == 0 ||
                        invoice.lines[i - 1].sourceNumber != line.sourceNumber))
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: pdfZebra),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        child: pw.Text(line.sourceNumber,
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: pdfMuted,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                      if (showRates) pw.SizedBox(),
                      pw.SizedBox(),
                    ],
                  ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i.isOdd ? pdfZebra : PdfColors.white),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 5, horizontal: 8),
                      child: pw.Text(lineText(line),
                          style:
                              const pw.TextStyle(fontSize: 10, color: pdfInk)),
                    ),
                    if (showRates)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 5, horizontal: 8),
                        // A credit line is money moving, not a supply: it
                        // carries no rate to print.
                        child: pw.Text(
                            line.amountCents > 0
                                ? ratePercent(line.vatPercent)
                                : '',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(
                                fontSize: 9, color: pdfMuted)),
                      ),
                    amountCell(invoice.quotedCents(line)),
                  ],
                ),
              ],
            ],
          );

  /// ── Totals: charges / payments / SOLDE ──
  /// One caption and its amount, on the two ends of a line.
  pw.Widget _summaryRow(String caption, String amount) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(caption,
            style: const pw.TextStyle(fontSize: 9, color: pdfMuted)),
        pw.Text(amount,
            style: const pw.TextStyle(fontSize: 9, color: pdfMuted)),
      ]);

  pw.Widget totals() => invoice.isSalesTax
      ? salesTaxTotals(
          invoice: invoice,
          strings: strings,
          money: money,
          paymentsCents: paymentsCents,
          palette: (ink: pdfInk, muted: pdfMuted, accent: pdfAccent))
      : pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 220,
                child: pw.Column(children: [
                  if (showVat) ...[
                    _summaryRow(strings.net, money(invoice.netCents)),
                    for (final total in vatTotals)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: _summaryRow(
                            '${strings.vat} ${ratePercent(total.percent)}',
                            money(total.vatCents)),
                      ),
                    pw.SizedBox(height: 2),
                  ],
                  _summaryRow(strings.charges, money(chargesCents)),
                  if (paymentsCents != 0)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: _summaryRow(strings.payments, money(paymentsCents)),
                    ),
                  pw.Container(
                      margin: const pw.EdgeInsets.symmetric(vertical: 5),
                      height: 1.5,
                      color: pdfAccent),
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(strings.total,
                            style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: pdfInk)),
                        pw.Text(money(invoice.totalCents),
                            style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: pdfInk)),
                      ]),
                ]),
              ),
            ],
          );

  /// ── Annex (0064) ──
  List<pw.Widget> annex() {
    if (!invoice.detailed) return const <pw.Widget>[];
    return [
            pw.SizedBox(height: 22),
            pw.Text(strings.annex,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: pdfInk)),
            pw.Container(
                margin: const pw.EdgeInsets.only(top: 3, bottom: 8),
                height: 1,
                width: 120,
                color: pdfAccent),
            if (invoice.attendance.isNotEmpty) ...[
              label(strings.attendance.toUpperCase()),
              pw.SizedBox(height: 4),
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside:
                      pw.BorderSide(color: pdfHairline, width: .4),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(2.6),
                },
                children: [
                  for (final row in invoice.attendance)
                    pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(row.startsAt.split('T').first,
                            style: const pw.TextStyle(
                                fontSize: 9, color: pdfInk)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(
                            '${row.startsAt.split('T').last}–'
                            '${row.endsAt.split('T').last}',
                            style: const pw.TextStyle(
                                fontSize: 9, color: pdfInk)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(
                            row.status == 'reserved'
                                ? '${row.space} · ${strings.reserved}'
                                : row.space,
                            style: const pw.TextStyle(
                                fontSize: 9, color: pdfMuted)),
                      ),
                    ]),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
            if (invoice.detailLedger.isNotEmpty) ...[
              label(strings.activity.toUpperCase()),
              pw.SizedBox(height: 4),
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside:
                      pw.BorderSide(color: pdfHairline, width: .4),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.8),
                  2: pw.FlexColumnWidth(),
                },
                children: [
                  for (final entry in invoice.detailLedger)
                    pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(entry.on,
                            style: const pw.TextStyle(
                                fontSize: 9, color: pdfInk)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(activityText(entry),
                            style: const pw.TextStyle(
                                fontSize: 9, color: pdfMuted)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(money(entry.amountCents),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: entry.amountCents < 0
                                    ? pdfAccent
                                    : pdfInk)),
                      ),
                    ]),
                ],
              ),
            ],
    ];
  }

}
