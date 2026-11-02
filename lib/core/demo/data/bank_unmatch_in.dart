// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 (0650) -- the Demo's undoing of a bank match of money in: the same
// refusals, in the same order, as `unmatch_bank_line_in_v1`, and the same
// effect when none applies. The match goes, the payment credit stays, the
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

/// What an undoing acts on.
typedef DemoUnmatchTarget = ({
  Invoice invoice,
  InvoiceMatch match,
  LedgerEntry payment,
});

/// A refusal carrying the server's code, so the screens word it as they do.
PostgrestException _refusal(String code, String message) =>
    PostgrestException(message: message, code: code);

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

/// The match [line] holds, or the refusal the server would answer.
DemoUnmatchTarget demoUnmatchTarget({
  required FakeMoneyRepository money,
  required StoredBankLine line,
  required String? paymentId,
  required DateTime? closedThrough,
}) {
  if (!line.isMoneyIn) {
    throw _refusal('DKB02', 'money out settles no invoice: undo its reconciliation');
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
    throw _refusal('DKB01', 'this match awaits its validation: reject it there');
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
  if (match.paymentLedgerId != paymentId || match.paidCents != payment.amountCents) {
    throw _refusal('DKB05', 'other payments are matched to this invoice');
  }
  if (closedThrough != null && !match.matchedAt.isAfter(closedThrough)) {
    throw _refusal(
      'DKB06',
      'this payment is dated inside a closed period of the books',
    );
  }
  return (invoice: invoice, match: match, payment: payment);
}

/// The match goes, the credit stays, the undoing is put on the timeline.
void demoApplyUnmatch(
  FakeMoneyRepository money,
  DemoUnmatchTarget target,
  String reason,
  DateTime today,
) {
  final invoice = target.invoice;
  money.invoiceMatchesStore.remove(invoice.id);
  money.consumedPaymentIds.remove(target.payment.id);
  final events = money.eventRepository;
  if (events == null) return;
  events.events.add(
    WorkspaceEvent(
      id: 'invrev-${events.events.length + 1}',
      workspaceId: invoice.workspaceId,
      type: EventType.invoicePaymentReversed,
      action: EventAction.created,
      actorMemberId: 'member-1',
      subjectMemberId: invoice.memberId,
      payload: {
        'invoice_id': invoice.id,
        'number': invoice.number,
        'payment_ledger_id': target.payment.id,
        'amount_cents': target.payment.amountCents,
        'resolution': target.match.resolution,
        'reason': reason,
      },
      status: EventStatus.applied,
      createdAt: today,
    ),
  );
}
