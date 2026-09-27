// SPDX-License-Identifier: AGPL-3.0-or-later
// #1648 — operator staging never activates federation, rewrites an existing
// provider, follows credentials to another host, or publishes raw API errors.
// Real HTTP tests exercise the same adapter and CLI entry used by operators.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/instance/federation.dart';

void main() {
  late HttpServer server;
  late FederationStager stager;
  late List<({String method, String path, Object? body})> calls;
  late Map<String, dynamic>? provider;
  var status = 200;
  var corruptReadback = false;
  var malformed = false;
  final issuer = Uri.parse('https://canonical.example/auth/v1');

  setUp(() async {
    calls = [];
    provider = null;
    status = 200;
    corruptReadback = false;
    malformed = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      expect(request.headers.value('apikey'), 'operator-secret');
      expect(request.headers.value('authorization'), 'Bearer operator-secret');
      final text = await utf8.decoder.bind(request).join();
      final body = text.isEmpty ? null : jsonDecode(text);
      calls.add((method: request.method, path: request.uri.path, body: body));
      request.response.headers.contentType = ContentType.json;
      request.response.statusCode = status;
      Object? result;
      if (status != 200) {
        if (status == 302) {
          request.response.headers.set('location', 'https://untrusted.example/');
        }
        result = {'error': 'operator-secret client-secret private detail'};
      } else if (request.method == 'POST') {
        provider = Map<String, dynamic>.from(body! as Map<String, dynamic>)
          ..remove('client_secret');
        result = provider;
      } else if (request.uri.path.endsWith('/custom-providers')) {
        result = malformed ? {'providers': [<String, dynamic>{}]} : {
          'providers': [?provider],
        };
      } else {
        result = {...?provider, if (corruptReadback) 'enabled': true};
      }
      request.response.write(jsonEncode(result));
      await request.response.close();
    });
    stager = FederationStager(
      authUrl: Uri.parse('http://127.0.0.1:${server.port}/auth/v1'),
      adminKey: 'operator-secret',
    );
  });

  tearDown(() async {
    stager.close();
    await server.close(force: true);
  });

  test('dry run reads supported API without a client secret or writes', () async {
    expect(await stager.stage(issuer: issuer, clientId: 'identity-client'),
        'dry_run_provider_disabled');
    expect(calls.single.method, 'GET');
    expect(calls.single.path, '/auth/v1/admin/custom-providers');
  });

  test('apply creates disabled provider, then independently reads it back', () async {
    expect(await stager.stage(issuer: issuer, clientId: 'identity-client',
        clientSecret: 'client-secret', apply: true), 'provider_staged_disabled');
    expect(calls.map((c) => c.method), ['GET', 'POST', 'GET']);
    expect(calls.last.path, '/auth/v1/admin/custom-providers/custom:deskilo');
    expect(provider!['issuer'], issuer.toString());
    expect(provider!['enabled'], false);
    expect(provider!['pkce_enabled'], true);
    expect(provider!['skip_nonce_check'], false);
    expect(provider!['scopes'], ['openid', 'profile']);
    expect((calls[1].body! as Map)['client_secret'], 'client-secret');
  });

  test('readback disagreement cannot report success', () async {
    corruptReadback = true;
    await expectLater(stager.stage(issuer: issuer, clientId: 'identity-client',
        clientSecret: 'client-secret', apply: true),
        throwsA(isA<FederationRefused>().having((e) => e.code, 'code',
            'provider_readback_mismatch')));
  });

  test('existing provider and malformed inventory are never overwritten', () async {
    provider = {'identifier': federationProvider, 'enabled': true};
    await expectLater(stager.stage(issuer: issuer, clientId: 'identity-client',
        clientSecret: 'client-secret', apply: true), throwsA(isA<FederationRefused>()));
    malformed = true;
    await expectLater(stager.stage(issuer: issuer, clientId: 'identity-client',
        clientSecret: 'client-secret', apply: true), throwsA(isA<FederationRefused>()));
    expect(calls.map((c) => c.method), ['GET', 'GET']);
  });

  for (final code in [302, 401, 403, 404, 500, 501]) {
    test('HTTP $code refuses without credential-bearing error text', () async {
      status = code;
      await expectLater(stager.stage(issuer: issuer, clientId: 'identity-client'),
          throwsA(isA<FederationRefused>().having((e) => e.toString(),
              'safe error', isNot(contains('secret')))));
      expect(calls, hasLength(1));
    });
  }

  test('endpoints preserve exact Auth paths and reject unsafe destinations', () {
    expect(federationEndpoint(issuer.toString()), issuer);
    for (final bad in ['http://remote.example/auth/v1',
      'https://user:secret@host/auth/v1', 'https://host/auth/v1?token=x',
      'https://host/auth/v1#secret', 'https://host/auth/v1/',
      'https://host//auth/v1', 'file:///tmp/auth']) {
      expect(() => federationEndpoint(bad), throwsA(isA<FederationRefused>()));
    }
  });

  test('canonical target uses native sign-in without any provider request', () async {
    await expectLater(stager.stage(issuer: stager.authUrl, clientId: 'client'),
        throwsA(isA<FederationRefused>()));
    expect(calls, isEmpty);
  });

  test('CLI stages with env secrets and emits only bounded readiness', () async {
    final dir = await Directory.systemTemp.createTemp('federation-cli-');
    final file = File('${dir.path}/result');
    final sink = file.openWrite();
    try {
      final exit = await runFederationStage([
        '--auth-url', stager.authUrl.toString(), '--issuer', issuer.toString(),
        '--client-id', 'identity-client', '--apply',
      ], environment: {'DESKILO_TARGET_AUTH_ADMIN_KEY': 'operator-secret',
        'DESKILO_FEDERATION_CLIENT_SECRET': 'client-secret'}, out: sink);
      await sink.flush();
      expect(exit, 0);
      final text = await file.readAsString();
      expect(text, isNot(contains('secret')));
      final result = jsonDecode(text) as Map<String, dynamic>;
      expect(result['native_federation_ready'], false);
      expect(result['mcp_ready'], false);
      expect(result['provider_callback'], '${stager.authUrl}/callback');
    } finally {
      await sink.close();
      await dir.delete(recursive: true);
    }
  });
}
