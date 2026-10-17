// SPDX-License-Identifier: AGPL-3.0-or-later
// #2562 -- a workspace on a connected (non-active) installation is reached
// through that installation's own pooled client and session; every failure
// is a typed refusal and the root client is never the answer.
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/connected_pool_host_resolver.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/installation_auth_storage.dart' show MemorySecrets;
import '../../helpers/native_federation_flow.dart' show session, user;

/// One fake installation. [installationId] may be swapped to simulate a
/// replaced backend; [refreshAccepted] decides the refresh-token grant.
class _Host {
  _Host(this.name, this.account) : installationId = 'inst-$name';
  final String name;
  final String account;
  String installationId;
  bool refreshAccepted = true;
  final seen = <String>[];
  final bearers = <String>[];
  int refreshes = 0;

  String get origin => 'https://$name.example';
  BackendEndpoint get endpoint =>
      BackendEndpoint(origin, 'sb_publishable_${name}_target');

  Future<http.Response> handle(http.Request r) async {
    seen.add(r.url.path);
    final auth = r.headers['authorization'];
    if (auth != null) bearers.add(auth);
    Object? body;
    switch (r.url.path) {
      case '/auth/v1/token':
        if (r.url.queryParameters['grant_type'] == 'refresh_token') {
          if (!refreshAccepted) {
            return http.Response(
              jsonEncode({'error': 'invalid_grant', 'error_description': 'x'}),
              400,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }
          refreshes++;
        }
        body = session(account);
      case '/auth/v1/user':
        body = user(account);
      case '/rest/v1/installation_identity':
        body = {'installation_id': installationId};
      case '/rest/v1/rpc/public_network_descriptor':
        return http.Response(
          jsonEncode({'code': 'PGRST202', 'message': 'not found'}),
          404,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      default:
        body = <Object?>[];
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: r,
    );
  }
}

Map<String, Object?> _expired(String id) {
  final s = Map<String, Object?>.from(session(id));
  final jwt = base64Url.encode(
    utf8.encode(jsonEncode({'sub': id, 'exp': 1000000000})),
  );
  return {...s, 'access_token': 'e30.$jwt.signature', 'expires_at': 1000000000};
}

void main() {
  late _Host root, one, two;
  late SupabaseClient rootClient;
  late MemorySecrets secrets;
  late ConnectedInstallations pool;
  late Map<String, String?> selection;
  late ConnectedPoolHostResolver resolver;

  http.Client wire() => MockClient((r) {
    final host = [
      root,
      one,
      two,
    ].firstWhere((h) => h.name == r.url.host.split('.').first);
    return host.handle(r);
  });

  Future<void> connectBoth() async {
    for (final h in [one, two]) {
      await pool.connect(h.endpoint, 'user@example.test', 'password');
    }
  }

  setUp(() async {
    root = _Host('root', 'p-user');
    one = _Host('one', 'one-user');
    two = _Host('two', 'two-user');
    secrets = MemorySecrets();
    rootClient = SupabaseClient(
      root.origin,
      'sb_publishable_root',
      httpClient: wire(),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await rootClient.auth.setInitialSession(jsonEncode(session('p-user')));
    pool = ConnectedInstallations(rootClient, secrets, transport: wire);
    selection = {};
    resolver = ConnectedPoolHostResolver(
      active: ActiveInstallationHostResolver(
        rootClient,
        (_) async => root.installationId,
      ),
      root: rootClient,
      pool: () => pool,
      sourceOf: (id) => selection[id],
    );
    await connectBoth();
    root.seen.clear();
    root.bearers.clear();
  });

  tearDown(() async {
    pool.close();
    await rootClient.dispose();
  });

  test(
    'a split target resolves to its own client, account and installation',
    () async {
      selection['ws-1'] = one.origin;
      final a = await resolver.resolve('ws-1');
      expect(a.installationId, 'inst-one');
      expect(a.localUserId, 'one-user');
      expect(identical(a.client, rootClient), isFalse);
      await a.client.from('reservations').select();
      expect(one.seen, contains('/rest/v1/reservations'));
      expect(two.seen.where((p) => p.contains('/reservations')), isEmpty);
      expect(root.seen, isEmpty, reason: 'the root client is never involved');

      // The same local workspace id on the other host is another target.
      selection['ws-1'] = two.origin;
      final b = await resolver.resolve('ws-1');
      expect(b.installationId, 'inst-two');
      expect(b.localUserId, 'two-user');
      expect(identical(a.client, b.client), isFalse);
      await b.client.from('reservations').select();
      expect(two.seen, contains('/rest/v1/reservations'));
      expect(root.seen, isEmpty);
      for (final bearer in one.bearers + two.bearers) {
        expect(root.bearers, isNot(contains(bearer)));
      }
    },
  );

  test(
    'a workspace of the active installation uses the active resolver',
    () async {
      final host = await resolver.resolve('ws-local');
      expect(identical(host.client, rootClient), isTrue);
      expect(host.installationId, 'inst-root');
    },
  );

  test(
    'a target that is not connected is refused, never answered by the root',
    () async {
      selection['ws-x'] = 'https://nowhere.example';
      await expectLater(
        resolver.resolve('ws-x'),
        throwsA(
          isA<ConnectionFailure>().having(
            (e) => e.reason,
            'reason',
            ConnectionFailureReason.notConnected,
          ),
        ),
      );
      expect(root.seen, isEmpty);
    },
  );

  test(
    'a replaced backend is quarantined and stays refused until re-connected',
    () async {
      selection['ws-1'] = one.origin;
      one.installationId = 'inst-replaced';
      for (var i = 0; i < 2; i++) {
        await expectLater(
          resolver.resolve('ws-1'),
          throwsA(
            isA<ConnectionFailure>().having(
              (e) => e.reason,
              'reason',
              ConnectionFailureReason.changedIdentity,
            ),
          ),
        );
      }
      final before = one.seen.length;
      await expectLater(
        resolver.resolve('ws-1'),
        throwsA(isA<ConnectionFailure>()),
      );
      expect(
        one.seen.length,
        before,
        reason: 'a quarantined target is not called',
      );
      // The peer target is unaffected.
      selection['ws-2'] = two.origin;
      expect((await resolver.resolve('ws-2')).installationId, 'inst-two');
      expect(root.seen, isEmpty);
    },
  );

  test(
    'an expired session is refreshed and saved under that target only',
    () async {
      final key = secrets.values.keys.single;
      final records = jsonDecode(secrets.values[key]!) as Map<String, dynamic>;
      (records[one.origin] as Map<String, dynamic>)['session'] = _expired(
        'one-user',
      );
      secrets.values[key] = jsonEncode(records);
      final twoBefore = jsonEncode(records[two.origin]);

      selection['ws-1'] = one.origin;
      final host = await resolver.resolve('ws-1');
      expect(host.localUserId, 'one-user');
      expect(one.refreshes, 1);
      final saved = jsonDecode(secrets.values[key]!) as Map<String, dynamic>;
      final savedOne = (saved[one.origin] as Map)['session'] as Map;
      expect(savedOne['expires_at'], isNot(1000000000));
      expect(jsonEncode(saved[two.origin]), twoBefore);
      expect(two.refreshes, 0);
      expect(root.seen, isEmpty);
    },
  );

  test(
    'a refresh token the target rejects is an expired sign-in for that target',
    () async {
      final key = secrets.values.keys.single;
      final records = jsonDecode(secrets.values[key]!) as Map<String, dynamic>;
      (records[one.origin] as Map<String, dynamic>)['session'] = _expired(
        'one-user',
      );
      secrets.values[key] = jsonEncode(records);
      one.refreshAccepted = false;
      selection['ws-1'] = one.origin;
      await expectLater(
        resolver.resolve('ws-1'),
        throwsA(
          isA<ConnectionFailure>().having(
            (e) => e.reason,
            'reason',
            ConnectionFailureReason.expired,
          ),
        ),
      );
      expect(root.seen, isEmpty);
    },
  );

  test('a disconnected target is closed and refused afterwards', () async {
    selection['ws-1'] = one.origin;
    await resolver.resolve('ws-1');
    await pool.disconnect(one.origin);
    await expectLater(
      resolver.resolve('ws-1'),
      throwsA(
        isA<ConnectionFailure>().having(
          (e) => e.reason,
          'reason',
          ConnectionFailureReason.notConnected,
        ),
      ),
    );
    expect(root.seen, isEmpty);
  });

  test(
    'a closed pool cancels the resolve instead of answering from another client',
    () async {
      selection['ws-1'] = one.origin;
      selection['ws-2'] = two.origin;
      final a = await resolver.resolve('ws-1');
      final b = await resolver.resolve('ws-2');
      expect(identical(a.client, b.client), isFalse);
      pool.close();
      await expectLater(
        resolver.resolve('ws-1'),
        throwsA(
          isA<ConnectionFailure>().having(
            (e) => e.reason,
            'reason',
            ConnectionFailureReason.cancelled,
          ),
        ),
      );
    },
  );
}
