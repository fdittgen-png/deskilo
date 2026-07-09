// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../events/domain/workspace_event.dart';
import 'bill_sections.dart';
import 'ledger_entry.dart';
import 'statement.dart';

/// Localized labels for the bill PDF (#133). The domain layer stays
/// l10n-free (ADR 0007 keeps `AppLocalizations` out of pure Dart), so the
/// call site resolves every string — including the statement-dependent
/// subscription/entitlement/overage lines — and hands this value object in.
class BillPdfStrings {
  const BillPdfStrings({
    required this.title,
    required this.subscription,
    required this.entitlement,
    required this.overage,
    required this.services,
    required this.servicesTotal,
    required this.serviceFallback,
    required this.openPositions,
    required this.pendingBadge,
    required this.paymentsCredits,
    required this.paymentFallback,
    required this.expenseFallback,
    required this.adjustmentFallback,
    required this.eventPayment,
    required this.eventExpense,
    required this.eventAdjustment,
    required this.balance,
    required this.settled,
    required this.outstanding,
  });

  /// Document title, e.g. "Monthly bill".
  final String title;

  /// Pre-resolved subscription line, e.g. "Subscription 50%".
  final String subscription;

  /// Pre-resolved entitlement line, e.g. "24 of 22 half-days used …".
  final String entitlement;

  /// Pre-resolved overage line; only rendered when extra half-days exist.
  final String overage;

  final String services;
  final String servicesTotal;

  /// Fallback description for a service ledger entry without one.
  final String serviceFallback;

  final String openPositions;
  final String pendingBadge;
  final String paymentsCredits;

  /// Fallback descriptions for credit ledger entries without one.
  final String paymentFallback;
  final String expenseFallback;
  final String adjustmentFallback;

  /// Labels for pending event types in the open-positions section.
  final String eventPayment;
  final String eventExpense;
  final String eventAdjustment;

  final String balance;
  final String settled;
  final String outstanding;
}

const _pendingColor = PdfColors.grey700;

/// Renders [statement] and its [sections] — the exact grouping the
/// on-screen bill shows via [buildBillSections] — as an A4 PDF (#133,
/// ADR 0008).
///
/// [baseFont]/[boldFont] must be real TTFs (the app embeds Roboto from
/// assets/fonts): the pdf package's base-14 Type1 fonts cannot encode
/// '€' (U+20AC) or the typographic minus '−' (U+2212) the bill uses.
Future<Uint8List> buildBillPdf({
  required Statement statement,
  required BillSections sections,
  required String currencyCode,
  required String workspaceName,
  required String memberName,
  required String periodLabel,
  required BillPdfStrings strings,
  required pw.Font baseFont,
  required pw.Font boldFont,
  String? locale,
}) async {
  final currency = NumberFormat.simpleCurrency(
    name: currencyCode,
    locale: locale,
  );
  String money(int cents) => currency.format(cents / 100);
  String charge(int cents) => '−${money(cents)}';
  String credit(int cents) => '+${money(cents)}';
  final dateFormat = DateFormat.yMMMd(locale);

  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        _header(
          workspaceName: workspaceName,
          memberName: memberName,
          periodLabel: periodLabel,
          title: strings.title,
        ),
        pw.SizedBox(height: 16),
        _section([
          _line(strings.subscription, charge(statement.feeCents), bold: true),
          _line(strings.entitlement, ''),
          if (statement.extraHalfDays > 0)
            _line(strings.overage, charge(statement.overageCents)),
        ]),
        if (sections.serviceEntries.isNotEmpty)
          _section([
            _sectionTitle(strings.services),
            for (final entry in sections.serviceEntries)
              _line(
                entry.description.isEmpty
                    ? strings.serviceFallback
                    : entry.description,
                charge(entry.amountCents),
              ),
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            _line(
              strings.servicesTotal,
              charge(sections.servicesTotalCents),
              bold: true,
            ),
          ]),
        if (sections.openPositions.isNotEmpty)
          // Not part of the balance: visually separated, all grey, with the
          // pending badge — mirrors the amber outline card on screen.
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _pendingColor, width: 0.75),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      strings.openPositions,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                        color: _pendingColor,
                      ),
                    ),
                    pw.Text(
                      strings.pendingBadge,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: _pendingColor,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                for (final position in sections.openPositions)
                  _line(
                    _openPositionLabel(strings, position.event),
                    position.isCredit
                        ? credit(position.amountCents)
                        : charge(position.amountCents),
                    color: _pendingColor,
                  ),
              ],
            ),
          ),
        if (sections.creditEntries.isNotEmpty)
          _section([
            _sectionTitle(strings.paymentsCredits),
            for (final entry in sections.creditEntries)
              _line(
                entry.description.isEmpty
                    ? _creditFallback(strings, entry)
                    : entry.description,
                credit(entry.amountCents),
                detail: dateFormat.format(entry.createdAt.toLocal()),
              ),
          ]),
        pw.Divider(thickness: 1, color: PdfColors.grey800),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                strings.balance,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            pw.Text(
              statement.isSettled ? strings.settled : strings.outstanding,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Text(
              money(statement.balanceCents),
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return Uint8List.fromList(await document.save());
}

String _openPositionLabel(BillPdfStrings strings, WorkspaceEvent event) {
  switch (event.type) {
    case EventType.serviceCharge:
      final name = event.payload['name'] as String? ?? '';
      final quantity = (event.payload['quantity'] as num?)?.toInt() ?? 0;
      return '$name ×$quantity';
    case EventType.payment:
      return strings.eventPayment;
    case EventType.expense:
      return strings.eventExpense;
    case EventType.reservation:
    case EventType.adjustment:
      return strings.eventAdjustment;
  }
}

String _creditFallback(BillPdfStrings strings, LedgerEntry entry) {
  return switch (entry.category) {
    LedgerCategory.expense => strings.expenseFallback,
    LedgerCategory.adjustment => strings.adjustmentFallback,
    _ => strings.paymentFallback,
  };
}

pw.Widget _header({
  required String workspaceName,
  required String memberName,
  required String periodLabel,
  required String title,
}) {
  final subtitle = '$memberName — $periodLabel';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        workspaceName,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
      ),
      pw.SizedBox(height: 2),
      pw.Text(title, style: const pw.TextStyle(fontSize: 13)),
      pw.SizedBox(height: 2),
      pw.Text(
        subtitle,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
      pw.Divider(thickness: 1, color: PdfColors.grey800),
    ],
  );
}

pw.Widget _section(List<pw.Widget> children) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    );

pw.Widget _sectionTitle(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
      ),
    );

pw.Widget _line(
  String label,
  String value, {
  String? detail,
  bool bold = false,
  PdfColor? color,
}) {
  final style = pw.TextStyle(
    fontSize: 10,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: color,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: style),
              if (detail != null)
                pw.Text(
                  detail,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
            ],
          ),
        ),
        pw.Text(value, style: style),
      ],
    ),
  );
}
