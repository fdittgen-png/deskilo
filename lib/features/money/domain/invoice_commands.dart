// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'billing_rules.dart';
import 'command_receipt.dart';

/// One part of a payment: [amountCents] of it settles [invoiceId] (#3671).
typedef PaymentAllocation = ({String invoiceId, int amountCents});

/// What the server answers to `apply_payment_to_invoices` (#3671): how many
/// invoices took a part and what stays on the payment as the payer's credit.
class PaymentApplied {
  const PaymentApplied({required this.invoices, required this.leftCents});

  factory PaymentApplied.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'apply_payment_to_invoices');
    return PaymentApplied(
      invoices: r.integer('invoices'),
      leftCents: r.integer('left_cents'),
    );
  }

  /// The invoices that took a part.
  final int invoices;

  /// What stays on the payment.
  final int leftCents;
}

/// What one open invoice of a payment's payer can take of it now (#3671,
/// `payment_invoice_capacity_v1`): the server's list, so the sheet never
/// offers a part the server refuses.
class InvoiceCapacity {
  const InvoiceCapacity({
    required this.invoiceId,
    required this.stillDueCents,
    required this.canTake,
  });

  factory InvoiceCapacity.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'payment_invoice_capacity_v1');
    return InvoiceCapacity(
      invoiceId: r.string('invoice_id'),
      stillDueCents: r.integer('still_due_cents'),
      canTake: r.isTrue('can_take'),
    );
  }

  final String invoiceId;

  /// The total, less what confirmed matches paid, less the parts that await
  /// approval.
  final int stillDueCents;

  /// False while a payment of this invoice awaits approval: it is shown,
  /// not offered.
  final bool canTake;
}

/// #2591 C3 — what a person does to an invoice: issue or correct, void,
/// remind, regroup, settle a credit note, match a payment. Each call is
/// the server's own decision (a policy may hold it pending); nothing here
/// re-derives an amount or a rule in Dart, and a lost write response is
/// never retried by the port.
abstract interface class InvoiceCommands {
  /// Issues an IMMUTABLE invoice (RPC `create_invoice`) — owner always,
  /// admins per the adminInvoicing delegation. Returns its id. Since
  /// 0062 the positions are DERIVED server-side from [period]'s tracked
  /// data — nothing is entered at issue time. With [replacesId] (0061)
  /// the new invoice references the erroneous one it replaces; the
  /// server voids that one in the same transaction.
  /// [detailed] (0064) snapshots the annex — the period's full ledger
  /// and attendance — into the immutable document.
  ///
  /// #827 — [kind] narrows the document to the subscription (ahead of
  /// the month) or the usage (after it); [InvoiceKind.full] is the
  /// historical whole-month invoice.
  Future<String> createInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
    String? replacesId,
    bool detailed = false,
    InvoiceKind kind = InvoiceKind.full,

    /// #922 — BT-10 and BT-13, for a public-sector buyer (Chorus Pro).
    /// Frozen on the document; empty for everyone else.
    String buyerReference = '',
    String purchaseOrder = '',

    /// #2440 — RD 1619/2012 art. 15: why a Spanish seller corrects a
    /// document (R1-R5). Ignored for every other seller.
    String correctionReason = '',
  });

  /// #2585 C2 — [createInvoice] for a NEW invoice (no replacement) under the
  /// attempt's own [requestId] (RPC `request_invoice_issue_v1`, 0462). The
  /// server records a receipt in the same transaction as the effect, so the
  /// outcome of a lost answer is read back by this id
  /// ([InvoiceQueries.invoiceCommandOutcome]) and the same id never acts
  /// twice. Same answers as [createInvoice]: the id, or a pending-validation
  /// exception.
  Future<String> issueInvoiceWithReceipt(InvoiceIssueCommand command);

  /// Tags an invoice erroneous (RPC `void_invoice`, 0061) — the sole
  /// one-way change the server permits on an issued invoice.
  Future<void> voidInvoice(String invoiceId);

  /// Records a payment reminder (RPC `record_invoice_reminder`, 0066)
  /// — collection metadata beside the immutable document.
  Future<void> remindInvoice(String invoiceId);

  /// Settles a NEGATIVE invoice — a credit note the WORKSPACE pays
  /// (#508, 0102): books the payout charge and closes the avoir with
  /// resolution 'refunded' (through the invoice_payment policy).
  Future<void> settleCreditInvoice(String invoiceId, {String note = ''});

  /// #804 — regroups [invoiceIds] into ONE invoice the member pays.
  /// The sources stay in the archive and stop being separately owed.
  /// Answers the settlement's id.
  Future<String> settleInvoices({
    required String workspaceId,
    required String memberId,
    required List<String> invoiceIds,
    String note = '',
  });

  /// Matches an open invoice to a REGISTERED payment (RPC
  /// `match_invoice`, 0068): the amount comes from the selected ledger
  /// payment — never typed. [resolution] ∈ exact | over_forced |
  /// over_credit_note | under_accepted; the forced paths REQUIRE
  /// [note]. [amountCents] is the part of the payment this invoice takes
  /// (#3671, `p_amount_cents`); absent, it takes what is left of it.
  Future<void> matchInvoice({
    required String invoiceId,
    required String paymentLedgerId,
    required String resolution,
    String note = '',
    int? amountCents,
  });

  /// Settles several invoices with ONE payment (RPC
  /// `apply_payment_to_invoices`, #3671): each of [allocations] is the part
  /// of the payment one invoice takes; a part below what is due on its
  /// invoice is accepted as partial and needs [note]. All or nothing.
  Future<PaymentApplied> applyPaymentToInvoices({
    required String workspaceId,
    required String paymentLedgerId,
    required List<PaymentAllocation> allocations,
    String note = '',
  });

  /// The open invoices of [paymentLedgerId]'s payer and what each can take
  /// of it now (RPC `payment_invoice_capacity_v1`, #3671).
  Future<List<InvoiceCapacity>> paymentInvoiceCapacity({
    required String workspaceId,
    required String paymentLedgerId,
  });
}
