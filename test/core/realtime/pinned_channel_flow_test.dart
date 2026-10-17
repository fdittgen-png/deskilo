// SPDX-License-Identifier: AGPL-3.0-or-later
// #2562 -- the selected workspace's realtime channel runs on the PINNED client
// of its connected installation: the channel follows the installation (even
// under the same local workspace id), a late event of installation A never
// refreshes B, and when the connection ends the channel is torn down and the
// root client does not take over.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/realtime/invalidation_map.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/core/realtime/realtime_wiring.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/installation_auth_storage.dart' show MemorySecrets;
import '../../helpers/native_federation_flow.dart' show session, user;
import '../../helpers/real_async.dart' show untilReal;

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

/// A change feed per client origin: which client a channel runs on is what
/// the tests pin.
class _Sync implements RealtimeSync {
  _Sync(this.origin, this.opened);
  final String origin;
  final List<_Sync> opened;
  final channels = <String, StreamController<String>>{};

  @override
  Stream<String> watch(String workspaceId) {
    opened.add(this);
    return (channels[workspaceId] = StreamController<String>()).stream;
  }

  @override
  Stream<String> watchAccount() => const Stream.empty();
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

var _probeBuilds = 0;
final _probe = Provider<int>((ref) => ++_probeBuilds);

const _workspace = Workspace(
  id: 'ws-1',
  name: 'ws-1',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Host root, one, two;
  late SupabaseClient rootClient;
  late ConnectedInstallations pool;
  late ProviderContainer container;
  late List<_Sync> opened;
  late Map<String, _Sync> byOrigin;

  http.Client wire() => MockClient((r) {
    final host = [
      root,
      one,
      two,
    ].firstWhere((h) => h.name == r.url.host.split('.').first);
    return host.handle(r);
  });

  setUp(() async {
    _probeBuilds = 0;
    root = _Host('root', 'p-user');
    one = _Host('one', 'one-user');
    two = _Host('two', 'two-user');
    opened = [];
    byOrigin = {};
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
    container = ProviderContainer(
      overrides: [
        sessionStateProvider.overrideWith((ref) => Stream.value('p-user')),
        authStateProvider.overrideWith((ref) => Stream.value('p-user')),
        bootedBackendUrlProvider.overrideWithValue(root.origin),
        contextClientsProvider.overrideWithValue(ContextClients(rootClient)),
        connectedInstallationsProvider.overrideWithValue(pool),
        installationIdReaderProvider.overrideWithValue(
          (client) async => 'inst-root',
        ),
        settingsSourceProvider.overrideWithValue(_Settings()),
        currentWorkspaceProvider.overrideWith((ref) async => _workspace),
        cacheStoreProvider.overrideWithValue(InMemoryCacheStore()),
        realtimeWorkspaceClientProvider.overrideWith(
          (ref) => ref.watch(selectedWorkspaceClientProvider),
        ),
        realtimeWorkspaceIdProvider.overrideWith(
          (ref) async => (await ref.watch(currentWorkspaceProvider.future))?.id,
        ),
        realtimeSyncProvider.overrideWith((ref) {
          final client = ref.watch(realtimeWorkspaceClientProvider);
          final origin = Uri.parse(client.rest.url).origin;
          return byOrigin[origin] ??= _Sync(origin, opened);
        }),
        invalidationLookupProvider.overrideWithValue(
          (table, {scopes}) => table == 't'
              ? TableInvalidation([_probe])
              : TableInvalidation([]),
        ),
      ],
    )..listen(workspaceContextProvider, (_, _) {});
    addTearDown(() {
      container.dispose();
      pool.close();
      unawaited(rootClient.dispose());
    });
  });

  Future<void> select(_Host host) async {
    container
        .read(selectedWorkspaceHostProvider.notifier)
        .select('ws-1', host.origin);
    await container.read(workspaceContextProvider.future);
    await container.read(
      realtimeInvalidatorProvider(RealtimeTarget.workspace).future,
    );
    await untilReal(
      () => byOrigin[host.origin]?.channels['ws-1']?.hasListener ?? false,
      what: '${host.name} channel',
    );
  }

  /// Waits until the probe was rebuilt [builds] times in total.
  Future<void> settle(int builds) => untilReal(() {
    container.read(_probe);
    return _probeBuilds == builds;
  }, what: 'the probe rebuilt $builds times');

  void arm() {
    container
      ..listen(realtimeInvalidatorProvider(RealtimeTarget.workspace), (_, _) {})
      ..read(_probe);
  }

  test(
    'the channel runs on the installation of the selected workspace',
    () async {
      await select(one);
      arm();
      expect(opened.map((s) => s.origin), [one.origin]);
      byOrigin[one.origin]!.channels['ws-1']!.add('t');
      await settle(2);
    },
  );

  test('the same local workspace id on another installation moves the channel; '
      "a late event of A never reaches B's providers", () async {
    await select(one);
    arm();
    final a = byOrigin[one.origin]!.channels['ws-1']!;

    await select(two);
    expect(opened.map((s) => s.origin), [one.origin, two.origin]);
    expect(a.hasListener, isFalse, reason: "A's channel is torn down");

    // A's late event goes nowhere; B's own event is the only one applied
    // (exactly one rebuild in total).
    a.add('t');
    byOrigin[two.origin]!.channels['ws-1']!.add('t');
    await settle(2);
    expect(_probeBuilds, 2, reason: "A's late event never reached B");
  });

  test('a disconnect tears the channel down and the root client does not take over', () async {
    await select(one);
    arm();
    final a = byOrigin[one.origin]!.channels['ws-1']!;

    await pool.disconnect(one.origin);
    await untilReal(
      () => !a.hasListener,
      what: 'the dead target channel closed',
    );

    expect(a.hasListener, isFalse, reason: 'the dead target has no channel');
    expect(
      () => container.read(selectedWorkspaceClientProvider),
      throwsA(isA<Object>()),
      reason: 'refused, not answered by the root client',
    );
    expect(
      byOrigin.containsKey(root.origin),
      isFalse,
      reason: 'no channel was ever opened on the root client',
    );

    // Recovery: connected again, selected again, the channel is back on
    // the target's own new client.
    await pool.connect(one.endpoint, 'user@example.test', 'password');
    container.invalidate(workspaceContextProvider);
    await container.read(workspaceContextProvider.future);
    await container.read(
      realtimeInvalidatorProvider(RealtimeTarget.workspace).future,
    );
    await untilReal(
      () => byOrigin[one.origin]!.channels['ws-1']!.hasListener,
      what: 'the channel back on the target',
    );
    byOrigin[one.origin]!.channels['ws-1']!.add('t');
    await settle(2);
    expect(byOrigin.containsKey(root.origin), isFalse);
  });
}
