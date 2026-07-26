// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'invoice.dart';

/// Localized strings the invoice PDF prints.
class InvoicePdfStrings {
  const InvoicePdfStrings({
    required this.invoiceTitle,
    required this.issuedOn,
    required this.issuedBy,
    required this.billedTo,
    required this.total,
    required this.signature,
    required this.voided,
    required this.replaces,
    required this.description,
    required this.charges,
    required this.payments,
    required this.annex,
    required this.attendance,
    required this.activity,
    required this.reserved,
    required this.page,
  });

  final String invoiceTitle;
  final String issuedOn;
  final String issuedBy;
  final String billedTo;

  /// The bottom line — the solde (0063).
  final String total;
  final String signature;

  /// Banner on an invoice tagged erroneous (0061).
  final String voided;

  /// Label before the replaced invoice's number on a replacement (0061).
  final String replaces;

  /// Lines-table column header.
  final String description;

  /// Subtotal captions above the balance (0063).
  final String charges;
  final String payments;

  /// Annex section titles (0064).
  final String annex;
  final String attendance;
  final String activity;

  /// Suffix on an attendance row that was booked but not attended.
  final String reserved;

  /// Footer page label ('Page').
  final String page;
}

/// DesKilo brand accent — matches the launcher icon red.
const PdfColor _accent = PdfColor.fromInt(0xFFD32F2F);
const PdfColor _ink = PdfColors.blueGrey900;
const PdfColor _muted = PdfColors.blueGrey600;
const PdfColor _hairline = PdfColors.blueGrey200;
const PdfColor _zebra = PdfColor.fromInt(0xFFF6F7F9);

/// The archive PDF of one invoice — professional layout (field
/// request): letterhead with the workspace identity, a boxed billed-to
/// block, a proper positions table with charges/payments subtotals and
/// the SOLDE as the bottom line, and — for detailed invoices (0064) —
/// an annex listing every check-in and every booked movement of the
/// month. Everything renders from the invoice's SNAPSHOT fields; the
/// caller supplies localized wording so this builder stays l10n-free.
Future<Uint8List> buildInvoicePdf({
  required Invoice invoice,
  required InvoicePdfStrings strings,
  required String Function(int cents) money,
  required String Function(InvoiceLine line) lineText,
  required String Function(InvoiceDetailEntry entry) activityText,
  required String dateLabel,
  required pw.Font baseFont,
  required pw.Font boldFont,
}) async {
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
  // Composed outside the widget calls (HARD RULE #1 lints inline
  // literals).
  final numberLine = '${strings.invoiceTitle} ${invoice.number}';
  final issuedOnLine = '${strings.issuedOn} $dateLabel';
  final issuedByLine = '${strings.issuedBy} ${invoice.issuerName}';
  final replacesLine = '${strings.replaces} ${invoice.replacesNumber}';

  final chargesCents = invoice.lines
      .where((l) => l.amountCents > 0)
      .fold(0, (sum, l) => sum + l.amountCents);
  final paymentsCents = invoice.lines
      .where((l) => l.amountCents < 0)
      .fold(0, (sum, l) => sum + l.amountCents);

  pw.Widget label(String text) => pw.Text(text,
      style: pw.TextStyle(
          fontSize: 8,
          color: _muted,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.2));

  pw.Widget amountCell(int cents, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        child: pw.Text(money(cents),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
                fontSize: 10,
                color: cents < 0 ? _accent : _ink,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 44),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          '${strings.page} ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ),
      build: (context) => [
        // ── Letterhead ────────────────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(invoice.workspaceName,
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink)),
                  if (invoice.workspaceAddress.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 3),
                      child: pw.Text(invoice.workspaceAddress,
                          style: const pw.TextStyle(
                              fontSize: 9, color: _muted)),
                    ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(numberLine,
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: _accent)),
                pw.SizedBox(height: 3),
                pw.Text(issuedOnLine,
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
                pw.Text(issuedByLine,
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
                if (invoice.replacesNumber.isNotEmpty)
                  pw.Text(replacesLine,
                      style:
                          const pw.TextStyle(fontSize: 9, color: _muted)),
              ],
            ),
          ],
        ),
        pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 14),
            height: 2,
            color: _accent),
        // ── Erroneous banner (0061) ───────────────────────────────
        if (invoice.isVoided)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _accent, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(strings.voided,
                style: pw.TextStyle(
                    fontSize: 10,
                    color: _accent,
                    fontWeight: pw.FontWeight.bold)),
          ),
        // ── Billed to + invoiced month ────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: _zebra,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    label(strings.billedTo.toUpperCase()),
                    pw.SizedBox(height: 4),
                    pw.Text(invoice.memberName,
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: _ink)),
                    if (invoice.memberAddress.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(invoice.memberAddress,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
                      ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _hairline),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(invoice.title,
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink)),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        // ── Positions ─────────────────────────────────────────────
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _ink),
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
            for (final (i, line) in invoice.lines.indexed)
              pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isOdd ? _zebra : PdfColors.white),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5, horizontal: 8),
                    child: pw.Text(lineText(line),
                        style:
                            const pw.TextStyle(fontSize: 10, color: _ink)),
                  ),
                  amountCell(line.amountCents),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 10),
        // ── Totals: charges / payments / SOLDE ────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 220,
              child: pw.Column(children: [
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(strings.charges,
                          style: const pw.TextStyle(
                              fontSize: 9, color: _muted)),
                      pw.Text(money(chargesCents),
                          style: const pw.TextStyle(
                              fontSize: 9, color: _muted)),
                    ]),
                if (paymentsCents != 0)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Row(
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(strings.payments,
                              style: const pw.TextStyle(
                                  fontSize: 9, color: _muted)),
                          pw.Text(money(paymentsCents),
                              style: const pw.TextStyle(
                                  fontSize: 9, color: _muted)),
                        ]),
                  ),
                pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 5),
                    height: 1.5,
                    color: _accent),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(strings.total,
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: _ink)),
                      pw.Text(money(invoice.totalCents),
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: _ink)),
                    ]),
              ]),
            ),
          ],
        ),
        // ── Annex (0064) ──────────────────────────────────────────
        if (invoice.detailed) ...[
          pw.SizedBox(height: 22),
          pw.Text(strings.annex,
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink)),
          pw.Container(
              margin: const pw.EdgeInsets.only(top: 3, bottom: 8),
              height: 1,
              width: 120,
              color: _accent),
          if (invoice.attendance.isNotEmpty) ...[
            label(strings.attendance.toUpperCase()),
            pw.SizedBox(height: 4),
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside:
                    pw.BorderSide(color: _hairline, width: .4),
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
                              fontSize: 9, color: _ink)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(
                          '${row.startsAt.split('T').last}–'
                          '${row.endsAt.split('T').last}',
                          style: const pw.TextStyle(
                              fontSize: 9, color: _ink)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(
                          row.status == 'reserved'
                              ? '${row.space} · ${strings.reserved}'
                              : row.space,
                          style: const pw.TextStyle(
                              fontSize: 9, color: _muted)),
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
                    pw.BorderSide(color: _hairline, width: .4),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.2),
                1: pw.FlexColumnWidth(2.8),
                2: pw.FlexColumnWidth(1),
              },
              children: [
                for (final entry in invoice.detailLedger)
                  pw.TableRow(children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(entry.on,
                          style: const pw.TextStyle(
                              fontSize: 9, color: _ink)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(activityText(entry),
                          style: const pw.TextStyle(
                              fontSize: 9, color: _muted)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(money(entry.amountCents),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: entry.amountCents < 0
                                  ? _accent
                                  : _ink)),
                    ),
                  ]),
              ],
            ),
          ],
        ],
        pw.SizedBox(height: 24),
        // ── Digital signature ─────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _hairline)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(strings.signature,
                  style: const pw.TextStyle(fontSize: 7, color: _muted)),
              pw.Text(invoice.signature,
                  style: const pw.TextStyle(fontSize: 7, color: _muted)),
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}
