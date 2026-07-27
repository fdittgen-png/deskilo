// SPDX-License-Identifier: 0BSD

/// Whether this workspace can SEND an e-invoice, and what it still needs
/// (0073). Probed from the `send-e-invoice` function so the app never
/// offers a button that cannot work: an undeployed function or an
/// unconfigured platform both land on [notConfigured].
class EInvoiceGatewayConfig {
  const EInvoiceGatewayConfig({
    required this.configured,
    this.provider = 'generic',
    this.missing = const [],
  });

  /// No platform, or no function deployed — the affordance stays hidden.
  static const notConfigured = EInvoiceGatewayConfig(configured: false);

  final bool configured;

  /// Which adapter the function will use.
  final String provider;

  /// Config fields the owner has not filled in yet.
  final List<String> missing;
}

/// What the platform answered.
enum EInvoiceSubmissionStatus {
  /// The platform took the document.
  accepted,

  /// It answered no — the detail carries its words.
  rejected,

  /// It could not be reached at all.
  failed,
}

class EInvoiceSubmission {
  const EInvoiceSubmission({
    required this.status,
    this.externalId = '',
    this.detail = '',
  });

  final EInvoiceSubmissionStatus status;

  /// The platform's own id for the document — the handle for asking about
  /// it later. '' when it returned none.
  final String externalId;

  final String detail;

  bool get accepted => status == EInvoiceSubmissionStatus.accepted;
}

/// One recorded attempt at sending an invoice (0071). The log is the
/// answer to "did this leave, when, and which version did they get".
class InvoiceTransmission {
  const InvoiceTransmission({
    required this.invoiceId,
    required this.status,
    required this.sentAt,
    this.provider = 'generic',
    this.externalId = '',
    this.documentHash = '',
    this.detail = '',
    this.byName = '',
  });

  final String invoiceId;
  final EInvoiceSubmissionStatus status;
  final DateTime sentAt;
  final String provider;
  final String externalId;

  /// SHA-256 of the bytes that left.
  final String documentHash;
  final String detail;
  final String byName;

  bool get accepted => status == EInvoiceSubmissionStatus.accepted;

  factory InvoiceTransmission.fromRow(Map<String, dynamic> row) =>
      InvoiceTransmission(
        invoiceId: row['invoice_id'] as String,
        status: EInvoiceSubmissionStatus.values.firstWhere(
          (s) => s.name == row['status'],
          orElse: () => EInvoiceSubmissionStatus.failed,
        ),
        sentAt: DateTime.parse(row['sent_at'] as String).toLocal(),
        provider: row['provider'] as String? ?? 'generic',
        externalId: row['external_id'] as String? ?? '',
        documentHash: row['document_hash'] as String? ?? '',
        detail: row['detail'] as String? ?? '',
        byName: row['by_name'] as String? ?? '',
      );
}

/// The owner-visible state of the platform credentials: the non-secret
/// fields as stored, plus the NAMES of the secrets that are set. A token
/// never comes back out of the server (0071).
class EInvoiceProviderStatus {
  const EInvoiceProviderStatus({
    required this.configured,
    this.fields = const {},
    this.secretsSet = const [],
  });

  final bool configured;
  final Map<String, String> fields;
  final List<String> secretsSet;
}
