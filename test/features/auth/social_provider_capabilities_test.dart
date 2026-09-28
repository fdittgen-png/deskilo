// SPDX-License-Identifier: AGPL-3.0-or-later
// #1791: provider availability belongs to the target installation; vendor
// identities are login methods, not new directory people or memberships.
import 'package:deskilo/features/auth/data/supabase_auth_repository.dart';
import 'package:deskilo/features/auth/domain/social_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('only advertised providers are offered and Microsoft maps to Azure', () async {
    final client = SupabaseClient('https://target.example', 'publishable-fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(client.dispose);
    final repository = SupabaseAuthRepository(client, providerSettingsGet: (uri, {headers}) async {
      expect(uri.toString(), 'https://target.example/auth/v1/settings');
      expect(headers, {'apikey': 'publishable-fixture'});
      return http.Response('{"external":{"google":true,"apple":true,"azure":true,"facebook":true}}', 200);
    });
    expect(await repository.availableSocialProviders(), SocialProvider.values);
    expect(SocialProvider.fromWire('azure'), SocialProvider.microsoft);
  });

  test('disabled, malformed and failed discovery never advertise working sign-in', () async {
    final client = SupabaseClient('https://target.example', 'publishable-fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(client.dispose);
    var response = http.Response('{"external":{"google":false,"apple":"true"}}', 200);
    final repository = SupabaseAuthRepository(client,
      providerSettingsGet: (_, {headers}) async => response);
    expect(await repository.availableSocialProviders(), isEmpty);
    response = http.Response('{}', 200);
    await expectLater(repository.availableSocialProviders(), throwsStateError);
    response = http.Response('unavailable', 503);
    await expectLater(repository.availableSocialProviders(), throwsStateError);
  });
}
