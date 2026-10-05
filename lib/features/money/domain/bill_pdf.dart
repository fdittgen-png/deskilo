// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';
import '../../../core/i18n/money_format.dart';

import 'package:intl/intl.dart';
import 'invoice_pdf.dart';
import 'invoice_report.dart';
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
    required this.accessorySupplements,
    required this.services,
    required this.servicesTotal,
    required this.serviceFallback,
    required this.packages,
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

  /// Accessory-supplements line (#170); only rendered when the statement
  /// carries a non-zero supplement.
  final String accessorySupplements;

  final String services;
  final String servicesTotal;

  /// Fallback description for a service ledger entry without one.
  final String serviceFallback;

  /// Section title for bought day packages (migration 0042).
  final String packages;

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
  String pageLabel = 'Page',
  String watermark = '',
  InvoiceReport? report,
  Map<String, Uint8List> reportImages = const {},
}) async {
  return buildBandedLetterPdf(
    report: report ?? buildBillReport(statement: statement, sections: sections,
        currencyCode: currencyCode, workspaceName: workspaceName,
        memberName: memberName, periodLabel: periodLabel,
        strings: strings, locale: locale),
    pageLabel: pageLabel, documentTitle: strings.title,
    baseFont: baseFont, boldFont: boldFont, watermark: watermark,
    reportImages: reportImages,
  );
}

/// The same complete bill content drives quick view and PDF output.
InvoiceReport buildBillReport({
  required Statement statement,
  required BillSections sections,
  required String currencyCode,
  required String workspaceName,
  required String memberName,
  required String periodLabel,
  required BillPdfStrings strings,
  String? locale,
}) {
  // #711 — the DOCUMENT locale, passed explicitly: a PDF is rendered
  // for its reader, not for whoever pressed the button.
  final currency = moneyFormat(currencyCode, locale: locale);
  String money(int cents) => currency.formatMinor(cents);
  String charge(int cents) => '−${money(cents)}';
  String credit(int cents) => '+${money(cents)}';
  final dateFormat = DateFormat.yMMMd(locale);

  return InvoiceReport(
    header: [ReportHeading(workspaceName), ReportSubheading(strings.title),
      ReportMuted('$memberName — $periodLabel'), const ReportDivider()],
    continuation: [ReportText('$workspaceName — ${strings.title} — $memberName — $periodLabel'),
      const ReportDivider()],
    body: [
      ReportTableRow([strings.subscription, charge(statement.feeCents)], bold: true),
      ReportMuted(strings.entitlement),
      if (statement.extraHalfDays > 0)
        ReportTableRow([strings.overage, charge(statement.overageCents)]),
      if (statement.accessorySupplementCents > 0)
        ReportTableRow([strings.accessorySupplements, charge(statement.accessorySupplementCents)]),
      if (sections.serviceEntries.isNotEmpty) ...[
        ReportSubheading(strings.services),
        for (final entry in sections.serviceEntries)
          ReportTableRow([entry.description.isEmpty ? strings.serviceFallback : entry.description,
            charge(entry.amountCents)]),
        ReportTableRow([strings.servicesTotal, charge(sections.servicesTotalCents)], bold: true),
      ],
      if (sections.packageEntries.isNotEmpty) ...[
        ReportSubheading(strings.packages),
        for (final entry in sections.packageEntries)
          ReportTableRow([entry.description.isEmpty ? strings.packages : entry.description,
            charge(entry.amountCents)]),
      ],
      if (sections.openPositions.isNotEmpty) ...[
        ReportSubheading(strings.openPositions),
        ReportMuted(strings.pendingBadge),
        for (final position in sections.openPositions)
          ReportTableRow([_openPositionLabel(strings, position.event),
            position.isCredit ? credit(position.amountCents) : charge(position.amountCents)]),
      ],
      if (sections.creditEntries.isNotEmpty) ...[
        ReportSubheading(strings.paymentsCredits),
        for (final entry in sections.creditEntries)
          ReportTableRow([
            '${entry.description.isEmpty ? _creditFallback(strings, entry) : entry.description} '
                '(${dateFormat.format(entry.on.toLocal())})', credit(entry.amountCents)]),
      ],
      const ReportDivider(),
      ReportTableRow([strings.balance,
        statement.isSettled ? strings.settled : strings.outstanding,
        money(statement.balanceCents)], bold: true),
    ],
    footer: const [],
  );
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
    // Quota requests carry no amount, so they never surface as open
    // positions — the fallback label keeps the switch exhaustive.
    case EventType.expenseRepartition:
    case EventType.expenseSchedule:
    case EventType.usageCorrection:
    case EventType.usageRecordDelete:
    case EventType.paymentTermsChange:
    case EventType.quota:
    case EventType.invoiceWriteoff:
      case EventType.invoiceReminder:
      case EventType.priceNegotiation:
    case EventType.reservationDelete:
    case EventType.roleChange:
    case EventType.memberJoin:
    case EventType.reservation:
    case EventType.spaceReservation:
    case EventType.invoicePayment:
    case EventType.invoiceIssue:
    case EventType.invoiceVoid:
    case EventType.refund:
    case EventType.memberStatusChange:
    case EventType.subscriptionChange:
    case EventType.matrixChange:
    case EventType.adjustment:
    // #1088 — never an open position; the fallback keeps it exhaustive.
    case EventType.unknown:
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
