// SPDX-License-Identifier: AGPL-3.0-or-later
// #1791: independent native sessions survive restart, never send the home
// bearer to targets, and disconnect/account changes fence delayed responses.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'installation_auth_storage_test.dart' show MemorySecrets;
import 'native_federation_flow_test.dart' show user, session;

void main() {
  test(
    'two target sessions stay separate and are restored only for their owner',
    () async {
      final secrets = MemorySecrets();
      final requests = <http.Request>[];
      final home = SupabaseClient(
        'https://home.example',
        'sb_publishable_home',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await home.auth.setInitialSession(jsonEncode(session('home-user')));
      final homeToken = home.auth.currentSession!.accessToken;
      http.Client wire() => MockClient((request) async {
        requests.add(request);
        final id = request.url.host == 'one.example' ? 'one-user' : 'two-user';
        expect(request.headers['authorization'], isNot('Bearer $homeToken'));
        Object? body;
        switch (request.url.path) {
          case '/auth/v1/token':
            body = session(id);
          case '/auth/v1/user':
            body = user(id);
          case '/rest/v1/installation_identity':
            body = {'installation_id': 'installation-$id'};
          case '/rest/v1/rpc/my_financial_activity':
            body = [
              {'account': id},
            ];
          default:
            throw StateError('unexpected endpoint');
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final connections = ConnectedInstallations(
        home,
        secrets,
        transport: wire,
      );
      for (final host in ['one', 'two']) {
        await connections.connect(
          BackendEndpoint(
            'https://$host.example',
            'sb_publishable_${host}_target',
          ),
          'user@example.test',
          'password',
        );
      }
      expect(await connections.list(), hasLength(2));
      connections.close();
      final restored = ConnectedInstallations(home, secrets, transport: wire);
      for (final host in ['one', 'two']) {
        final rows = await restored.use(
          'https://$host.example',
          (c) => c.rpc<List<dynamic>>(
            'my_financial_activity',
            params: {'p_kind': 'invoices'},
          ),
        );
        expect((rows.single as Map)['account'], '$host-user');
      }
      for (final request in requests) {
        expect(request.followRedirects, isFalse);
        expect(
          request.headers['apikey'],
          'sb_publishable_${request.url.host.split('.').first}_target',
        );
      }
      await home.auth.setInitialSession(
        jsonEncode(session('another-home-user')),
      );
      await expectLater(restored.list(), throwsStateError);
      final another = ConnectedInstallations(home, secrets, transport: wire);
      expect(await another.list(), isEmpty);
      another.close();
      restored.close();
      await home.dispose();
    },
  );
  test('disconnect cannot be undone by an in-flight source response', () async {
    final home = SupabaseClient(
      'https://home.example',
      'sb_publishable_home',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await home.auth.setInitialSession(jsonEncode(session('home-user')));
    final started = Completer<void>(), release = Completer<void>();
    var block = false;
    final registry = ConnectedInstallations(
      home,
      MemorySecrets(),
      transport: () => MockClient((r) async {
        Object? body;
        if (r.url.path == '/auth/v1/token') {
          body = session('target');
        } else if (r.url.path == '/auth/v1/user') {
          body = user('target');
        } else if (r.url.path == '/rest/v1/installation_identity') {
          body = {'installation_id': 'target-installation'};
        } else {
          if (block) {
            started.complete();
            await release.future;
          }
          body = <Object?>[];
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    await registry.connect(
      const BackendEndpoint('https://target.example', 'sb_publishable_target'),
      'me@example.test',
      'password',
    );
    block = true;
    final pending = registry.use(
      'https://target.example',
      (c) => c.rpc<List<dynamic>>('my_financial_activity'),
    );
    final assertion = expectLater(pending, throwsStateError);
    await started.future;
    await registry.disconnect('https://target.example');
    release.complete();
    await assertion;
    expect(await registry.list(), isEmpty);
    registry.close();
    await home.dispose();
  });
}
