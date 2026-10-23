// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C1b -- the single-registration adoption into the connection pool.
// A session the identity flow obtained on a workspace installation's OWN
// server is kept under the canonical identity (issuer + subject) and the
// verified installation, one installation per connection. A refused or
// expired adoption changes nothing: no record, no pooled client, and an
// earlier connection of the same target keeps working. The identity
// provider's tokens are never written.
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/installation_auth_storage.dart' show MemorySecrets;
import '../../helpers/native_federation_flow.dart' show session, user;

const _home = 'https://home.example';
const _one = 'https://one.example';
const _alias = 'https://alias.example';
const _issuer = '$_home/auth/v1';
const _installation = '00000000-0000-4000-8000-000000002562';

/// A target account whose Deskilo identity names [subject].
Map<String, Object?> _account(String id, String subject) => {
  ...user(id),
  'identities': [
    {
      'id': 'identity-$id',
      'identity_id': 'identity-$id',
      'user_id': id,
      'provider': 'custom:deskilo',
      'identity_data': {'sub': subject},
    },
  ],
};

/// [session] whose access token ended in 2000.
Map<String, Object?> _expired(String id) {
  final jwt = base64Url.encode(
    utf8.encode(jsonEncode({'sub': id, 'exp': 946684800})),
  );
  return {...session(id), 'access_token': 'e30.$jwt.signature'};
}

/// The session the identity flow hands over, provider tokens included.
Session _flowSession(String id) => Session.fromJson({
  ...session(id),
  'user': _account(id, 'home-user'),
  'provider_token': 'canonical-identity-token',
  'provider_refresh_token': 'canonical-identity-refresh',
})!;

class _World {
  /// What each target says its account's Deskilo subject is now.
  final subjects = <String, String>{_one: 'home-user', _alias: 'home-user'};

  /// What each target says its installation is.
  final installations = <String, String>{
    _one: _installation,
    _alias: _installation,
  };
  final requests = <http.Request>[];
  final secrets = MemorySecrets();
  late SupabaseClient home;
  late ConnectedInstallations pool;

  http.Response _json(http.Request r, Object? value, [int status = 200]) =>
      http.Response(
        jsonEncode(value),
        status,
        headers: {'content-type': 'application/json'},
        request: r,
      );

  http.Client wire() => MockClient((r) async {
    requests.add(r);
    final origin = r.url.origin;
    final id = 'user-${r.url.host.split('.').first}';
    return switch (r.url.path) {
      '/auth/v1/user' => _json(r, _account(id, subjects[origin]!)),
      '/auth/v1/token' => _json(r, {
        ...session(id),
        'user': _account(id, subjects[origin]!),
      }),
      '/rest/v1/installation_identity' => _json(r, {
        'installation_id': installations[origin],
      }),
      '/rest/v1/rpc/public_network_descriptor' => _json(r, {
        'code': 'PGRST202',
        'message': 'not found',
      }, 404),
      _ => throw StateError('unexpected endpoint ${r.url.path}'),
    };
  });

  Future<void> build() async {
    home = SupabaseClient(
      _home,
      'sb_publishable_home',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await home.auth.setInitialSession(jsonEncode(session('home-user')));
    pool = ConnectedInstallations(home, secrets, transport: wire);
  }

  Future<void> adopt(String source, Session s, {String? installation}) =>
      pool.adopt(
        BackendEndpoint(source, 'sb_publishable_target'),
        s,
        installationId: installation ?? _installation,
        issuer: _issuer,
        subject: 'home-user',
      );

  String get stored => secrets.values.entries
      .where((e) => e.key.startsWith('deskilo.connections.'))
      .map((e) => e.value)
      .join();

  Future<void> dispose() async {
    pool.close();
    await home.dispose();
  }
}

Matcher _refused(ConnectionFailureReason reason) =>
    throwsA(isA<ConnectionFailure>().having((f) => f.reason, 'reason', reason));

void main() {
  test('adopted under the canonical identity and the verified installation; '
      'the pooled client carries only the target\'s own session', () async {
    final w = _World();
    await w.build();
    addTearDown(w.dispose);

    await w.adopt(_one, _flowSession('user-one'));

    final saved = (await w.pool.list()).single;
    expect(saved.endpoint.url, _one);
    expect(saved.account, 'user-one', reason: 'its own local id there');
    expect(saved.installationId, _installation);
    expect(saved.issuer, _issuer);
    expect(saved.subject, 'home-user');
    expect(
      w.stored,
      isNot(contains('canonical-identity')),
      reason: 'the identity provider\'s tokens are never written',
    );

    final pin = await w.pool.pin(_one);
    expect(pin.account, 'user-one');
    expect(pin.client.auth.currentUser!.id, 'user-one');
    expect(
      w.home.auth.currentUser!.id,
      'home-user',
      reason: 'this app\'s own session is untouched',
    );
    final homeToken = w.home.auth.currentSession!.accessToken;
    expect(
      w.requests.any((r) => r.headers['authorization'] == 'Bearer $homeToken'),
      isFalse,
      reason: 'no home bearer reaches the target',
    );
    pin.release();
  });

  test(
    'an expired session is refused before anything is asked or kept',
    () async {
      final w = _World();
      await w.build();
      addTearDown(w.dispose);

      await expectLater(
        w.adopt(
          _one,
          Session.fromJson({
            ..._expired('user-one'),
            'user': _account('user-one', 'home-user'),
          })!,
        ),
        _refused(ConnectionFailureReason.expired),
      );
      expect(w.requests, isEmpty, reason: 'no refresh into a connection');
      expect(await w.pool.list(), isEmpty);
    },
  );

  test('another subject, or another installation, is refused and leaves no '
      'record', () async {
    final w = _World()..subjects[_one] = 'somebody-else';
    await w.build();
    addTearDown(w.dispose);
    await expectLater(
      w.adopt(_one, _flowSession('user-one')),
      _refused(ConnectionFailureReason.changedIdentity),
    );
    w.subjects[_one] = 'home-user';
    await expectLater(
      w.adopt(
        _one,
        _flowSession('user-one'),
        installation: '00000000-0000-4000-8000-00000000ffff',
      ),
      _refused(ConnectionFailureReason.changedIdentity),
    );
    expect(await w.pool.list(), isEmpty);
    await expectLater(
      w.pool.open(_one),
      _refused(ConnectionFailureReason.notConnected),
      reason: 'no half-adopted client to open',
    );
  });

  test('a refused adoption keeps the earlier connection and its leases; a '
      'verified one replaces it', () async {
    final w = _World();
    await w.build();
    addTearDown(w.dispose);
    await w.adopt(_one, _flowSession('user-one'));
    final before = w.stored;
    final pin = await w.pool.pin(_one);

    w.subjects[_one] = 'somebody-else';
    await expectLater(
      w.adopt(_one, _flowSession('user-one')),
      _refused(ConnectionFailureReason.changedIdentity),
    );
    expect(pin.isLive, isTrue, reason: 'the refusal ended nothing');
    expect(w.stored, before, reason: 'the saved connection is unchanged');

    // Recovery: the same person signs in again and is adopted.
    w.subjects[_one] = 'home-user';
    await w.adopt(_one, _flowSession('user-one'));
    expect(
      await pin.ended,
      isA<ConnectionFailure>(),
      reason: 'the replaced connection ends its leases',
    );
    expect(pin.isLive, isFalse);
    final again = await w.pool.pin(_one);
    expect(again.client.auth.currentUser!.id, 'user-one');
    again.release();
  });

  test('one installation is one connection: another address claiming it is '
      'refused', () async {
    final w = _World();
    await w.build();
    addTearDown(w.dispose);
    await w.adopt(_one, _flowSession('user-one'));
    await expectLater(
      w.adopt(_alias, _flowSession('user-alias')),
      _refused(ConnectionFailureReason.changedIdentity),
    );
    expect([for (final c in await w.pool.list()) c.endpoint.url], [_one]);
  });

  test('a target whose account stops carrying the subject is quarantined on '
      'its next use', () async {
    final w = _World();
    await w.build();
    addTearDown(w.dispose);
    await w.adopt(_one, _flowSession('user-one'));
    w.subjects[_one] = 'somebody-else';
    await expectLater(
      w.pool.open(_one),
      _refused(ConnectionFailureReason.changedIdentity),
    );
    // Quarantined: it is not asked again until it is connected again.
    w.subjects[_one] = 'home-user';
    await expectLater(
      w.pool.open(_one),
      _refused(ConnectionFailureReason.changedIdentity),
    );
  });
}
