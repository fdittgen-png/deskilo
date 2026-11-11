// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- after an administrator confirms a customer's declared
// payment, the payment is on the customer's account. When it pays the
// invoice's open amount exactly, the invoice page matches it in the same
// gesture; this finds that payment: the newest payment of exactly that
// amount, of the same customer, that no match has consumed yet. A ledger
// entry does not name the event it came from, so another unconsumed
// payment of the same amount from the same customer is the same money and
// settles the invoice just as well. The account is kept in the workspace's
// currency: an invoice in another currency is never settled this way.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../domain/ledger_entry.dart';

/// The id of [customerId]'s payment in [ledger] to match after a
/// confirmation of [amountCents] on an invoice in [invoiceCurrency], or null
/// when none is free or the account's [accountCurrency] is another.
String? confirmedPaymentFor(
  Iterable<LedgerEntry> ledger, {
  required String customerId,
  required int amountCents,
  required String invoiceCurrency,
  required String accountCurrency,
  required Set<String> consumed,
}) {
  if (invoiceCurrency != accountCurrency) return null;
  LedgerEntry? newest;
  for (final entry in ledger) {
    if (entry.memberId == customerId &&
        entry.kind == LedgerKind.credit &&
        entry.category == LedgerCategory.payment &&
        entry.amountCents == amountCents &&
        !consumed.contains(entry.id) &&
        (newest == null || entry.createdAt.isAfter(newest.createdAt))) {
      newest = entry;
    }
  }
  return newest?.id;
}

/// What the Confirm gesture ended in.
enum ConfirmOutcome {
  /// The payment settled the invoice.
  matched,

  /// The match was recorded and waits for a second approval (0067).
  awaitsApproval,

  /// Confirmed only: the person matches the payment themselves.
  confirmedOnly,
}

/// The outcome after the match call, read from the invoice's [match] as the
/// server now has it.
ConfirmOutcome outcomeOfMatch(InvoiceMatch? match) => match == null
    ? ConfirmOutcome.confirmedOnly
    : match.pending
    ? ConfirmOutcome.awaitsApproval
    : ConfirmOutcome.matched;
