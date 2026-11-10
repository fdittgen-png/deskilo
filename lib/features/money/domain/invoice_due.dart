// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3285 -- ONE rule for when an invoice is due and whether it is overdue, read
// by the register, the journey, Me's summary and the banner: the due date
// frozen on the invoice wins; an invoice from before it was frozen keeps the
// date its document always printed (issue date + the term). Days are CALENDAR
// days (a clock change moves nothing). The due day itself is overdue, as the
// server rules it (`today < due_on` is "before the term", 0331): a changed
// current term never rewrites an issued obligation.
import '../../../core/time/calendar_days.dart';

/// When an invoice falls due, as of a day.
class InvoiceDue {
  const InvoiceDue({required this.dueOn, required this.daysToTerm});

  /// The calendar date the payment is due.
  final DateTime dueOn;

  /// Days until the due date (positive), 0 on it, past it (negative).
  final int daysToTerm;

  /// The due day and every day after it.
  bool get overdue => daysToTerm <= 0;
}

/// The due date and the days to it, as of [now]. [dueOn] is the frozen date
/// (null on an invoice issued before 0331); [termDays] is only its fallback.
InvoiceDue invoiceDue({
  required DateTime? dueOn,
  required DateTime issuedAt,
  required int termDays,
  required DateTime now,
}) {
  final fixed = dueOn;
  return InvoiceDue(
    dueOn: fixed ?? addCalendarDays(issuedAt, termDays),
    daysToTerm: fixed != null
        ? calendarDaysBetween(now, fixed)
        : termDays - calendarDaysBetween(issuedAt, now),
  );
}

/// Whether a frozen [dueOn] has been reached by [now] (the due day counts).
bool isOverdueOn(DateTime dueOn, DateTime now) =>
    calendarDaysBetween(now, dueOn) <= 0;
