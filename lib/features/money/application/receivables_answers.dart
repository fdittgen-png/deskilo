// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 Design 2 — the answers the invoicing home draws from [Receivable]s:
// what is owed and in which state (the owed card), the month's two figures,
// "To do", and one line per customer. Pure functions; money is never added
// across currencies.
import 'package:meta/meta.dart';

import '../../../core/text/collation.dart';
import 'receivables.dart';

/// The three states of what is owed (Design 2's owed card and its filter).
enum OwedBucket {
  /// Outstanding, not late, nothing on its way.
  notYetDue,

  /// Money that is probably in and not yet closed: a declared payment, a
  /// payment to match, a match waiting for its second approval.
  toConfirm,

  /// Late (#3285), nothing on its way.
  overdue,
}

/// The bucket of [r] on [today]; null when nothing is owed on it. Money on
/// its way goes to [OwedBucket.toConfirm] whatever the due date.
OwedBucket? owedBucketOf(Receivable r, DateTime today) {
  if (!r.isOutstanding) return null;
  if (r.paymentDeclared || r.paymentToMatch || r.awaitingSecondApproval) {
    return OwedBucket.toConfirm;
  }
  return r.isLateOn(today) ? OwedBucket.overdue : OwedBucket.notYetDue;
}

/// What is owed in one currency: the total and each bucket's share.
@immutable
class OwedInCurrency {
  const OwedInCurrency(this.currency, this.buckets);

  final String currency;

  /// Each bucket with what it holds; a bucket with nothing is absent.
  final Map<OwedBucket, ({int count, int minor})> buckets;

  int get totalMinor => buckets.values.fold(0, (sum, b) => sum + b.minor);
}

/// What [invoices] owe on [today], one entry per currency (by currency
/// code), never summed across currencies.
List<OwedInCurrency> owedOf(Iterable<Receivable> invoices, DateTime today) {
  final byCurrency = <String, Map<OwedBucket, ({int count, int minor})>>{};
  for (final r in invoices) {
    final bucket = owedBucketOf(r, today);
    if (bucket == null) continue;
    final buckets = byCurrency[r.currency] ??= {};
    final b = buckets[bucket] ?? (count: 0, minor: 0);
    buckets[bucket] = (count: b.count + 1, minor: b.minor + r.openMinor);
  }
  final codes = byCurrency.keys.toList()..sort();
  return [for (final c in codes) OwedInCurrency(c, byCurrency[c]!)];
}

/// The month's two figures: what was invoiced and what was received.
typedef MonthFigures = ({Tally invoiced, Tally received});

/// One payment received: the money a match consumed, dated by the match
/// (the rows the collected figure sums, `workspace_recorded_payments_v1`).
/// An invoice's own payment lines are netted at issue and carry no date.
typedef ReceivedPayment = ({String currency, int minor, DateTime on});

/// [today]'s calendar month: invoiced = every invoice issued in it (a draft
/// or a cancelled one is not invoiced), at its total; received = every
/// payment of [received] dated in it, partial payments included. Per
/// currency, never summed across currencies.
MonthFigures monthOf(
  Iterable<Receivable> invoices,
  DateTime today, {
  Iterable<ReceivedPayment> received = const [],
}) {
  bool inMonth(DateTime d) => d.year == today.year && d.month == today.month;
  var invoiced = Tally.empty;
  for (final r in invoices) {
    final counts =
        r.stage != ReceivableStage.draft &&
        r.stage != ReceivableStage.cancelled;
    if (counts && inMonth(r.issuedOn)) {
      invoiced = invoiced.plus(r.currency, r.totalMinor);
    }
  }
  var money = Tally.empty;
  for (final p in received) {
    if (inMonth(p.on)) money = money.plus(p.currency, p.minor);
  }
  return (invoiced: invoiced, received: money);
}

/// What "To do" can ask for, in its order.
enum TodoKind {
  invoiceTheMonth,
  sendReminders,
  confirmPayments,
  matchPayments,
  fixSending,
  issueDrafts,
}

/// One entry of "To do": what to do, for how many, and the money at stake.
typedef Todo = ({TodoKind kind, Tally tally});

/// The "To do" entry [r] belongs to on [today], or null. A hold stops the
/// reminders only: a payment declared on a held invoice is still confirmed.
TodoKind? _todoOf(Receivable r, DateTime today) {
  if (r.stage == ReceivableStage.draft) return TodoKind.issueDrafts;
  if (!r.isOutstanding) return null;
  if (r.sendFailed) return TodoKind.fixSending;
  if (r.paymentDeclared) return TodoKind.confirmPayments;
  if (r.paymentToMatch) return TodoKind.matchPayments;
  final status = invoiceStatusOf(r, today);
  return status.kind == InvoiceStatusKind.reminderDue
      ? TodoKind.sendReminders
      : null;
}

/// "To do" of [invoices] and [toInvoice] on [today]: invoice the month,
/// send reminders, confirm payments, match payments, could not be sent,
/// drafts to issue — each present only when it has something to do. No age
/// threshold decides an entry.
List<Todo> todoOf(
  Iterable<Receivable> invoices, {
  Iterable<ToInvoice> toInvoice = const [],
  required DateTime today,
}) {
  final tallies = {for (final k in TodoKind.values) k: Tally.empty};
  for (final t in toInvoice) {
    tallies[TodoKind.invoiceTheMonth] = tallies[TodoKind.invoiceTheMonth]!.plus(
      t.currency,
      t.amountMinor,
    );
  }
  for (final r in invoices) {
    final kind = _todoOf(r, today);
    if (kind != null) {
      tallies[kind] = tallies[kind]!.plus(r.currency, r.openMinor);
    }
  }
  return [
    for (final k in TodoKind.values)
      if (tallies[k]!.count > 0) (kind: k, tally: tallies[k]!),
  ];
}

/// One customer's line of the list (Design 2: the list is by customer).
@immutable
class CustomerRow {
  const CustomerRow({
    required this.customerId,
    required this.customerName,
    required this.invoices,
    required this.owes,
    required this.daysLate,
    required this.remindersDue,
    required this.declared,
    required this.toMatch,
    required this.onHold,
  });

  final String customerId;
  final String customerName;

  /// The customer's invoices in the list, oldest due first.
  final List<Receivable> invoices;

  /// What they owe, per currency; never summed across currencies.
  final Tally owes;

  /// Days the most late invoice is late (the due day counts as day 0);
  /// null when none is late.
  final int? daysLate;
  final int remindersDue;
  final int declared;
  final int toMatch;

  /// One of their invoices is on hold.
  final bool onHold;

  /// The line's one action: remind, else confirm, else match; null when
  /// nothing waits on the business.
  InvoiceAction? get action => remindersDue > 0
      ? InvoiceAction.sendReminder
      : declared > 0
      ? InvoiceAction.confirmPayment
      : toMatch > 0
      ? InvoiceAction.match
      : null;
}

/// [invoices] (the list's current selection) as one line per customer on
/// [today]: late customers first, the most late first, then the larger
/// amount when both owe in one same currency, then by name.
List<CustomerRow> customerRowsOf(
  Iterable<Receivable> invoices, {
  required DateTime today,
}) {
  final byCustomer = <String, List<Receivable>>{};
  for (final r in invoices) {
    (byCustomer[r.customerId] ??= []).add(r);
  }
  final rows = [
    for (final MapEntry(key: id, value: rs) in byCustomer.entries)
      _rowOf(id, rs, today),
  ];
  return rows..sort(_byUrgency);
}

int _byUrgency(CustomerRow a, CustomerRow b) {
  final byLate = (b.daysLate ?? -1).compareTo(a.daysLate ?? -1);
  if (byLate != 0) return byLate;
  final ca = a.owes.byCurrency;
  final cb = b.owes.byCurrency;
  if (ca.length == 1 && cb.length == 1 && ca.keys.first == cb.keys.first) {
    final byAmount = cb.values.first.compareTo(ca.values.first);
    if (byAmount != 0) return byAmount;
  }
  return compareNames(a.customerName, b.customerName);
}

CustomerRow _rowOf(String id, List<Receivable> rs, DateTime today) {
  int dueKey(Receivable r) => r.dueOn?.millisecondsSinceEpoch ?? 0;
  rs.sort((a, b) => dueKey(a).compareTo(dueKey(b)));
  var owes = Tally.empty;
  int? daysLate;
  for (final r in rs) {
    owes = owes.plus(r.currency, r.openMinor);
    if (owedBucketOf(r, today) == OwedBucket.overdue) {
      final days = -r.daysToDue(today)!;
      if (daysLate == null || days > daysLate) daysLate = days;
    }
  }
  int count(TodoKind kind) => rs.where((r) => _todoOf(r, today) == kind).length;
  return CustomerRow(
    customerId: id,
    customerName: rs.first.customerName,
    invoices: List.unmodifiable(rs),
    owes: owes,
    daysLate: daysLate,
    remindersDue: count(TodoKind.sendReminders),
    declared: count(TodoKind.confirmPayments),
    toMatch: count(TodoKind.matchPayments),
    onHold: rs.any((r) => r.onHold),
  );
}
