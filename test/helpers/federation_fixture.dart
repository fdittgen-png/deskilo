// SPDX-License-Identifier: AGPL-3.0-or-later
// #1648 — one explicit target, driven end to end in process: the real
// callback guard, dispatcher, isolated SDK exchange and repository, with
// only the system browser and the target's HTTP answers faked.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/backend/auth_callback_dispatch.dart';
import 'package:deskilo/core/backend/auth_callback_guard.dart';
import 'package:deskilo/core/backend/native_federation_flow.dart';
import 'package:deskilo/features/auth/data/supabase_auth_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/installation_auth_storage_test.dart' show MemorySecrets;

const fixtureInstallation = '00000000-0000-4000-8000-000000001648';
const fixtureIssuer = 'https://identity.example/auth/v1';

Map<String, Object?> fixtureUser(String id) => {
  'id': id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'created_at': '2026-09-28T00:00:00Z',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
};

Map<String, Object?> fixtureSession(String id, String origin) {
  final jwt = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': id,
        'iss': '$origin/auth/v1',
        'exp':
            4102444800 /* fixed year 2100: the SDK checks real token expiry */,
      }),
    ),
  );
  return {
    'access_token': 'e30.$jwt.signature',
    'refresh_token': 'refresh-$id',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': fixtureUser(id),
  };
}

/// One target installation and everything the app would own for it.
class FederationTarget {
  FederationTarget(this.origin, {DateTime Function()? now}) {
    guard = AuthCallbackGuard(
      secrets,
      Uri.parse(origin),
      Uri.parse('deskilo://auth-callback'),
      now: now,
    );
    wire = MockClient(_answer);
    active = SupabaseClient(
      origin,
      'public-target',
      httpClient: wire,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = SupabaseAuthRepository(
      active,
      callbackGuard: guard,
      authorityRead: () async => authority,
      providerSettingsGet: (_, {headers}) async =>
          http.Response('{"external":{}}', 200),
      federationFlow: flow,
    );
    dispatch = AuthCallbackDispatcher(
      guard,
      currentUser: () => active.auth.currentUser?.id,
    );
    unawaited(
      dispatch.attach((uri) {
        final done = flow(guard).complete(uri);
        completions.add(done);
        return done;
      }),
    );
  }

  final String origin;
  final secrets = MemorySecrets();
  late final AuthCallbackGuard guard;
  late final MockClient wire;
  late final SupabaseClient active;
  late final SupabaseAuthRepository repository;
  late final AuthCallbackDispatcher dispatch;

  /// Every system-browser launch, in order. The browser is the one fake.
  final launches = <Uri>[];
  bool browserOpens = true;
  final calls = <String>[];
  final completions = <Future<void>>[];

  /// What the target answers.
  Map<String, Object?>? authority = {
    'kind': 'oidc',
    'provider': 'custom:deskilo',
    'installation_id': fixtureInstallation,
    'issuer': fixtureIssuer,
  };
  String person = 'target-person';
  String advertisedIssuer = fixtureIssuer;
  Map<String, Object?> binding = {
    'status': 'verified',
    'installation_id': fixtureInstallation,
    'issuer': fixtureIssuer,
  };
  int tokenStatus = 200;

  NativeFederationFlow flow(AuthCallbackGuard guard) => NativeFederationFlow(
    active,
    guard,
    secrets,
    httpClient: wire,
    launch: (uri) async {
      launches.add(uri);
      return browserOpens;
    },
  );

  /// The browser coming back with [query] for the last launched flow.
  Uri returnFor(Map<String, String> query, {int launch = -1}) {
    final opened = launches[launch < 0 ? launches.length + launch : launch];
    final redirect = Uri.parse(opened.queryParameters['redirect_to']!);
    return redirect.replace(
      queryParameters: {...redirect.queryParameters, ...query},
    );
  }

  /// Hands [uri] to the app the way the OS does; true when it was owned.
  Future<bool> deliver(Uri uri) async {
    final before = completions.length;
    dispatch(uri);
    final owned = completions.length > before;
    await Future.wait(completions);
    return owned;
  }

  Future<http.Response> _answer(http.Request request) async {
    calls.add(request.url.path);
    http.Response reply(Object? value, [int status = 200]) => http.Response(
      jsonEncode(value),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    );
    switch (request.url.path) {
      case '/auth/v1/token':
        if (tokenStatus != 200) {
          return reply({'code': 'unexpected_failure'}, tokenStatus);
        }
        return reply(fixtureSession(person, origin));
      case '/auth/v1/user':
        return reply(fixtureUser(person));
      case '/rest/v1/rpc/public_identity_authority':
        return reply({...?authority, 'issuer': advertisedIssuer});
      case '/rest/v1/rpc/finalize_identity_binding':
        return reply(binding);
      case '/auth/v1/logout':
        return reply({});
      default:
        return reply({'code': 'not_found'}, 404);
    }
  }

  Future<void> dispose() => active.dispose();
}
