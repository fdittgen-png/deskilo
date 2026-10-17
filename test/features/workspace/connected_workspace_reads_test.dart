// SPDX-License-Identifier: AGPL-3.0-or-later
// #2564 O1 -- the reads and operations of a CONNECTED workspace (the
// workspace repository's operations half, floor plan, accessories, calendar)
// run on that installation's pinned client: success reaches its host only,
// the list half stays on the root session, a ended lease is the typed
// ConnectionFailure (never the root), and a new connection recovers.
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
import 'package:deskilo/features/calendar/providers/calendar_providers.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/plan/providers/accessory_providers.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/profile/providers/profile_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/connected_space_providers.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_fields_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/installation_auth_storage.dart' show MemorySecrets;
import '../../helpers/native_federation_flow.dart' show session, user;

class _Host {
  _Host(this.name, this.account);
  final String name;
  final String account;
  String get origin => 'https://$name.example';
  BackendEndpoint get endpoint =>
      BackendEndpoint(origin, 'sb_publishable_${name}_target');

  final paths = <String>[];

  /// What reached this host after the connection was set up.
  List<String> get data =>
      paths.where((p) => p.startsWith('/rest/v1/')).toList();

  Future<http.Response> handle(http.Request r) async {
    paths.add(r.url.path);
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
  late ConnectedInstallations pool;
  late ProviderContainer container;

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
        activeWorkspaceIdProvider.overrideWith(_Ids.new),
        // Both installations hold a workspace with the SAME local id.
        connectedWorkspaceReaderProvider.overrideWithValue((client) async {
          final origin = Uri.parse(client.rest.url).origin;
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
    container
      ..listen(sessionStateProvider, (_, _) {})
      ..listen(authStateProvider, (_, _) {})
      ..listen(workspaceContextProvider, (_, _) {}, onError: (_, _) {});
    await container.read(sessionStateProvider.future);
  });

  Future<Workspace?> enter(_Host host) => container
      .read(connectedSpaceEntryProvider.notifier)
      .enter(host.origin, 'ws-1');

  /// One read through each migrated factory; a payload the empty fake host
  /// cannot parse is not what these tests are about, a refusal is.
  Future<void> touch() async {
    final reads = <Future<Object?> Function()>[
      () => container.read(workspaceRepositoryProvider).fetchSites('ws-1'),
      () => container.read(workspaceRepositoryProvider).fetchMembers('ws-1'),
      () => container.read(floorPlanRepositoryProvider).fetchLevels('ws-1'),
      () => container.read(accessoryRepositoryProvider).fetchAccessories('ws-1'),
      () => container.read(calendarRepositoryProvider).whoCanAccessMe('ws-1'),
      // #2564: the members' rows and the workspace feeds follow the host.
      () => container
          .read(memberProfileRepositoryProvider)
          .fetchProfiles('ws-1', ['u-1']),
      // #2564: the notices, rights and erasure preview of a space are its
      // host's.
      () => container
          .read(memberProfileRepositoryProvider)
          .fetchPrivacyNotices('ws-1'),
      () => container
          .read(memberProfileRepositoryProvider)
          .previewMyErasure('ws-1'),
      () => container.read(eventRepositoryProvider).fetchEvents('ws-1'),
      () => container.read(workspaceFieldsRepositoryProvider).fetchFields('ws-1'),
    ];
    for (final read in reads) {
      try {
        await read();
      } on ProviderException catch (e) {
        // A provider in error state wraps what its source threw.
        var cause = e.exception;
        while (cause is ProviderException) {
          cause = cause.exception;
        }
        if (cause is ConnectionFailure) throw cause;
      } on ConnectionFailure {
        rethrow;
      } on Object {
        // answered, but not with a shape the empty fake parses
      }
    }
  }

  void forget() {
    for (final h in [root, one, two]) {
      h.paths.clear();
    }
  }

  test('success: the connected workspace is read and operated on its host only',
      () async {
    await enter(one);
    await container.read(workspaceContextProvider.future);
    forget();
    await touch();
    expect(one.data, isNotEmpty);
    expect(root.data, isEmpty, reason: 'the root never serves workspace rows');
    expect(two.data, isEmpty);
  });

  test('the list half stays on the root session, whatever is selected',
      () async {
    await enter(one);
    await container.read(workspaceContextProvider.future);
    forget();
    try {
      await container.read(workspaceListRepositoryProvider).fetchMyWorkspaces();
    } on Object {
      // the empty fake host answers; the shape is not the point
    }
    expect(root.data, isNotEmpty);
    expect(one.data, isEmpty);
    expect(two.data, isEmpty);
  });

  test('my own profile row stays on the root session, whatever is selected',
      () async {
    await enter(one);
    await container.read(workspaceContextProvider.future);
    forget();
    try {
      await container.read(profileRepositoryProvider).fetchMyProfile();
    } on Object {
      // the empty fake host answers; the shape is not the point
    }
    expect(root.data, isNotEmpty);
    expect(one.data, isEmpty);
    expect(two.data, isEmpty);
  });

  test('the privacy notice of the entered space is read on its host; my rights '
      'requests across spaces stay on the root', () async {
    await enter(one);
    await container.read(workspaceContextProvider.future);
    forget();
    try {
      await container.read(privacyNoticesProvider.future);
    } on Object {
      // the empty fake host answers; the shape is not the point
    }
    expect(one.paths, contains('/rest/v1/rpc/current_privacy_notice'));
    expect(root.paths, isNot(contains('/rest/v1/rpc/current_privacy_notice')));
    expect(two.data, isEmpty);

    forget();
    try {
      await container.read(profileRepositoryProvider).fetchMyRightsRequests();
    } on Object {
      // the empty fake host answers; the shape is not the point
    }
    expect(root.paths, contains('/rest/v1/rpc/my_rights_requests'));
    expect(one.data, isEmpty);
    expect(two.data, isEmpty);
  });

  test('equal local ids: a switch from host one to host two follows the host',
      () async {
    await enter(one);
    await enter(two);
    await container.read(workspaceContextProvider.future);
    forget();
    await touch();
    expect(two.data, isNotEmpty);
    expect(one.data, isEmpty);
    expect(root.data, isEmpty);
  });

  test('the lease ends: a typed ConnectionFailure, never the root; a new '
      'connection recovers', () async {
    await enter(one);
    await container.read(workspaceContextProvider.future);
    await pool.disconnect(one.origin);
    // The context re-resolves and refuses with the pool's typed reason.
    await expectLater(
      container.read(workspaceContextProvider.future),
      throwsA(isA<ConnectionFailure>()),
    );
    forget();
    await expectLater(touch(), throwsA(isA<ConnectionFailure>()));
    expect(root.data, isEmpty);
    expect(two.data, isEmpty);
    expect(one.data, isEmpty);

    // Connected again and entered again: the host answers once more.
    await pool.connect(one.endpoint, 'user@example.test', 'password');
    await enter(one);
    await container.read(workspaceContextProvider.future);
    forget();
    await touch();
    expect(one.data, isNotEmpty);
    expect(root.data, isEmpty);
  });
}
