// SPDX-License-Identifier: AGPL-3.0-or-later
import 'command_receipt.dart';

/// #2585 C2 — the two acts on an EXISTING invoice that answer no new id,
/// sent under the attempt's own request id (RPCs `request_invoice_void_v1`
/// and `request_refund_v1`, 0463). The server records a receipt in the same
/// transaction as the effect, so a lost answer is read back by the id
/// ([InvoiceQueries.invoiceCommandOutcome]) and the same id never acts twice.
///
/// Both return normally when applied and throw a pending-validation
/// exception when a policy holds the act.
abstract interface class InvoiceActionCommands {
  /// Tags [invoiceId] erroneous, the sole one-way change on an issued
  /// invoice.
  Future<void> voidInvoice(
    String invoiceId, {
    required String requestId,
    String reason = '',
  });

  /// Settles the NEGATIVE invoice [invoiceId] — a credit note the workspace
  /// pays — through the refund policy.
  Future<void> settleCreditInvoice(
    String invoiceId, {
    required String requestId,
    String note = '',
  });

  /// The direct issue the invoicing wizard and the sweep use (RPC
  /// `create_invoice_receipted_v1`, 0464): no validation policy, as before,
  /// but one receipt per [InvoiceIssueCommand.requestId]. A constituent that
  /// already committed replays its original id instead of failing on "already
  /// invoiced". Returns the invoice id.
  Future<String> createInvoiceOnce(InvoiceIssueCommand command);

  /// The correction of an erroneous invoice (RPC
  /// `create_invoice_replacement_v1`, 0465): issues directly, voids the
  /// replaced one in the same step and records one receipt under
  /// [InvoiceIssueCommand.requestId]. [InvoiceIssueCommand.replacesId] is
  /// required. Returns the new invoice's id; the same id replays it.
  Future<String> replaceInvoiceOnce(InvoiceIssueCommand command);

  /// Regroups [invoiceIds] into ONE invoice the member pays (RPC
  /// `settle_invoices_v1`, 0464) under [requestId]. Returns the settlement's
  /// id; the same id with the same set answers the same settlement.
  Future<String> settleInvoicesOnce({
    required String workspaceId,
    required String memberId,
    required List<String> invoiceIds,
    required String requestId,
    String note = '',
  });
}
