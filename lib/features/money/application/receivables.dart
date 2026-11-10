// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 — the owner's invoicing read as answers: what is owed and in which
// state (Design 2's owed card), the month's figures, "To do", what each
// customer owes, each invoice's status and its one action. Pure functions over what the invoices screen already loads, handed
// in as [Receivable] lines (the screen builds them from the journey, the
// match and the dunning facts it has today). No new state, no rule: the
// server's rules stay where they are.
//
// Money is never added across currencies: every amount is a map
// currency code → minor units, one line per currency on screen.
//
// "Today" is the issuing business's calendar day (#3285's decision): the
// caller passes the business zone's wall clock, and lateness is #3285's one
// rule — the due day itself is late (`calendarDaysBetween(today, due) <= 0`).
import 'package:meta/meta.dart';

import '../../../core/time/calendar_days.dart';

/// Where an invoice stands, as the server and the journey have it.
enum ReceivableStage {
  /// Prepared, not issued.
  draft,

  /// Issued, nothing paid.
  open,

  /// Issued, part of it paid, the rest still owed.
  partlyPaid,

  /// Paid in full.
  paid,

  /// Cancelled (erroneous, or its remainder written off).
  cancelled,

  /// Answered by a credit note.
  credited,
}

/// One invoice as the owner's invoicing reads it.
@immutable
class Receivable {
  const Receivable({
    required this.invoiceId,
    required this.customerId,
    required this.customerName,
    required this.number,
    required this.currency,
    required this.totalMinor,
    required this.openMinor,
    required this.issuedOn,
    required this.stage,
    this.dueOn,
    this.paymentDeclared = false,
    this.declaredEventId,
    this.declaredOn,
    this.awaitingCustomerConfirmation = false,
    this.paymentToMatch = false,
    this.awaitingSecondApproval = false,
    this.onHold = false,
    this.sendFailed = false,
    this.remindersSent = 0,
    this.reminderDueLevel,
    this.paidOn,
  });

  final String invoiceId;
  final String customerId;
  final String customerName;

  /// '' for a draft.
  final String number;
  final String currency;
  final int totalMinor;

  /// What is still owed, in [currency].
  final int openMinor;

  /// The day it was issued (for a draft: the day it was prepared).
  final DateTime issuedOn;

  /// The day payment is due (#3285); null for a draft.
  final DateTime? dueOn;
  final ReceivableStage stage;

  /// The customer said they paid (a pending payment event they recorded);
  /// another administrator confirms it or says it was not received.
  final bool paymentDeclared;

  /// That declaration's event, which Confirm and Not received decide.
  final String? declaredEventId;

  /// The day the customer says they paid.
  final DateTime? declaredOn;

  /// An administrator recorded a payment for the customer, who confirms it.
  final bool awaitingCustomerConfirmation;

  /// A confirmed payment sits on the customer's account, not yet matched to
  /// this invoice: the issuer matches it.
  final bool paymentToMatch;

  /// A match or a write-off waits for its second approval (its quorum).
  final bool awaitingSecondApproval;

  /// Reminders are suspended for it.
  final bool onHold;

  /// Its sending (e-mail or e-invoice) failed and was not retried.
  final bool sendFailed;

  /// How many reminders were sent.
  final int remindersSent;

  /// The level of the reminder the dunning rules say is due now; null when
  /// none is.
  final int? reminderDueLevel;

  /// The day it was paid in full; null otherwise.
  final DateTime? paidOn;

  bool get isOutstanding =>
      stage == ReceivableStage.open || stage == ReceivableStage.partlyPaid;

  /// Days from [today] to the due day: positive before, 0 on it, negative
  /// after. Null without a due day.
  int? daysToDue(DateTime today) =>
      dueOn == null ? null : calendarDaysBetween(today, dueOn!);

  /// Outstanding and its due day reached on [today] (#3285: the due day
  /// itself is late).
  bool isLateOn(DateTime today) {
    final days = daysToDue(today);
    return isOutstanding && days != null && days <= 0;
  }
}

/// The words an invoice's status is said in (the screen picks the sentence).
enum InvoiceStatusKind {
  draft,

  /// Issued without a due date: nothing is late.
  noDueDate,
  dueIn,
  dueToday,
  late,
  reminderSent,
  reminderDue,
  paymentDeclared,
  awaitingSecondApproval,
  paymentToMatch,
  awaitingCustomer,
  partlyPaid,
  paid,
  onHold,
  couldNotBeSent,
  cancelled,
  credited,
}

/// An invoice's status: its kind and the number its sentence names (days
/// for dueIn and late, the level for the reminders; 0 otherwise).
@immutable
class InvoiceStatus {
  const InvoiceStatus(this.kind, [this.number = 0]);

  final InvoiceStatusKind kind;
  final int number;

  @override
  bool operator ==(Object other) =>
      other is InvoiceStatus && other.kind == kind && other.number == number;

  @override
  int get hashCode => Object.hash(kind, number);

  @override
  String toString() => '$kind($number)';
}

/// The one status of [r] on [today]. What ended comes first, then could
/// not be sent, then money on its way (a declared payment, a second
/// approval, a payment to match, a customer's confirmation) — a claim of
/// payment outranks a hold — then on hold, a reminder due, the calendar.
InvoiceStatus invoiceStatusOf(Receivable r, DateTime today) {
  switch (r.stage) {
    case ReceivableStage.draft:
      return const InvoiceStatus(InvoiceStatusKind.draft);
    case ReceivableStage.paid:
      return const InvoiceStatus(InvoiceStatusKind.paid);
    case ReceivableStage.cancelled:
      return const InvoiceStatus(InvoiceStatusKind.cancelled);
    case ReceivableStage.credited:
      return const InvoiceStatus(InvoiceStatusKind.credited);
    case ReceivableStage.open || ReceivableStage.partlyPaid:
      break;
  }
  if (r.sendFailed) {
    return const InvoiceStatus(InvoiceStatusKind.couldNotBeSent);
  }
  if (r.paymentDeclared) {
    return const InvoiceStatus(InvoiceStatusKind.paymentDeclared);
  }
  if (r.awaitingSecondApproval) {
    return const InvoiceStatus(InvoiceStatusKind.awaitingSecondApproval);
  }
  if (r.paymentToMatch) {
    return const InvoiceStatus(InvoiceStatusKind.paymentToMatch);
  }
  if (r.awaitingCustomerConfirmation) {
    return const InvoiceStatus(InvoiceStatusKind.awaitingCustomer);
  }
  if (r.onHold) return const InvoiceStatus(InvoiceStatusKind.onHold);
  final days = r.daysToDue(today);
  final late = days != null && days <= 0;
  if (late && r.reminderDueLevel != null) {
    return InvoiceStatus(InvoiceStatusKind.reminderDue, r.reminderDueLevel!);
  }
  if (late && r.remindersSent > 0) {
    return InvoiceStatus(InvoiceStatusKind.reminderSent, r.remindersSent);
  }
  if (r.stage == ReceivableStage.partlyPaid && !late) {
    return const InvoiceStatus(InvoiceStatusKind.partlyPaid);
  }
  if (days == null) return const InvoiceStatus(InvoiceStatusKind.noDueDate);
  if (days > 0) return InvoiceStatus(InvoiceStatusKind.dueIn, days);
  if (days == 0) return const InvoiceStatus(InvoiceStatusKind.dueToday);
  return InvoiceStatus(InvoiceStatusKind.late, -days);
}

/// The one action an invoice's row offers.
enum InvoiceAction { issue, open, sendReminder, confirmPayment, match, fix }

/// The action for [status] (everything else is under "More").
InvoiceAction actionFor(InvoiceStatus status) => switch (status.kind) {
  InvoiceStatusKind.draft => InvoiceAction.issue,
  InvoiceStatusKind.reminderDue => InvoiceAction.sendReminder,
  InvoiceStatusKind.paymentDeclared => InvoiceAction.confirmPayment,
  InvoiceStatusKind.paymentToMatch => InvoiceAction.match,
  InvoiceStatusKind.couldNotBeSent => InvoiceAction.fix,
  _ => InvoiceAction.open,
};

/// Amounts per currency and how many invoices they come from.
@immutable
class Tally {
  const Tally(this.count, this.byCurrency);

  static const empty = Tally(0, {});

  final int count;

  /// currency code → minor units; never summed across currencies.
  final Map<String, int> byCurrency;

  Tally plus(String currency, int minor) => Tally(count + 1, {
    ...byCurrency,
    currency: (byCurrency[currency] ?? 0) + minor,
  });

  @override
  bool operator ==(Object other) =>
      other is Tally &&
      other.count == count &&
      other.byCurrency.length == byCurrency.length &&
      byCurrency.entries.every((e) => other.byCurrency[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    count,
    Object.hashAllUnordered(
      byCurrency.entries.map((e) => '${e.key}=${e.value}'),
    ),
  );

  @override
  String toString() => 'Tally($count, $byCurrency)';
}

/// One customer the month still has to invoice, and how much.
typedef ToInvoice = ({String customerId, String currency, int amountMinor});
