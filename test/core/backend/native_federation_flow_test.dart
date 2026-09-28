// SPDX-License-Identifier: AGPL-3.0-or-later
// #1791: an isolated SDK exchange cannot replace the active account before
// issuer, installation and native binding checks pass; failures retain context.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/backend/auth_callback_guard.dart';
import 'package:deskilo/core/backend/federation_authority.dart';
import 'package:deskilo/core/backend/native_federation_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'installation_auth_storage_test.dart' show MemorySecrets;

const installation = '00000000-0000-4000-8000-000000001791';
const issuer = 'https://identity.example/auth/v1';
const authority = FederationAuthority(installation, issuer);
Map<String, Object?> user(String id) => {
  'id': id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'created_at': '2026-09-28T00:00:00Z',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
};
Map<String, Object?> session(String id) {
  final jwt = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': id,
        'iss': 'https://target.example/auth/v1',
        'exp':
            4102444800 /* fixed year 2100: the SDK checks real token expiry */,
      }),
    ),
  );
  return {
    'access_token': 'e30.$jwt.signature',
    'refresh_token': 'target-refresh-$id',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': user(id),
  };
}

void main() {
  for (final scenario in [
    'success',
    'wrong issuer',
    'wrong account',
    'account changed',
  ]) {
    test('real SDK exchange: $scenario retains the correct native context', () async {
      final secrets = MemorySecrets();
      final guard = AuthCallbackGuard(
        secrets,
        Uri.parse('https://target.example'),
        Uri.parse('deskilo://auth-callback'),
      );
      final proofStarted = Completer<void>();
      final proofRelease = Completer<void>();
      final linked = scenario == 'wrong account';
      final calls = <http.Request>[];
      final wire = MockClient((request) async {
        http.Response reply(Object? value) => http.Response(
          jsonEncode(value),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
        calls.add(request);
        expect(request.url.origin, 'https://target.example');
        expect(
          request.headers['apikey'],
          'public-target',
          reason: request.headers.keys.join(','),
        );
        switch (request.url.path) {
          case '/auth/v1/user/identities/authorize':
            return reply({
              'url': 'https://target.example/auth/v1/authorize?provider=custom%3Adeskilo',
            });
          case '/auth/v1/token':
            final body = jsonDecode(request.body) as Map;
            expect(body['auth_code'], 'target-code');
            expect(body['code_verifier'], isNotEmpty);
            return reply({
              ...session('target-person'),
              'provider_token': 'canonical-identity-token',
              'provider_refresh_token': 'canonical-identity-refresh',
            });
          case '/auth/v1/user':
            return reply(user('target-person'));
          case '/rest/v1/rpc/public_identity_authority':
            return reply({
              'kind': 'oidc',
              'provider': 'custom:deskilo',
              'installation_id': installation,
              'issuer': scenario == 'wrong issuer'
                  ? 'https://other.example'
                  : issuer,
            });
          case '/rest/v1/rpc/finalize_identity_binding':
            proofStarted.complete();
            await proofRelease.future;
            return reply({
              'status': 'verified',
              'installation_id': installation,
              'issuer': issuer,
            });
          case '/auth/v1/logout':
            return reply({});
          default:
            fail('Unexpected target endpoint: ${request.url.path}');
        }
      });
      final active = SupabaseClient(
        'https://target.example',
        'public-target',
        httpClient: wire,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(active.dispose);
      if (linked) {
        await active.auth.recoverSession(
          jsonEncode(session('original-person')),
        );
      }
      Uri? launched;
      final federation = NativeFederationFlow(
        active,
        guard,
        secrets,
        httpClient: wire,
        launch: (uri) async {
          launched = uri;
          return true;
        },
      );
      await federation.begin(authority, link: linked);
      final redirect = Uri.parse(
        linked
            ? calls.single.url.queryParameters['redirect_to']!
            : launched!.queryParameters['redirect_to']!,
      );
      final callback = redirect.replace(
        queryParameters: {...redirect.queryParameters, 'code': 'target-code'},
      );
      expect(guard.claim(callback, account: active.auth.currentUser?.id), true);
      final completion = federation.complete(callback);
      if (scenario == 'success' || scenario == 'account changed') {
        await Future.any([proofStarted.future, completion]);
        expect(
          proofStarted.isCompleted,
          true,
          reason:
              '${guard.lastFeedback}: ${calls.map((r) => r.url.path).join(', ')}',
        );
        expect(
          active.auth.currentUser,
          isNull,
          reason: 'unproved target sessions stay isolated',
        );
        if (scenario == 'account changed') {
          await active.auth.recoverSession(
            jsonEncode(session('different-person')),
          );
        }
        proofRelease.complete();
      }
      await completion;
      expect(active.auth.currentUser?.id, switch (scenario) {
        'success' => 'target-person',
        'wrong account' => 'original-person',
        'account changed' => 'different-person',
        _ => null,
      });
      expect(
        guard.lastFeedback,
        scenario == 'success'
            ? AuthCallbackStatus.authenticated
            : AuthCallbackStatus.refused,
      );
      if (scenario == 'success') {
        expect(active.auth.currentSession!.providerToken, isNull);
        expect(active.auth.currentSession!.providerRefreshToken, isNull);
      }
      expect(
        calls.any(
          (r) => r.headers.values.any((v) => v.contains('canonical-identity')),
        ),
        false,
        reason: 'canonical provider tokens are never sent to target data APIs',
      );
      expect(
        secrets.values,
        isEmpty,
        reason: 'callback metadata and SDK verifier are scrubbed',
      );
      expect(calls.any((r) => r.url.path == '/auth/v1/signup'), false);
    });
  }
}
