// SPDX-License-Identifier: AGPL-3.0-or-later
// #2562 -- a pinned client per connected installation: a lease whose
// lifetime is its holder's, that serves only its own target, and that ends
// with a typed ConnectionFailure when the connection is disconnected,
// replaced, signed out or the pool closes.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/installation_auth_storage.dart' show MemorySecrets;
import '../../helpers/native_federation_flow.dart' show session, user;

class _Host {
  _Host(this.name, this.account) : installationId = 'inst-$name';
  final String name;
  final String account;
  String installationId;
  final seen = <String>[];

  String get origin => 'https://$name.example';
  BackendEndpoint get endpoint =>
      BackendEndpoint(origin, 'sb_publishable_${name}_target');

  Future<http.Response> handle(http.Request r) async {
    seen.add(r.url.path);
    Object? body;
    switch (r.url.path) {
      case '/auth/v1/token':
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

Matcher _failure(ConnectionFailureReason reason) =>
    isA<ConnectionFailure>().having((e) => e.reason, 'reason', reason);

void main() {
  late _Host root, one, two;
  late SupabaseClient rootClient;
  late ConnectedInstallations pool;

  http.Client wire() => MockClient((r) {
    final host = [
      root,
      one,
      two,
    ].firstWhere((h) => h.name == r.url.host.split('.').first);
    return host.handle(r);
  });

  setUp(() async {
    root = _Host('root', 'p-user');
    one = _Host('one', 'one-user');
    two = _Host('two', 'two-user');
    rootClient = SupabaseClient(
      root.origin,
      'sb_publishable_root',
      httpClient: wire(),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await rootClient.auth.setInitialSession(jsonEncode(session('p-user')));
    pool = ConnectedInstallations(rootClient, MemorySecrets(), transport: wire);
    for (final h in [one, two]) {
      await pool.connect(h.endpoint, 'user@example.test', 'password');
    }
    root.seen.clear();
  });

  tearDown(() async {
    pool.close();
    await rootClient.dispose();
  });

  test('a pin serves its own target only, one client per target', () async {
    final a = await pool.pin(one.origin);
    final b = await pool.pin(two.origin);
    final again = await pool.pin(one.origin);
    expect(a.installationId, 'inst-one');
    expect(a.account, 'one-user');
    expect(b.installationId, 'inst-two');
    expect(identical(a.client, b.client), isFalse);
    expect(identical(a.client, again.client), isTrue, reason: 'opened once');
    expect(identical(a.client, rootClient), isFalse);

    two.seen.clear();
    await a.client.from('reservations').select();
    expect(one.seen, contains('/rest/v1/reservations'));
    expect(two.seen.where((p) => p.contains('/reservations')), isEmpty);
    expect(root.seen, isEmpty, reason: 'the root client is never involved');
  });

  test(
    'a disconnect ends that pin with a typed reason; the peer lives',
    () async {
      final a = await pool.pin(one.origin);
      final b = await pool.pin(two.origin);
      expect(a.isLive, isTrue);

      await pool.disconnect(one.origin);

      expect(await a.ended, _failure(ConnectionFailureReason.cancelled));
      expect(a.isLive, isFalse);
      expect(
        () => a.client,
        throwsA(_failure(ConnectionFailureReason.cancelled)),
      );
      expect(b.isLive, isTrue);
      await b.client.from('reservations').select();
      expect(two.seen, contains('/rest/v1/reservations'));
      expect(root.seen, isEmpty);

      // Recovery: a fresh pin of the disconnected target is refused typed.
      await expectLater(
        pool.pin(one.origin),
        throwsA(_failure(ConnectionFailureReason.notConnected)),
      );
    },
  );

  test(
    'a replaced connection ends the old pin; the new pin is another client',
    () async {
      final old = await pool.pin(one.origin);
      await pool.connect(one.endpoint, 'user@example.test', 'password');
      expect(old.isLive, isFalse, reason: 'ended at the replacement itself');
      final fresh = await pool.pin(one.origin);

      expect(await old.ended, _failure(ConnectionFailureReason.cancelled));
      expect(
        () => old.client,
        throwsA(_failure(ConnectionFailureReason.cancelled)),
      );
      expect(fresh.isLive, isTrue);
      await fresh.client.from('reservations').select();
      expect(one.seen, contains('/rest/v1/reservations'));
    },
  );

  test('a closed pool ends every pin and refuses new ones', () async {
    final a = await pool.pin(one.origin);
    final b = await pool.pin(two.origin);
    pool.close();
    expect(await a.ended, _failure(ConnectionFailureReason.cancelled));
    expect(await b.ended, _failure(ConnectionFailureReason.cancelled));
    await expectLater(
      pool.pin(one.origin),
      throwsA(_failure(ConnectionFailureReason.cancelled)),
    );
  });

  test('a target that signed out ends its pin as expired', () async {
    final a = await pool.pin(one.origin);
    final b = await pool.pin(two.origin);
    await a.client.auth.signOut();
    expect(await a.ended, _failure(ConnectionFailureReason.expired));
    expect(b.isLive, isTrue);
  });

  test('a replaced backend is refused and never pinned', () async {
    one.installationId = 'inst-replaced';
    await expectLater(
      pool.pin(one.origin),
      throwsA(_failure(ConnectionFailureReason.changedIdentity)),
    );
    expect((await pool.pin(two.origin)).isLive, isTrue);
  });

  test(
    'releasing a pin is idempotent and keeps the client for other holders',
    () async {
      final a = await pool.pin(one.origin);
      final b = await pool.pin(one.origin);
      a
        ..release()
        ..release();
      expect(a.isLive, isFalse);
      expect(b.isLive, isTrue);
      await b.client.from('reservations').select();
      expect(one.seen, contains('/rest/v1/reservations'));

      // A released lease is not told about a later disconnect.
      var told = false;
      unawaited(a.ended.then((_) => told = true));
      await pool.disconnect(one.origin);
      await b.ended;
      expect(told, isFalse);
    },
  );
}
