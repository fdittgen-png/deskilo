// SPDX-License-Identifier: 0BSD
//
// #1050 — the confirmation e-mail must come back to the app.
//
// Asking Supabase for nothing gets you the project's Site URL, and on an
// instance created before the wizard (#977) that is still the Supabase
// default `http://localhost:3000`. A new member tapped "Confirm your
// mail" on a phone and met ERR_CONNECTION_REFUSED: the account could
// never be confirmed.
//
// The screens are covered through FakeAuthRepository, which is exactly
// why this slipped through — the fake never speaks to gotrue. So this
// test drives the REAL SupabaseAuthRepository against a captured HTTP
// client and reads the wire: gotrue puts `redirect_to` in the query
// string of POST /auth/v1/signup.
import 'dart:convert';

import 'package:deskilo/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// PKCE writes its verifier somewhere before the request goes out; the
/// app hands gotrue real storage, so the test hands it a map rather than
/// dropping to the implicit flow and testing a path nobody runs.
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

void main() {
  late Uri captured;

  SupabaseAuthRepository repositoryOver(MockClient client) =>
      SupabaseAuthRepository(
        SupabaseClient(
          'https://project.supabase.co',
          'anon-key',
          httpClient: client,
          authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryStorage()),
        ),
      );

  MockClient capturingSignup() => MockClient((request) async {
        captured = request.url;
        return http.Response(
          jsonEncode({
            'id': '00000000-0000-0000-0000-000000000001',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'newcomer@example.org',
            'created_at': '2026-09-09T17:42:00Z',
            'app_metadata': <String, Object?>{},
            'user_metadata': <String, Object?>{},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

  test('signUp asks for the deskilo:// callback, never the Site URL',
      () async {
    final repo = repositoryOver(capturingSignup());

    await repo.signUp(
      email: 'newcomer@example.org',
      password: 'a-long-enough-password',
      displayName: 'Newcomer',
    );

    expect(captured.path, endsWith('/auth/v1/signup'));
    expect(
      captured.queryParameters['redirect_to'],
      'deskilo://auth-callback',
      reason: 'without it the e-mail carries the project Site URL — '
          'http://localhost:3000 on any instance older than the wizard',
    );
  });
}
