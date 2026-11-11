// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3671 -- one payment over several invoices, in the demo: the rules and the
// words of `apply_payment_to_invoices` (0718). Every part is checked against
// its invoice and against what is left of the payment; each part is one
// match (exact when it equals what is due, else under_accepted); all of it or
// none of it is kept.
import 'package:deskilo/features/money/domain/invoice_commands.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../bank_unmatch_in.dart' show demoRecordMatchPayment;
import '../money_repository.dart';

/// What [DemoInvoiceCommands.matchInvoice] takes.
typedef DemoMatch = Future<void> Function({
  required String invoiceId,
  required String paymentLedgerId,
  required String resolution,
  String note,
  int? amountCents,
});

/// Applies [paymentLedgerId] to [allocations] on the money store [m], one
/// [match] per part; a refused part undoes the parts before it.
Future<PaymentApplied> applyPaymentInDemo(
  FakeMoneyRepository m,
  DemoMatch match, {
  required String paymentLedgerId,
  required List<PaymentAllocation> allocations,
  String note = '',
}) async {
  if (allocations.isEmpty) throw StateError('no invoice to pay');
  final payment = m.ledger
      .where(
        (e) =>
            e.id == paymentLedgerId &&
            e.kind == LedgerKind.credit &&
            (e.category == LedgerCategory.payment ||
                e.category == LedgerCategory.adjustment),
      )
      .firstOrNull;
  if (payment == null) throw StateError('unknown payment');
  final left = m.remainingOf(payment);
  if ({for (final a in allocations) a.invoiceId}.length != allocations.length) {
    throw StateError('an invoice appears twice');
  }
  // The money store knows no business: its currency is the invoices'.
  final currency = m.invoices
      .map((i) => i.currency)
      .firstWhere((c) => c.isNotEmpty, orElse: () => '');
  var total = 0;
  final parts = <(String invoiceId, int amount, bool exact)>[];
  for (final a in allocations) {
    if (a.amountCents <= 0) throw StateError('each part is a positive amount');
    final invoice = m.invoices.where((i) => i.id == a.invoiceId).firstOrNull;
    if (invoice == null || invoice.memberId != payment.memberId) {
      throw StateError('an invoice is not of this payer');
    }
    if (currency.isNotEmpty && invoice.currency != currency) {
      throw StateError("an invoice is not in the business's currency");
    }
    final due = _demoStillDue(m, invoice);
    if (a.amountCents > due) {
      throw StateError('a part is more than what is due on its invoice');
    }
    total += a.amountCents;
    if (total > left) {
      throw StateError('the parts are more than what is left of the payment');
    }
    parts.add((invoice.id, a.amountCents, a.amountCents == due));
  }
  final matches = Map.of(m.invoiceMatchesStore);
  final used = Map.of(m.usedPaymentCents);
  final rows = {
    for (final e in m.invoiceMatchPaymentsStore.entries)
      e.key: List.of(e.value),
  };
  final ledgerLength = m.ledger.length;
  final events = m.eventRepository?.events;
  final eventLength = events?.length;
  try {
    for (final (invoiceId, amount, exact) in parts) {
      final before = m.invoiceMatchesStore[invoiceId];
      await match(
        invoiceId: invoiceId,
        paymentLedgerId: paymentLedgerId,
        resolution: exact ? 'exact' : 'under_accepted',
        note: note,
        amountCents: amount,
      );
      // The junction keeps one row per part, as the server does (#2380).
      demoRecordMatchPayment(m, invoiceId, before);
    }
  } on Object {
    m.invoiceMatchesStore
      ..clear()
      ..addAll(matches);
    m.usedPaymentCents
      ..clear()
      ..addAll(used);
    m.invoiceMatchPaymentsStore
      ..clear()
      ..addAll(rows);
    m.ledger.removeRange(ledgerLength, m.ledger.length);
    if (events != null && eventLength != null) {
      events.removeRange(eventLength, events.length);
    }
    rethrow;
  }
  return PaymentApplied(invoices: parts.length, leftCents: left - total);
}

/// What is still due on [invoice] in the demo, as `invoice_still_due_cents`
/// (0718): the total, less what its match paid, less the further parts that
/// await approval (a pending match's first part is already its paid amount).
int _demoStillDue(FakeMoneyRepository m, Invoice invoice) {
  final match = m.invoiceMatchesStore[invoice.id];
  final held = match?.pending ?? false;
  final waiting = held
      ? 0
      : (m.invoiceMatchPaymentsStore[invoice.id] ?? const <InvoiceMatch>[])
            .where((p) => p.pending)
            .fold(0, (sum, p) => sum + p.paidCents);
  return invoice.totalCents - (match?.paidCents ?? 0) - waiting;
}

/// The open invoices of [paymentLedgerId]'s payer and what each can take of
/// it now, as `payment_invoice_capacity_v1` (0718), oldest issued first.
List<InvoiceCapacity> paymentCapacityInDemo(
  FakeMoneyRepository m,
  String paymentLedgerId,
) {
  final payment = m.ledger.where((e) => e.id == paymentLedgerId).firstOrNull;
  if (payment == null) throw StateError('unknown payment');
  final currency = m.invoices
      .map((i) => i.currency)
      .firstWhere((c) => c.isNotEmpty, orElse: () => '');
  final out = <(DateTime, InvoiceCapacity)>[];
  for (final i in m.invoices) {
    if (i.memberId != payment.memberId ||
        (currency.isNotEmpty && i.currency != currency) ||
        i.isVoided ||
        i.settledByInvoiceId != null) {
      continue;
    }
    final match = m.invoiceMatchesStore[i.id];
    final held = match?.pending ?? false;
    if (match != null &&
        !held &&
        (match.resolution != 'under_accepted' || match.writeoffAt != null)) {
      continue;
    }
    final waiting =
        held ||
        (m.invoiceMatchPaymentsStore[i.id] ?? const <InvoiceMatch>[]).any(
          (p) => p.pending,
        );
    final due = _demoStillDue(m, i);
    if (due <= 0 && !waiting) continue;
    out.add((
      i.issuedAt,
      InvoiceCapacity(invoiceId: i.id, stillDueCents: due, canTake: due > 0 && !held),
    ));
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, c) in out) c];
}
