// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1647 — the native DTO for the caller's own canonical-identity status.
// Every server answer maps to exactly one state; an unknown status, a
// malformed answer or a "verified" without its issuer and date is
// `unavailable`, never promoted to verified; the subject is never read.
// The JSON fixtures are the shapes 0269 returns (see 57_identity_bindings).
import 'package:deskilo/core/demo/data/identity_binding_repository.dart';
import 'package:deskilo/features/auth/domain/identity_binding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each server answer maps to its own state', () {
    final verified = IdentityBindingStatus.fromJson({
      'status': 'verified',
      'installation_id': 'f0895307-5b95-4805-be2c-f1ccb9ed209f',
      'issuer': 'https://auth.deskilo.test/auth/v1',
      'verified_via': 'native_authority',
      'bound_at': '2026-09-26T13:46:40.876629+00:00',
    });
    expect(verified.state, IdentityBindingState.verified);
    expect(verified.issuer, 'https://auth.deskilo.test/auth/v1');
    expect(verified.boundAt, DateTime.utc(2026, 9, 26, 13, 46, 40, 876, 629));

    expect(IdentityBindingStatus.fromJson({'status': 'unlinked', 'issuer': 'https://a.test'}).state,
        IdentityBindingState.unlinked);
    final ineligible =
        IdentityBindingStatus.fromJson({'status': 'ineligible', 'reason': 'unverified'});
    expect(ineligible.state, IdentityBindingState.ineligible);
    expect(ineligible.reason, 'unverified');
    expect(
        IdentityBindingStatus.fromJson(
                {'status': 'conflict', 'reason': 'subject_bound_to_another_user'})
            .state,
        IdentityBindingState.conflict);
    expect(
        IdentityBindingStatus.fromJson({'status': 'unavailable', 'reason': 'no_authority'})
            .state,
        IdentityBindingState.unavailable);
  });

  test('nothing unknown or incomplete is ever read as verified', () {
    for (final answer in <Object?>[
      null,
      'verified',
      <String, Object?>{},
      {'status': 'VERIFIED'},
      {'status': 'linked'},
      {'status': 'verified'},
      {'status': 'verified', 'issuer': 'https://a.test'},
      {'status': 'verified', 'bound_at': '2026-09-26T00:00:00Z'},
      {'status': 'verified', 'issuer': 42, 'bound_at': '2026-09-26T00:00:00Z'},
    ]) {
      expect(IdentityBindingStatus.fromJson(answer).state,
          IdentityBindingState.unavailable,
          reason: '$answer');
    }
  });

  test('the DTO carries no subject, whatever the server sends', () {
    final status = IdentityBindingStatus.fromJson({
      'status': 'unlinked',
      'subject': 'kc-1',
      'identity_data': {'sub': 'kc-1'},
    });
    expect(status.state, IdentityBindingState.unlinked);
    expect('${status.issuer}${status.reason}${status.installationId}',
        isNot(contains('kc-1')));
  });

  test('the fake binds on finalize and unlinks on revoke', () async {
    final repo = FakeIdentityBindingRepository(
      initial: const IdentityBindingStatus(state: IdentityBindingState.unlinked),
      finalizeAnswer: IdentityBindingStatus(
        state: IdentityBindingState.verified,
        issuer: 'https://a.test',
        boundAt: DateTime.utc(2026, 9, 26),
      ),
    );
    expect((await repo.status()).state, IdentityBindingState.unlinked);
    expect((await repo.finalize()).state, IdentityBindingState.verified);
    expect((await repo.status()).state, IdentityBindingState.verified);
    expect((await repo.revoke()).state, IdentityBindingState.unlinked);
    expect(repo.finalizeCalls, 1);
  });
}
