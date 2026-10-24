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

import '../../helpers/installation_auth_storage.dart' show MemorySecrets;
import '../../helpers/native_federation_flow.dart' show session, user;

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

  /// #2562 C1b -- what the target says at completion (after the browser).
  String completeInstallation = installation;
  bool expiredExchange = false;
  int authorityReads = 0;
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
        // The first read is the check before the browser opens.
        final atCompletion = authorityReads++ > 0;
        return _json(
          request,
          offersDeskilo
              ? {
                  'kind': 'oidc',
                  'provider': 'custom:deskilo',
                  'installation_id': atCompletion
                      ? completeInstallation
                      : installation,
                  'issuer': authorityIssuer,
                }
              : null,
        );
      case '/auth/v1/token':
        return _json(request, {
          ...session('target-user'),
          if (expiredExchange) 'access_token': _expiredToken,
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

/// An access token that ended in 2000.
final _expiredToken =
    'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'target-user', 'exp': 946684800})))}.signature';

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
    // #2562 C1b -- one registration, two local ids: kept under the
    // canonical identity, not under the home account's id.
    expect(saved.single.account, isNot(w.active.auth.currentUser!.id));
    expect(saved.single.issuer, homeIssuer);
    expect(saved.single.subject, 'home-user');
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

  group('#2562 C1b -- the callback intent: target and personal epoch', () {
    test('signed out and in again here (same person) while the browser was '
        'open: refused before any code is exchanged', () async {
      final w = _World();
      await w.build();
      final event = w.federation.events.first;
      await w.federation.begin(w.intent);
      await w.active.auth.setInitialSession(
        jsonEncode({
          ...session('home-user'),
          'user': {...user('home-user'), 'last_sign_in_at': '2026-10-23T09:00:00Z'},
        }),
      );
      expect(
        w.dispatcher.call(w.returnWith('target-code')),
        false,
        reason: 'the main client never exchanges it',
      );
      final result = await event;
      expect(result.status, SecondaryConnectStatus.failed);
      expect(result.failure, FederationFailure.wrongAccount);
      expect(
        w.requests.where((r) => r.url.path == '/auth/v1/token'),
        isEmpty,
        reason: 'no target session was created for an ended sign-in',
      );
      expect(await w.registry.list(), isEmpty);
    });

    test('a tampered return, or the return of a replaced flow, is not '
        'claimed; the newer flow connects', () async {
      final w = _World();
      await w.build();
      final events = <SecondaryConnectEvent>[];
      final sub = w.federation.events.listen(events.add);
      addTearDown(sub.cancel);
      await w.federation.begin(w.intent);
      final first = w.returnWith('first-code');
      final tampered = first.replace(
        queryParameters: {
          ...first.queryParameters,
          'deskilo_flow': 'not-this-flow',
        },
      );
      expect(w.dispatcher.call(tampered), false);
      final second = await w.federation.begin(w.intent);
      expect(w.dispatcher.call(first), false, reason: 'replaced: refused');
      await pumpEventQueue();
      expect(w.requests.where((r) => r.url.path == '/auth/v1/token'), isEmpty);
      w.dispatcher.call(w.returnWith('second-code'));
      await pumpEventQueue();
      expect(events.map((e) => e.status), [
        SecondaryConnectStatus.cancelled,
        SecondaryConnectStatus.connected,
      ]);
      expect(events.last.flow, second);
      expect(await w.registry.list(), hasLength(1));
    });

    test('the target names another installation after the browser: refused, '
        'nothing kept, its session ended', () async {
      final w = _World()
        ..completeInstallation = '00000000-0000-4000-8000-00000000ffff';
      await w.build();
      final event = w.federation.events.first;
      await w.federation.begin(w.intent);
      w.dispatcher.call(w.returnWith('target-code'));
      final result = await event;
      expect(result.status, SecondaryConnectStatus.failed);
      expect(result.failure, FederationFailure.incompatibleServer);
      expect(await w.registry.list(), isEmpty);
      expect(w.requests.where((r) => r.url.path == '/auth/v1/logout'),
          isNotEmpty);
      expect(w.active.auth.currentUser!.id, 'home-user');
    });

    test('a session that ended before it could be adopted: expired, nothing '
        'kept; connecting again works', () async {
      final w = _World()..expiredExchange = true;
      await w.build();
      final first = w.federation.events.first;
      await w.federation.begin(w.intent);
      w.dispatcher.call(w.returnWith('target-code'));
      final result = await first;
      expect(result.status, SecondaryConnectStatus.failed);
      expect(result.failure, FederationFailure.expired);
      expect(await w.registry.list(), isEmpty);
      expect(
        w.secrets.values.keys.where(
          (k) => !k.startsWith('deskilo.connections.'),
        ),
        isEmpty,
        reason: 'the verifier and the callback metadata are gone',
      );

      // Recovery: a fresh flow with a live session connects.
      w.expiredExchange = false;
      final again = w.federation.events.first;
      await w.federation.begin(w.intent);
      w.dispatcher.call(w.returnWith('target-code'));
      expect((await again).status, SecondaryConnectStatus.connected);
      expect(await w.registry.list(), hasLength(1));
    });
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
