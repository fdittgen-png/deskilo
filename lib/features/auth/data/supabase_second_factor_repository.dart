// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/second_factor.dart';

/// #1627 — Supabase Auth MFA (TOTP): list, enroll, challenge and verify.
class SupabaseSecondFactorRepository implements SecondFactorRepository {
  const SupabaseSecondFactorRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<SecondFactorState> state() async {
    final factors = await _client.auth.mfa.listFactors();
    final level = _client.auth.mfa.getAuthenticatorAssuranceLevel();
    final verified = factors.totp.where(
      (f) => f.status == FactorStatus.verified,
    );
    return SecondFactorState(
      aal2: level.currentLevel == AuthenticatorAssuranceLevels.aal2,
      verifiedTotpId: verified.isEmpty ? null : verified.first.id,
    );
  }

  @override
  Future<TotpEnrollment> enrollTotp() async {
    final r = await _client.auth.mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'Deskilo',
    );
    final totp = r.totp;
    if (totp == null) {
      throw StateError('the server did not return a TOTP enrollment');
    }
    return TotpEnrollment(factorId: r.id, secret: totp.secret, uri: totp.uri);
  }

  @override
  Future<void> verify(String factorId, String code) =>
      _client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
}
