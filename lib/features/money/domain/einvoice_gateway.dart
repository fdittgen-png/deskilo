// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

export 'einvoice_resolution.dart';

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

  /// #3335 — submitted and not yet answered: the document is prepared or its
  /// dispatch is in flight. Nothing is sent again while it stands.
  inProgress,

  /// #3335 — the upload may have landed and its outcome is not known. Never
  /// resent blindly: a lookup or a person with the send authority settles it.
  uncertain;

  /// The status a server row or answer carries: the new `phase` when the
  /// server sends one, else the legacy `status` (an older server). A phase
  /// this client does not know reads as [uncertain], never as a failure that
  /// invites a resend.
  static EInvoiceSubmissionStatus fromWire({String? phase, String? status}) {
    final word = (phase != null && phase.isNotEmpty) ? phase : status;
    return switch (word) {
      'accepted' => accepted,
      'rejected' => rejected,
      'failed' => failed,
      'prepared' || 'sent' => inProgress,
      'uncertain' => uncertain,
      null || '' => failed,
      _ when phase != null && phase.isNotEmpty => uncertain,
      _ => failed,
    };
  }

  /// The submission is neither settled nor safely retryable.
  bool get isUnresolved => this == inProgress || this == uncertain;
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
    this.documentVerdict = '',
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

  /// #3881 — the platform's own verdict on the document: 'accepted',
  /// 'rejected', or '' while it has given none (`verdict.status`).
  final String documentVerdict;

  /// #3881 — an upload the platform took whose document it has not confirmed
  /// yet: a national channel that waits for the confirmation stays closed.
  bool get awaitsDocumentVerdict =>
      status == EInvoiceSubmissionStatus.accepted &&
      provider != 'generic' &&
      documentVerdict.isEmpty;

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

  /// The same row after it was settled by hand (#3335).
  InvoiceTransmission copyWithStatus(EInvoiceSubmissionStatus value) =>
      InvoiceTransmission(
        invoiceId: invoiceId,
        status: value,
        sentAt: sentAt,
        id: id,
        format: format,
        receipt: receipt,
        receiptAt: receiptAt,
        provider: provider,
        externalId: externalId,
        documentHash: documentHash,
        detail: detail,
        byName: byName,
        environment: environment,
        destination: destination,
        documentVerdict: documentVerdict,
      );

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
        documentVerdict: documentVerdict,
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

  /// #3335 — a submission whose outcome is not settled: no resend offered.
  bool get isUnresolved => status.isUnresolved;

  bool get isTestSend => environment != 'prod';

  factory InvoiceTransmission.fromRow(Map<String, dynamic> row) =>
      InvoiceTransmission(
        invoiceId: row['invoice_id'] as String,
        status: EInvoiceSubmissionStatus.fromWire(
          phase: row['phase'] as String?,
          status: row['status'] as String?,
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
        documentVerdict: _documentVerdictOf(row['verdict']),
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

/// #3881 — the platform's verdict as the row stores it: a person's record of a
/// rejection (`document`) or the platform's own answer (`status`).
String _documentVerdictOf(Object? verdict) {
  if (verdict is! Map) return '';
  if (verdict['document'] == 'rejected') return 'rejected';
  final status = verdict['status'];
  return status == 'accepted' || status == 'rejected' ? status as String : '';
}

// #3883 — the sandbox test document that opens a national channel's issuing
// gate: what its latest one says, and how a send of one ended.

/// Where the latest test document stands.
enum EInvoiceTestVerdict {
  /// No test document was sent yet.
  none,

  /// Sent, and the platform has not given its verdict yet.
  awaiting,

  /// The platform accepted it: the issuing gate is open.
  accepted,

  /// The platform refused it: another one can be sent.
  rejected,
}

/// The workspace's latest test document, as `send-e-invoice` reports it.
class EInvoiceTestState {
  const EInvoiceTestState({
    required this.available,
    this.transmissionId = '',
    this.verdict = EInvoiceTestVerdict.none,
  });

  /// Whether the configured channel takes a test document at all.
  final bool available;
  final String transmissionId;
  final EInvoiceTestVerdict verdict;

  /// A test may be sent: the channel takes one and none awaits its verdict.
  bool get canSend => available && verdict != EInvoiceTestVerdict.awaiting;

  static const unavailable = EInvoiceTestState(available: false);

  /// Reads the function's answer; anything unreadable is [unavailable].
  static EInvoiceTestState fromWire(Map<String, Object?> body) {
    final test = body['test'];
    if (test is! Map) {
      return EInvoiceTestState(available: body['available'] == true);
    }
    final phase = test['phase'];
    final document = test['document_status'];
    return EInvoiceTestState(
      available: body['available'] == true,
      transmissionId: test['transmission_id'] is String
          ? test['transmission_id'] as String
          : '',
      verdict: switch (document) {
        'accepted' => EInvoiceTestVerdict.accepted,
        'rejected' => EInvoiceTestVerdict.rejected,
        _ when phase == 'rejected' || phase == 'failed' =>
          EInvoiceTestVerdict.rejected,
        _ => EInvoiceTestVerdict.awaiting,
      },
    );
  }
}

/// Why a test document did not leave, or [none] when it did.
enum EInvoiceTestRefusal {
  none,

  /// Another test still awaits its verdict.
  pending,

  /// A sandbox credential field is missing.
  sandboxMissing,

  /// The sandbox credentials point elsewhere than the channel's sandbox.
  sandboxNotDocumented,

  /// The configured channel takes no test document.
  unavailable,

  /// The person may not manage the integrations.
  notAllowed,

  /// The platform could not be reached or refused the upload.
  failed;

  /// The function's `error` code, read; an unknown one is [failed].
  static EInvoiceTestRefusal fromWire(String? error) => switch (error) {
    null || '' => none,
    'test_pending' => pending,
    'sandbox_credentials_missing' => sandboxMissing,
    'sandbox_not_documented' => sandboxNotDocumented,
    'test_unavailable' => unavailable,
    'not allowed to manage the integrations of this workspace' => notAllowed,
    _ => failed,
  };
}

/// How sending a test document ended.
class EInvoiceTestSent {
  const EInvoiceTestSent({required this.refusal, this.missing = const []});

  final EInvoiceTestRefusal refusal;

  /// The sandbox fields still to fill, for [EInvoiceTestRefusal.sandboxMissing].
  final List<String> missing;

  bool get sent => refusal == EInvoiceTestRefusal.none;
}
