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

/// How much of each payment the matches have used (#3671): the sum of the
/// parts its junction rows settle, pending rows included, and the credits
/// moved to another member, which exclude a whole payment. Built in one place
/// (`paymentUseOf` in `unassigned_money.dart`).
@immutable
class PaymentUse {
  const PaymentUse({this.usedCents = const {}, this.moved = const {}});

  /// Nothing is used: every payment is free with its full amount.
  static const none = PaymentUse();

  /// payment ledger id -> cents its matches have used.
  final Map<String, int> usedCents;

  /// The credits moved to another member.
  final Set<String> moved;

  /// What is left of [entry]: its amount minus what the matches used, and
  /// zero for a moved credit. Never negative.
  int remainingOf(LedgerEntry entry) {
    if (moved.contains(entry.id)) return 0;
    final left = entry.amountCents - (usedCents[entry.id] ?? 0);
    return left > 0 ? left : 0;
  }
}

/// A payment with something left of it (#3671): the ledger entry as it was
/// received, unchanged, and the three amounts a reader needs, so no reader
/// takes the entry's amount for what is left.
@immutable
class PaymentLeft {
  const PaymentLeft({
    required this.entry,
    required this.receivedCents,
    required this.assignedCents,
    required this.leftCents,
  });

  /// What [use] says of [entry]: received, assigned to invoices, left.
  factory PaymentLeft.of(LedgerEntry entry, PaymentUse use) {
    final left = use.remainingOf(entry);
    return PaymentLeft(
      entry: entry,
      receivedCents: entry.amountCents,
      assignedCents: entry.amountCents - left,
      leftCents: left,
    );
  }

  /// The ledger entry, as received.
  final LedgerEntry entry;

  /// What the payer paid.
  final int receivedCents;

  /// What invoices have taken of it (or a credit moved away).
  final int assignedCents;

  /// What no invoice has taken.
  final int leftCents;

  /// Whether invoices have already taken a part of it.
  bool get isPartlyUsed => assignedCents > 0;

  String get id => entry.id;
}

/// The payments of [memberId] that no invoice has taken (all of them, or
/// what is left of them): credits that are a payment or an adjustment (an
/// avoir's excess settles too), with something left (`PaymentUse`), and not
/// spent inside an invoice issued after them (a credit baked into an invoice
/// was spent there, #512). Each is a [PaymentLeft]: the entry as received and
/// what is left of it. Newest first by the day the money moved.
List<PaymentLeft> unmatchedPaymentsOf({
  required String memberId,
  required List<LedgerEntry> ledger,
  required PaymentUse use,
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
          use.remainingOf(entry) > 0 &&
          !baked(entry))
        PaymentLeft.of(entry, use),
  ]..sort((a, b) => b.entry.on.compareTo(a.entry.on));
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

/// A customer's credit: what is left of the payments no invoice has taken,
/// in one amount (the ledger holds one currency, the business's own).
int creditMinorOf(Iterable<PaymentLeft> unmatched) =>
    unmatched.fold(0, (sum, p) => sum + p.leftCents);

/// Whether a customer holds money no invoice has taken in a currency in which
/// they also have an open invoice: the ONE predicate of Payments to match, of
/// the customer page's main action, of the reminder queue's "check first" and
/// of the home's To-do count. We do not chase a customer whose money we hold
/// unassigned.
bool holdsUnassignedMoney({
  required Map<String, int> credit,
  required Iterable<Receivable> customerInvoices,
}) => credit.entries.any(
  (c) =>
      c.value > 0 &&
      customerInvoices.any(
        (r) => r.isOutstanding && r.currency == c.key && r.openMinor > 0,
      ),
);
