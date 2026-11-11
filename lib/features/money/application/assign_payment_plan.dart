// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3671 (part 2) -- one payment over several invoices: what the sheet works
// out before it calls the server. Pure: the invoices a payment may pay, the
// parts prefilled oldest first, the parts a person typed turned into the
// allocations the call takes, what the answer means and why a refusal came.
// The server stays the authority (`apply_payment_to_invoices`, 0718); this
// only keeps the person from sending what it will refuse.
import 'package:meta/meta.dart';

import '../../../core/data/server_error.dart';
import '../domain/invoice_commands.dart';
import 'receivables.dart';

/// The invoices of [customerId] in [currency] that [capacity] (the server's
/// `payment_invoice_capacity_v1`) says can take a part now, each with what
/// is still due on it, oldest due first (an invoice with no due date after
/// the others, then the oldest issued).
List<Receivable> invoicesToPay({
  required Iterable<Receivable> receivables,
  required String customerId,
  required String currency,
  required Map<String, InvoiceCapacity> capacity,
}) => _oldestDueFirst([
  for (final r in receivables)
    if (r.customerId == customerId && r.currency == currency)
      if (capacity[r.invoiceId] case final c? when c.canTake)
        r.withOpenMinor(c.stillDueCents),
]);

/// The invoices [capacity] lists that cannot take a part now: a payment of
/// them awaits approval. Shown, not offered.
List<Receivable> invoicesWaiting({
  required Iterable<Receivable> receivables,
  required String customerId,
  required Map<String, InvoiceCapacity> capacity,
}) => _oldestDueFirst([
  for (final r in receivables)
    if (r.customerId == customerId)
      if (capacity[r.invoiceId] case final c? when !c.canTake)
        r.withOpenMinor(c.stillDueCents),
]);

List<Receivable> _oldestDueFirst(List<Receivable> rows) => rows
    ..sort((a, b) {
      final ad = a.dueOn, bd = b.dueOn;
      final byDue = switch ((ad, bd)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        (final x?, final y?) => x.compareTo(y),
      };
      return byDue != 0 ? byDue : a.issuedOn.compareTo(b.issuedOn);
    });

/// What each of [oldestFirst] takes when [leftCents] is used up from the
/// oldest: an invoice gets what is due on it until the money is out, the last
/// one may get a part. Invoices after that get nothing (absent).
Map<String, int> prefillOldestFirst(
  List<Receivable> oldestFirst,
  int leftCents,
) {
  final parts = <String, int>{};
  var rest = leftCents;
  for (final r in oldestFirst) {
    if (rest <= 0) break;
    final part = r.openMinor < rest ? r.openMinor : rest;
    parts[r.invoiceId] = part;
    rest -= part;
  }
  return parts;
}

/// What the sheet's lines say of the parts typed (invoice id -> cents, only
/// the ticked rows with an amount).
@immutable
class PaymentPlan {
  const PaymentPlan({
    required this.leftCents,
    required this.parts,
    required this.dueCents,
  });

  /// What is left of the payment.
  final int leftCents;

  /// The parts, in the order of the list.
  final List<PaymentAllocation> parts;

  /// invoice id -> what is still due on it.
  final Map<String, int> dueCents;

  /// The parts added up.
  int get sumCents => parts.fold(0, (sum, p) => sum + p.amountCents);

  /// What stays as credit after the parts (negative when they are too much).
  int get staysCents => leftCents - sumCents;

  bool get overLeft => sumCents > leftCents;

  /// The invoices whose part is more than what is due on them.
  Set<String> get overDue => {
    for (final p in parts)
      if (p.amountCents > (dueCents[p.invoiceId] ?? 0)) p.invoiceId,
  };

  /// A part below what is due: it is accepted as partial and needs a note.
  bool get hasPartial =>
      parts.any((p) => p.amountCents < (dueCents[p.invoiceId] ?? 0));

  int get fullCount =>
      parts.where((p) => p.amountCents >= (dueCents[p.invoiceId] ?? 0)).length;

  int get partCount => parts.length - fullCount;

  /// Whether the call may be sent: at least one part, none beyond its
  /// invoice, together not beyond what is left, and a note for a partial.
  bool canSend({required String note}) =>
      parts.isNotEmpty &&
      !overLeft &&
      overDue.isEmpty &&
      (!hasPartial || note.trim().isNotEmpty);
}

/// Why the server refused (or the Demo, in the server's words); the sheet
/// says each in its own sentence, never the server's English.
enum PaymentRefusal {
  payer,
  business,
  currency,
  duplicate,
  partBeyondInvoice,
  sumBeyondLeft,
  usedMeanwhile,

  /// An invoice was paid, voided or replaced in the meantime (#3671).
  invoiceChanged,

  /// The payment was deducted on an invoice issued since: it pays nothing
  /// else, and trying again will not change that.
  creditDeducted,
  noteRequired,
  notAllowed,
  generic;

  /// The reason behind [error]: a server error's message, or the message of
  /// the Demo's `StateError`, matched on the wording of 0718 and of
  /// `match_invoice`; anything else is [generic].
  static PaymentRefusal of(Object error) {
    final said =
        (serverErrorMessage(error) ??
                (error is StateError ? error.message : '$error'))
            .toLowerCase();
    bool has(String part) => said.contains(part);
    if (has('not of this payer')) return payer;
    if (has('unknown payment') || has('no invoice to pay')) return business;
    if (has('business\'s currency')) return currency;
    if (has('appears twice')) return duplicate;
    if (has('positive amount') || has('more than what is due')) {
      return partBeyondInvoice;
    }
    if (has('more than what is left')) return sumBeyondLeft;
    if (has('add up to more than the payment') ||
        has('payment already matched')) {
      return usedMeanwhile;
    }
    if (has('invoice already matched') ||
        has('nothing is due on this invoice') ||
        has('invoice is voided') ||
        has('invoice is settled')) {
      return invoiceChanged;
    }
    if (has('credit already deducted')) return creditDeducted;
    if (has('note is required')) return noteRequired;
    if (has('not authenticated') || has('may not issue invoices')) {
      return notAllowed;
    }
    return generic;
  }
}
