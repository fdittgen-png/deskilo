// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3070 — what a supplier has cost this year and when its last bill came,
// read from the purchase documents: only approved bills and credit notes
// count, a credit note takes away, and only the currency of the supplier's
// most recent bill is summed (a mix of currencies is never added up).
import 'purchase.dart';

class SupplierStanding {
  const SupplierStanding({
    required this.lastBillOn,
    required this.yearGrossCents,
    required this.currency,
  });

  final DateTime? lastBillOn;
  final int yearGrossCents;
  final String currency;
}

/// The most rows one read returns before the server cuts the answer without
/// an error (PostgREST max_rows, 1000 on Supabase). A list that long may be
/// missing its oldest documents.
const _purchaseReadCap = 1000;

/// Empty when [purchases] reached [_purchaseReadCap]: a truncated sum must
/// never be printed as what a supplier cost.
Map<String, SupplierStanding> supplierStandings(
  Iterable<PurchaseSummary> purchases, {
  required int year,
}) {
  if (purchases.length >= _purchaseReadCap) return const {};
  final byId = <String, List<PurchaseSummary>>{};
  for (final p in purchases) {
    final id = p.supplierId;
    if (id == null || p.state != PurchaseState.approved) continue;
    if (p.kind == PurchaseKind.memberReceipt) continue;
    (byId[id] ??= []).add(p);
  }
  return {
    for (final MapEntry(:key, :value) in byId.entries)
      key: _standing(value, year),
  };
}

SupplierStanding _standing(List<PurchaseSummary> docs, int year) {
  final bills = [
    for (final p in docs)
      if (p.kind == PurchaseKind.bill && p.receivedOn != null) p,
  ]..sort((a, b) => b.receivedOn!.compareTo(a.receivedOn!));
  final currency = bills.firstOrNull?.currency ?? docs.first.currency;
  var total = 0;
  for (final p in docs) {
    if (p.currency != currency || p.receivedOn?.year != year) continue;
    total += p.kind == PurchaseKind.creditNote ? -p.grossCents : p.grossCents;
  }
  return SupplierStanding(
    lastBillOn: bills.firstOrNull?.receivedOn,
    yearGrossCents: total,
    currency: currency,
  );
}
