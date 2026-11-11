// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- "Payments to match": a payment that reached a customer's
// account and that no invoice has taken yet, and the invoices of the same
// customer it could settle. Two pure questions, answered from what the money
// screens already read (the member's ledger, the payments already consumed by
// a match, the member's invoices): the rules of what counts as a payment
// still free are the ones the match dialog has always used (0068, #506, #512).
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:meta/meta.dart';

import '../domain/ledger_entry.dart';
import 'receivables.dart';

/// The payments of [memberId] that no invoice has taken: credits that are a
/// payment or an adjustment (an avoir's excess settles too), not consumed by
/// a match, and not spent inside an invoice issued after them (a credit baked
/// into an invoice was spent there, #512). Newest first by the day the money
/// moved.
List<LedgerEntry> unmatchedPaymentsOf({
  required String memberId,
  required List<LedgerEntry> ledger,
  required Set<String> consumed,
  required List<Invoice> invoices,
}) {
  bool baked(LedgerEntry entry) => invoices.any(
    (i) =>
        i.memberId == memberId &&
        !i.isVoided &&
        i.period == entry.period &&
        i.issuedAt.isAfter(entry.createdAt),
  );
  return [
    for (final entry in ledger)
      if (entry.memberId == memberId &&
          entry.kind == LedgerKind.credit &&
          (entry.category == LedgerCategory.payment ||
              entry.category == LedgerCategory.adjustment) &&
          !consumed.contains(entry.id) &&
          !baked(entry))
        entry,
  ]..sort((a, b) => b.on.compareTo(a.on));
}

/// How a payment settles an invoice, as the server's resolution names it.
enum MatchFit {
  /// The payment is the open amount: one tap.
  exact,

  /// Anything else: the match dialog asks how to settle the difference.
  needsDecision,
}

/// An invoice a payment could settle.
@immutable
class MatchCandidate {
  const MatchCandidate(this.invoice, this.fit);

  final Receivable invoice;
  final MatchFit fit;
}

/// The open invoices of the customer in the payment's currency, the ones the
/// payment settles exactly first, then the oldest: what the person is most
/// likely to mean.
List<MatchCandidate> candidatesFor({
  required int paymentMinor,
  required String currency,
  required Iterable<Receivable> customerInvoices,
}) {
  final open = [
    for (final r in customerInvoices)
      if (r.isOutstanding && r.currency == currency && r.openMinor > 0) r,
  ];
  int rank(Receivable r) => r.openMinor == paymentMinor ? 0 : 1;
  open.sort((a, b) {
    final byFit = rank(a).compareTo(rank(b));
    return byFit != 0 ? byFit : a.issuedOn.compareTo(b.issuedOn);
  });
  return [
    for (final r in open)
      MatchCandidate(
        r,
        r.openMinor == paymentMinor ? MatchFit.exact : MatchFit.needsDecision,
      ),
  ];
}
