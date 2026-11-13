// SPDX-License-Identifier: AGPL-3.0-or-later
//
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
  const EInvoiceTestSent({
    required this.refusal,
    this.missing = const [],
  });

  final EInvoiceTestRefusal refusal;

  /// The sandbox fields still to fill, for [EInvoiceTestRefusal.sandboxMissing].
  final List<String> missing;

  bool get sent => refusal == EInvoiceTestRefusal.none;
}
