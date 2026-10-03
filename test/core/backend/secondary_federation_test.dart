// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1834 A — connecting another installation with the identity the person
// already has: the other server's own sign-in, through the one callback
// owner, its verified binding, and the session kept in the connection
// registry. Never this app's main session, never an e-mail match, never a
// browser return that belongs to another flow or another person.
import 'dart:convert';

import 'package:deskilo/core/backend/auth_callback_dispatch.dart';
import 'package:deskilo/core/backend/auth_callback_guard.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/federation_handoff.dart';
import 'package:deskilo/core/backend/secondary_federation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'installation_auth_storage_test.dart' show MemorySecrets;
import 'native_federation_flow_test.dart' show session, user;

const home = 'https://home.example';
const target = 'https://target.example';
const targetKey = 'sb_publishable_target';
const installation = '00000000-0000-4000-8000-000000001834';
const homeIssuer = '$home/auth/v1';

/// A target user whose Deskilo identity names [subject].
Map<String, Object?> targetUser(String id, String subject) => {
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

class _World {
  _World({
    this.subject = 'home-user',
    this.authorityIssuer = homeIssuer,
    this.offersDeskilo = true,
    this.failSave = false,
  });
  final String subject;
  final String authorityIssuer;
  final bool offersDeskilo;
  final bool failSave;
  final requests = <http.Request>[];
  late final secrets = _Secrets(failSave: failSave);
  late SupabaseClient active;
  late AuthCallbackDispatcher dispatcher;
  late ConnectedInstallations registry;
  late SecondaryFederation federation;
  Uri? launched;

  http.Response _json(
    http.Request request,
    Object? value, [
    int status = 200,
  ]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
    request: request,
  );

  http.Client targetWire() => MockClient((request) async {
    requests.add(request);
    expect(request.url.origin, target, reason: 'nothing leaves the target');
    switch (request.url.path) {
      case '/rest/v1/rpc/public_network_descriptor':
        return _json(request, {'code': 'PGRST202', 'message': 'nf'}, 404);
      case '/rest/v1/rpc/public_identity_authority':
        return _json(
          request,
          offersDeskilo
              ? {
                  'kind': 'oidc',
                  'provider': 'custom:deskilo',
                  'installation_id': installation,
                  'issuer': authorityIssuer,
                }
              : null,
        );
      case '/auth/v1/token':
        return _json(request, {
          ...session('target-user'),
          'user': targetUser('target-user', subject),
          'provider_token': 'canonical-identity-token',
          'provider_refresh_token': 'canonical-identity-refresh',
        });
      case '/auth/v1/user':
        return _json(request, targetUser('target-user', subject));
      case '/rest/v1/rpc/finalize_identity_binding':
        return _json(request, {
          'status': 'verified',
          'installation_id': installation,
          'issuer': authorityIssuer,
        });
      case '/rest/v1/installation_identity':
        return _json(request, {'installation_id': installation});
      case '/auth/v1/logout':
        return _json(request, {});
      default:
        fail('unexpected target endpoint ${request.url.path}');
    }
  });

  Future<void> build() async {
    active = SupabaseClient(
      home,
      'sb_publishable_home',
      httpClient: MockClient((request) async {
        // The person's own server is its identity authority (native).
        if (request.url.path == '/rest/v1/rpc/public_identity_authority') {
          return _json(request, null);
        }
        fail('unexpected home endpoint ${request.url.path}');
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await active.auth.setInitialSession(jsonEncode(session('home-user')));
    final guard = AuthCallbackGuard(
      secrets,
      Uri.parse(home),
      Uri.parse('deskilo://auth-callback'),
    );
    dispatcher = AuthCallbackDispatcher(
      guard,
      currentUser: () => active.auth.currentUser?.id,
    );
    registry = ConnectedInstallations(active, secrets, transport: targetWire);
    federation = SecondaryFederation(
      active: active,
      registry: registry,
      secrets: secrets,
      callback: Uri.parse('deskilo://auth-callback'),
      dispatcher: dispatcher,
      transport: targetWire,
      launch: (uri) async {
        launched = uri;
        return true;
      },
    );
  }

  SecondaryConnectIntent get intent => const SecondaryConnectIntent(
    target: BackendEndpoint(target, targetKey),
    workspaceId: 'workspace-b',
    action: SecondaryConnectAction.apply,
  );

  /// The browser's return for the flow that was launched.
  Uri returnWith(String code) {
    final redirect = Uri.parse(launched!.queryParameters['redirect_to']!);
    return redirect.replace(
      queryParameters: {...redirect.queryParameters, 'code': code},
    );
  }
}

class _Secrets extends MemorySecrets {
  _Secrets({this.failSave = false});
  final bool failSave;
  @override
  Future<void> write(String key, String value) async {
    if (failSave && key.startsWith('deskilo.connections.')) {
      throw StateError('keychain unavailable');
    }
    return super.write(key, value);
  }
}

void main() {
  test('the other server\'s own sign-in, its binding and the registry: '
      'connected, never this app\'s main session', () async {
    final w = _World();
    await w.build();
    final events = <SecondaryConnectEvent>[];
    final sub = w.federation.events.listen(events.add);
    addTearDown(sub.cancel);

    final flow = await w.federation.begin(w.intent);
    expect(w.launched!.origin, target, reason: 'sign-in runs on the target');
    expect(w.launched!.queryParameters['provider'], 'custom:deskilo');

    final callback = w.returnWith('target-code');
    expect(
      w.dispatcher.call(callback),
      false,
      reason: 'the main client never exchanges a connect return',
    );
    await pumpEventQueue();

    expect(events.single.flow, flow);
    expect(events.single.status, SecondaryConnectStatus.connected);
    final saved = await w.registry.list();
    expect(saved.single.endpoint.url, target);
    expect(saved.single.account, 'target-user');
    expect(saved.single.installationId, installation);
    expect(
      w.active.auth.currentUser!.id,
      'home-user',
      reason: 'the main session is untouched',
    );
    final homeToken = w.active.auth.currentSession!.accessToken;
    expect(
      w.requests.any(
        (r) =>
            r.headers['authorization'] == 'Bearer $homeToken' ||
            r.headers.values.any((v) => v.contains('canonical-identity')),
      ),
      false,
      reason: 'no home bearer and no canonical provider token reach the target',
    );
    expect(
      w.secrets.values.values.any((v) => v.contains('canonical-identity')),
      false,
      reason: 'provider tokens are never stored',
    );
    expect(
      w.secrets.values.keys.where((k) => !k.startsWith('deskilo.connections.')),
      isEmpty,
      reason: 'the verifier and the callback metadata are gone',
    );

    // The same return again is refused: nothing is exchanged twice.
    expect(w.dispatcher.call(callback), false);
    await pumpEventQueue();
    expect(events, hasLength(1));
  });

  test(
    'a browser that returns somebody else is refused; nothing is saved',
    () async {
      final w = _World(subject: 'somebody-else');
      await w.build();
      final event = w.federation.events.first;
      await w.federation.begin(w.intent);
      w.dispatcher.call(w.returnWith('target-code'));
      final result = await event;
      expect(result.status, SecondaryConnectStatus.failed);
      expect(result.failure, FederationFailure.wrongAccount);
      expect(await w.registry.list(), isEmpty);
      expect(
        w.requests.where((r) => r.url.path == '/auth/v1/logout'),
        isNotEmpty,
        reason: 'the unused target session is signed out',
      );
    },
  );

  test(
    'cancelled before the browser returns: the late return is refused',
    () async {
      final w = _World();
      await w.build();
      final events = <SecondaryConnectEvent>[];
      final sub = w.federation.events.listen(events.add);
      addTearDown(sub.cancel);
      final flow = await w.federation.begin(w.intent);
      await w.federation.cancel(flow);
      expect(w.dispatcher.call(w.returnWith('target-code')), false);
      await pumpEventQueue();
      expect(events.map((e) => e.status), [SecondaryConnectStatus.cancelled]);
      expect(await w.registry.list(), isEmpty);
      expect(w.requests.where((r) => r.url.path == '/auth/v1/token'), isEmpty);
    },
  );

  test('the account here changed while the browser was open: the return '
      'is not claimed and nothing is connected', () async {
    final w = _World();
    await w.build();
    final events = <SecondaryConnectEvent>[];
    final sub = w.federation.events.listen(events.add);
    addTearDown(sub.cancel);
    await w.federation.begin(w.intent);
    await w.active.auth.setInitialSession(jsonEncode(session('other-user')));
    expect(w.dispatcher.call(w.returnWith('target-code')), false);
    await pumpEventQueue();
    expect(events, isEmpty);
    // The registry is the old account's and now refuses to answer; no
    // connection was written for anybody.
    expect(
      w.secrets.values.keys.where((k) => k.startsWith('deskilo.connections.')),
      isEmpty,
    );
  });

  test('accepted by the target but not kept on this device: notSaved, '
      'nothing submitted, the target session ended', () async {
    final w = _World(failSave: true);
    await w.build();
    final event = w.federation.events.first;
    await w.federation.begin(w.intent);
    w.dispatcher.call(w.returnWith('target-code'));
    final result = await event;
    expect(result.status, SecondaryConnectStatus.notSaved);
    expect(
      result.intent.action,
      SecondaryConnectAction.apply,
      reason: 'the intent is handed back for a safe retry',
    );
    expect(
      w.requests.where((r) => r.url.path == '/auth/v1/logout'),
      isNotEmpty,
    );
  });

  group('a server that cannot take the identity says why', () {
    test('no Deskilo sign-in there', () async {
      final w = _World(offersDeskilo: false);
      await w.build();
      await expectLater(
        w.federation.assess(w.intent.target),
        throwsA(
          isA<IdentityConnectUnavailable>().having(
            (e) => e.reason,
            'reason',
            IdentityConnectUnsupported.targetWithoutDeskiloSignIn,
          ),
        ),
      );
      expect(w.launched, isNull);
    });

    test('another identity authority there', () async {
      final w = _World(authorityIssuer: 'https://other.example/auth/v1');
      await w.build();
      await expectLater(
        w.federation.begin(w.intent),
        throwsA(
          isA<IdentityConnectUnavailable>().having(
            (e) => e.reason,
            'reason',
            IdentityConnectUnsupported.differentAuthority,
          ),
        ),
      );
      expect(w.launched, isNull);
    });

    test('the server this app already runs on', () async {
      final w = _World();
      await w.build();
      await expectLater(
        w.federation.assess(const BackendEndpoint(home, 'sb_publishable_x')),
        throwsA(
          isA<IdentityConnectUnavailable>().having(
            (e) => e.reason,
            'reason',
            IdentityConnectUnsupported.currentServer,
          ),
        ),
      );
    });
  });
}
