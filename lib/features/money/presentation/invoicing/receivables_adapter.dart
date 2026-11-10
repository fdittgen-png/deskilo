// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 — the owner's invoicing reads its invoices as [Receivable]s:
// each issued invoice with its match, its reminders and the dunning rules,
// through the same journey the invoice page draws, so a status here and a
// status there cannot disagree. A source folded into a settlement says where
// it went; a credit note is a refund the business owes (or has paid out).
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../application/receivables.dart';
import '../../domain/dunning.dart';
import '../../domain/einvoice_gateway.dart';
import '../invoice_journey.dart';
import '../invoice_status.dart';

/// What the payment events say about one invoice: the journey's facts and
/// the customer's own declaration ([journeyFactsOf], [declarationOf]).
typedef InvoiceEventFacts = ({
  InvoiceJourneyFacts journey,
  ({String eventId, DateTime paidOn})? declaration,
});

/// Reads invoices as receivables with what the screen has loaded: their
/// [matches], the [reminders] sent, the dunning [rules], the instant [now],
/// the business's calendar day of an instant ([dayOf]), the facts the
/// payment events give for an invoice ([eventFactsOf]), the e-invoice
/// [transmissions] and the invoices [held] from reminders.
class ReceivablesReader {
  const ReceivablesReader({
    required this.matches,
    required this.reminders,
    required this.rules,
    required this.now,
    required this.dayOf,
    this.eventFactsOf,
    this.transmissions = const {},
    this.held = const {},
  });

  final Map<String, InvoiceMatch> matches;
  final Map<String, ({int count, DateTime last})> reminders;
  final DunningRules rules;
  final DateTime now;
  final DateTime Function(DateTime instant) dayOf;
  final InvoiceEventFacts Function(Invoice invoice, InvoiceMatch? match)?
  eventFactsOf;
  final Map<String, InvoiceTransmission> transmissions;

  /// The invoices whose reminders are on hold (`dunningHoldsProvider`).
  final Set<String> held;

  /// The receivables of [invoices] (every issued document of the workspace).
  List<Receivable> read(Iterable<Invoice> invoices) {
    final numbers = {for (final i in invoices) i.id: i.number};
    return [
      for (final invoice in invoices)
        if (invoice.totalCents != 0) _receivableOf(invoice, numbers),
    ];
  }

  Receivable _receivableOf(Invoice invoice, Map<String, String> numbers) {
    final match = matches[invoice.id];
    final facts = eventFactsOf?.call(invoice, match);
    final journey = InvoiceJourney.of(
      invoice: invoice,
      match: match,
      reminder: reminders[invoice.id],
      rules: rules,
      now: now,
      facts: facts?.journey ?? noJourneyFacts,
    );
    final stage = invoice.isFolded
        ? ReceivableStage.regrouped
        : _stageOf(journey.lifecycle, credit: invoice.totalCents < 0);
    final owed = stage == ReceivableStage.paid ? 0 : journey.remainingCents;
    // The payment's own step, in the journey's words (invoice_journey.dart).
    final move = journey.move;
    final declared = move == InvoiceMove.adminConfirmsPayment;
    final declaration = declared ? facts?.declaration : null;
    return Receivable(
      invoiceId: invoice.id,
      customerId: invoice.memberId,
      customerName: invoice.memberName,
      number: invoice.number,
      currency: invoice.currency,
      totalMinor: invoice.totalCents,
      openMinor: owed.abs(),
      issuedOn: dayOf(invoice.issuedAt),
      dueOn: dayOf(journey.dueOn),
      dueDateSet: invoice.dueOn != null,
      stage: stage,
      paymentDeclared: declared,
      declaredEventId: declaration?.eventId,
      declaredOn: declaration == null ? null : dayOf(declaration.paidOn),
      awaitingCustomerConfirmation: move == InvoiceMove.memberConfirmsPayment,
      paymentToMatch: move == InvoiceMove.issuerMatchesPayment,
      awaitingSecondApproval:
          move == InvoiceMove.validatorsDecideMatch ||
          move == InvoiceMove.validatorsDecideWriteoff,
      onHold: held.contains(invoice.id),
      eInvoiceRejected:
          transmissions[invoice.id]?.status ==
          EInvoiceSubmissionStatus.rejected,
      remindersSent: journey.reminderCount,
      remindersExhausted: journey.reminderCount >= rules.levels,
      reminderDueLevel: journey.reminderDue,
      paidOn: stage == ReceivableStage.paid && match != null
          ? dayOf(match.matchedAt)
          : null,
      regroupedInto: numbers[invoice.settledByInvoiceId] ?? '',
    );
  }
}

/// The stage of a document in [lifecycle]; a [credit] note owes a refund
/// until it is paid out.
ReceivableStage _stageOf(InvoiceLifecycle lifecycle, {required bool credit}) =>
    switch (lifecycle) {
      InvoiceLifecycle.erroneous ||
      InvoiceLifecycle.remainderCancelled => ReceivableStage.cancelled,
      InvoiceLifecycle.refunded => ReceivableStage.refunded,
      _ when credit => ReceivableStage.refundOwed,
      InvoiceLifecycle.open ||
      InvoiceLifecycle.awaitingValidation => ReceivableStage.open,
      InvoiceLifecycle.partiallyPaid => ReceivableStage.partlyPaid,
      InvoiceLifecycle.paid => ReceivableStage.paid,
    };
