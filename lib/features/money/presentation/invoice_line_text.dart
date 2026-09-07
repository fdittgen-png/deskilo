// SPDX-License-Identifier: 0BSD
import '../../../l10n/app_localizations.dart';
import '../domain/invoice.dart';
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
  AppLocalizations? l10n,
  int pct, {
  required bool association,
  String month = '',
}) {
  if (month.isNotEmpty) {
    return association
        ? (l10n?.billParticipationMonth(month, pct) ?? '$month $pct%')
        : (l10n?.billSubscriptionMonth(month, pct) ??
            'Subscription $month $pct%');
  }
  return association
      ? (l10n?.billParticipation(pct) ?? 'Participation $pct%')
      : (l10n?.billSubscription(pct) ?? 'Subscription $pct%');
}

String invoiceLineText(
  AppLocalizations? l10n,
  InvoiceLine line, {
  bool association = false,
  /// #1000 — the invoice's period, so the recurring line names its month.
  String? period,
}) =>
    switch (line.kind) {
      'subscription' => subscriptionLabel(
          l10n, int.tryParse(line.label) ?? 0,
          association: association,
          month: monthNameOf(l10n?.localeName, period)),
      'overage' =>
        l10n?.billOverage(line.quantity) ?? '${line.quantity} extra half-days',
      'accessories' =>
        l10n?.billAccessorySupplements ?? 'Accessory supplements',
      'level' => l10n?.levelSupplementLabel ?? 'Level reservations',
      'office' => l10n?.officeSupplementLabel ?? 'Office reservations',
      'desk' => l10n?.deskSupplementLabel ?? 'Desk reservations',
      'adjustment' => line.label.isNotEmpty
          ? line.label
          : l10n?.invoiceLineAdjustment ?? 'Adjustment',
      // 0063 — credits: payments and expense reimbursements carry
      // their ledger note behind the category label.
      'payment' => line.label.isEmpty
          ? (l10n?.ledgerCategoryPayment ?? 'Payment')
          : '${l10n?.ledgerCategoryPayment ?? 'Payment'} · ${line.label}',
      'expense' => line.label.isEmpty
          ? (l10n?.ledgerCategoryExpense ?? 'Expense reimbursement')
          : '${l10n?.ledgerCategoryExpense ?? 'Expense reimbursement'}'
              ' · ${line.label}',
      _ => line.label,
    };

/// Localized wording for one annex activity row (0064): the ledger
/// category label, with the entry's own note behind it.
String annexEntryText(AppLocalizations? l10n, InvoiceDetailEntry entry) {
  final category = switch (entry.category) {
    'subscription' =>
      l10n?.ledgerCategorySubscription ?? 'Subscription',
    'overage' => l10n?.ledgerCategoryOverage ?? 'Overage',
    'expense' => l10n?.ledgerCategoryExpense ?? 'Expense reimbursement',
    'payment' => l10n?.ledgerCategoryPayment ?? 'Payment',
    'adjustment' => l10n?.ledgerCategoryAdjustment ?? 'Adjustment',
    'service' => l10n?.ledgerCategoryService ?? 'Service',
    _ => entry.category,
  };
  return entry.label.isEmpty ? category : '$category · ${entry.label}';
}
