// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 (0650, 0657-0660) -- the Demo's undoing of a bank match of money in: the
// same refusals, in the same order, as `unmatch_bank_line_in_v1`, and the
// same effect when none applies. The payment's part of the match goes (the
// whole match when it was the last payment), the payment credit stays, the
// undoing is a record on the timeline and is not a payment.
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../features/events/domain/workspace_event.dart';
import '../../../features/money/domain/bank/bank_records.dart';
import '../../../features/money/domain/invoice.dart';
import '../../../features/money/domain/ledger_entry.dart';
import 'money_repository.dart';

/// A match undone, as the server records it.
typedef DemoUnmatch = ({
  String lineId,
  String invoiceId,
  String paymentId,
  String reason,
});

/// What an undoing acts on: the match, the payment undone (its row) and the
/// payments that remain, oldest first.
typedef DemoUnmatchTarget = ({
  Invoice invoice,
  InvoiceMatch match,
  LedgerEntry payment,
  InvoiceMatch row,
  List<InvoiceMatch> rest,
});

/// A refusal carrying the server's code, so the screens word it as they do.
PostgrestException _refusal(String code, String message) =>
    PostgrestException(message: message, code: code);

/// The right that matches a payment is the right that undoes the match.
void demoRequireIssueRight({required bool allowed}) {
  if (!allowed) throw _refusal('42501', 'issuing invoices is not allowed');
}

/// Whether this request was answered before (and so changes nothing); the
/// refusals of a request id used for another line and of a blank reason.
bool demoUnmatchIsReplay(
  Map<String, DemoUnmatch> done,
  String requestId,
  String lineId,
  String reason,
) {
  final earlier = done[requestId];
  if (earlier != null) {
    if (earlier.lineId != lineId) {
      throw _refusal(
        '22023',
        'this request id was already used for a different request',
      );
    }
    return true;
  }
  if (reason.isEmpty) throw _refusal('22023', 'state why the match is undone');
  return false;
}

/// #2380 (0657) — after a bank line matched [invoiceId], keeps the payment's
/// own row as invoice_match_payments does: [before] is the match that stood
/// (null for the first payment), a standing match without rows being its one
/// earlier payment. The new row is what the aggregate grew by.
void demoRecordMatchPayment(
  FakeMoneyRepository money,
  String invoiceId,
  InvoiceMatch? before,
) {
  final after = money.invoiceMatchesStore[invoiceId]!;
  final row = after.copyWith(paidCents: after.paidCents - (before?.paidCents ?? 0));
  final rows = money.invoiceMatchPaymentsStore;
  rows[invoiceId] = [
    if (before != null) ...(rows[invoiceId] ?? [before]),
    row,
  ];
}

/// The payment undone and the payments that remain (oldest first), or the
/// refusal the server would answer: DKB05 when the rows do not add up to
/// the match, DKB07 when the first payment would go before a later one.
({InvoiceMatch row, List<InvoiceMatch> rest}) _paymentRows(
  FakeMoneyRepository money,
  String invoiceId,
  InvoiceMatch match,
  String paymentId,
) {
  // A match seeded without its payment rows is its one payment.
  final rows = money.invoiceMatchPaymentsStore[invoiceId] ?? [match];
  final row = rows.where((r) => r.paymentLedgerId == paymentId).firstOrNull;
  if (row == null ||
      rows.fold<int>(0, (sum, r) => sum + r.paidCents) != match.paidCents) {
    throw _refusal(
      'DKB05',
      'the payments of this invoice do not add up to its match',
    );
  }
  final rest = [
    for (final r in rows)
      if (!identical(r, row)) r,
  ];
  // 0660 — the first payment goes last.
  if (identical(row, rows.first) && rest.isNotEmpty) {
    throw _refusal('DKB07', 'undo the later payments of this invoice first');
  }
  return (row: row, rest: rest);
}

/// The match [line] holds, or the refusal the server would answer.
DemoUnmatchTarget demoUnmatchTarget({
  required FakeMoneyRepository money,
  required StoredBankLine line,
  required String? paymentId,
  required DateTime? closedThrough,
}) {
  if (!line.isMoneyIn) {
    throw _refusal(
      'DKB02',
      'money out settles no invoice: undo its reconciliation',
    );
  }
  final invoiceId = line.invoiceId;
  final match = invoiceId == null ? null : money.invoiceMatchesStore[invoiceId];
  if (invoiceId == null ||
      paymentId == null ||
      match == null ||
      (line.status != BankLineStatus.matched &&
          line.status != BankLineStatus.pending)) {
    throw _refusal('DKB01', 'this movement settles no invoice');
  }
  if (match.pending || line.status == BankLineStatus.pending) {
    throw _refusal(
      'DKB01',
      'this match awaits its validation: reject it there',
    );
  }
  final invoice = money.invoices.firstWhere((i) => i.id == invoiceId);
  final payment = money.ledger.firstWhere((e) => e.id == paymentId);
  if (match.resolution == 'over_credit_note' ||
      match.writeoffAt != null ||
      invoice.settledByInvoiceId != null ||
      money.invoices.any((i) => i.settledByInvoiceId == invoiceId)) {
    throw _refusal(
      'DKB04',
      'this match did more than link a payment: it cannot be undone here',
    );
  }
  final (:row, :rest) = _paymentRows(money, invoiceId, match, paymentId);
  bool closed(DateTime at) =>
      closedThrough != null &&
      !DateTime(at.year, at.month, at.day).isAfter(closedThrough);
  if (closed(row.matchedAt) ||
      closed(match.matchedAt) ||
      (rest.isNotEmpty && closed(rest.last.matchedAt))) {
    throw _refusal(
      'DKB06',
      'this payment is dated inside a closed period of the books',
    );
  }
  return (
    invoice: invoice,
    match: match,
    payment: payment,
    row: row,
    rest: rest,
  );
}

/// The match goes, the credit stays, the undoing is put on the timeline.
void demoApplyUnmatch(
  FakeMoneyRepository money,
  DemoUnmatchTarget target,
  String actorMemberId,
  DateTime today, {
  required String reason,
}) {
  final invoice = target.invoice;
  final rest = target.rest;
  if (rest.isEmpty) {
    money.invoiceMatchesStore.remove(invoice.id);
    money.invoiceMatchPaymentsStore.remove(invoice.id);
  } else {
    // What the remaining payments make the match: their sum, and the
    // latest one's link, note and date; below the total, a part payment.
    final latest = rest.last;
    final paid = target.match.paidCents - target.row.paidCents;
    money.invoiceMatchPaymentsStore[invoice.id] = rest;
    money.invoiceMatchesStore[invoice.id] = target.match.copyWith(
      paidCents: paid,
      resolution: paid < invoice.totalCents
          ? 'under_accepted'
          : latest.resolution,
      note: latest.note.isEmpty ? reason : latest.note,
      paymentLedgerId: latest.paymentLedgerId,
      matchedAt: latest.matchedAt,
      byName: latest.byName,
    );
  }
  money.consumedPaymentIds.remove(target.payment.id);
  final events = money.eventRepository;
  if (events == null) return;
  events.events.add(
    WorkspaceEvent(
      id: 'invrev-${events.events.length + 1}',
      workspaceId: invoice.workspaceId,
      type: EventType.invoicePaymentReversed,
      action: EventAction.created,
      actorMemberId: actorMemberId,
      // The acting staff member, never the invoice's member: the subject
      // reads the events about them, and the reason must not reach the payer.
      subjectMemberId: actorMemberId,
      payload: {
        'invoice_id': invoice.id,
        'number': invoice.number,
        'payment_ledger_id': target.payment.id,
        'amount_cents': target.row.paidCents,
        'resolution': target.row.resolution,
      },
      status: EventStatus.applied,
      createdAt: today,
    ),
  );
}
