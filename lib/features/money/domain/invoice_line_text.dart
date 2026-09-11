// SPDX-License-Identifier: 0BSD
import '../domain/invoice.dart';
import 'report_strings.dart';
import 'period_label.dart';

/// Localized wording for one DERIVED invoice position (0062): the kind
/// names the tracked source, the label carries its data. Reuses the
/// bill's own section labels so the invoice reads exactly like the
/// monthly bill it summarizes. Legacy 0060 free-form lines (empty kind)
/// and service/package lines render their stored text verbatim.
/// #870 — what the recurring position is CALLED.
///
/// A non-profit collects a member participation; only a commercial
/// space sells a subscription. The distinction is not cosmetic: on a
/// French association's invoice 'abonnement' reads as a commercial
/// supply and is exactly the wording that argues the association into
/// the VAT-liable trading sector. So the word follows the seller kind,
/// and every surface that names the position uses this one function.
///
/// #1000 — with [month] the position names the month it covers
/// ('Septembre 100 %'), so every invoice reads as the month it is for.
String subscriptionLabel(
  ReportStrings strings,
  int pct, {
  required bool association,
  String month = '',
}) {
  if (month.isNotEmpty) {
    return association
        ? strings.participationMonth(month, pct)
        : strings.subscriptionMonth(month, pct);
  }
  return association
      ? strings.participation(pct)
      : strings.subscription(pct);
}

String invoiceLineText(
  ReportStrings strings,
  InvoiceLine line, {
  bool association = false,
  /// #1000 — the invoice's period, so the recurring line names its month.
  String? period,
}) =>
    switch (line.kind) {
      'subscription' => subscriptionLabel(
          strings, int.tryParse(line.label) ?? 0,
          association: association,
          month: monthNameOf(strings.localeName, period)),
      'overage' =>
        strings.overage(line.quantity),
      'accessories' =>
        strings.accessorySupplements,
      'level' => strings.levelReservations,
      'office' => strings.officeReservations,
      'desk' => strings.deskReservations,
      'adjustment' => line.label.isNotEmpty
          ? line.label
          : strings.lineAdjustment,
      // 0063 — credits: payments and expense reimbursements carry
      // their ledger note behind the category label.
      'payment' => line.label.isEmpty
          ? (strings.categoryPayment)
          : '${strings.categoryPayment} · ${line.label}',
      'expense' => line.label.isEmpty
          ? (strings.categoryExpense)
          : '${strings.categoryExpense}'
              ' · ${line.label}',
      _ => line.label,
    };

/// Localized wording for one annex activity row (0064): the ledger
/// category label, with the entry's own note behind it.
String annexEntryText(ReportStrings strings, InvoiceDetailEntry entry) {
  final category = switch (entry.category) {
    'subscription' =>
      strings.categorySubscription,
    'overage' => strings.categoryOverage,
    'expense' => strings.categoryExpense,
    'payment' => strings.categoryPayment,
    'adjustment' => strings.categoryAdjustment,
    'service' => strings.categoryService,
    _ => entry.category,
  };
  return entry.label.isEmpty ? category : '$category · ${entry.label}';
}
