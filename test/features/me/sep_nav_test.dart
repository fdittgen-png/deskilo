// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2552 SEP-NAV — the personal home (P) and two workspace installations
// (W-A, W-B) holding a workspace with the SAME local id, each with its own
// account for the person. Going P → W-A → P → W-B keeps the personal
// session as it was: the same client, the same token, the same personal
// context and epoch; every workspace request goes to the installation the
// workspace was entered on, signed by that installation's own account, and
// no request to W ever carries P's token. A W-A sign-in that has ended
// refuses W-A only: P and W-B stay signed in and keep answering.
//
// Real clients over fake servers: what is asserted is what went over the
// wire. The physical three-stack proof is test/topology (CI only).
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/connected_space_providers.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fixed_business_inputs.dart';
import '../../helpers/installation_auth_storage.dart' show MemorySecrets;
import '../../helpers/native_federation_flow.dart' show session, user;

/// One installation: its own account, and every request it received.
class _Host {
  _Host(this.name, this.account);
  final String name;
  final String account;
  final requests = <({String path, String? bearer})>[];

  String get origin => 'https://$name.example';
  BackendEndpoint get endpoint =>
      BackendEndpoint(origin, 'sb_publishable_${name}_target');
  String get token => session(account)['access_token']! as String;

  Future<http.Response> handle(http.Request r) async {
    final auth = r.headers['Authorization'] ?? r.headers['authorization'];
    requests.add((
      path: r.url.path,
      bearer: auth?.startsWith('Bearer ') == true ? auth!.substring(7) : null,
    ));
    Object? body;
    switch (r.url.path) {
      case '/auth/v1/token':
        body = session(account);
      case '/auth/v1/user':
        body = user(account);
      case '/rest/v1/installation_identity':
        body = {'installation_id': 'inst-$name'};
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

  /// The bearer tokens of the data requests (not the sign-in itself).
  Set<String?> get dataBearers => {
    for (final r in requests)
      if (r.path.startsWith('/rest/')) r.bearer,
  };
}

class _Settings implements SettingsSource {
  @override
  Future<SettingsSet> load(String? workspaceId) async {
    final d = SettingDefinition(
      key: 'dunning.first_after_days',
      type: SettingType.integer,
      defaultValue: 14,
      group: 'dunning',
      scopes: {SettingScope.workspace},
    );
    return SettingsSet({d.key: d}, {d.key: 14});
  }

  @override
  Future<List<SettingVersion>> history(String? workspaceId, String key) async =>
      [];
}

/// No saved default: the entries alone select.
class _Ids extends ActiveWorkspaceId {
  @override
  Future<String?> build() async => null;
}

Workspace _space(String id, String name) => Workspace(
  id: id,
  name: name,
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

void main() {
  late _Host p, wa, wb;
  late SupabaseClient personal;
  late MemorySecrets secrets;
  late List<ConnectedInstallations> pools;

  _Host hostOf(http.Request r) =>
      [p, wa, wb].firstWhere((h) => h.name == r.url.host.split('.').first);

  http.Client wire({bool refreshEnded = false}) => MockClient((r) async {
    if (refreshEnded &&
        r.url.path == '/auth/v1/token' &&
        r.url.queryParameters['grant_type'] == 'refresh_token') {
      return http.Response(
        jsonEncode({'error': 'invalid_grant', 'error_description': 'x'}),
        400,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    }
    return hostOf(r).handle(r);
  });

  ProviderContainer containerWith(ConnectedInstallations pool) {
    final container = ProviderContainer(
      overrides: [
        ...fixedBusinessInputs(),
        sessionStateProvider.overrideWith((ref) => Stream.value(p.account)),
        authStateProvider.overrideWith((ref) => Stream.value(p.account)),
        bootedBackendUrlProvider.overrideWithValue(p.origin),
        contextClientsProvider.overrideWithValue(ContextClients(personal)),
        connectedInstallationsProvider.overrideWithValue(pool),
        installationIdReaderProvider.overrideWithValue((client) async {
          final origin = Uri.parse(client.rest.url).origin;
          return [p, wa, wb].firstWhere((h) => h.origin == origin).name;
        }),
        settingsSourceProvider.overrideWithValue(_Settings()),
        activeWorkspaceIdProvider.overrideWith(_Ids.new),
        // W-A and W-B both hold workspace ws-1.
        connectedWorkspaceReaderProvider.overrideWithValue((client) async {
          final origin = Uri.parse(client.rest.url).origin;
          return [_space('ws-1', origin == wa.origin ? 'At W-A' : 'At W-B')];
        }),
      ],
    );
    addTearDown(container.dispose);
    container
      ..listen(sessionStateProvider, (_, _) {})
      ..listen(authStateProvider, (_, _) {})
      ..listen(personalContextProvider, (_, _) {})
      ..listen(workspaceContextProvider, (_, _) {});
    return container;
  }

  setUp(() async {
    p = _Host('p', 'p-user');
    wa = _Host('wa', 'wa-user');
    wb = _Host('wb', 'wb-user');
    secrets = MemorySecrets();
    pools = [];
    personal = SupabaseClient(
      p.origin,
      'sb_publishable_p',
      httpClient: wire(),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await personal.auth.setInitialSession(jsonEncode(session(p.account)));
    final pool = ConnectedInstallations(personal, secrets, transport: wire);
    pools.add(pool);
    for (final h in [wa, wb]) {
      await pool.connect(h.endpoint, 'person@example.test', 'password');
    }
    addTearDown(() {
      for (final pool in pools) {
        pool.close();
      }
      unawaited(personal.dispose());
    });
  });

  /// P as it is now: the client, its token and the personal context.
  Future<(SupabaseClient, String?, Object?, int?)> personalState(
    ProviderContainer c,
  ) async {
    final context = await c.read(personalContextProvider.future);
    return (
      c.read(personalClientProvider),
      personal.auth.currentSession?.accessToken,
      context?.identity.subject,
      context?.personalEpoch,
    );
  }

  /// A personal read and a workspace read, as the screens make them.
  Future<void> readBoth(ProviderContainer c) async {
    await c.read(personalClientProvider).rpc<dynamic>('my_visibility');
    await c.read(selectedWorkspaceClientProvider).from('reservations').select();
  }

  test('SEP-NAV: P → W-A → P → W-B keeps the personal session; each '
      'workspace answers on its own installation and account', () async {
    final c = containerWith(pools.single);
    final before = await personalState(c);
    expect(before.$1, same(personal));
    expect(before.$2, p.token);
    expect(before.$3, p.account);

    // P → W-A.
    final a = await c
        .read(connectedSpaceEntryProvider.notifier)
        .enter(wa.origin, 'ws-1');
    expect(a?.name, 'At W-A');
    final atA = await c.read(workspaceContextProvider.future);
    expect(atA?.target.installationId, 'inst-wa');
    expect(atA?.target.workspaceId, 'ws-1');
    expect(atA?.workspaceLocalUserId, wa.account);
    await readBoth(c);
    expect(await personalState(c), before);

    // → P: the personal layer reads through P with P's own token.
    p.requests.clear();
    await c.read(personalClientProvider).rpc<dynamic>('my_visibility');
    expect(p.dataBearers, {p.token});
    expect(await personalState(c), before);

    // → W-B: the same local workspace id, another installation and account.
    final b = await c
        .read(connectedSpaceEntryProvider.notifier)
        .enter(wb.origin, 'ws-1');
    expect(b?.name, 'At W-B');
    final atB = await c.read(workspaceContextProvider.future);
    expect(atB?.target.installationId, 'inst-wb');
    expect(atB?.target.workspaceId, 'ws-1');
    expect(atB?.workspaceLocalUserId, wb.account);
    expect(atB?.identity, atA?.identity, reason: 'one person throughout');
    expect(atB?.personalEpoch, before.$4);
    await readBoth(c);

    expect(
      await personalState(c),
      before,
      reason: 'no new client, no new sign-in, the same personal epoch',
    );
    expect(p.dataBearers, {p.token});
    expect(wa.dataBearers, {wa.token});
    expect(wb.dataBearers, {wb.token});
    expect(
      p.requests.where((r) => r.path.contains('/reservations')),
      isEmpty,
      reason: 'the personal home never serves a workspace read',
    );
    expect(
      [...wa.requests, ...wb.requests].map((r) => r.bearer),
      isNot(contains(p.token)),
      reason: 'P\'s token never accompanies a W request',
    );
  });

  test('SEP-NAV: a W-A sign-in that ended refuses W-A only; P and W-B stay '
      'signed in and keep answering', () async {
    // W-A's stored session is long expired and W-A refuses its refresh.
    final key = secrets.values.keys.single;
    final records = jsonDecode(secrets.values[key]!) as Map<String, dynamic>;
    final saved = Map<String, Object?>.from(
      (records[wa.origin] as Map)['session'] as Map,
    );
    final jwt = base64Url.encode(
      utf8.encode(jsonEncode({'sub': wa.account, 'exp': 1000000000})),
    );
    (records[wa.origin] as Map<String, dynamic>)['session'] = {
      ...saved,
      'access_token': 'e30.$jwt.signature',
      'expires_at': 1000000000,
    };
    secrets.values[key] = jsonEncode(records);
    final pool = ConnectedInstallations(
      personal,
      secrets,
      transport: () => wire(refreshEnded: true),
    );
    pools.add(pool);
    final c = containerWith(pool);
    final before = await personalState(c);

    final entry = c.read(connectedSpaceEntryProvider.notifier);
    expect(await entry.enter(wb.origin, 'ws-1'), isNotNull);
    await expectLater(
      entry.enter(wa.origin, 'ws-1'),
      throwsA(
        isA<ConnectionFailure>().having(
          (f) => f.reason,
          'reason',
          ConnectionFailureReason.expired,
        ),
      ),
    );

    expect(
      c.read(selectedWorkspaceHostProvider)?.source,
      wb.origin,
      reason: 'W-B stays the selected workspace',
    );
    expect(
      (await c.read(workspaceContextProvider.future))?.target.installationId,
      'inst-wb',
    );
    wb.requests.clear();
    p.requests.clear();
    await readBoth(c);
    expect(wb.dataBearers, {wb.token}, reason: 'W-B still answers');
    expect(p.dataBearers, {p.token}, reason: 'P still answers');
    expect(await personalState(c), before, reason: 'P was not signed out');
    expect(await c.read(authStateProvider.future), p.account);
  });
}
