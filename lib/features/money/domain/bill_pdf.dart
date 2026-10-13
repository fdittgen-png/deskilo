// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/i18n/money_format.dart';
import '../../events/domain/workspace_event.dart';
import 'bill_sections.dart';
import 'invoice_pdf.dart';
import 'invoice_report.dart';
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


/// What one bill renders from: the statement with its grouped
/// [sections], and the words around them. One object for the quick view
/// and the PDF, so the two cannot disagree.
class BillDocument {
  const BillDocument({
    required this.statement,
    required this.sections,
    required this.currencyCode,
    required this.workspaceName,
    required this.memberName,
    required this.periodLabel,
    required this.strings,
    this.locale,
    this.report,
    this.reportImages = const {},
  });

  final Statement statement;
  final BillSections sections;
  final String currencyCode;
  final String workspaceName;
  final String memberName;
  final String periodLabel;
  final BillPdfStrings strings;

  /// #711 — the DOCUMENT locale, passed explicitly: a PDF is rendered
  /// for its reader, not for whoever pressed the button.
  final String? locale;

  /// The owner's report bands already rendered for this bill, with their
  /// images; null = the built-in layout ([buildBillReport]).
  final InvoiceReport? report;
  final Map<String, Uint8List> reportImages;
}

/// Renders [bill] — the exact grouping the on-screen bill shows via
/// [buildBillSections] — as an A4 PDF (#133, ADR 0008).
///
/// [baseFont]/[boldFont] must be real TTFs (the app embeds Roboto from
/// assets/fonts): the pdf package's base-14 Type1 fonts cannot encode
/// '€' (U+20AC) or the typographic minus '−' (U+2212) the bill uses.
Future<Uint8List> buildBillPdf(
  BillDocument bill, {
  required pw.Font baseFont,
  required pw.Font boldFont,
  String pageLabel = 'Page',
  String watermark = '',
}) async {
  return buildBandedLetterPdf(
    report: bill.report ?? buildBillReport(bill),
    pageLabel: pageLabel, documentTitle: bill.strings.title,
    baseFont: baseFont, boldFont: boldFont, watermark: watermark,
    reportImages: bill.reportImages,
  );
}

/// The same complete bill content drives quick view and PDF output.
InvoiceReport buildBillReport(BillDocument bill) {
  final rows = _BillRows(bill);
  return InvoiceReport(
    header: rows.header(),
    continuation: rows.continuation(),
    body: [
      ...rows.charges(),
      ...rows.services(),
      ...rows.packages(),
      ...rows.openPositions(),
      ...rows.credits(),
      const ReportDivider(),
      rows.balance(),
    ],
    footer: const [],
  );
}

/// The bill's blocks, one method per section.
class _BillRows {
  _BillRows(this.bill)
      : currency = moneyFormat(bill.currencyCode, locale: bill.locale),
        dateFormat = DateFormat.yMMMd(bill.locale);

  final BillDocument bill;
  final MoneyFormat currency;
  final DateFormat dateFormat;

  BillPdfStrings get strings => bill.strings;
  Statement get statement => bill.statement;
  BillSections get sections => bill.sections;

  String charge(int cents) => '−${currency.formatMinor(cents)}';
  String credit(int cents) => '+${currency.formatMinor(cents)}';

  List<ReportBlock> header() => [
        ReportHeading(bill.workspaceName),
        ReportSubheading(strings.title),
        ReportMuted('${bill.memberName} — ${bill.periodLabel}'),
        const ReportDivider(),
      ];

  List<ReportBlock> continuation() => [
        ReportText('${bill.workspaceName} — ${strings.title} — '
            '${bill.memberName} — ${bill.periodLabel}'),
        const ReportDivider(),
      ];

  List<ReportBlock> charges() => [
        ReportTableRow([strings.subscription, charge(statement.feeCents)],
            bold: true),
        ReportMuted(strings.entitlement),
        if (statement.extraHalfDays > 0)
          ReportTableRow([strings.overage, charge(statement.overageCents)]),
        if (statement.accessorySupplementCents > 0)
          ReportTableRow([
            strings.accessorySupplements,
            charge(statement.accessorySupplementCents),
          ]),
      ];

  List<ReportBlock> services() => [
        if (sections.serviceEntries.isNotEmpty) ...[
          ReportSubheading(strings.services),
          for (final entry in sections.serviceEntries)
            ReportTableRow([
              if (entry.description.isEmpty) strings.serviceFallback else entry.description,
              charge(entry.amountCents),
            ]),
          ReportTableRow(
              [strings.servicesTotal, charge(sections.servicesTotalCents)],
              bold: true),
        ],
      ];

  List<ReportBlock> packages() => [
        if (sections.packageEntries.isNotEmpty) ...[
          ReportSubheading(strings.packages),
          for (final entry in sections.packageEntries)
            ReportTableRow([
              if (entry.description.isEmpty) strings.packages else entry.description,
              charge(entry.amountCents),
            ]),
        ],
      ];

  List<ReportBlock> openPositions() => [
        if (sections.openPositions.isNotEmpty) ...[
          ReportSubheading(strings.openPositions),
          ReportMuted(strings.pendingBadge),
          for (final position in sections.openPositions)
            ReportTableRow([
              _openPositionLabel(strings, position.event),
              if (position.isCredit)
                credit(position.amountCents)
              else
                charge(position.amountCents),
            ]),
        ],
      ];

  List<ReportBlock> credits() => [
        if (sections.creditEntries.isNotEmpty) ...[
          ReportSubheading(strings.paymentsCredits),
          for (final entry in sections.creditEntries)
            ReportTableRow([
              '${entry.description.isEmpty ? _creditFallback(strings, entry) : entry.description} '
                  '(${dateFormat.format(entry.on.toLocal())})',
              credit(entry.amountCents),
            ]),
        ],
      ];

  ReportBlock balance() => ReportTableRow([
        strings.balance,
        if (statement.isSettled) strings.settled else strings.outstanding,
        currency.formatMinor(statement.balanceCents),
      ], bold: true);
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
