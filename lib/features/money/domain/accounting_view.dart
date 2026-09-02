// SPDX-License-Identifier: 0BSD
import 'billing_rules.dart';
import 'invoice.dart';

/// #831 — the ACCOUNTING view of the invoices: what the accountant's
/// software must receive, as opposed to what the app shows.
///
/// A settlement (regrouping) is a management document — the one the
/// member pays, chases and reads — but it is NOT a sale: the revenue,
/// the VAT and the receivables live on the invoices it regroups, which
/// were issued, numbered and declared. So for every export and every
/// declaration the settlement is transparent: it leaves the list, and
/// the payment matched to it is ALLOCATED to its sources, oldest first
/// and to the cent, so each source's receivable is lettered exactly as
/// if it had been paid on its own. A partial payment of the settlement
/// pays the oldest sources first and leaves the youngest open; a
/// pending match (awaiting validation) allocates nothing yet.
///
/// The app shows the same truth from the member's side: a regrouped
/// invoice reads as "paid through INV-…" once its settlement is paid.
({List<Invoice> invoices, Map<String, InvoiceMatch> matches}) accountingView(
  List<Invoice> invoices,
  Map<String, InvoiceMatch> matches,
) {
  final effective = Map<String, InvoiceMatch>.of(matches);
  final kept = <Invoice>[];
  for (final invoice in invoices) {
    if (invoice.kind == InvoiceKind.settlement) {
      // Its allocation, never the document itself.
      effective.remove(invoice.id);
      if (invoice.isVoided) continue;
      final match = matches[invoice.id];
      if (match == null || match.status == 'pending') continue;
      effective.addAll(allocateSettlementPayment(invoice, match));
      continue;
    }
    kept.add(invoice);
  }
  return (invoices: kept, matches: effective);
}

/// The settlement's [match] spread over its sources in the snapshot's
/// order (issue order): every source takes what it is owed until the
/// paid amount runs out. A fully covered source gets the settlement's
/// own resolution; a partly covered one reads as a partial payment; an
/// uncovered one gets nothing and stays open.
Map<String, InvoiceMatch> allocateSettlementPayment(
  Invoice settlement,
  InvoiceMatch match,
) {
  final out = <String, InvoiceMatch>{};
  var left = match.paidCents;
  for (final source in settlement.settles) {
    if (left <= 0) break;
    final take = left < source.totalCents ? left : source.totalCents;
    if (take <= 0) continue;
    final covered = take >= source.totalCents;
    out[source.invoiceId] = match.copyWith(
      invoiceId: source.invoiceId,
      paidCents: take,
      resolution: covered
          ? (match.resolution == 'under_accepted' ? 'exact' : match.resolution)
          : 'under_accepted',
      note: [
        if (match.note.isNotEmpty) match.note,
        'via ${settlement.number}',
      ].join(' — '),
    );
    left -= take;
  }
  return out;
}

/// #831 — how a regrouped source stands, seen through its settlement:
/// the settlement's confirmed match, allocated, or null while the
/// settlement is unpaid or its match awaits validation.
InvoiceMatch? effectiveMatchOf(
  Invoice source,
  Invoice settlement,
  InvoiceMatch? settlementMatch,
) {
  if (settlementMatch == null || settlementMatch.status == 'pending') {
    return null;
  }
  return allocateSettlementPayment(settlement, settlementMatch)[source.id];
}
