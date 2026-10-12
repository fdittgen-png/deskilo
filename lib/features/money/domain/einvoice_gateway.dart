// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';

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
    this.destinations = const {},
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

  /// destination name → its readiness (#568). EMPTY when the deployed
  /// function predates destinations — the same latch as [environments]:
  /// the customer leg is only offered when the function demonstrably
  /// understands the parameter, because an older one would ignore it and
  /// post the document to the government platform.
  final Map<String, EInvoiceDestination> destinations;

  /// Test environments (anything but prod) that are ready to send.
  List<String> get testEnvironments => [
        for (final entry in environments.entries)
          if (entry.key != 'prod' && entry.value) entry.key,
      ];

  /// The customer's delivery service is configured AND the function
  /// understands destinations (#568).
  bool get customerConfigured =>
      destinations['customer']?.configured ?? false;
}

/// One destination's readiness (#568): the government platform or the
/// customer's own delivery service, each with its own endpoint and
/// credential.
class EInvoiceDestination {
  const EInvoiceDestination({
    required this.configured,
    this.missing = const [],
    this.environments = const {},
  });

  final bool configured;
  final List<String> missing;
  final Map<String, bool> environments;
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
    this.id = '',
    this.format = '',
    this.receipt = const {},
    this.receiptAt,
    this.provider = 'generic',
    this.externalId = '',
    this.documentHash = '',
    this.detail = '',
    this.byName = '',
    this.environment = 'prod',
    this.destination = 'government',
  });

  final String invoiceId;
  final EInvoiceSubmissionStatus status;
  final DateTime sentAt;

  /// The row's id — the handle for asking the channel about it (#2358).
  final String id;

  /// #2358 — the syntax that left ('' before #2358).
  final String format;

  /// #2358 — what the channel said about the document afterwards, as it
  /// said it (a Peppol evidence, the PA lifecycle, the SdI notification,
  /// the KSeF number, the ANAF state). Empty until it is asked.
  final Map<String, Object?> receipt;
  final DateTime? receiptAt;

  /// The one fact a reader wants from [receipt]: the number the network
  /// gave the document, or the state it reports — '' when it said nothing.
  String get receiptSummary {
    for (final key in const [
      'ksefNumber',
      'id_descarcare',
      'flowStatus',
      'notification',
      'state',
      'stare',
      'status',
    ]) {
      final value = receipt[key];
      if (value is String && value.isNotEmpty) return value;
      if (value is num) return '$value';
    }
    return '';
  }

  InvoiceTransmission copyWithReceipt(Map<String, Object?> value) =>
      InvoiceTransmission(
        invoiceId: invoiceId,
        status: status,
        sentAt: sentAt,
        id: id,
        format: format,
        receipt: value,
        receiptAt: sentAt,
        provider: provider,
        externalId: externalId,
        documentHash: documentHash,
        detail: detail,
        byName: byName,
        environment: environment,
        destination: destination,
      );
  final String provider;
  final String externalId;

  /// SHA-256 of the bytes that left.
  final String documentHash;
  final String detail;
  final String byName;

  /// Where it went (#393): a rehearsal must never read like the real
  /// submission. 'prod' for every row that predates environments.
  final String environment;

  /// WHO received it (#568): 'government' or 'customer'. 'government'
  /// for every row that predates destinations.
  final String destination;

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
        destination: row['destination'] as String? ?? 'government',
        id: JsonReader.of(row).stringOr('id'),
        format: JsonReader.of(row).stringOr('format'),
        receipt: JsonReader.of(row).objectOrEmpty('receipt'),
        receiptAt: JsonReader.of(row).dateTimeOrNull('receipt_at')?.toLocal(),
      );
}

/// The owner-visible state of the platform credentials: the non-secret
/// fields as stored, plus the NAMES of the secrets that are set. A token
/// never comes back out of the server (0071).
class EInvoiceProviderStatus {
  const EInvoiceProviderStatus({
    required this.configured,
    this.provider = 'generic',
    this.fields = const {},
    this.secretsSet = const [],
  });

  final bool configured;

  /// #2358 — the connector: 'generic', 'peppol', 'fr_pa', 'it_sdi',
  /// 'pl_ksef' or 'ro_efactura'.
  final String provider;
  final Map<String, String> fields;
  final List<String> secretsSet;
}
