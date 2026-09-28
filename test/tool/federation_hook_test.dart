// SPDX-License-Identifier: AGPL-3.0-or-later
// #1648: the real Management HTTP adapter configures only the installed hook,
// refuses other hooks (even disabled ones), and requires independent readback.
// Actual hook invocation/claims are proved by pgTAP and federation_scope_runtime.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/instance/management_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/instance/federation.dart';
import '../../tool/instance/federation_hook.dart';

void main() {
  const ref = 'abcdefghijklmnopqrst';
  const enabled = 'hook_custom_access_token_enabled';
  const uri = 'hook_custom_access_token_uri';
  late HttpServer server;
  late Dio dio;
  late SupabaseManagement api;
  late Map<String, Object?> config;
  late List<String> calls;
  var installed = true;
  var ignorePatch = false;

  setUp(() async {
    config = {enabled: false, uri: null};
    calls = [];
    installed = true;
    ignorePatch = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      calls.add(request.method);
      expect(request.uri.path, startsWith('/v1/projects/$ref/'));
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('/database/query')) {
        expect(jsonDecode(body)['query'], contains('has_function_privilege'));
        request.response.write(jsonEncode([{'installed': installed}]));
      } else {
        if (request.method == 'PATCH') {
          expect(jsonDecode(body), {enabled: true, uri: identityHookUri});
          if (!ignorePatch) config.addAll(jsonDecode(body) as Map<String, dynamic>);
        }
        request.response.write(jsonEncode(config));
      }
      await request.response.close();
    });
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}',
        followRedirects: false));
    api = DioSupabaseManagement('test-token', dio: dio);
  });

  tearDown(() async {
    dio.close();
    await server.close(force: true);
  });

  test('dry run reads config and schema without a write', () async {
    expect(await configureIdentityHook(api, ref), 'dry_run_identity_hook');
    expect(calls, ['GET', 'POST']); // POST is read-only SQL.
    expect(config[enabled], false);
  });
  test('apply patches only the hook then reads it back', () async {
    expect(await configureIdentityHook(api, ref, apply: true),
        'identity_hook_configured');
    expect(calls, ['GET', 'POST', 'PATCH', 'GET']);
  });
  test('already configured hook is read back without patching', () async {
    config = {enabled: true, uri: identityHookUri};
    await configureIdentityHook(api, ref, apply: true);
    expect(calls, ['GET', 'POST', 'GET']);
  });
  for (final active in [false, true]) {
    test('foreign hook is refused when enabled=$active', () async {
      config = {enabled: active, uri: 'https://existing.example/hook'};
      await expectLater(configureIdentityHook(api, ref, apply: true),
          throwsA(isA<FederationRefused>().having((e) => e.code, 'reason',
              'existing_hook_requires_composition')));
      expect(calls, ['GET']);
    });
  }
  test('missing schema never patches Auth', () async {
    installed = false;
    await expectLater(configureIdentityHook(api, ref, apply: true),
        throwsA(isA<FederationRefused>()));
    expect(calls, ['GET', 'POST']);
  });
  test('successful patch response alone cannot report configured', () async {
    ignorePatch = true;
    await expectLater(configureIdentityHook(api, ref, apply: true),
        throwsA(isA<FederationRefused>().having((e) => e.code, 'reason',
            'identity_hook_readback_mismatch')));
  });
  test('malformed capability response fails closed', () async {
    config = {enabled: 'false', uri: null};
    await expectLater(configureIdentityHook(api, ref, apply: true),
        throwsA(isA<FederationRefused>()));
    expect(calls, ['GET']);
  });
  test('project path injection is rejected before network', () async {
    await expectLater(configureIdentityHook(api, '../another'),
        throwsA(isA<FederationRefused>()));
    expect(calls, isEmpty);
  });
}
