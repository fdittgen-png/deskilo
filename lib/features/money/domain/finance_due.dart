// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3659 (i18n I13) -- when one of MY invoices is late: on the ISSUING
// business's day, never the device's. The due day counts, as the server and
// the register rule it (#3285: one rule, `invoiceDue`); a credit note is
// money due to me and never late. A business whose calendar is unknown (no
// zone, or one that is not an IANA name) is never claimed late, and
// [FinanceInvoiceDue.dueDayUnknownAt] says so instead.
import '../../../core/time/business_day.dart';
import 'finance_overview.dart';
import 'invoice_due.dart';

/// Whether [FinanceInvoice] is late, on its business's day.
extension FinanceInvoiceDue on FinanceInvoice {
  /// Past the term at the instant [now], read in [FinanceInvoice.timezone].
  bool overdueAt(DateTime now) {
    final today = businessTodayAt(now, timezone).date;
    return _dueApplies && today != null && isOverdueOn(dueOn!, today);
  }

  /// A due date this invoice cannot be judged against: neither "late" nor
  /// "not late" holds.
  bool dueDayUnknownAt(DateTime now) =>
      _dueApplies && businessTodayAt(now, timezone) is UnknownBusinessDay;

  bool get _dueApplies => state.toPay && !isCreditNote && dueOn != null;
}
