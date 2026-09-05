// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'vat_declaration.dart';
import 'invoice_pdf.dart' show watermarkForeground;

/// The localized labels the declaration PDF prints (#534) — passed in so
/// the domain builder stays l10n-free like the other PDF seams.
class VatDeclarationPdfStrings {
  const VatDeclarationPdfStrings({
    required this.title,
    required this.period,
    required this.seller,
    required this.vatIdLabel,
    required this.colRate,
    required this.colNet,
    required this.colVat,
    required this.colInvoices,
    required this.totals,
    required this.boxesTitle,
    required this.colBox,
    required this.statusLabel,
    required this.disclaimer,
  });

  final String title;
  final String period;
  final String seller;
  final String vatIdLabel;
  final String colRate;
  final String colNet;
  final String colVat;
  final String colInvoices;
  final String totals;
  final String boxesTitle;
  final String colBox;
  final String statusLabel;
  final String disclaimer;
}

/// Renders the periodic VAT declaration as an A4 PDF: seller identity,
/// period, the per-rate table (net base, output VAT, invoice count), the
/// country's OFFICIAL form boxes (CA3 / UStVA / generic) and totals —
/// what the owner keys into EFI/ELSTER or hands to the accountant.
Future<Uint8List> buildVatDeclarationPdf({
  required VatDeclarationPdfStrings strings,
  required VatDeclaration declaration,
  required String workspaceName,
  required String vatId,
  required String countryCode,
  required String Function(int cents) money,
  required String Function(DateTime day) date,
  required pw.Font baseFont,
  required pw.Font boldFont,
  /// #917 — 'DEVELOPMENT' from a rehearsal workspace. A declaration is
  /// the one document that goes to a tax authority: it must be the
  /// LEAST mistakable of all.
  String watermark = '',
}) async {
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
  );
  final boxes = vatFormBoxes(countryCode, declaration.lines);

  pw.Widget cell(String text, {bool bold = false, bool right = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : null,
          ),
        ),
      );

  String pct(double percent) => percent == percent.roundToDouble()
      ? '${percent.toStringAsFixed(0)} %'
      : '$percent %';

  document.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        buildForeground: watermarkForeground(watermark),
      ),
      build: (context) => [
        pw.Text(strings.title,
            style:
                pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          '${strings.seller}: $workspaceName'
          '${vatId.isEmpty ? '' : ' · ${strings.vatIdLabel} $vatId'}',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.Text(
          '${strings.period}: ${date(declaration.periodStart)} – '
          '${date(declaration.periodEnd)}',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.Text(
          '${strings.statusLabel}: ${declaration.status}'
          '${declaration.submittedAt == null ? '' : ' · ${date(declaration.submittedAt!)}'}',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: [
            strings.colRate,
            strings.colNet,
            strings.colVat,
            strings.colInvoices,
          ],
          headerStyle:
              pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignments: const {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          data: [
            for (final line in declaration.lines)
              [
                pct(line.percent),
                money(line.netCents),
                money(line.vatCents),
                '${line.invoiceCount}',
              ],
            [
              strings.totals,
              money(declaration.totalNetCents),
              money(declaration.totalVatCents),
              '${declaration.invoiceCount}',
            ],
          ],
        ),
        if (boxes.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(strings.boxesTitle,
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border:
                pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(1.4),
              3: pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(children: [
                cell(strings.colBox, bold: true),
                cell('', bold: true),
                cell(strings.colNet, bold: true, right: true),
                cell(strings.colVat, bold: true, right: true),
              ]),
              for (final box in boxes)
                pw.TableRow(children: [
                  cell(box.code),
                  cell(box.label),
                  cell(money(box.netCents), right: true),
                  cell(money(box.vatCents), right: true),
                ]),
            ],
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Text(strings.disclaimer,
            style:
                const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    ),
  );
  return document.save();
}
