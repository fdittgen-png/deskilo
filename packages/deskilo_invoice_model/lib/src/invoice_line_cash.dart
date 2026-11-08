// SPDX-License-Identifier: AGPL-3.0-or-later
import 'invoice.dart';

/// #2365 — which negative lines are money that ARRIVED. A ledger expense
/// credit is booked once, in the purchases journal, and a goodwill
/// adjustment is no cash at all: neither may reach the bank account.
extension InvoiceLineCash on InvoiceLine {
  bool get isMoneyIn =>
      amountCents < 0 && kind != 'expense' && kind != 'adjustment';
}

/// #2365 — the money the workspace PAID OUT on a credit note: the standing
/// match of a refunded credit note (`settle_credit_invoice`, resolution
/// `refunded`, a positive `paid_cents`). Zero for everything else, and for
/// a refund still awaiting validation. It is bank money going OUT: every
/// exporter books it as the reverse of a receipt.
int refundedCents(Invoice invoice, InvoiceMatch? match) =>
    invoice.isCreditNote &&
        match != null &&
        !match.pending &&
        match.resolution == 'refunded' &&
        match.paidCents > 0
    ? match.paidCents
    : 0;
