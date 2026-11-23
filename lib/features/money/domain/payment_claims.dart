// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — a payment that names the invoices it pays (its claim, 0797)
// can be refused by the business's server before anything is charged or
// recorded: each refusal has its code (DKC01–DKC15) and the app answers
// each by its own sentence, never as a failure of the app.

import '../../../core/data/dk_code.dart';

/// Why a claim was refused, by the server's code.
enum ClaimRefusal {
  /// DKC01 — no invoice named.
  empty(DkCode.dkc01),

  /// DKC02 — an invoice that is not mine to pay (or unknown, or of another
  /// business: one answer for all).
  notYours(DkCode.dkc02),

  /// DKC03 — invoices of several months.
  months(DkCode.dkc03),

  /// DKC04 — the payment's month is not the invoices'.
  otherMonth(DkCode.dkc04),

  /// DKC05 — an invoice that cannot take a payment now.
  cannotTake(DkCode.dkc05),

  /// DKC06 — an invoice already in another payment.
  alreadyInPayment(DkCode.dkc06),

  /// DKC07 — the amount is not what the invoices still owe.
  amount(DkCode.dkc07),

  /// DKC08 — not one of my payments.
  notMyPayment(DkCode.dkc08),

  /// DKC09 — the payment names no invoices to free (already withdrawn).
  nothingToFree(DkCode.dkc09),

  /// DKC10 — the payment is no longer being processed.
  notProcessing(DkCode.dkc10),

  /// DKC11 — an invoice in another currency than the payment.
  currency(DkCode.dkc11),

  /// DKC12 — a retry of a payment whose claim was withdrawn.
  withdrawn(DkCode.dkc12),

  /// DKC13 — the business already decided this declaration.
  decided(DkCode.dkc13),

  /// DKC15 — the request id of this payment was used for another one.
  requestChanged(DkCode.dkc15),

  /// A claim's code this version does not know (a newer server's).
  other('');

  const ClaimRefusal(this.code);
  final String code;

  /// The refusal of [code]: a claim's code this version does not know is
  /// [other]; null when it is not a claim's at all.
  static ClaimRefusal? of(String? code) {
    if (code == null || !RegExp(r'^DKC\d{2}$').hasMatch(code)) return null;
    return values.where((r) => r.code == code).firstOrNull ?? other;
  }
}

/// The server refused a payment's claim; nothing was charged or recorded.
class ClaimRefused implements Exception {
  const ClaimRefused(this.reason);
  final ClaimRefusal reason;

  @override
  String toString() => 'ClaimRefused(${reason.code})';
}

/// #3556 — the most invoices one payment names: the payment function's
/// limit (`MAX_CLAIMED_INVOICES` in create-payment-order/request.ts; a lint
/// keeps the two equal).
const int maxClaimedInvoices = 100;

/// #3556 — the invoices one payment names, of one month, and what they
/// still owe as the app read it (the server derives it again and refuses
/// another amount, DKC07).
class InvoiceClaim {
  const InvoiceClaim({
    required this.period,
    required this.amountCents,
    required this.invoiceIds,
  });

  final String period;
  final int amountCents;
  final List<String> invoiceIds;
}
