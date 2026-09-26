// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1647 — the signed-in person's canonical-identity status on THIS
// installation, as `my_identity_status` / `finalize_identity_binding`
// answer it. It never carries the subject or any raw Auth payload, and it
// confers nothing: no membership, no role, no MCP eligibility.

/// Where the local account stands.
enum IdentityBindingState {
  /// Bound to the installation's canonical identity.
  verified,

  /// The installation has an authority; this account is not bound yet.
  unlinked,

  /// The account cannot be bound: anonymous, unconfirmed, no provider
  /// identity, wrong issuer.
  ineligible,

  /// Another binding stands in the way; relinking needs explicit proof.
  conflict,

  /// No authority is configured here, or the server predates 0269, or the
  /// answer could not be read. Never read as "unlinked".
  unavailable,
}

class IdentityBindingStatus {
  const IdentityBindingStatus({
    required this.state,
    this.installationId,
    this.issuer,
    this.reason,
    this.boundAt,
  });

  final IdentityBindingState state;
  final String? installationId;
  final String? issuer;

  /// The server's reason code (`unverified`, `issuer_mismatch`,
  /// `subject_bound_to_another_user`, `no_authority`, …).
  final String? reason;
  final DateTime? boundAt;

  static const unknown = IdentityBindingStatus(
    state: IdentityBindingState.unavailable,
    reason: 'unknown_answer',
  );

  /// Parses the RPC's JSON. An unknown status or a malformed answer is
  /// [IdentityBindingState.unavailable] — never promoted to verified.
  factory IdentityBindingStatus.fromJson(Object? json) {
    if (json is! Map) return unknown;
    final state = IdentityBindingState.values
        .where((s) => s.name == json['status'])
        .firstOrNull;
    if (state == null) return unknown;
    String? text(String key) => json[key] is String ? json[key] as String : null;
    final boundAt = DateTime.tryParse(text('bound_at') ?? '');
    if (state == IdentityBindingState.verified &&
        (text('issuer') == null || boundAt == null)) {
      return unknown;
    }
    return IdentityBindingStatus(
      state: state,
      installationId: text('installation_id'),
      issuer: text('issuer'),
      reason: text('reason'),
      boundAt: boundAt?.toUtc(),
    );
  }
}

/// The caller's own binding. Implementations answer for the signed-in
/// account only; there is no way to ask about anybody else.
abstract interface class IdentityBindingRepository {
  Future<IdentityBindingStatus> status();
  Future<IdentityBindingStatus> finalize();
  Future<IdentityBindingStatus> revoke();
}
