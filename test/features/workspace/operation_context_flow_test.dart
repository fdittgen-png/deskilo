// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 C1 -- the first usable P/W flow through independently supplied
// clients: the own-profile read and write reach P only, an existing
// reservation read reaches the verified W host of the selected workspace
// only, and selecting another workspace leaves the personal context alone.
// Three real SupabaseClients over three recording fake servers; the signed-in
// identities are independent plumbing seeds, NOT the single-registration
// proof (#2562) and NOT the physical three-stack proof (C2).
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/backend/auth_secret_store.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/me/providers/me_providers.dart';
import 'package:deskilo/features/reservations/data/context_reservation_repository.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One fake installation: records what reached it, can hold its reservation
/// answer back, can be taken down.
class _Host {
  _Host(this.origin, this.installationId, this.reservationId);

  final String origin;
  final String installationId;
  final String reservationId;
  final paths = <String>[];
  Completer<void>? gate;
  bool down = false;

  late final SupabaseClient client = SupabaseClient(
    origin,
    'sb_publishable_test',
    httpClient: MockClient(_handle),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  http.Response _json(http.Request request, Object? body, {Map<String, String>? extra}) =>
      http.Response(
        jsonEncode(body),
        200,
        request: request,
        headers: {'content-type': 'application/json', ...?extra},
      );

  Future<http.Response> _handle(http.Request request) async {
    if (down) throw http.ClientException('host down');
    paths.add('${request.method} ${request.url.path}');
    switch (request.url.path) {
      case '/rest/v1/reservations':
        await gate?.future;
        final isCount = (request.headers['prefer'] ?? '').contains('count=exact');
        final offset = int.tryParse(request.url.queryParameters['offset'] ?? '') ?? 0;
        final rows = offset > 0 ? <Object>[] : [
          {
            'id': reservationId,
            'workspace_id': 'ws-1',
            'member_id': 'm-1',
            'starts_at': '2026-10-16T08:00:00Z',
            'ends_at': '2026-10-16T09:00:00Z',
            'status': 'reserved',
            'seat_id': 's-1',
          },
        ];
        final body = isCount
            ? [
                {'id': reservationId},
              ]
            : rows;
        return _json(request, body, extra: {'content-range': '0-0/1'});
      default:
        return _json(request, null);
    }
  }
}

Workspace _ws(String id, String timezone) => Workspace(
      id: id,
      name: id,
      countryCode: 'FR',
      currencyCode: 'EUR',
      timezone: timezone,
      inviteCode: 'x',
    );

class _Settings implements SettingsSource {
  int days = 14;
  @override
  Future<SettingsSet> load(String? workspaceId) async {
    final d = SettingDefinition(
      key: 'dunning.first_after_days',
      type: SettingType.integer,
      defaultValue: 14,
      group: 'dunning',
      scopes: {SettingScope.workspace},
    );
    return SettingsSet({d.key: d}, {d.key: days});
  }

  @override
  Future<List<SettingVersion>> history(String? workspaceId, String key) async => [];
}

class _Resolver implements WorkspaceHostResolver {
  _Resolver(this.host);
  _Host host;

  @override
  Future<ResolvedWorkspaceHost> resolve(String workspaceId) async =>
      ResolvedWorkspaceHost(
        installationId: host.installationId,
        client: host.client,
        localUserId: 'local-${host.installationId}',
      );
}

class _Rig {
  _Rig() {
    resolver = _Resolver(a);
  }

  final p = _Host('https://p.example', 'inst-p', 'unused');
  final a = _Host('https://wa.example', 'inst-a', 'res-from-a');
  final b = _Host('https://wb.example', 'inst-b', 'res-from-b');
  final settings = _Settings();
  late final _Resolver resolver;
  final cache = InMemoryCacheStore();
  Workspace current = _ws('ws-1', 'Europe/Paris');

  late final ProviderContainer container = ProviderContainer(overrides: [
    sessionStateProvider.overrideWith((ref) => Stream.value('p-1')),
    authStateProvider.overrideWith((ref) => Stream.value('p-1')),
    bootedBackendUrlProvider.overrideWithValue('https://p.example'),
    contextClientsProvider.overrideWithValue(ContextClients(p.client)),
    connectedInstallationsProvider.overrideWithValue(
      ConnectedInstallations(p.client, const PlatformAuthSecretStore()),
    ),
    installationIdReaderProvider.overrideWithValue((client) async {
      final origin = Uri.parse(client.rest.url).origin;
      return [p, a, b].firstWhere((h) => h.origin == origin).installationId;
    }),
    workspaceHostResolverProvider.overrideWithValue(resolver),
    settingsSourceProvider.overrideWithValue(settings),
    currentWorkspaceProvider.overrideWith((ref) async => current),
    cacheStoreProvider.overrideWithValue(cache),
  ]);

  /// Select [workspace] hosted on [host].
  void select(Workspace workspace, _Host host) {
    current = workspace;
    resolver.host = host;
    container
      ..invalidate(currentWorkspaceProvider)
      ..invalidate(currentSettingsCaptureProvider)
      ..invalidate(workspaceContextProvider);
  }
}

const _limit = Timeout(Duration(seconds: 30));

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  /// Pumps until [future] completes; its value or its error.
  Future<({T? value, Object? error})> outcome<T>(
      WidgetTester tester, Future<T> future, [String label = '']) async {
    T? value;
    Object? error;
    var done = false;
    unawaited(future.then((v) {
      value = v;
      done = true;
    }, onError: (Object e) {
      error = e;
      done = true;
    }));
    for (var i = 0; i < 1000 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(done, isTrue, reason: 'the future never completed: $label');
    return (value: value, error: error);
  }

  Future<T> settle<T>(WidgetTester tester, Future<T> future, [String label = '']) async {
    final result = await outcome(tester, future, label);
    expect(result.error, isNull);
    return result.value as T;
  }

  /// Ends the test cleanly: no provider retry or client timer outlives it.
  Future<void> finish(WidgetTester tester) async {
    rig.container.dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('own-profile read and write reach P and no workspace host', timeout: _limit, (tester) async {
    final sub = rig.container.listen(authStateProvider, (_, _) {});
    addTearDown(sub.close);
    await tester.pump();
    await settle(tester, rig.container.read(myVisibilityProvider.future));
    await settle(tester, rig.container.read(meActionsProvider).saveAbout('Maker', 'Hello'));
    expect(rig.p.paths, contains('POST /rest/v1/rpc/my_visibility'));
    expect(rig.p.paths, contains('POST /rest/v1/rpc/set_my_about'));
    expect(rig.a.paths, isEmpty);
    expect(rig.b.paths, isEmpty);
    await finish(tester);
  });

  testWidgets('a reservation read reaches the verified host of the selected workspace only', timeout: _limit, (tester) async {
    final sub = rig.container.listen(workspaceContextProvider, (_, _) {});
    addTearDown(sub.close);
    final repo = rig.container.read(reservationRepositoryProvider);
    final from = DateTime.utc(2026, 10, 16);
    final rows = await settle(
        tester, repo.fetchWindow('ws-1', from: from, to: from.add(const Duration(days: 1))));
    expect(rows.single.id, 'res-from-a');
    expect(rig.a.paths.where((p) => p.contains('/reservations')), isNotEmpty);
    expect(rig.b.paths, isEmpty);
    expect(rig.p.paths.where((p) => p.contains('/reservations')), isEmpty,
        reason: 'the personal home never serves workspace rows');
    await finish(tester);
  });

  testWidgets('selecting W-B (equal local workspace id) leaves the personal context alone', timeout: _limit, (tester) async {
    final sub = rig.container.listen(workspaceContextProvider, (_, _) {});
    addTearDown(sub.close);
    final psub = rig.container.listen(personalContextProvider, (_, _) {});
    addTearDown(psub.close);

    final personalBefore = await settle(tester, rig.container.read(personalContextProvider.future));
    final contextA = await settle(tester, rig.container.read(workspaceContextProvider.future));

    rig.settings.days = 30;
    rig.select(_ws('ws-1', 'America/New_York'), rig.b);
    final contextB = await settle(tester, rig.container.read(workspaceContextProvider.future));
    final personalAfter = await settle(tester, rig.container.read(personalContextProvider.future));

    // The same local id on two hosts: two targets, two accounts, two zones.
    expect(contextA!.target.workspaceId, contextB!.target.workspaceId);
    expect(contextA.target, isNot(contextB.target));
    expect(contextA.workspaceLocalUserId, isNot(contextB.workspaceLocalUserId));
    expect([contextA.timezone, contextB.timezone], ['Europe/Paris', 'America/New_York']);
    expect(contextA.settings.settings.read<int>('dunning.first_after_days'), 14);
    expect(contextB.settings.settings.read<int>('dunning.first_after_days'), 30);
    expect(contextA.sameOperationAs(contextB), isFalse);

    // P: identity, home, epoch and client are untouched by the selection.
    expect(personalAfter, personalBefore);
    expect(personalAfter!.personalEpoch, personalBefore!.personalEpoch);
    expect(personalAfter.homeInstallationId, 'inst-p');
    expect(contextB.personalEpoch, contextA.personalEpoch);
    expect(rig.container.read(personalClientProvider), same(rig.p.client));

    // Each target's client is the verified one.
    expect(rig.container.read(workspaceClientProvider('inst-a')), same(rig.a.client));
    expect(rig.container.read(workspaceClientProvider('inst-b')), same(rig.b.client));
    expect(() => rig.container.read(contextClientsProvider).workspace('inst-unknown'),
        throwsA(isA<UnverifiedInstallation>()));
    await finish(tester);
  });

  testWidgets('a late W-A answer cannot reach or populate W-B', timeout: _limit, (tester) async {
    final sub = rig.container.listen(workspaceContextProvider, (_, _) {});
    addTearDown(sub.close);
    final from = DateTime.utc(2026, 10, 16);
    final to = from.add(const Duration(days: 1));
    final repo = rig.container.read(reservationRepositoryProvider);
    await settle(tester, rig.container.read(workspaceContextProvider.future), 'context A');

    rig.a.gate = Completer<void>();
    final late = repo.fetchWindow('ws-1', from: from, to: to);
    unawaited(late.then<void>((_) {}, onError: (Object _) {}));
    await tester.pump(const Duration(milliseconds: 50));

    // The member switches to W-B (same local id) and W-B then goes down.
    rig.select(_ws('ws-1', 'America/New_York'), rig.b);
    await settle(tester, rig.container.read(workspaceContextProvider.future), 'context B');
    rig.b.down = true;
    rig.a.gate!.complete();
    final lateRows = await settle(tester, late, 'late A read');
    expect(lateRows.single.id, 'res-from-a', reason: 'A answers A, from its own context');

    // W-B is down: nothing of W-A's, cached or late, answers for it.
    final refused = await outcome(
      tester,
      rig.container.read(reservationRepositoryProvider).fetchWindow('ws-1', from: from, to: to),
      'B read',
    );
    expect(refused.error, isNotNull);
    expect(refused.value, isNull);
    await finish(tester);
  });

  testWidgets('a read for a workspace other than the captured context is refused', timeout: _limit, (tester) async {
    final sub = rig.container.listen(workspaceContextProvider, (_, _) {});
    addTearDown(sub.close);
    final from = DateTime.utc(2026, 10, 16);
    final refused = await outcome(
      tester,
      rig.container
          .read(reservationRepositoryProvider)
          .fetchWindow('ws-other', from: from, to: from.add(const Duration(days: 1))),
    );
    expect(refused.error, isA<StaleWorkspaceContext>());
    expect(rig.a.paths.where((p) => p.contains('/reservations')), isEmpty);
    await finish(tester);
  });
}
