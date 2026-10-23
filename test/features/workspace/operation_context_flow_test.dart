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

import 'package:deskilo/app/active_tax_reference.dart';
import 'package:deskilo/core/backend/auth_secret_store.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/backend/operation_context.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/instance/tax_reference_bundle_asset.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/core/realtime/realtime_wiring.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/core/time/workspace_calendar.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/me/providers/me_providers.dart';
import 'package:deskilo/features/money/providers/book_profile_providers.dart';
import 'package:deskilo/features/money/providers/credit_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/profile/providers/personal_preferences_providers.dart';
import 'package:deskilo/features/reservations/data/context_reservation_repository.dart';
import 'package:deskilo/features/reservations/providers/place_feedback_providers.dart';
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

  // #2561 L4 -- this installation's own calendar and tax reference.
  List<int> openWeekdays = const [1, 2, 3, 4, 5];
  int workStart = 8 * 60;
  String closureDay = '2026-12-25';
  bool issuesInFr = true;
  bool taxDown = false;
  Completer<void>? calendarGate;

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
      case '/rest/v1/workspaces':
        await calendarGate?.future;
        return _json(request, {
          'booking_rules': {
            'open_weekdays': openWeekdays,
            'work_start_minutes': workStart,
          },
        });
      case '/rest/v1/closure_days':
        return _json(request, [
          {
            'id': 'closure-$installationId',
            'workspace_id': 'ws-1',
            'day': closureDay,
            'reason': 'closed at $installationId',
          },
        ]);
      case '/rest/v1/rpc/tax_reference_history':
        if (taxDown) return http.Response('{}', 503, request: request);
        return _json(request, [
          {
            'id': 'gate-$installationId',
            'domain': 'issuing_gate',
            'country': 'FR',
            'key': 'gate',
            'valid_from': '1900-01-01',
            'valid_to': null,
            'value': {
              'supported': issuesInFr,
              'requires_tax_number': false,
              'national_channel_required': false,
            },
            'source': installationId,
            'confirmed': true,
          },
        ]);
      default:
        return _json(request, null);
    }
  }

  /// What reached this host other than a context capturing its calendar and
  /// tax reference (#2561 L4).
  List<String> get operations => [
        for (final p in paths)
          if (!_captures.any(p.endsWith)) p,
      ];
}

const _captures = [
  '/rest/v1/workspaces',
  '/rest/v1/closure_days',
  '/rest/v1/rpc/tax_reference_history',
];

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
    // #2561 L4 -- W-B's own calendar and tax reference differ from W-A's.
    b
      ..openWeekdays = const [1, 2, 3, 4, 5, 6]
      ..workStart = 7 * 60
      ..closureDay = '2026-12-26'
      ..issuesInFr = false;
  }

  final p = _Host('https://p.example', 'inst-p', 'unused');
  final a = _Host('https://wa.example', 'inst-a', 'res-from-a');
  final b = _Host('https://wb.example', 'inst-b', 'res-from-b');
  final settings = _Settings();
  late final _Resolver resolver;
  final cache = InMemoryCacheStore();
  Workspace current = _ws('ws-1', 'Europe/Paris');

  /// The copy bundled with the app (#2561 L4): null = none can be read.
  TaxReferenceSet? bundled;

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
    realtimeWorkspaceClientProvider.overrideWith(
      (ref) => ref.watch(selectedWorkspaceClientProvider),
    ),
    taxReferenceBundleLoaderProvider.overrideWithValue(() async =>
        bundled ?? (throw StateError('no bundled copy in this test'))),
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

  testWidgets('the change feeds follow their targets: W channel on the selected host, account feed on P', timeout: _limit, (tester) async {
    final sub = rig.container.listen(workspaceContextProvider, (_, _) {});
    addTearDown(sub.close);
    await settle(tester, rig.container.read(workspaceContextProvider.future), 'context A');
    SupabaseClient workspaceFeed() =>
        (rig.container.read(realtimeSyncProvider) as SupabaseRealtimeSync).client;
    SupabaseClient accountFeed() =>
        (rig.container.read(accountRealtimeSyncProvider) as SupabaseRealtimeSync).client;
    final fsub = rig.container.listen(realtimeSyncProvider, (_, _) {});
    addTearDown(fsub.close);
    expect(workspaceFeed(), same(rig.a.client));
    expect(accountFeed(), same(rig.p.client));

    // Selecting W-B (equal local id) moves the workspace feed only.
    rig.select(_ws('ws-1', 'America/New_York'), rig.b);
    await settle(tester, rig.container.read(workspaceContextProvider.future), 'context B');
    expect(workspaceFeed(), same(rig.b.client));
    expect(accountFeed(), same(rig.p.client),
        reason: 'the account feed never follows the workspace selection');
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

  // #2564 O1/O2 -- the migrated factories take their client from the role
  // seam: root-session consumers the personal client, workspace operations
  // the verified host of the captured context.
  testWidgets('selectedWorkspaceClient follows the context host; P consumers keep P', timeout: _limit, (tester) async {
    final sub = rig.container.listen(workspaceContextProvider, (_, _) {});
    addTearDown(sub.close);
    await settle(tester, rig.container.read(workspaceContextProvider.future));
    expect(rig.container.read(selectedWorkspaceClientProvider), same(rig.a.client));

    rig.select(_ws('ws-1', 'America/New_York'), rig.b);
    await settle(tester, rig.container.read(workspaceContextProvider.future));
    expect(rig.container.read(selectedWorkspaceClientProvider), same(rig.b.client));
    expect(rig.container.read(selectedWorkspaceClientProvider), isNot(same(rig.p.client)));

    // The reservation scope (booking recovery's account + origin) is the
    // selected host's, not a global one.
    final scope = rig.container.read(bookingIntentScopeProvider);
    expect(scope.origin, rig.b.client.rest.url);

    // Workspace operations written through the migrated factory reach W-B.
    await outcome(tester, rig.container.read(placeFeedbackRepositoryProvider).favorites('ws-1'), 'favourites');
    expect(rig.b.paths, isNotEmpty);
    expect(rig.a.operations, isEmpty);
    expect(rig.p.paths, isEmpty);
    await finish(tester);
  });

  testWidgets('personal preferences reach P only', timeout: _limit, (tester) async {
    final sub = rig.container.listen(workspaceContextProvider, (_, _) {});
    addTearDown(sub.close);
    await settle(tester, rig.container.read(workspaceContextProvider.future));
    await outcome(tester, rig.container.read(personalPreferencesRepositoryProvider).read(), 'prefs');
    expect(rig.p.paths, isNotEmpty);
    expect(rig.a.operations, isEmpty);
    expect(rig.b.paths, isEmpty);
    await finish(tester);
  });
  // #2564 O3 -- the money factories run on the selected workspace's host.
  testWidgets('money reads and commands reach the selected W host only, then follow a switch', timeout: _limit, (tester) async {
    final sub = rig.container.listen(workspaceContextProvider, (_, _) {});
    addTearDown(sub.close);
    await settle(tester, rig.container.read(workspaceContextProvider.future));

    Future<void> touchMoney() async {
      await outcome(tester, rig.container.read(creditRepositoryProvider).fetchCreditProducts('ws-1'), 'credit');
      await outcome(tester, rig.container.read(bookProfileRepositoryProvider).fetchBookProfiles('ws-1'), 'book');
      await outcome(tester, rig.container.read(invoiceQueriesProvider).fetchInvoices('ws-1'), 'invoices');
    }

    await touchMoney();
    expect(rig.a.paths, isNotEmpty);
    expect(rig.b.paths, isEmpty);
    expect(rig.p.paths, isEmpty, reason: 'the personal home never serves money rows');

    // W-B with the same local workspace id: its own host, W-A sees nothing new.
    final seenByA = rig.a.paths.length;
    rig.select(_ws('ws-1', 'America/New_York'), rig.b);
    await settle(tester, rig.container.read(workspaceContextProvider.future));
    await touchMoney();
    expect(rig.b.paths, isNotEmpty);
    expect(rig.a.paths.length, seenByA);
    expect(rig.p.paths, isEmpty);

    // Refusal then recovery: W-B down answers an error, never W-A's rows.
    rig.b.down = true;
    final seenByB = rig.b.paths.length;
    final refused = await outcome(
        tester, rig.container.read(creditRepositoryProvider).fetchCreditProducts('ws-1'), 'down');
    expect(refused.error, isNotNull);
    expect(rig.a.paths.length, seenByA);
    rig.b.down = false;
    final recovered = await outcome(
        tester, rig.container.read(creditRepositoryProvider).fetchCreditProducts('ws-1'), 'up');
    expect(rig.b.paths.length, greaterThan(seenByB), reason: 'recovery reaches W-B again');
    expect(recovered.error, isNot(isA<http.ClientException>()));
    await finish(tester);
  });

  // #2564 O1 -- the workspace repository is split: its operations half runs
  // on the selected host, its list half on the root session.
  testWidgets('workspace operations reach the selected host; the list half stays on P', timeout: _limit, (tester) async {
    final sub = rig.container.listen(workspaceContextProvider, (_, _) {});
    addTearDown(sub.close);
    await settle(tester, rig.container.read(workspaceContextProvider.future));

    Future<void> operate() => outcome(
        tester, rig.container.read(workspaceRepositoryProvider).fetchSites('ws-1'), 'sites');
    await operate();
    expect(rig.a.paths.where((p) => p.contains('/sites')), isNotEmpty);
    expect(rig.b.paths, isEmpty);
    expect(rig.p.paths.where((p) => p.contains('/sites')), isEmpty);

    await outcome(tester, rig.container.read(workspaceListRepositoryProvider).fetchMyWorkspaces(), 'workspaces');
    expect(rig.p.paths, isNotEmpty, reason: 'the list half is the root session\'s');
    final seenByA = rig.a.paths.length;
    expect(rig.b.paths, isEmpty);

    // Equal local id on W-B: operations follow, W-A sees nothing new.
    rig.select(_ws('ws-1', 'America/New_York'), rig.b);
    await settle(tester, rig.container.read(workspaceContextProvider.future));
    await operate();
    expect(rig.b.paths.where((p) => p.contains('/sites')), isNotEmpty);
    expect(rig.a.paths.length, seenByA);

    // Refusal with W-B down never falls back to W-A or P; recovery reaches W-B.
    rig.b.down = true;
    final refused = await outcome(
        tester, rig.container.read(workspaceRepositoryProvider).fetchSites('ws-1'), 'down');
    expect(refused.error, isNotNull);
    expect(rig.a.paths.length, seenByA);
    rig.b.down = false;
    final seenByB = rig.b.paths.length;
    await operate();
    expect(rig.b.paths.length, greaterThan(seenByB));
    await finish(tester);
  });

  // #2561 L4 -- the calendar and the tax reference are captured into the
  // context from the selected workspace's own host; W-A's never stand for
  // W-B's, early, late or through a consumer.
  group('calendar and tax reference in the context', () {
    late TaxReferenceSet installed;
    setUp(() => installed = ActiveTaxReference.current);
    tearDown(() => ActiveTaxReference.install(installed));

    testWidgets('each workspace\'s context carries its own host\'s calendar and tax reference, '
        'and the consumers follow a switch', timeout: _limit, (tester) async {
      final subs = [
        rig.container.listen(workspaceContextProvider, (_, _) {}),
        rig.container.listen(readyWorkspaceContextProvider, (_, _) {}),
        rig.container.listen(activeTaxReferenceProvider, (_, _) {}),
      ];
      addTearDown(() => [for (final s in subs) s.close()]);

      // What the consumer-facing providers answer, as one line.
      Future<String> consumers() async {
        final days = await settle(tester, rig.container.read(openWeekdaysProvider.future));
        final hours = await settle(tester, rig.container.read(workHoursProvider.future));
        final closures = await settle(tester, rig.container.read(closureDaysProvider.future));
        return '$days ${hours.startMinutes} '
            '${[for (final c in closures) '${c.id}|${c.day.month}-${c.day.day}|${c.reason}']}';
      }

      final contextA = await settle(tester, rig.container.read(workspaceContextProvider.future));
      expect(contextA!.calendar.timezone, 'Europe/Paris');
      expect(contextA.calendar.openWeekdays, [1, 2, 3, 4, 5]);
      expect(contextA.calendar.workHours.startMinutes, 8 * 60);
      expect(contextA.taxReference.set.issuesFor('FR'), isTrue);
      expect(contextA.taxReference.set.rows.single.source, 'inst-a');
      expect(await consumers(), '[1, 2, 3, 4, 5] 480 [closure-inst-a|12-25|closed at inst-a]');
      await tester.pump();
      expect(rig.container.read(readyWorkspaceContextProvider), contextA);
      expect(ActiveTaxReference.current.issuesFor('FR'), isTrue,
          reason: 'the legacy adapter is fed from the captured context');

      // W-B, same local workspace id, another zone, calendar and dataset.
      rig.select(_ws('ws-1', 'America/New_York'), rig.b);
      final contextB = await settle(tester, rig.container.read(workspaceContextProvider.future));
      expect(contextB!.target.installationId, 'inst-b');
      expect(contextB.calendar.timezone, 'America/New_York');
      expect(contextB.calendar.openWeekdays, [1, 2, 3, 4, 5, 6]);
      expect(contextB.calendar.workHours.startMinutes, 7 * 60);
      expect(contextB.calendar.closures.single.reason, 'closed at inst-b');
      expect(contextB.taxReference.set.issuesFor('FR'), isFalse);
      expect(contextB.taxReference.set.rows.single.source, 'inst-b');
      expect(contextB.calendar, isNot(contextA.calendar));
      expect(contextB.taxReference, isNot(contextA.taxReference));
      expect(await consumers(), '[1, 2, 3, 4, 5, 6] 420 [closure-inst-b|12-26|closed at inst-b]');
      await tester.pump();
      expect(rig.container.read(readyWorkspaceContextProvider), contextB);
      expect(ActiveTaxReference.current.issuesFor('FR'), isFalse);

      // Read from each host's own client; the personal home serves neither.
      for (final path in _captures) {
        expect(rig.a.paths.where((p) => p.endsWith(path)), isNotEmpty, reason: path);
        expect(rig.b.paths.where((p) => p.endsWith(path)), isNotEmpty, reason: path);
        expect(rig.p.paths.where((p) => p.endsWith(path)), isEmpty, reason: path);
      }
      await finish(tester);
    });

    testWidgets('a late W-A calendar answer never becomes W-B\'s, and nothing shows W-A\'s '
        'while W-B is captured', timeout: _limit, (tester) async {
      final contexts = <WorkspaceContext?>[];
      final ready = <WorkspaceContext?>[];
      final subs = [
        rig.container.listen(workspaceContextProvider, (_, next) => contexts.add(next.value)),
        rig.container.listen(readyWorkspaceContextProvider, (_, next) => ready.add(next)),
      ];
      addTearDown(() => [for (final s in subs) s.close()]);
      final contextA = await settle(tester, rig.container.read(workspaceContextProvider.future));

      // W-A re-captures (an edit) and its answer is held back...
      rig.a.calendarGate = Completer<void>();
      rig.a.openWeekdays = const [7];
      rig.container.invalidate(workspaceContextProvider);
      await tester.pump(const Duration(milliseconds: 50));

      // ...the member moves to W-B, which answers, then W-A's answer lands.
      rig.select(_ws('ws-1', 'America/New_York'), rig.b);
      final contextB = await settle(tester, rig.container.read(workspaceContextProvider.future));
      rig.a.calendarGate!.complete();
      await tester.pump(const Duration(milliseconds: 200));

      final now = await settle(tester, rig.container.read(workspaceContextProvider.future));
      expect(now, contextB);
      expect(now!.calendar.openWeekdays, [1, 2, 3, 4, 5, 6]);
      expect(await settle(tester, rig.container.read(openWeekdaysProvider.future)), [1, 2, 3, 4, 5, 6]);
      expect([for (final c in contexts) c?.calendar.openWeekdays], isNot(contains([7])),
          reason: 'the held-back W-A capture never became a context');
      // Every context the synchronous readers saw is A's before the switch
      // or B's after it: never A's under B.
      final firstB = ready.indexWhere((c) => c?.target.installationId == 'inst-b');
      expect(firstB, isNot(-1));
      expect(ready.skip(firstB).where((c) => c?.target.installationId == 'inst-a'), isEmpty);
      expect(ready.where((c) => c != null && c != contextA && c != contextB), isEmpty);
      await finish(tester);
    });

    testWidgets('an unknown zone is a typed configuration failure, never the device clock', timeout: _limit, (tester) async {
      final subs = [
        rig.container.listen(workspaceContextProvider, (_, _) {}),
        rig.container.listen(readyWorkspaceContextProvider, (_, _) {}),
      ];
      addTearDown(() => [for (final s in subs) s.close()]);
      rig.select(_ws('ws-1', 'Mars/Olympus_Mons'), rig.a);
      final refused = await outcome(tester, rig.container.read(workspaceContextProvider.future));
      expect(refused.error, isA<WorkspaceCalendarUnavailable>());
      final days = rig.container.listen(openWeekdaysProvider, (_, _) {});
      addTearDown(days.close);
      await tester.pump(const Duration(milliseconds: 50));
      expect(days.read().hasValue, isFalse, reason: 'no invented open days either');
      expect(rig.container.read(readyWorkspaceContextProvider), isNull);

      // Recovery: a valid zone captures again.
      rig.select(_ws('ws-1', 'Europe/Paris'), rig.a);
      final context = await settle(tester, rig.container.read(workspaceContextProvider.future));
      expect(context!.calendar.timezone, 'Europe/Paris');
      await finish(tester);
    });

    testWidgets('a host without its tax reference: the bundled copy, else a typed failure, '
        'never another workspace\'s rows', timeout: _limit, (tester) async {
      final sub = rig.container.listen(workspaceContextProvider, (_, _) {});
      addTearDown(sub.close);
      rig.b.taxDown = true;
      rig.select(_ws('ws-1', 'America/New_York'), rig.b);
      final refused = await outcome(tester, rig.container.read(workspaceContextProvider.future));
      expect(refused.error, isA<TaxReferenceUnavailable>());

      rig.bundled = TaxReferenceSet([
        TaxReferenceRow.fromJson({
          'domain': 'eu_member',
          'country': 'FR',
          'key': 'member',
          'valid_from': '1900-01-01',
          'value': <String, Object?>{},
          'source': 'bundle',
          'confirmed': true,
        }),
      ], origin: TaxReferenceOrigin.bundle);
      rig.container.invalidate(workspaceContextProvider);
      final context = await settle(tester, rig.container.read(workspaceContextProvider.future));
      expect(context!.target.installationId, 'inst-b');
      expect(context.taxReference.origin, TaxReferenceOrigin.bundle);
      expect(context.taxReference.set.rows.map((r) => r.source), ['bundle']);
      expect(rig.a.paths.where((p) => p.endsWith('tax_reference_history')), isEmpty);
      await finish(tester);
    });

    testWidgets('an edit re-captures the same target\'s calendar under the same epochs', timeout: _limit, (tester) async {
      final sub = rig.container.listen(workspaceContextProvider, (_, _) {});
      addTearDown(sub.close);
      final before = await settle(tester, rig.container.read(workspaceContextProvider.future));
      rig.a.workStart = 9 * 60;
      rig.container.invalidate(workspaceContextProvider);
      final after = await settle(tester, rig.container.read(workspaceContextProvider.future));
      expect(after!.calendar.workHours.startMinutes, 9 * 60);
      expect(after.target, before!.target);
      expect([after.personalEpoch, after.workspaceEpoch], [before.personalEpoch, before.workspaceEpoch]);
      expect(after.sameOperationAs(before), isFalse,
          reason: 'a result computed on the old calendar is not this one\'s');
      await finish(tester);
    });
  });
}
