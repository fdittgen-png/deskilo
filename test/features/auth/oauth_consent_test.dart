// SPDX-License-Identifier: AGPL-3.0-or-later
// #1648: protected consent context fails closed and a provider return cannot
// move its code to another host, port, path, scheme or user-info authority.
import 'package:deskilo/features/auth/domain/oauth_consent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final identity = <String, Object?>{
    'purpose': 'identity_federation',
    'client_id': 'client',
    'local_user_id': 'person',
    'target_auth_url': 'https://target.example/auth/v1',
    'target_installation_id': 'installation',
  };

  test('identity return is confined to the registered callback', () {
    final context = OAuthConsentContext.fromJson(identity);
    expect(context.permitsIdentityReturn(Uri.parse(
        'https://target.example/auth/v1/callback?code=secret&state=opaque')), isTrue);
    for (final url in [
      'http://target.example/auth/v1/callback?code=secret',
      'https://other.example/auth/v1/callback?code=secret',
      'https://target.example:8443/auth/v1/callback?code=secret',
      'https://person@target.example/auth/v1/callback?code=secret',
      'https://target.example/auth/v1/callback/next?code=secret',
      'https://target.example/auth/v1/callback#code=secret',
    ]) {
      expect(context.permitsIdentityReturn(Uri.parse(url)), isFalse);
    }
  });

  test('unknown purpose and malformed targets do not become MCP consent', () {
    for (final value in <Object?>[
      null,
      {...identity, 'purpose': 'other'},
      {...identity, 'target_auth_url': 'https://target.example/auth/v1?key=value'},
      {...identity, 'target_auth_url': 'https://user@target.example/auth/v1'},
      {...identity, 'target_installation_id': null},
      {...identity, 'local_user_id': ''},
    ]) {
      expect(() => OAuthConsentContext.fromJson(value), throwsFormatException);
    }
    final mcp = OAuthConsentContext.fromJson({...identity, 'purpose': 'mcp'});
    expect(mcp.purpose, OAuthConsentPurpose.mcp);
    expect(mcp.targetAuthUrl, isNull);
    expect(mcp.permitsIdentityReturn(
        Uri.parse('https://target.example/auth/v1/callback')), isFalse);
  });
}
