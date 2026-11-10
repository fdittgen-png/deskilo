// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 — the owner's invoicing reads its invoices as [Receivable]s:
// each issued invoice with its match, its reminders and the dunning rules,
// through the same journey the invoice page draws, so a status here and a
// status there cannot disagree. A document folded into a settlement and a
// credit note are not receivables of their own: the settlement is chased,
// the credit note is the workspace's debt.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../events/domain/workspace_event.dart';
import '../../application/receivables.dart';
import '../../domain/dunning.dart';
import '../invoice_journey.dart';
import '../invoice_status.dart';

/// The receivables of [invoices] (every issued document of the workspace),
/// read with their [matches], the [reminders] sent and the dunning [rules]
/// at [now], with the payment [events] of the feed (a payment declared and
/// not yet confirmed). [dayOf] is the business's calendar day of an instant.
List<Receivable> receivablesOf({
  required Iterable<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required Map<String, ({int count, DateTime last})> reminders,
  required DunningRules rules,
  required DateTime now,
  required DateTime Function(DateTime instant) dayOf,
  Iterable<WorkspaceEvent> events = const [],
}) => [
  for (final invoice in invoices)
    if (invoice.totalCents > 0 && invoice.settledByInvoiceId == null)
      _receivableOf(
        invoice,
        matches[invoice.id],
        reminders[invoice.id],
        rules,
        now,
        dayOf,
        events,
      ),
];

Receivable _receivableOf(
  Invoice invoice,
  InvoiceMatch? match,
  ({int count, DateTime last})? reminder,
  DunningRules rules,
  DateTime now,
  DateTime Function(DateTime) dayOf,
  Iterable<WorkspaceEvent> events,
) {
  final journey = InvoiceJourney.of(
    invoice: invoice,
    match: match,
    reminder: reminder,
    rules: rules,
    now: now,
    facts: journeyFactsOf(invoice, match, events),
  );
  final stage = switch (journey.lifecycle) {
    InvoiceLifecycle.open ||
    InvoiceLifecycle.awaitingValidation => ReceivableStage.open,
    InvoiceLifecycle.partiallyPaid => ReceivableStage.partlyPaid,
    InvoiceLifecycle.paid => ReceivableStage.paid,
    InvoiceLifecycle.refunded => ReceivableStage.credited,
    InvoiceLifecycle.remainderCancelled ||
    InvoiceLifecycle.erroneous => ReceivableStage.cancelled,
  };
  // The payment's own step, in the journey's words (invoice_journey.dart).
  final move = journey.move;
  final declared = move == InvoiceMove.adminConfirmsPayment;
  final declaration = declared ? _declarationOf(invoice, events) : null;
  return Receivable(
    invoiceId: invoice.id,
    customerId: invoice.memberId,
    customerName: invoice.memberName,
    number: invoice.number,
    currency: invoice.currency,
    totalMinor: invoice.totalCents,
    openMinor: stage == ReceivableStage.paid ? 0 : journey.remainingCents,
    issuedOn: dayOf(invoice.issuedAt),
    dueOn: dayOf(journey.dueOn),
    stage: stage,
    paymentDeclared: declared,
    declaredEventId: declaration?.id,
    declaredOn: declaration == null ? null : dayOf(_paidOn(declaration)),
    awaitingCustomerConfirmation: move == InvoiceMove.memberConfirmsPayment,
    paymentToMatch: move == InvoiceMove.issuerMatchesPayment,
    awaitingSecondApproval:
        move == InvoiceMove.validatorsDecideMatch ||
        move == InvoiceMove.validatorsDecideWriteoff,
    remindersSent: journey.reminderCount,
    reminderDueLevel: journey.reminderDue,
    paidOn: stage == ReceivableStage.paid && match != null
        ? dayOf(match.matchedAt)
        : null,
  );
}

/// The customer's own pending payment declaration (the latest one): what
/// Confirm and Not received decide. Payment events are per customer, not per
/// invoice, as the journey reads them.
WorkspaceEvent? _declarationOf(
  Invoice invoice,
  Iterable<WorkspaceEvent> events,
) {
  WorkspaceEvent? latest;
  for (final e in events) {
    if (e.type == EventType.payment &&
        e.isPending &&
        e.actorIsSubject &&
        e.subjectMemberId == invoice.memberId &&
        (latest == null || e.createdAt.isAfter(latest.createdAt))) {
      latest = e;
    }
  }
  return latest;
}

/// The day the customer says they paid, else the day they said so.
DateTime _paidOn(WorkspaceEvent e) =>
    DateTime.tryParse(e.payload['paid_on'] as String? ?? '') ?? e.createdAt;
