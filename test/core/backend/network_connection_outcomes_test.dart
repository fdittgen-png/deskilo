// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1832 A — a connected installation fails with a TYPED outcome, each with
// its own recovery, through the real registry and real SDK clients over a
// controlled transport:
//   * connecting reads the #1847 descriptor, never the account's invoices;
//   * an unsupported server is refused and nothing is saved;
//   * one target that is down leaves another usable;
//   * an expired session is "sign in again", a changed installation is
//     quarantined and not called again;
//   * a committed action whose refreshed session cannot be saved is still
//     the committed result, done once.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/backend/auth_secret_store.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'installation_auth_storage_test.dart' show MemorySecrets;
import 'native_federation_flow_test.dart' show user, session;

Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/fixtures/public_network/$name').readAsStringSync())
        as Map<String, Object?>;

/// One target's scripted answers. `installation` is what its
/// installation_identity says; `descriptor` its descriptor answer (null:
/// a pre-negotiation server, PGRST202).
class _Target {
  _Target(this.host, {this.descriptor});
  final String host;
  String? installation;
  Object? descriptor;
  bool down = false;
  bool sessionRevoked = false;
  int actions = 0;
  final paths = <String>[];
}

http.Response _json(http.Request r, Object? body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: r,
    );

http.Client Function() _wire(Map<String, _Target> targets) =>
    () => MockClient((r) async {
      final t = targets[r.url.host]!;
      t.paths.add(r.url.path);
      if (t.down) throw http.ClientException('Connection refused', r.url);
      final id = '${t.host}-user';
      switch (r.url.path) {
        case '/auth/v1/token':
          return _json(r, session(id));
        case '/auth/v1/user':
          // A target that revoked the session refuses its token.
          if (t.sessionRevoked) {
            return _json(r, {
              'code': 401,
              'error_code': 'bad_jwt',
              'msg': 'invalid JWT: session revoked',
            }, 401);
          }
          return _json(r, user(id));
        case '/rest/v1/installation_identity':
          return _json(r, {'installation_id': t.installation ?? 'i-${t.host}'});
        case '/rest/v1/rpc/public_network_descriptor':
          if (t.descriptor == null) {
            final legacy = _fixture('legacy_server_no_descriptor.json');
            return _json(r, legacy['body'], legacy['status']! as int);
          }
          return _json(r, t.descriptor);
        case '/rest/v1/rpc/book':
          t.actions++;
          return _json(r, 'booked-${t.actions}');
      }
      throw StateError('unexpected endpoint ${r.url.path}');
    });

Future<SupabaseClient> _home() async {
  final home = SupabaseClient(
    'https://home.example',
    'sb_publishable_home',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  await home.auth.setInitialSession(jsonEncode(session('home-user')));
  return home;
}

BackendEndpoint _endpoint(String host) =>
    BackendEndpoint('https://$host.example', 'sb_publishable_${host}_key');

/// A secret store whose writes start failing on demand.
class _FlakySecrets implements AuthSecretStore {
  final inner = MemorySecrets();
  bool failWrites = false;
  @override
  Future<String?> read(String key) => inner.read(key);
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw const FileSystemException('keychain unavailable');
    await inner.write(key, value);
  }

  @override
  Future<void> delete(String key) => inner.delete(key);
}

void main() {
  final current = _fixture('descriptor_current.json')['descriptor'];

  group('classifyConnectionError — SDK types and codes, never sentences', () {
    ConnectionFailureReason r(Object e) =>
        classifyConnectionError(e, source: 'https://t.example').reason;

    test('transport and server faults are unavailable', () {
      expect(r(TimeoutException('slow')), ConnectionFailureReason.unavailable);
      expect(
        r(http.ClientException('Connection refused')),
        ConnectionFailureReason.unavailable,
      );
      expect(
        r(AuthRetryableFetchException(message: 'x')),
        ConnectionFailureReason.unavailable,
      );
      expect(
        r(const PostgrestException(message: 'bad gateway', code: '502')),
        ConnectionFailureReason.unavailable,
      );
    });

    test('an ended session is expired; a refused account is denied', () {
      expect(
        r(
          const AuthException(
            'Invalid Refresh Token: Refresh Token Not Found',
            statusCode: '400',
            code: 'refresh_token_not_found',
          ),
        ),
        ConnectionFailureReason.expired,
      );
      expect(
        r(const PostgrestException(message: 'JWT expired', code: 'PGRST301')),
        ConnectionFailureReason.expired,
      );
      expect(
        r(
          const AuthException(
            'Invalid login credentials',
            statusCode: '400',
            code: 'invalid_credentials',
          ),
        ),
        ConnectionFailureReason.denied,
      );
      expect(
        r(const PostgrestException(message: 'denied', code: '42501')),
        ConnectionFailureReason.denied,
      );
    });

    test('unreadable answers are malformed, never supported', () {
      expect(r(const FormatException('x')), ConnectionFailureReason.malformed);
      expect(
        r(const PostgrestException(message: 'odd', code: 'XX000')),
        ConnectionFailureReason.malformed,
      );
      expect(r(Exception('?')), ConnectionFailureReason.malformed);
      expect(
        r(StateError('cross-origin request refused')),
        ConnectionFailureReason.invalidEndpoint,
      );
    });

    test('a typed failure passes through unchanged, after-send kept', () {
      final f = ConnectionFailure(
        's',
        ConnectionFailureReason.unavailable,
        afterSend: true,
      );
      expect(classifyConnectionError(f, source: 'other'), same(f));
      expect(f, isA<StateError>(), reason: 'old callers still catch it');
    });
  });

  group('the registry', () {
    test(
      'connecting reads the descriptor and no financial operation',
      () async {
        final home = await _home();
        final t = _Target('one', descriptor: current);
        final legacy = _Target('two');
        final targets = {'one.example': t, 'two.example': legacy};
        final registry = ConnectedInstallations(
          home,
          MemorySecrets(),
          transport: _wire(targets),
        );
        await registry.connect(_endpoint('one'), 'me@example.test', 'pw');
        await registry.connect(_endpoint('two'), 'me@example.test', 'pw');
        expect(
          await registry.list(),
          hasLength(2),
          reason: 'a current and a pre-negotiation server both connect',
        );
        for (final target in targets.values) {
          expect(
            target.paths,
            contains('/rest/v1/rpc/public_network_descriptor'),
          );
          expect(
            target.paths.where((p) => p.contains('financial')),
            isEmpty,
            reason: 'connecting runs no financial operation',
          );
        }
        registry.close();
        await home.dispose();
      },
    );

    test(
      'an unsupported server is refused by name and nothing is saved',
      () async {
        final home = await _home();
        final newer = {
          ...(current! as Map<String, Object?>),
          'protocol_versions': [7],
        };
        final unknownTerm = _fixture(
          'synthetic_unknown_required_term.json',
        )['descriptor'];
        for (final descriptor in [newer, unknownTerm]) {
          final registry = ConnectedInstallations(
            home,
            MemorySecrets(),
            transport: _wire({
              'one.example': _Target('one', descriptor: descriptor),
            }),
          );
          await expectLater(
            registry.connect(_endpoint('one'), 'me@example.test', 'pw'),
            throwsA(
              isA<ConnectionFailure>().having(
                (f) => f.reason,
                'reason',
                ConnectionFailureReason.unsupported,
              ),
            ),
          );
          expect(await registry.list(), isEmpty);
          registry.close();
        }
        await home.dispose();
      },
    );

    test('one target down leaves the other usable', () async {
      final home = await _home();
      final a = _Target('alpha', descriptor: current);
      final b = _Target('beta', descriptor: current);
      final registry = ConnectedInstallations(
        home,
        MemorySecrets(),
        transport: _wire({'alpha.example': a, 'beta.example': b}),
      );
      await registry.connect(_endpoint('alpha'), 'me@example.test', 'pw');
      await registry.connect(_endpoint('beta'), 'me@example.test', 'pw');
      a.down = true;
      final failure = await registry.check('https://alpha.example');
      expect(failure?.reason, ConnectionFailureReason.unavailable);
      expect(await registry.check('https://beta.example'), isNull);
      expect(
        await registry.use('https://beta.example', (c) => c.rpc<String>('book')),
        'booked-1',
      );
      registry.close();
      await home.dispose();
    });

    test(
      'a session the target revoked is "sign in again"',
      () async {
        final home = await _home();
        final t = _Target('one', descriptor: current);
        final registry = ConnectedInstallations(
          home,
          MemorySecrets(),
          transport: _wire({'one.example': t}),
        );
        await registry.connect(_endpoint('one'), 'me@example.test', 'pw');
        // The target revoked the saved session.
        t.sessionRevoked = true;
        final failure = await registry.check('https://one.example');
        expect(failure?.reason, ConnectionFailureReason.expired);
        expect(t.actions, 0);
        registry.close();
        await home.dispose();
      },
    );

    test(
      'a changed installation is quarantined and not called again',
      () async {
        final home = await _home();
        final t = _Target('one', descriptor: current);
        final registry = ConnectedInstallations(
          home,
          MemorySecrets(),
          transport: _wire({'one.example': t}),
        );
        await registry.connect(_endpoint('one'), 'me@example.test', 'pw');
        t.installation = 'a-replacement-backend';
        await expectLater(
          registry.use('https://one.example', (c) => c.rpc<String>('book')),
          throwsA(
            isA<ConnectionFailure>().having(
              (f) => f.reason,
              'reason',
              ConnectionFailureReason.changedIdentity,
            ),
          ),
        );
        expect(t.actions, 0, reason: 'nothing ran on the replacement');
        final before = t.paths.length;
        t.installation = null; // the original answers again: still quarantined
        expect(
          (await registry.check('https://one.example'))?.reason,
          ConnectionFailureReason.changedIdentity,
        );
        expect(
          t.paths.length,
          before,
          reason: 'a quarantined target is not called until re-verified',
        );
        // Re-verification is connecting it again.
        await registry.connect(_endpoint('one'), 'me@example.test', 'pw');
        expect(await registry.check('https://one.example'), isNull);
        registry.close();
        await home.dispose();
      },
    );

    test(
      'a committed action stays committed when its session cannot be saved',
      () async {
        final home = await _home();
        final t = _Target('one', descriptor: current);
        final secrets = _FlakySecrets();
        final registry = ConnectedInstallations(
          home,
          secrets,
          transport: _wire({'one.example': t}),
        );
        await registry.connect(_endpoint('one'), 'me@example.test', 'pw');
        secrets.failWrites = true;
        final result = await registry.use(
          'https://one.example',
          (c) => c.rpc<String>('book'),
        );
        expect(result, 'booked-1', reason: 'the known result, not a failure');
        expect(t.actions, 1, reason: 'done once, never retried');
        expect(registry.sessionNotSaved('https://one.example'), isTrue);
        secrets.failWrites = false;
        await registry.use('https://one.example', (c) => c.rpc<String>('book'));
        expect(registry.sessionNotSaved('https://one.example'), isFalse);
        registry.close();
        await home.dispose();
      },
    );

    test(
      'a transport lost after send is "outcome unknown", not refused',
      () async {
        final home = await _home();
        final t = _Target('one', descriptor: current);
        final registry = ConnectedInstallations(
          home,
          MemorySecrets(),
          transport: _wire({'one.example': t}),
        );
        await registry.connect(_endpoint('one'), 'me@example.test', 'pw');
        await expectLater(
          registry.use('https://one.example', (c) async {
            await c.rpc<String>('book');
            throw http.ClientException('Connection reset by peer');
          }),
          throwsA(
            isA<ConnectionFailure>()
                .having(
                  (f) => f.reason,
                  'reason',
                  ConnectionFailureReason.unavailable,
                )
                .having((f) => f.afterSend, 'afterSend', isTrue),
          ),
        );
        expect(t.actions, 1);
        registry.close();
        await home.dispose();
      },
    );

    test('the app account changing discards the answer as cancelled', () async {
      final home = await _home();
      final registry = ConnectedInstallations(
        home,
        MemorySecrets(),
        transport: _wire({'one.example': _Target('one', descriptor: current)}),
      );
      await registry.connect(_endpoint('one'), 'me@example.test', 'pw');
      await home.auth.setInitialSession(jsonEncode(session('someone-else')));
      await expectLater(
        registry.list(),
        throwsA(
          isA<ConnectionFailure>().having(
            (f) => f.reason,
            'reason',
            ConnectionFailureReason.cancelled,
          ),
        ),
      );
      registry.close();
      await home.dispose();
    });
  });
}
