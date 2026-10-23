// SPDX-License-Identifier: AGPL-3.0-or-later
// #2562 -- entering a workspace of a connected installation: its workspaces
// are read through that installation's PINNED client, the selection then
// names workspace + source, and the app is root-free for it. Every refusal
// is the pool's typed ConnectionFailure and changes nothing.
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

class _Host {
  _Host(this.name, this.account);
  final String name;
  final String account;
  String get origin => 'https://$name.example';
  BackendEndpoint get endpoint =>
      BackendEndpoint(origin, 'sb_publishable_${name}_target');

  Future<http.Response> handle(http.Request r) async {
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

/// The saved-choice side is out of scope: no default, no store.
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
  late _Host root, one, two;
  late SupabaseClient rootClient;
  late MemorySecrets secrets;
  late ConnectedInstallations pool;
  late ProviderContainer container;
  late List<String> readOn;
  late Map<String, Future<void>> gate;

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
    readOn = [];
    gate = {};
    secrets = MemorySecrets();
    rootClient = SupabaseClient(
      root.origin,
      'sb_publishable_root',
      httpClient: wire(),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await rootClient.auth.setInitialSession(jsonEncode(session('p-user')));
    pool = ConnectedInstallations(rootClient, secrets, transport: wire);
    for (final h in [one, two]) {
      await pool.connect(h.endpoint, 'user@example.test', 'password');
    }
    container = ProviderContainer(
      overrides: [
        ...fixedBusinessInputs(), // #2561 L4
        sessionStateProvider.overrideWith((ref) => Stream.value('p-user')),
        authStateProvider.overrideWith((ref) => Stream.value('p-user')),
        bootedBackendUrlProvider.overrideWithValue(root.origin),
        contextClientsProvider.overrideWithValue(ContextClients(rootClient)),
        connectedInstallationsProvider.overrideWithValue(pool),
        installationIdReaderProvider.overrideWithValue(
          (client) async => 'inst-root',
        ),
        settingsSourceProvider.overrideWithValue(_Settings()),
        activeWorkspaceIdProvider.overrideWith(_Ids.new),
        // Both installations hold a workspace with the SAME local id.
        connectedWorkspaceReaderProvider.overrideWithValue((client) async {
          final origin = Uri.parse(client.rest.url).origin;
          readOn.add(origin);
          await gate[origin];
          final name = origin == one.origin ? 'Space of one' : 'Space of two';
          return [_space('ws-1', name)];
        }),
      ],
    );
    addTearDown(() {
      container.dispose();
      pool.close();
      unawaited(rootClient.dispose());
    });
    // The person is signed in before any space is opened.
    container
      ..listen(sessionStateProvider, (_, _) {})
      ..listen(authStateProvider, (_, _) {})
      ..listen(workspaceContextProvider, (_, _) {});
    await container.read(sessionStateProvider.future);
  });

  Future<Workspace?> enter(_Host host, [String id = 'ws-1']) => container
      .read(connectedSpaceEntryProvider.notifier)
      .enter(host.origin, id);

  Matcher refused(ConnectionFailureReason reason) => throwsA(
    isA<ConnectionFailure>().having((f) => f.reason, 'reason', reason),
  );

  test('success: read through the pinned client, then pinned and root-free',
      () async {
    final entered = await enter(one);
    expect(entered?.name, 'Space of one');
    expect(readOn, [one.origin], reason: 'read on the target, not the root');

    final host = container.read(selectedWorkspaceHostProvider);
    expect(host?.workspaceId, 'ws-1');
    expect(host?.source, one.origin);
    expect(container.read(activeWorkspaceIdProvider).value, 'ws-1');

    expect((await container.read(currentWorkspaceProvider.future))?.name,
        'Space of one');
    final context = await container.read(workspaceContextProvider.future);
    expect(context?.target.installationId, 'inst-one');
    final client = container.read(selectedWorkspaceClientProvider);
    expect(Uri.parse(client.rest.url).origin, one.origin);
    expect(identical(client, rootClient), isFalse);
  });

  test('equal local workspace ids on two hosts follow the host chosen',
      () async {
    await enter(one);
    expect((await container.read(currentWorkspaceProvider.future))?.name,
        'Space of one');
    await enter(two);
    expect(container.read(selectedWorkspaceHostProvider)?.source, two.origin);
    expect((await container.read(currentWorkspaceProvider.future))?.name,
        'Space of two');
    final context = await container.read(workspaceContextProvider.future);
    expect(context?.target.installationId, 'inst-two');
    expect(
      Uri.parse(container.read(selectedWorkspaceClientProvider).rest.url)
          .origin,
      two.origin,
    );
  });

  test('a late answer of installation A never selects over B', () async {
    final slow = Completer<void>();
    gate[one.origin] = slow.future;
    final a = enter(one);
    await Future<void>.delayed(Duration.zero);
    expect(await enter(two), isNotNull);
    slow.complete();
    expect(await a, isNull, reason: 'superseded: it selects nothing');
    expect(container.read(selectedWorkspaceHostProvider)?.source, two.origin);
  });

  test('not connected: typed refusal, nothing selected, no root read',
      () async {
    await expectLater(
      container
          .read(connectedSpaceEntryProvider.notifier)
          .enter('https://never.example', 'ws-1'),
      refused(ConnectionFailureReason.notConnected),
    );
    expect(container.read(selectedWorkspaceHostProvider), isNull);
    expect(readOn, isEmpty);
  });

  test('a workspace the installation does not show this account is denied',
      () async {
    await expectLater(
      enter(one, 'ws-9'),
      refused(ConnectionFailureReason.denied),
    );
    expect(container.read(selectedWorkspaceHostProvider), isNull);
  });

  test('replaced during the read: refused, nothing selected', () async {
    final slow = Completer<void>();
    gate[one.origin] = slow.future;
    final a = enter(one);
    await Future<void>.delayed(Duration.zero);
    await pool.connect(one.endpoint, 'user@example.test', 'password');
    slow.complete();
    await expectLater(a, refused(ConnectionFailureReason.cancelled));
    expect(container.read(selectedWorkspaceHostProvider), isNull);
  });

  test('disconnected during the read and before it: refused, nothing selected',
      () async {
    final slow = Completer<void>();
    gate[one.origin] = slow.future;
    final a = enter(one);
    await Future<void>.delayed(Duration.zero);
    await pool.disconnect(one.origin);
    slow.complete();
    await expectLater(a, refused(ConnectionFailureReason.cancelled));
    expect(container.read(selectedWorkspaceHostProvider), isNull);

    gate.clear();
    await expectLater(
      enter(one),
      refused(ConnectionFailureReason.notConnected),
    );
    expect(container.read(selectedWorkspaceHostProvider), isNull);
  });

  test('a sign-in the target ended: expired, nothing selected', () async {
    // The stored session is long expired and the target rejects the refresh.
    final key = secrets.values.keys.single;
    final records = jsonDecode(secrets.values[key]!) as Map<String, dynamic>;
    final saved = Map<String, Object?>.from(
      (records[one.origin] as Map)['session'] as Map,
    );
    final jwt = base64Url.encode(
      utf8.encode(jsonEncode({'sub': 'one-user', 'exp': 1000000000})),
    );
    (records[one.origin] as Map<String, dynamic>)['session'] = {
      ...saved,
      'access_token': 'e30.$jwt.signature',
      'expires_at': 1000000000,
    };
    secrets.values[key] = jsonEncode(records);
    final rejecting = ConnectedInstallations(
      rootClient,
      secrets,
      transport: () => MockClient((r) async {
        if (r.url.path == '/auth/v1/token' &&
            r.url.queryParameters['grant_type'] == 'refresh_token') {
          return http.Response(
            jsonEncode({'error': 'invalid_grant', 'error_description': 'x'}),
            400,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }
        final host = [
          root,
          one,
          two,
        ].firstWhere((h) => h.name == r.url.host.split('.').first);
        return host.handle(r);
      }),
    );
    addTearDown(rejecting.close);
    final local = ProviderContainer(
      overrides: [
        ...fixedBusinessInputs(), // #2561 L4
        sessionStateProvider.overrideWith((ref) => Stream.value('p-user')),
        connectedInstallationsProvider.overrideWithValue(rejecting),
        connectedWorkspaceReaderProvider.overrideWithValue((_) async {
          readOn.add('read');
          return [_space('ws-1', 'x')];
        }),
        activeWorkspaceIdProvider.overrideWith(_Ids.new),
      ],
    );
    addTearDown(local.dispose);
    await expectLater(
      local
          .read(connectedSpaceEntryProvider.notifier)
          .enter(one.origin, 'ws-1'),
      refused(ConnectionFailureReason.expired),
    );
    expect(local.read(selectedWorkspaceHostProvider), isNull);
    expect(readOn, isEmpty);
  });

  test('choosing a space of this installation drops the connected selection',
      () async {
    await enter(one);
    container.read(activeWorkspaceIdProvider.notifier).activate('ws-1');
    expect(container.read(selectedWorkspaceHostProvider), isNull);
  });
}
