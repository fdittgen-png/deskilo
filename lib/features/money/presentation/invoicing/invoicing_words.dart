// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-c -- how the invoicing home says things: each status of the final
// list in words and its tone (every status is a word as well as a colour),
// and what each "To do" entry is called. One place, so a row, a chip and a
// page cannot say the same state two ways.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/receivables.dart';
import '../../application/receivables_answers.dart';
import 'invoicing_dates.dart';

/// The tone of a status (#3587's final list).
StatusTone statusToneOf(InvoiceStatusKind kind) => switch (kind) {
  InvoiceStatusKind.late ||
  InvoiceStatusKind.lateReminderSent ||
  InvoiceStatusKind.lateEveryReminderSent ||
  InvoiceStatusKind.eInvoiceRejected => StatusTone.due,
  InvoiceStatusKind.paymentDeclared ||
  InvoiceStatusKind.awaitingCustomer ||
  InvoiceStatusKind.paymentToMatch ||
  InvoiceStatusKind.awaitingSecondApproval => StatusTone.info,
  InvoiceStatusKind.dueToday ||
  InvoiceStatusKind.onHold ||
  InvoiceStatusKind.refundOwed => StatusTone.warn,
  InvoiceStatusKind.paid || InvoiceStatusKind.refunded => StatusTone.ok,
  InvoiceStatusKind.draft ||
  InvoiceStatusKind.dueIn ||
  InvoiceStatusKind.noDueDate ||
  InvoiceStatusKind.partlyPaid ||
  InvoiceStatusKind.cancelled ||
  InvoiceStatusKind.credited ||
  InvoiceStatusKind.regrouped => StatusTone.neutral,
};

/// [r]'s status [s] in words on [today], with [format] for its dates and
/// amounts: a date of another year than [today]'s says its year.
/// #3773 — the state in its parts, for a place that shows them as pieces
/// that wrap between each other (the invoice table): the lateness, then the
/// reminder. A state of one part is that part.
List<String> statusPartsOf(
  AppLocalizations l,
  AppFormat format,
  Receivable r,
  InvoiceStatus s,
  DateTime today,
) => switch (s.kind) {
  InvoiceStatusKind.lateReminderSent => [
    l.invoicingDaysLate(s.number),
    l.invoicingReminderLevelSent(s.level),
  ],
  InvoiceStatusKind.lateEveryReminderSent => [
    l.invoicingDaysLate(s.number),
    l.invoicingEveryReminderSent,
  ],
  _ => [statusWordsOf(l, format, r, s, today)],
};

String statusWordsOf(
  AppLocalizations l,
  AppFormat format,
  Receivable r,
  InvoiceStatus s,
  DateTime today,
) {
  String day(DateTime? d) => d == null ? '' : invoicingDay(format, d, today);
  return switch (s.kind) {
    InvoiceStatusKind.draft => l.invoicingStatusDraft,
    InvoiceStatusKind.dueIn => l.invoicingDueIn(s.number),
    InvoiceStatusKind.dueToday => l.invoicingStatusDueToday,
    InvoiceStatusKind.late => l.invoicingDaysLate(s.number),
    InvoiceStatusKind.lateReminderSent => l.invoicingStatusReminderSent(
      s.number,
      s.level,
    ),
    InvoiceStatusKind.lateEveryReminderSent =>
      l.invoicingStatusEveryReminderSent(s.number),
    InvoiceStatusKind.paymentDeclared =>
      r.declaredOn == null
          ? l.invoicingStatusSaysPaidUndated
          : l.invoicingStatusSaysPaid(day(r.declaredOn)),
    InvoiceStatusKind.awaitingCustomer => l.invoicingStatusAwaitingCustomer,
    InvoiceStatusKind.paymentToMatch => l.invoicingStatusToMatch,
    InvoiceStatusKind.awaitingSecondApproval => l.invoicingStatusSecondApproval,
    InvoiceStatusKind.onHold => l.invoicingStatusOnHold,
    InvoiceStatusKind.eInvoiceRejected => l.invoicingStatusRejected,
    InvoiceStatusKind.noDueDate => l.biCustomerCohortUnknownDue,
    InvoiceStatusKind.partlyPaid => l.invoicingStatusPartlyPaid(
      format.moneyIn(r.currency).formatMinor(s.number),
    ),
    InvoiceStatusKind.paid =>
      r.paidOn == null
          ? l.invoicingStatusPaidUndated
          : l.invoicingStatusPaid(day(r.paidOn)),
    InvoiceStatusKind.cancelled => l.invoicingStatusCancelled,
    InvoiceStatusKind.credited => l.invoicingStatusCredited,
    InvoiceStatusKind.regrouped => l.invoicingStatusRegrouped(r.regroupedInto),
    InvoiceStatusKind.refundOwed => l.invoicingStatusRefundOwed,
    InvoiceStatusKind.refunded => l.invoicingStatusRefunded,
  };
}

/// A "To do" entry's icon, title and button, [month] naming the month to
/// invoice.
({IconData icon, String title, String button, bool alert}) todoWordsOf(
  AppLocalizations l,
  Todo todo,
  String month,
) => switch (todo.kind) {
  TodoKind.invoiceTheMonth => (
    icon: Icons.description_outlined,
    title: l.invoicingTodoMonth(month),
    button: l.invoicingTodoReview,
    alert: false,
  ),
  TodoKind.shareReminders => (
    icon: Icons.notifications_outlined,
    title: l.invoicingTodoReminders,
    button: l.invoicingTodoReview,
    alert: false,
  ),
  TodoKind.confirmPayments => (
    icon: Icons.payments_outlined,
    title: l.invoicingTodoConfirm,
    button: l.invoicingTodoReview,
    alert: false,
  ),
  TodoKind.matchPayments => (
    icon: Icons.link,
    title: l.invoicingTodoMatch,
    button: l.invoicingTodoReview,
    alert: false,
  ),
  TodoKind.payOutRefunds => (
    icon: Icons.undo,
    title: l.invoicingTodoRefunds,
    button: l.invoicingTodoReview,
    alert: false,
  ),
  TodoKind.rejectedEInvoices => (
    icon: Icons.error_outline,
    title: l.invoicingTodoRejected(todo.tally.count),
    button: l.invoicingTodoFix,
    alert: true,
  ),
  TodoKind.issueDrafts => (
    icon: Icons.edit_note_outlined,
    title: l.invoicingTodoDrafts,
    button: l.invoicingTodoReview,
    alert: false,
  ),
};

/// Amounts per currency, said one after the other ("CHF 120.00 · EUR 40.00"):
/// never added across currencies.
String amountsOf(AppFormat format, Tally tally) => [
  for (final e in tally.byCurrency.entries)
    format.moneyIn(e.key).formatMinor(e.value),
].join(' · ');
