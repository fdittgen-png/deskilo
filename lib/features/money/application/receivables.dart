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

  /// Cancelled (issued by mistake, or its remainder written off).
  cancelled,

  /// Answered by a credit note.
  credited,

  /// Folded into a settlement that is chased instead ([Receivable.regroupedInto]).
  regrouped,

  /// A credit note: the business owes the customer a refund.
  refundOwed,

  /// A credit note whose refund is paid out.
  refunded,
}

/// One invoice (or credit note) as the owner's invoicing reads it.
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
    this.dueDateSet = true,
    this.paymentDeclared = false,
    this.declaredEventId,
    this.declaredOn,
    this.awaitingCustomerConfirmation = false,
    this.paymentToMatch = false,
    this.awaitingSecondApproval = false,
    this.onHold = false,
    this.eInvoiceRejected = false,
    this.remindersSent = 0,
    this.remindersExhausted = false,
    this.reminderDueLevel,
    this.paidOn,
    this.regroupedInto = '',
  });

  /// This invoice with [open] as what is still due on it: the server's
  /// figure, which also leaves out the parts awaiting approval (#3671).
  Receivable withOpenMinor(int open) => Receivable(
    invoiceId: invoiceId,
    customerId: customerId,
    customerName: customerName,
    number: number,
    currency: currency,
    totalMinor: totalMinor,
    issuedOn: issuedOn,
    stage: stage,
    dueOn: dueOn,
    dueDateSet: dueDateSet,
    paymentDeclared: paymentDeclared,
    declaredEventId: declaredEventId,
    declaredOn: declaredOn,
    awaitingCustomerConfirmation: awaitingCustomerConfirmation,
    paymentToMatch: paymentToMatch,
    awaitingSecondApproval: awaitingSecondApproval,
    onHold: onHold,
    eInvoiceRejected: eInvoiceRejected,
    remindersSent: remindersSent,
    remindersExhausted: remindersExhausted,
    reminderDueLevel: reminderDueLevel,
    paidOn: paidOn,
    regroupedInto: regroupedInto,
    openMinor: open,
  );

  final String invoiceId;
  final String customerId;
  final String customerName;

  /// '' for a draft.
  final String number;
  final String currency;

  /// The document's total; a credit note's is negative.
  final int totalMinor;

  /// What is still owed, in [currency]: by the customer on an invoice, by
  /// the business on a credit note (a refund owed), always positive.
  final int openMinor;

  /// The day it was issued (for a draft: the day it was prepared).
  final DateTime issuedOn;

  final ReceivableStage stage;

  /// The day payment is due: the date frozen at issue, else the payment
  /// term (#3285's one rule); null for a draft.
  final DateTime? dueOn;

  /// A due date was frozen at issue; without one the automatic reminders
  /// leave the invoice to the owner ("Set a due date").
  final bool dueDateSet;

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

  /// The e-invoicing platform rejected it.
  final bool eInvoiceRejected;

  /// How many reminders were sent.
  final int remindersSent;

  /// Every level of the dunning rules was sent and it is still owed.
  final bool remindersExhausted;

  /// The level of the reminder the dunning rules say is due now; null when
  /// none is.
  final int? reminderDueLevel;

  /// The day it was paid in full; null otherwise.
  final DateTime? paidOn;

  /// The number of the settlement it was folded into; '' otherwise.
  final String regroupedInto;

  bool get isOutstanding =>
      stage == ReceivableStage.open || stage == ReceivableStage.partlyPaid;

  /// Money on its way: declared, to match, or waiting for a second approval.
  bool get paymentPending =>
      paymentDeclared || paymentToMatch || awaitingSecondApproval;

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

/// The words an invoice's status is said in (#3587's final list; the screen
/// picks the sentence and the tone).
enum InvoiceStatusKind {
  draft,
  dueIn,
  dueToday,
  late,

  /// Late, and reminders were sent ([InvoiceStatus.level] of them).
  lateReminderSent,

  /// Late, and every level of the rules was sent.
  lateEveryReminderSent,
  paymentDeclared,
  awaitingCustomer,
  paymentToMatch,
  awaitingSecondApproval,
  onHold,
  eInvoiceRejected,
  noDueDate,

  /// Part paid: [InvoiceStatus.number] is the open amount, in minor units.
  partlyPaid,
  paid,
  cancelled,
  credited,
  regrouped,
  refundOwed,
  refunded,
}

/// An invoice's status: its kind, the number its sentence names (days for
/// dueIn and the late kinds, the open amount for partlyPaid; 0 otherwise)
/// and the reminder level for [InvoiceStatusKind.lateReminderSent].
@immutable
class InvoiceStatus {
  const InvoiceStatus(this.kind, [this.number = 0, this.level = 0]);

  final InvoiceStatusKind kind;
  final int number;
  final int level;

  @override
  bool operator ==(Object other) =>
      other is InvoiceStatus &&
      other.kind == kind &&
      other.number == number &&
      other.level == level;

  @override
  int get hashCode => Object.hash(kind, number, level);

  @override
  String toString() => '$kind($number, $level)';
}

/// The status of a document whose story has ended, or null.
InvoiceStatusKind? _endedKind(ReceivableStage stage) => switch (stage) {
  ReceivableStage.draft => InvoiceStatusKind.draft,
  ReceivableStage.paid => InvoiceStatusKind.paid,
  ReceivableStage.cancelled => InvoiceStatusKind.cancelled,
  ReceivableStage.credited => InvoiceStatusKind.credited,
  ReceivableStage.regrouped => InvoiceStatusKind.regrouped,
  ReceivableStage.refundOwed => InvoiceStatusKind.refundOwed,
  ReceivableStage.refunded => InvoiceStatusKind.refunded,
  ReceivableStage.open || ReceivableStage.partlyPaid => null,
};

/// The one status of [r] on [today]. A document whose story ended says so;
/// then a rejected e-invoice; then money on its way (a declared payment, a
/// second approval, a payment to match, a customer's confirmation) — a claim
/// of payment outranks a hold; then on hold; then lateness and its
/// reminders; then a part paid; then the calendar.
InvoiceStatus invoiceStatusOf(Receivable r, DateTime today) {
  final ended = _endedKind(r.stage);
  if (ended != null) return InvoiceStatus(ended);
  if (r.eInvoiceRejected) {
    return const InvoiceStatus(InvoiceStatusKind.eInvoiceRejected);
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
  if (days != null && days <= 0) {
    if (r.remindersExhausted) {
      return InvoiceStatus(InvoiceStatusKind.lateEveryReminderSent, -days);
    }
    if (r.remindersSent > 0) {
      return InvoiceStatus(
        InvoiceStatusKind.lateReminderSent,
        -days,
        r.remindersSent,
      );
    }
    return InvoiceStatus(InvoiceStatusKind.late, -days);
  }
  if (r.stage == ReceivableStage.partlyPaid) {
    return InvoiceStatus(InvoiceStatusKind.partlyPaid, r.openMinor);
  }
  if (days == null || !r.dueDateSet) {
    return const InvoiceStatus(InvoiceStatusKind.noDueDate);
  }
  if (days > 0) return InvoiceStatus(InvoiceStatusKind.dueIn, days);
  return const InvoiceStatus(InvoiceStatusKind.dueToday);
}

/// The one action a document's line offers.
enum InvoiceAction {
  issue,
  open,
  shareReminder,
  confirmPayment,
  match,
  payOutRefund,
  fix,
}

/// Whether reminders go out by themselves or are shared by hand
/// (`workspaces.dunning_rules.automatic`).
enum ReminderMode { automatic, byHand }

/// The reminder [r] can be shared by hand now: due by the rules, nothing on
/// its way, not on hold, the ladder not exhausted. Never in automatic mode.
bool reminderToShare(Receivable r, ReminderMode mode) =>
    mode == ReminderMode.byHand &&
    r.isOutstanding &&
    r.reminderDueLevel != null &&
    !r.onHold &&
    !r.paymentPending &&
    !r.awaitingCustomerConfirmation &&
    !r.remindersExhausted;

/// The one action of [r] on [today] (everything else is under "More").
InvoiceAction actionOf(Receivable r, DateTime today, ReminderMode mode) {
  final status = invoiceStatusOf(r, today);
  return switch (status.kind) {
    InvoiceStatusKind.draft => InvoiceAction.issue,
    InvoiceStatusKind.paymentDeclared => InvoiceAction.confirmPayment,
    InvoiceStatusKind.paymentToMatch => InvoiceAction.match,
    InvoiceStatusKind.refundOwed => InvoiceAction.payOutRefund,
    InvoiceStatusKind.eInvoiceRejected => InvoiceAction.fix,
    _ when reminderToShare(r, mode) => InvoiceAction.shareReminder,
    _ => InvoiceAction.open,
  };
}

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
