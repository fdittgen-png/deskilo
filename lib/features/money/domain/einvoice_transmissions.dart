// SPDX-License-Identifier: AGPL-3.0-or-later
import 'einvoice_gateway.dart';

/// #2591 — sending an issued invoice through an e-invoicing channel, its
/// receipts, and the owner's channel credentials.
abstract interface class EInvoiceTransmissions {
  /// Can this workspace SEND an e-invoice, and what does it still need
  /// (0073)? An undeployed function maps to
  /// [EInvoiceGatewayConfig.notConfigured], never a throw — the app hides
  /// the affordance rather than offering a button that cannot work.
  Future<EInvoiceGatewayConfig> fetchEInvoiceGateway(String workspaceId);

  /// invoiceId → its LATEST transmission (0071); invoices never sent are
  /// absent. Admin-readable.
  Future<Map<String, InvoiceTransmission>> fetchInvoiceTransmissions(
    String workspaceId,
  );

  /// Owner-only: the non-secret fields as stored plus the NAMES of the
  /// secrets that are set — never a secret's value.
  Future<EInvoiceProviderStatus> fetchEInvoiceStatus(String workspaceId);

  /// Posts an issued invoice's document to one of the workspace's
  /// e-invoicing channels (Edge Function `send-e-invoice`): the
  /// government platform, or the customer's own delivery service (#568).
  /// The CLIENT builds the bytes with the same builder the download uses;
  /// the function holds the credential and records the attempt.
  Future<EInvoiceSubmission> sendEInvoice({
    required String workspaceId,
    required String invoiceId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    String environment = 'prod',
    String destination = 'government',
    String format = '',
    String receiverScheme = '',
    String receiverId = '',
  });

  /// #2358 — asks the channel what became of an earlier transmission and
  /// stores its receipt (a Peppol evidence, the PA lifecycle, the SdI
  /// notification, the KSeF number, the ANAF state) on that row.
  Future<EInvoiceSubmission> requestEInvoiceReceipt({
    required String workspaceId,
    required String transmissionId,
  });

  /// #3335 — settles an `uncertain` submission by hand: what the person
  /// established ([resolution]), why, and the platform record they checked.
  /// The function re-checks the send authority and refuses a second
  /// resolution; a refusal is a result, not a throw.
  Future<EInvoiceResolveResult> resolveEInvoiceTransmission({
    required String workspaceId,
    required String transmissionId,
    required EInvoiceResolution resolution,
    required String reason,
    required String evidence,
    bool documentRejected = false,
  });

  /// Owner-only: merge the platform credentials (blank fields keep their
  /// stored value, so an endpoint changes without re-typing a token).
  Future<void> setEInvoiceCredentials(
    String workspaceId,
    Map<String, String> config,
  );

  /// Owner-only: forget the platform entirely.
  Future<void> clearEInvoiceCredentials(String workspaceId);

  /// #3883 — the latest sandbox test document of the national channel, for
  /// whoever manages the integrations; [EInvoiceTestState.unavailable] when
  /// the function is not deployed.
  Future<EInvoiceTestState> fetchEInvoiceTest(String workspaceId);

  /// #3883 — sends a sandbox test document the app built (no invoice): the
  /// function sends it to the channel's sandbox only, one at a time.
  Future<EInvoiceTestSent> sendEInvoiceTest({
    required String workspaceId,
    required String fileName,
    required List<int> bytes,
  });
}
