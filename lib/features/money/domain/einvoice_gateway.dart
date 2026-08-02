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
    this.environments = const {},
  });

  /// No platform, or no function deployed — the affordance stays hidden.
  static const notConfigured = EInvoiceGatewayConfig(configured: false);

  final bool configured;

  /// Which adapter the function will use.
  final String provider;

  /// Config fields the owner has not filled in yet.
  final List<String> missing;

  /// environment name → ready to send there (#393). EMPTY when the
  /// deployed function predates environments — and that emptiness is the
  /// safety latch: the app only offers a UAT/dev choice when the function
  /// demonstrably understands the parameter, because an older one would
  /// ignore it and send the test document to production.
  final Map<String, bool> environments;

  /// Test environments (anything but prod) that are ready to send.
  List<String> get testEnvironments => [
        for (final entry in environments.entries)
          if (entry.key != 'prod' && entry.value) entry.key,
      ];
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
    this.environment = 'prod',
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

  /// Where it went (#393): a rehearsal must never read like the real
  /// submission. 'prod' for every row that predates environments.
  final String environment;

  bool get accepted => status == EInvoiceSubmissionStatus.accepted;

  bool get isTestSend => environment != 'prod';

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
        environment: row['environment'] as String? ?? 'prod',
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
