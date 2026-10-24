// SPDX-License-Identifier: AGPL-3.0-or-later
//
// DISC-01 (#2555): a public discovery request carries no account token.
//
// Invariants:
// - Signed in at the personal home P, and connected to the workspace host
//   W-A with a live session there, every request the public directory path
//   makes -- the personal-home declaration, the source list, each source's
//   cards, a card's live detail -- carries only the publishable key of the
//   origin it goes to: neither the P session nor the W-A session appears in
//   any header or URL.
// - A source that answers with a redirect is not followed: no request
//   leaves for the redirect's origin, the source reads as unavailable, and
//   every other source is still listed.
// - Signed out and signed in, the public path sends the same requests with
//   the same credentials: one public boundary, not two.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/features/directory/providers/directory_providers.dart';
import 'package:deskilo/features/directory/providers/discovery_listing_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/installation_auth_storage.dart' show MemorySecrets;
import '../../helpers/native_federation_flow.dart' show session, user;

const _p = BackendEndpoint('https://p.example', 'sb_publishable_p_key_0001');
const _wa = BackendEndpoint('https://wa.example', 'sb_publishable_wa_key_001');
const _wb = BackendEndpoint('https://wb.example', 'sb_publishable_wb_key_001');
const _elsewhere = 'https://elsewhere.example';
const _idA = '00000000-0000-4000-8000-00000000a001';
const _idB = '00000000-0000-4000-8000-00000000b001';

final _keys = {_p.url: _p.key, _wa.url: _wa.key, _wb.url: _wb.key};

/// The P and W-A sessions: neither may reach a public request.
final _pToken = session('p-user')['access_token']! as String;
final _waToken = session('wa-user')['access_token']! as String;

/// P, W-A and W-B behind one wire that records every request and, like a
/// platform client, follows a redirect with the same headers unless the
/// request says not to.
class _Network extends http.BaseClient {
  final seen = <http.BaseRequest>[];

  /// W-B answers its cards with a redirect to [_elsewhere].
  bool redirectWb = false;

  Map<String, Object?> _card(String id, String name) => {
    'workspace_id': id,
    'name': name,
    'updated_at': '2026-10-01T09:30:00+00:00',
    'document': {'name': name, 'host_type': 'company'},
  };

  http.Response _json(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  http.Response _answer(Uri url) {
    final origin = url.origin;
    switch (url.path) {
      case '/auth/v1/token':
        return _json(session('wa-user'));
      case '/auth/v1/user':
        return _json(user('wa-user'));
      case '/rest/v1/rpc/public_network_descriptor':
        return _json({'code': 'PGRST202', 'message': 'not found'}, 404);
      case '/rest/v1/installation_identity':
        return _json(
          origin == _p.url
              ? {
                  'roles': ['personal_home'],
                  'personal_home_kind': 'self',
                }
              : {'installation_id': 'inst-$origin'},
        );
      case '/rest/v1/public_directory_sources' when origin == _p.url:
        return _json([
          {'origin': _wa.url, 'publishable_key': _wa.key},
          {'origin': _wb.url, 'publishable_key': _wb.key},
        ]);
      case '/rest/v1/public_workspace_cards':
        if (origin == _wb.url && redirectWb) {
          return http.Response(
            '',
            302,
            headers: {
              'location':
                  '$_elsewhere/rest/v1/public_workspace_cards?${url.query}',
            },
          );
        }
        final id = url.queryParameters['workspace_id'];
        return _json([
          for (final c in switch (origin) {
            'https://wa.example' => [_card(_idA, 'Atelier A')],
            'https://wb.example' => [_card(_idB, 'Bureau B')],
            _elsewhere => [_card(_idB, 'Hijacked')],
            // P is a personal home: it publishes no workspace.
            _ => <Map<String, Object?>>[],
          })
            if (id == null || id == 'eq.${c['workspace_id']}') c,
        ]);
    }
    return _json({'message': 'not found'}, 404);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    seen.add(request);
    final answer = _answer(request.url);
    final location = answer.headers['location'];
    if (location != null && request.followRedirects) {
      final next = http.Request(request.method, Uri.parse(location))
        ..headers.addAll(request.headers);
      return send(next);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(answer.body)),
      answer.statusCode,
      headers: answer.headers,
      request: request,
    );
  }

  http.Client transport() => this;

  /// What a public request carried, by origin and path.
  List<String> carried() => [
    for (final r in seen)
      '${r.method} ${r.url} apikey=${r.headers['apikey']} '
          'authorization=${r.headers['Authorization'] ?? r.headers['authorization']}',
  ];
}

/// A container wired as production wires discovery, with [personal] as the
/// P client and, when given, [pool] as the connected installations.
ProviderContainer _container(
  _Network network,
  SupabaseClient personal, {
  ConnectedInstallations? pool,
}) {
  final c = ProviderContainer(
    overrides: [
      personalClientProvider.overrideWithValue(personal),
      publicTransportProvider.overrideWithValue(network.transport),
      if (pool != null) connectedInstallationsProvider.overrideWithValue(pool),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

SupabaseClient _pClient(_Network network) => SupabaseClient(
  _p.url,
  _p.key,
  httpClient: network,
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

/// Searches, then reads the first card's live detail: the whole public path.
Future<List<String>> _discover(ProviderContainer c) async {
  final listing = discoveryListingProvider('');
  final sub = c.listen(listing, (_, _) {});
  addTearDown(sub.close);
  final results = await c.read(listing.future);
  final first = results.workspaces.first;
  final detail = publicWorkspaceDetailProvider(
    first.source,
    first.key,
    first.id,
  );
  final held = c.listen(detail, (_, _) {});
  addTearDown(held.close);
  expect((await c.read(detail.future))?.name, first.name);
  return [
    for (final w in results.workspaces) '${w.source}/${w.name}',
    for (final o in results.unavailable) 'unavailable:$o',
  ];
}

/// Signed in at P and connected to W-A, with every set-up request
/// forgotten: what [seen] holds afterwards is the public path alone.
Future<ProviderContainer> _signedIn(_Network network) async {
  final personal = _pClient(network);
  await personal.auth.setInitialSession(jsonEncode(session('p-user')));
  expect(personal.auth.currentSession?.accessToken, _pToken);
  final pool = ConnectedInstallations(
    personal,
    MemorySecrets(),
    transport: network.transport,
  );
  addTearDown(pool.close);
  await pool.connect(_wa, 'user@example.test', 'password');
  expect(
    await pool.use(_wa.url, (c) async => c.auth.currentSession?.accessToken),
    _waToken,
    reason: 'the W-A session is live: a real sentinel',
  );
  network.seen.clear();
  return _container(network, personal, pool: pool);
}

void main() {
  test('DISC-01: signed in at P and at W-A, every public discovery request '
      'carries only its own origin\'s publishable key', () async {
    final network = _Network();
    final c = await _signedIn(network);
    expect(await _discover(c), ['${_wa.url}/Atelier A', '${_wb.url}/Bureau B']);

    expect(network.seen, isNotEmpty);
    expect(
      network.seen.map((r) => r.url.path).toSet(),
      containsAll([
        '/rest/v1/installation_identity',
        '/rest/v1/public_directory_sources',
        '/rest/v1/public_workspace_cards',
      ]),
    );
    for (final r in network.seen) {
      final sent = '${r.url} ${r.headers.values.join(' ')}';
      expect(sent, isNot(contains(_pToken)), reason: 'P session to ${r.url}');
      expect(
        sent,
        isNot(contains(_waToken)),
        reason: 'W-A session to ${r.url}',
      );
      final key = _keys[r.url.origin];
      expect(r.headers['apikey'], key, reason: '${r.url}');
      expect(
        r.headers['Authorization'] ?? r.headers['authorization'],
        'Bearer $key',
        reason: 'a public read carries its publishable key alone: ${r.url}',
      );
    }
  });

  test('DISC-01: a source that redirects is not followed; it reads as '
      'unavailable and the other sources are still listed', () async {
    final network = _Network()..redirectWb = true;
    final c = await _signedIn(network);
    expect(await _discover(c), [
      '${_wa.url}/Atelier A',
      'unavailable:${_wb.url}',
    ]);
    expect(
      network.seen.where((r) => r.url.origin == _elsewhere),
      isEmpty,
      reason: 'nothing, not even the publishable key, follows the redirect',
    );
    for (final r in network.seen) {
      expect(r.followRedirects, isFalse, reason: '${r.url}');
      final sent = '${r.url} ${r.headers.values.join(' ')}';
      expect(sent, isNot(contains(_pToken)));
      expect(sent, isNot(contains(_waToken)));
    }
  });

  test('DISC-01: signed out and signed in, the public path sends the same '
      'requests with the same credentials', () async {
    final anonymous = _Network();
    await _discover(_container(anonymous, _pClient(anonymous)));

    final signedIn = _Network();
    await _discover(await _signedIn(signedIn));

    expect(signedIn.carried(), anonymous.carried());
  });
}
