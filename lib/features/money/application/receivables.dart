// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 step 1 — the owner's invoicing read as answers: the four figures,
// "Do next", what each customer owes, each invoice's status and its one
// action. Pure functions over what the invoices screen already loads, handed
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

import '../../../core/text/collation.dart';
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

  /// The customer said they paid; nobody has confirmed it yet.
  final bool paymentDeclared;

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

/// Days from [today] to [r]'s due day: positive before, 0 on it, negative
/// after. Null without a due day.
int? _daysToDue(Receivable r, DateTime today) =>
    r.dueOn == null ? null : calendarDaysBetween(today, r.dueOn!);

/// Whether [r] is late on [today]: outstanding and its due day reached
/// (#3285: the due day itself is late).
bool _isLate(Receivable r, DateTime today) {
  final days = _daysToDue(r, today);
  return r.isOutstanding && days != null && days <= 0;
}

/// The one status of [r] on [today]. What ended comes first, then what
/// stops the chase (on hold, could not be sent), then what waits on the
/// business (a declared payment, a reminder due), then the calendar.
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
  if (r.onHold) return const InvoiceStatus(InvoiceStatusKind.onHold);
  if (r.sendFailed) {
    return const InvoiceStatus(InvoiceStatusKind.couldNotBeSent);
  }
  if (r.paymentDeclared) {
    return const InvoiceStatus(InvoiceStatusKind.paymentDeclared);
  }
  final days = _daysToDue(r, today);
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
enum InvoiceAction { issue, open, sendReminder, confirmPayment, fix }

/// The action for [status] (everything else is under "More").
InvoiceAction actionFor(InvoiceStatus status) => switch (status.kind) {
  InvoiceStatusKind.draft => InvoiceAction.issue,
  InvoiceStatusKind.reminderDue => InvoiceAction.sendReminder,
  InvoiceStatusKind.paymentDeclared => InvoiceAction.confirmPayment,
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

/// The four figures that answer the four questions, and filter the list.
@immutable
class ReceivableFigures {
  const ReceivableFigures({
    required this.toInvoice,
    required this.awaitingPayment,
    required this.overdue,
    required this.paidThisMonth,
  });

  final Tally toInvoice;

  /// Outstanding and not yet late.
  final Tally awaitingPayment;

  /// Outstanding and late.
  final Tally overdue;

  /// Paid in full in [today]'s calendar month.
  final Tally paidThisMonth;
}

/// The four figures of [invoices] and [toInvoice] on [today].
ReceivableFigures figuresOf(
  Iterable<Receivable> invoices, {
  Iterable<ToInvoice> toInvoice = const [],
  required DateTime today,
}) {
  var invoice = Tally.empty;
  for (final t in toInvoice) {
    invoice = invoice.plus(t.currency, t.amountMinor);
  }
  var awaiting = Tally.empty;
  var overdue = Tally.empty;
  var paid = Tally.empty;
  for (final r in invoices) {
    if (r.isOutstanding) {
      if (_isLate(r, today)) {
        overdue = overdue.plus(r.currency, r.openMinor);
      } else {
        awaiting = awaiting.plus(r.currency, r.openMinor);
      }
    } else if (r.stage == ReceivableStage.paid &&
        r.paidOn != null &&
        r.paidOn!.year == today.year &&
        r.paidOn!.month == today.month) {
      paid = paid.plus(r.currency, r.totalMinor);
    }
  }
  return ReceivableFigures(
    toInvoice: invoice,
    awaitingPayment: awaiting,
    overdue: overdue,
    paidThisMonth: paid,
  );
}

/// What "Do next" can ask for.
enum DoNextKind {
  invoiceTheMonth,
  sendReminders,
  confirmPayments,
  fixSending,
  issueDrafts,
}

/// One entry of "Do next": what to do, for how many, and the money at stake.
typedef DoNext = ({DoNextKind kind, Tally tally});

/// "Do next" of [invoices] and [toInvoice] on [today]: at most five entries
/// in the issue's order — invoice the month, reminders due, payments to
/// confirm, could not be sent, drafts to issue — each
/// present only when it has something to do.
List<DoNext> doNextOf(
  Iterable<Receivable> invoices, {
  Iterable<ToInvoice> toInvoice = const [],
  required DateTime today,
}) {
  var month = Tally.empty;
  for (final t in toInvoice) {
    month = month.plus(t.currency, t.amountMinor);
  }
  final tallies = {for (final k in DoNextKind.values) k: Tally.empty};
  tallies[DoNextKind.invoiceTheMonth] = month;
  for (final r in invoices) {
    final status = invoiceStatusOf(r, today);
    final kind = switch (status.kind) {
      InvoiceStatusKind.reminderDue => DoNextKind.sendReminders,
      InvoiceStatusKind.paymentDeclared => DoNextKind.confirmPayments,
      InvoiceStatusKind.couldNotBeSent => DoNextKind.fixSending,
      InvoiceStatusKind.draft => DoNextKind.issueDrafts,
      _ => null,
    };
    if (kind != null) {
      tallies[kind] = tallies[kind]!.plus(r.currency, r.openMinor);
    }
  }
  return [
    for (final k in DoNextKind.values)
      if (tallies[k]!.count > 0) (kind: k, tally: tallies[k]!),
  ];
}

/// What one customer owes.
@immutable
class CustomerBalance {
  const CustomerBalance({
    required this.customerId,
    required this.customerName,
    required this.open,
    required this.overdue,
    required this.oldestDays,
  });

  final String customerId;
  final String customerName;

  /// Everything outstanding, per currency.
  final Tally open;

  /// The late part of [open], per currency.
  final Tally overdue;

  /// Days since the oldest outstanding invoice was issued; 0 when none.
  final int oldestDays;
}

/// What each customer of [invoices] owes on [today]: only customers with
/// something outstanding, the most overdue first (most late invoices, then
/// the oldest), then by name.
List<CustomerBalance> customerBalancesOf(
  Iterable<Receivable> invoices, {
  required DateTime today,
}) {
  final byCustomer = <String, List<Receivable>>{};
  for (final r in invoices) {
    if (r.isOutstanding) (byCustomer[r.customerId] ??= []).add(r);
  }
  final balances = [
    for (final MapEntry(key: id, value: rs) in byCustomer.entries)
      _balanceOf(id, rs, today),
  ];
  return balances..sort((a, b) {
    final byLate = b.overdue.count.compareTo(a.overdue.count);
    if (byLate != 0) return byLate;
    final byAge = b.oldestDays.compareTo(a.oldestDays);
    if (byAge != 0) return byAge;
    return compareNames(a.customerName, b.customerName);
  });
}

CustomerBalance _balanceOf(String id, List<Receivable> rs, DateTime today) {
  var open = Tally.empty;
  var overdue = Tally.empty;
  var oldest = 0;
  for (final r in rs) {
    open = open.plus(r.currency, r.openMinor);
    if (_isLate(r, today)) overdue = overdue.plus(r.currency, r.openMinor);
    final age = calendarDaysBetween(r.issuedOn, today);
    if (age > oldest) oldest = age;
  }
  return CustomerBalance(
    customerId: id,
    customerName: rs.first.customerName,
    open: open,
    overdue: overdue,
    oldestDays: oldest,
  );
}
