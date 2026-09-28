// SPDX-License-Identifier: AGPL-3.0-or-later
// #1791: sessions and PKCE are isolated by full installation origin and
// account; migration preserves matching sessions and logout wins write races.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/backend/auth_secret_store.dart';
import 'package:deskilo/core/backend/installation_auth_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemorySecrets implements AuthSecretStore {
  final values = <String, String>{};
  Completer<void>? delay;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    await delay?.future;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class LegacySession extends EmptyLocalStorage {
  LegacySession(this.value);
  String? value;
  @override
  Future<String?> accessToken() async => value;
  @override
  Future<void> removePersistedSession() async => value = null;
}

String session(String account, String issuer) => jsonEncode({
  'user': {'id': account},
  'access_token':
      'header.${base64Url.encode(utf8.encode(jsonEncode({'iss': issuer})))}.signature',
  'refresh_token': 'refresh-$account',
});

void main() {
  final a = Uri.parse('https://auth.example:8443');
  final b = Uri.parse('https://auth.example:9443');

  test('sessions and logout stay scoped to full origin and account', () async {
    final secrets = MemorySecrets();
    final first = InstallationSessionStorage(secrets, a);
    final second = InstallationSessionStorage(secrets, b);
    await first.persistSession(session('one', '${a.origin}/auth/v1'));
    await second.persistSession(session('two', '${b.origin}/auth/v1'));
    await first.persistSession(session('three', '${a.origin}/auth/v1'));
    expect(secrets.values.values.any((v) => v.contains('refresh-one')), false);
    await first.removePersistedSession();
    expect(await first.accessToken(), isNull);
    expect(await second.accessToken(), session('two', '${b.origin}/auth/v1'));
  });

  test(
    'queued logout cannot be overtaken by a delayed persistence write',
    () async {
      final secrets = MemorySecrets()..delay = Completer<void>();
      final storage = InstallationSessionStorage(secrets, a);
      final writing = storage.persistSession(
        session('one', '${a.origin}/auth/v1'),
      );
      final logout = storage.removePersistedSession();
      secrets.delay!.complete();
      await Future.wait([writing, logout]);
      expect(await storage.accessToken(), isNull);
      expect(secrets.values, isEmpty);
    },
  );

  test(
    'legacy migration retains the session and removes only a matching old copy',
    () async {
      final secrets = MemorySecrets();
      final old = LegacySession(session('one', '${a.origin}/auth/v1'));
      final storage = InstallationSessionStorage(secrets, a, legacy: old);
      await storage.initialize();
      expect(
        await storage.accessToken(),
        session('one', '${a.origin}/auth/v1'),
      );
      expect(old.value, isNull);
      final foreign = LegacySession(session('one', '${a.origin}/auth/v1'));
      final other = InstallationSessionStorage(secrets, b, legacy: foreign);
      await other.initialize();
      expect(await other.accessToken(), isNull);
      expect(foreign.value, isNotNull);
    },
  );

  test(
    'the actual SDK keeps simultaneous target PKCE verifiers separate',
    () async {
      final secrets = MemorySecrets();
      final first = SupabaseClient(
        a.origin,
        'public-a',
        authOptions: AuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: false,
          pkceAsyncStorage: InstallationPkceStorage(secrets, a),
        ),
      );
      final second = SupabaseClient(
        b.origin,
        'public-b',
        authOptions: AuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: false,
          pkceAsyncStorage: InstallationPkceStorage(secrets, b),
        ),
      );
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final urls = await Future.wait([
        first.auth.getOAuthSignInUrl(
          provider: const OAuthProvider('custom:deskilo'),
          redirectTo: 'deskilo://auth-callback',
        ),
        second.auth.getOAuthSignInUrl(
          provider: const OAuthProvider('custom:deskilo'),
          redirectTo: 'deskilo://auth-callback',
        ),
      ]);
      expect(secrets.values.length, 2);
      expect(secrets.values.values.toSet().length, 2);
      final one = Uri.parse(urls[0].url);
      final two = Uri.parse(urls[1].url);
      expect(one.origin, a.origin);
      expect(two.origin, b.origin);
      expect(
        one.queryParameters['code_challenge'],
        isNot(two.queryParameters['code_challenge']),
      );
      expect(one.queryParameters['code_challenge_method'], 's256');
    },
  );
}
