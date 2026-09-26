// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1627 — the second factor a database decision needs. The server checks
// the session's `aal` claim itself (require_database_reviewer); this is
// only how the person reaches aal2. Nothing here simulates success.

class SecondFactorState {
  const SecondFactorState({required this.aal2, this.verifiedTotpId});

  /// The current session was verified with a second factor.
  final bool aal2;

  /// An enrolled, verified authenticator app, if any.
  final String? verifiedTotpId;
}

class TotpEnrollment {
  const TotpEnrollment({
    required this.factorId,
    required this.secret,
    required this.uri,
  });
  final String factorId;
  final String secret;

  /// The otpauth:// URI an authenticator app scans.
  final String uri;
}

abstract interface class SecondFactorRepository {
  Future<SecondFactorState> state();
  Future<TotpEnrollment> enrollTotp();

  /// Verifies [code] for [factorId]; the session is aal2 afterwards.
  Future<void> verify(String factorId, String code);
}
