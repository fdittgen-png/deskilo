// SPDX-License-Identifier: AGPL-3.0-or-later

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
}
