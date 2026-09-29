// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — what a member scans or pastes to reach an instance carries public
// connection information only: the endpoint, its publishable key and a
// display label. No grant, consent, eligibility, administrator id,
// installation epoch or operator key can ride along — an extra parameter in
// a code is dropped, never re-shared, and a non-public key refuses the code.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/backend_uri.dart';
import 'package:flutter_test/flutter_test.dart';

const publishable = 'sb_publishable_0123456789abcdefghij';
const endpoint = BackendEndpoint('https://coworking.example.org', publishable);

void main() {
  test('an encoded server code names only url, key and label', () {
    final uri = Uri.parse(BackendUriCodec.encode(endpoint, label: 'Our space'));
    expect(uri.queryParameters.keys.toSet(), {'url', 'key', 'name'});
    expect(uri.queryParameters['key'], publishable);
  });

  test('authority smuggled into a code is dropped and never re-shared', () {
    final smuggled = Uri(
      scheme: 'deskilo',
      host: 'server',
      queryParameters: {
        'url': endpoint.url,
        'key': publishable,
        'name': 'Our space',
        'grant': 'mcp:all',
        'consent': 'workspace-a',
        'admin': '00000000-0000-4000-8000-0000001633a1',
        'epoch': '7',
        'installation': '00000000-0000-4000-8000-000000001633',
      },
    ).toString();
    final decoded = BackendUriCodec.decodeDescriptor(smuggled);
    expect(decoded, isNotNull, reason: 'the public part still connects');
    final again = Uri.parse(
      BackendUriCodec.encode(decoded!.endpoint, label: decoded.label),
    );
    expect(again.queryParameters.keys.toSet(), {'url', 'key', 'name'});
    expect(again.toString(), isNot(contains('1633')));
    expect(again.toString(), isNot(contains('mcp')));
  });

  test('a key that is not a public client key refuses the whole code', () {
    for (final key in [
      'sb_secret_0123456789abcdefghij',
      // Built at run time so no token-shaped literal is committed.
      'sbp_${'0' * 40}',
      'postgresql://postgres:pw@db.example.org:5432/postgres',
    ]) {
      final code = Uri(
        scheme: 'deskilo',
        host: 'server',
        queryParameters: {'url': endpoint.url, 'key': key},
      ).toString();
      expect(BackendUriCodec.decodeDescriptor(code), isNull, reason: key);
      expect(
        validateBackendEndpoint(endpoint.url, key),
        isNotNull,
        reason: key,
      );
    }
  });
}
