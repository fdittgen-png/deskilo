// SPDX-License-Identifier: AGPL-3.0-or-later
import 'invoice.dart';

/// #2365 — which negative lines are money that ARRIVED. A ledger expense
/// credit is booked once, in the purchases journal, and a goodwill
/// adjustment is no cash at all: neither may reach the bank account.
extension InvoiceLineCash on InvoiceLine {
  bool get isMoneyIn =>
      amountCents < 0 && kind != 'expense' && kind != 'adjustment';
}
