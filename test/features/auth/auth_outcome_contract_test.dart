// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1649 — the repository answers WHAT HAPPENED, as a value, from the
// wire shapes gotrue 2.25 actually produces: a sign-up that issued a
// session is `authenticated`, one that sent an e-mail is
// `verificationRequired` (new account or obfuscated existing one alike),
// every coded refusal is its own `AuthRefusal`, a 429 is `rateLimited`
// with the server's own wait, a 5xx or a dead socket is `unavailable`, and
// a recovery whose update failed after its code was redeemed is
// `recoverySessionReadyButPasswordNotUpdated` — never a bad code — with
// the session it opened held back until the update lands.
//
// The fake never speaks to gotrue, so this drives the REAL
// SupabaseAuthRepository over a MockClient, the way signup_redirect_test
// does, and reads the request that went out where the contract is about
// the request (resend hits /resend, not /signup).
import 'dart:convert';

import 'package:deskilo/features/auth/data/supabase_auth_repository.dart';
import 'package:deskilo/features/auth/domain/auth_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryStorage extends GotrueAsyncStorage {
  final Map<String, String> _items = {};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _items[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}

const _email = 'newcomer@example.org';

const _user = {
  'id': '00000000-0000-0000-0000-000000000001',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': _email,
  'created_at': '2026-09-25T09:00:00Z',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
};

/// gotrue's answer when the address is already taken and enumeration
/// protection is on: a user-shaped body with no identities and no
/// session — indistinguishable, on purpose, from a fresh sign-up.
const _obfuscatedUser = {..._user, 'identities': <Object?>[]};

const _session = {
  'access_token': 'at',
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'rt',
  'user': _user,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {
        'content-type': 'application/json',
        // The header gotrue reads to decide that `code` (not the legacy
        // `error_code`) carries the error code.
        'x-supabase-api-version': '2024-01-01',
      },
    );

http.Response _error(String code, String message, [int status = 400]) =>
    _json({'code': code, 'message': message}, status);

void main() {
  final requests = <http.Request>[];

  SupabaseAuthRepository repositoryAnswering(
    http.Response Function(http.Request) answer,
  ) {
    requests.clear();
    return SupabaseAuthRepository(SupabaseClient(
      'https://project.supabase.co',
      'anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return answer(request);
      }),
      authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryStorage()),
    ));
  }

  Future<AuthResult> signUp(SupabaseAuthRepository repo) => repo.signUp(
        email: _email,
        password: 'a-long-enough-password',
        displayName: 'Newcomer',
      );

  test('a sign-up that issued a session is authenticated', () async {
    final repo = repositoryAnswering((_) => _json(_session));
    final result = await signUp(repo);
    expect(result.outcome, AuthOutcome.authenticated);
    expect(repo.currentUserId, _user['id']);
  });

  test('a sign-up without a session is verificationRequired, and the '
      'obfuscated existing-user body reads exactly the same', () async {
    for (final body in [_user, _obfuscatedUser]) {
      final repo = repositoryAnswering((_) => _json(body));
      final result = await signUp(repo);
      expect(result.outcome, AuthOutcome.verificationRequired,
          reason: 'body $body');
      expect(repo.currentUserId, isNull, reason: 'no session was issued');
    }
  });

  test('a refused sign-up leaves no session behind', () async {
    final repo = repositoryAnswering(
        (_) => _error('signup_disabled', 'Signups not allowed', 422));
    final result = await signUp(repo);
    expect(result.outcome, AuthOutcome.refused);
    expect(result.refusal, AuthRefusal.providerDisabled);
    expect(repo.currentUserId, isNull);
  });

  test('each coded refusal is its own AuthRefusal, and the trace carries '
      'the code, never the message', () async {
    const cases = {
      'invalid_credentials': AuthRefusal.credentials,
      'email_not_confirmed': AuthRefusal.emailNotConfirmed,
      'email_provider_disabled': AuthRefusal.providerDisabled,
      'user_already_exists': AuthRefusal.alreadyRegistered,
      'some_code_nobody_mapped': AuthRefusal.credentials,
    };
    for (final MapEntry(key: code, value: refusal) in cases.entries) {
      final repo = repositoryAnswering(
          (_) => _error(code, 'server prose quoting $_email', 400));
      final result = await repo.signInWithPassword(
          email: _email, password: 'whatever-it-was');
      expect(result.outcome, AuthOutcome.refused, reason: code);
      expect(result.refusal, refusal, reason: code);
      expect(result.trace, code);
      expect(result.trace, isNot(contains(_email)));
    }
  });

  test('a weak password is refused as such', () async {
    final repo = repositoryAnswering((_) => _json({
          'code': 'weak_password',
          'message': 'Password should be at least 12 characters',
          'weak_password': {
            'reasons': ['length']
          },
        }, 422));
    final result = await signUp(repo);
    expect(result.outcome, AuthOutcome.refused);
    expect(result.refusal, AuthRefusal.weakPassword);
  });

  test('a 429 is rateLimited — not refused, nothing was judged', () async {
    final repo = repositoryAnswering((_) => _error(
        'over_request_rate_limit', 'Request rate limit reached', 429));
    final result = await signUp(repo);
    expect(result.outcome, AuthOutcome.rateLimited);
    expect(result.refusal, isNull);
    expect(result.retryAfter, isNull, reason: 'the server named no wait');
  });

  test('resend goes to /resend as a signup OTP, never to /signup again',
      () async {
    final repo = repositoryAnswering((_) => _json(<String, Object?>{}));
    final result = await repo.resendSignUpVerification(_email);
    expect(result.outcome, AuthOutcome.verificationRequired);
    final sent = requests.single;
    expect(sent.url.path, endsWith('/auth/v1/resend'));
    final body = jsonDecode(sent.body) as Map;
    expect(body['type'], 'signup');
    expect(body['email'], _email);
  });

  test('a resend too soon is rateLimited with the wait the server named',
      () async {
    final repo = repositoryAnswering((_) => _error(
        'over_email_send_rate_limit',
        'For security purposes, you can only request this after 42 seconds.',
        429));
    final result = await repo.resendSignUpVerification(_email);
    expect(result.outcome, AuthOutcome.rateLimited);
    expect(result.retryAfter, const Duration(seconds: 42));
  });

  test('a 5xx and a dead socket are unavailable — nothing was judged',
      () async {
    final crashed =
        repositoryAnswering((_) => _json({'message': 'boom'}, 503));
    expect((await signUp(crashed)).outcome, AuthOutcome.unavailable);

    final offline = repositoryAnswering(
        (_) => throw http.ClientException('Connection refused'));
    expect((await signUp(offline)).outcome, AuthOutcome.unavailable);
    expect(offline.currentUserId, isNull);
  });

  group('recovery', () {
    Future<AuthResult> confirm(SupabaseAuthRepository repo) =>
        repo.confirmPasswordReset(
          email: _email,
          code: '123456',
          newPassword: 'brand-new-password',
        );

    /// /verify answers a session; /user answers [update]; the rest 200.
    SupabaseAuthRepository recovering(http.Response Function() update) =>
        repositoryAnswering((request) {
          final path = request.url.path;
          if (path.endsWith('/auth/v1/verify')) return _json(_session);
          if (path.endsWith('/auth/v1/user')) return update();
          return _json(<String, Object?>{});
        });

    List<String> paths() => [for (final r in requests) r.url.path];

    test('a request that went out is recoveryVerificationRequired', () async {
      final repo = repositoryAnswering((_) => _json(<String, Object?>{}));
      final result = await repo.requestPasswordReset(_email);
      expect(result.outcome, AuthOutcome.recoveryVerificationRequired);
      expect(requests.single.url.path, endsWith('/auth/v1/recover'));
    });

    test('a spent or wrong code is refused as codeInvalid, and no update '
        'is attempted', () async {
      final repo = repositoryAnswering(
          (_) => _error('otp_expired', 'Token has expired or is invalid', 403));
      final result = await confirm(repo);
      expect(result.outcome, AuthOutcome.refused);
      expect(result.refusal, AuthRefusal.codeInvalid);
      expect(paths(), [endsWith('/auth/v1/verify')]);
      expect(repo.currentUserId, isNull);
    });

    test('completed only once the update itself answered; then, and only '
        'then, the session is visible', () async {
      final repo = recovering(() => _json(_user));
      final result = await confirm(repo);
      expect(result.outcome, AuthOutcome.completed);
      expect(paths(), [endsWith('/auth/v1/verify'), endsWith('/auth/v1/user')]);
      expect(repo.currentUserId, _user['id']);
    });

    test('an update that fails AFTER the code was redeemed is '
        'recoverySessionReadyButPasswordNotUpdated — and the session it '
        'opened is held back from the router', () async {
      final repo = recovering(() => _json({'message': 'boom'}, 500));
      final result = await confirm(repo);
      expect(result.outcome,
          AuthOutcome.recoverySessionReadyButPasswordNotUpdated);
      expect(result.refusal, isNull);
      expect(repo.currentUserId, isNull,
          reason: 'gotrue holds a session; the app must not act on it');
      expect(await repo.authStateChanges().first, isNull);
    });

    test('the retry goes to /user only — the spent code is never sent '
        'again — and completing it releases the session', () async {
      var updates = 0;
      final repo = recovering(() =>
          ++updates == 1 ? _json({'message': 'boom'}, 500) : _json(_user));
      await confirm(repo);
      requests.clear();
      final retried = await repo.updateRecoveredPassword('brand-new-password');
      expect(retried.outcome, AuthOutcome.completed);
      expect(paths(), [endsWith('/auth/v1/user')]);
      expect(repo.currentUserId, _user['id']);
      expect(await repo.authStateChanges().first, _user['id']);
    });

    test('a retry with the session gone is recoveryVerificationRequired',
        () async {
      final repo = repositoryAnswering((_) => _json(_user));
      final result = await repo.updateRecoveredPassword('brand-new-password');
      expect(result.outcome, AuthOutcome.recoveryVerificationRequired);
      expect(requests, isEmpty, reason: 'gotrue refuses before the wire');
    });

    test('a deferred update (429) stays held back for the retry', () async {
      final repo = recovering(() => _error(
          'over_request_rate_limit', 'Request rate limit reached', 429));
      final result = await confirm(repo);
      expect(result.outcome, AuthOutcome.rateLimited);
      expect(repo.currentUserId, isNull);
    });

    test('cancelling after a spent code signs out THIS session only', () async {
      final repo = recovering(() => _json({'message': 'boom'}, 500));
      await confirm(repo);
      requests.clear();
      await repo.cancelPasswordRecovery();
      final logout = requests.single;
      expect(logout.url.path, endsWith('/auth/v1/logout'));
      expect(logout.url.queryParameters['scope'], 'local');
      expect(repo.currentUserId, isNull);
    });

    test('cancelling with nothing pending touches nothing', () async {
      final repo = recovering(() => _json(_user));
      await confirm(repo);
      requests.clear();
      await repo.cancelPasswordRecovery();
      expect(requests, isEmpty);
      expect(repo.currentUserId, _user['id'], reason: 'the update landed');
    });
  });
}
