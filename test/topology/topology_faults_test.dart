// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L2 -- physical faults on the three local stacks of the database job
// (P, W-A, W-B; scripts/topology_stacks.sh prepares and seeds them). A fault
// is applied to a stack's API gateway with `topology_stacks.sh fault`:
// `block` stops it (every connection refused), `stall` pauses it (accepted,
// never answered), `restore` brings it back. The consumers are the
// production ones: the P profile read and write, the W reservation window
// read through the captured workspace context, and the context providers.
//
//   SEP-04 (R3)  every W gateway blocked after P signed in: P refreshes,
//                reads and writes; W answers stale-marked or unavailable,
//                never an empty success; nobody is signed out.
//   SEP-04       W-A blocked: W-B reads live and P answers; no barrier
//                waits for the host that is down.
//   SEP-02, SEP-04 (R4)  W-A stalled: W-B answers while W-A still hangs,
//                one request reached W-A, and W-A's late answer is W-A's
//                alone (the in-flight request stays bound to its source).
//   SEP-05 (R11) the personal account switches, or the host at the same
//                URL identifies as another installation, while a W-A read
//                hangs: the personal epoch or the target moves, the late
//                answer reaches only its own caller and populates nothing
//                of the new context.
//   SEP-05       the app restored after its process ended: its persisted
//                window answers the account that read it, never another
//                account on the same target.
//
// Runs only with DESKILO_TOPOLOGY_FILE (the seed's descriptor), in its own
// `flutter test` call after the other topology files, because it pauses and
// stops gateways those files use. The identities are independently seeded
// plumbing users, NOT the one-registration proof (#2562). A change of
// installation identity is what the resolver verifies; the physical
// connected-pool quarantine needs HTTPS endpoints and stays with #2562.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/backend/auth_secret_store.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/backend/operation_context.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/cache/read_failure.dart';
import 'package:deskilo/core/cache/stale_reads.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/realtime/realtime_wiring.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/me/providers/me_providers.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/real_async.dart';

final _file = Platform.environment['DESKILO_TOPOLOGY_FILE'];
const _limit = Timeout(Duration(minutes: 4));

/// Applies a physical fault through the harness, or fails with its output.
Future<void> _fault(String mode, String target) async {
  final r = await Process.run('bash', [
    'scripts/topology_stacks.sh',
    'fault',
    mode,
    target,
  ]);
  expect(
    r.exitCode,
    0,
    reason: 'fault $mode $target\n${r.stdout}\n${r.stderr}',
  );
}

/// Forwards to the real network and remembers what it sent.
class _Wire extends http.BaseClient {
  final _inner = http.Client();
  final paths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    paths.add('${request.method} ${request.url.path}');
    return _inner.send(request);
  }

  int count(String part) => paths.where((p) => p.contains(part)).length;
}

/// One physical stack: a recorded app client signed in as [who], and a
/// service-key client for readback.
class _Stack {
  _Stack(this.role, this.installationId, this.j, String password)
    : url = j['url'] as String,
      anon = j['anon'] as String,
      _password = password {
    readback = SupabaseClient(url, j['service'] as String);
  }

  final String role;
  final String installationId;
  final Map<String, dynamic> j;
  final String url;
  final String anon;
  final String _password;
  final wire = _Wire();
  late final SupabaseClient readback;

  Map<String, dynamic> account(String name) => j[name] as Map<String, dynamic>;

  /// A fresh client over [wire], signed in as the seeded [name].
  Future<SupabaseClient> signedIn(String name) async {
    final c = SupabaseClient(
      url,
      anon,
      httpClient: wire,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final who = account(name);
    final s = await c.auth.signInWithPassword(
      email: who['email'] as String,
      password: _password,
    );
    expect(s.user?.id, who['id'], reason: '$role signed in as $name');
    return c;
  }

  Future<int> rows(String table) async =>
      (await readback.from(table).select('id')).length;
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

/// The host a workspace resolves to: what the verified host is, its
/// client, and the local account there. Each field can change mid-test.
class _Resolver implements WorkspaceHostResolver {
  _Resolver(this.installationId, this.client, this.localUserId);
  String installationId;
  SupabaseClient client;
  String localUserId;

  @override
  Future<ResolvedWorkspaceHost> resolve(String workspaceId) async =>
      ResolvedWorkspaceHost(
        installationId: installationId,
        client: client,
        localUserId: localUserId,
      );
}

typedef _Outcome<T> = ({T? value, Object? error});

Future<_Outcome<T>> _outcome<T>(Future<T> f) async {
  try {
    return (value: await f, error: null);
  } on Object catch (e) {
    return (value: null, error: e);
  }
}

List<String> _ids(List<Reservation>? rows) => [
  for (final r in rows ?? const <Reservation>[]) r.id,
];

void main() {
  if (_file == null) {
    test(
      'the topology faults',
      () {},
      skip: 'needs the three stacks of the database job; set DESKILO_TOPOLOGY_FILE',
    );
    return;
  }
  late Map<String, dynamic> d;
  late String workspaceId;
  late _Stack p;
  late _Stack a;
  late _Stack b;
  late SupabaseClient aClient;
  late SupabaseClient bClient;

  DateTime from() => DateTime.parse(d['windowFrom'] as String);
  DateTime to() => DateTime.parse(d['windowTo'] as String);
  String reservationOf(_Stack s) => s.j['reservationId'] as String;

  Workspace workspaceOf(_Stack s) => Workspace(
    id: workspaceId,
    name: 'Topology ${s.role}',
    countryCode: 'FR',
    currencyCode: 'EUR',
    timezone: s.j['timezone'] as String,
    inviteCode: 'x',
  );

  setUpAll(() async {
    // flutter_test replaces the HTTP client with one that answers 400.
    HttpOverrides.global = null;
    d = jsonDecode(File(_file!).readAsStringSync()) as Map<String, dynamic>;
    final password = d['password'] as String;
    workspaceId = d['workspaceId'] as String;
    p = _Stack('P', 'inst-p', d['p'] as Map<String, dynamic>, password);
    a = _Stack('W-A', 'inst-wa', d['wa'] as Map<String, dynamic>, password);
    b = _Stack('W-B', 'inst-wb', d['wb'] as Map<String, dynamic>, password);
    // A fault a crashed earlier run left behind is lifted first.
    await _fault('restore', 'all');
    aClient = await a.signedIn('user');
    bClient = await b.signedIn('user');
  });

  tearDownAll(() => _fault('restore', 'all'));

  // One app: its own P client (signed in as the first P account), the
  // selected workspace and its host, the session the app believes in.
  late SupabaseClient personal;
  late String subject;
  late Workspace? current;
  late _Resolver resolver;
  late ProviderContainer container;

  void select(_Stack s, SupabaseClient client) {
    current = workspaceOf(s);
    resolver
      ..installationId = s.installationId
      ..client = client
      ..localUserId = (s.account('user'))['id'] as String;
    container
      ..invalidate(currentWorkspaceProvider)
      ..invalidate(currentSettingsCaptureProvider)
      ..invalidate(workspaceContextProvider);
  }

  setUp(() async {
    for (final s in [p, a, b]) {
      s.wire.paths.clear();
    }
    personal = await p.signedIn('user');
    subject = p.account('user')['id'] as String;
    current = workspaceOf(a);
    resolver = _Resolver(
      a.installationId,
      aClient,
      a.account('user')['id'] as String,
    );
    container = ProviderContainer(
      overrides: [
        sessionStateProvider.overrideWith((ref) => Stream.value(subject)),
        authStateProvider.overrideWith((ref) => Stream.value(subject)),
        bootedBackendUrlProvider.overrideWithValue(p.url),
        contextClientsProvider.overrideWithValue(ContextClients(personal)),
        connectedInstallationsProvider.overrideWithValue(
          ConnectedInstallations(personal, const PlatformAuthSecretStore()),
        ),
        installationIdReaderProvider.overrideWithValue(
          (client) async => p.installationId,
        ),
        workspaceHostResolverProvider.overrideWithValue(resolver),
        settingsSourceProvider.overrideWithValue(_Settings()),
        currentWorkspaceProvider.overrideWith((ref) async => current),
        cacheStoreProvider.overrideWithValue(InMemoryCacheStore()),
        realtimeWorkspaceClientProvider.overrideWith(
          (ref) => ref.watch(selectedWorkspaceClientProvider),
        ),
      ],
    );
    final sub = container.listen(workspaceContextProvider, (_, _) {});
    final auth = container.listen(authStateProvider, (_, _) {});
    addTearDown(() {
      sub.close();
      auth.close();
      container.dispose();
    });
  });

  // Every fault is lifted whatever the test did.
  tearDown(() => _fault('restore', 'all'));

  ReservationRepository repo() => container.read(reservationRepositoryProvider);
  Future<WorkspaceContext?> context() => container
      .read(workspaceContextProvider.future)
      .timeout(const Duration(seconds: 30));
  Future<PersonalContext?> personalContext() => container
      .read(personalContextProvider.future)
      .timeout(const Duration(seconds: 30));

  Future<void> expectOperationalCountsZeroAtP() async {
    for (final table in ['workspaces', 'members', 'reservations', 'invoices']) {
      expect(await p.rows(table), 0, reason: 'P holds no operational $table');
    }
  }

  /// One process of the app: its own container over [cache], which stands
  /// for what it persisted. A restart is a new process over the same cache.
  ProviderContainer process({
    required SupabaseClient personalClient,
    required String personalSubject,
    required _Resolver host,
    required CacheStore cache,
  }) {
    return ProviderContainer(
      overrides: [
        sessionStateProvider.overrideWith(
          (ref) => Stream.value(personalSubject),
        ),
        authStateProvider.overrideWith((ref) => Stream.value(personalSubject)),
        bootedBackendUrlProvider.overrideWithValue(p.url),
        contextClientsProvider.overrideWithValue(
          ContextClients(personalClient),
        ),
        connectedInstallationsProvider.overrideWithValue(
          ConnectedInstallations(
            personalClient,
            const PlatformAuthSecretStore(),
          ),
        ),
        installationIdReaderProvider.overrideWithValue(
          (client) async => p.installationId,
        ),
        workspaceHostResolverProvider.overrideWithValue(host),
        settingsSourceProvider.overrideWithValue(_Settings()),
        currentWorkspaceProvider.overrideWith((ref) async => workspaceOf(a)),
        cacheStoreProvider.overrideWithValue(cache),
        realtimeWorkspaceClientProvider.overrideWith(
          (ref) => ref.watch(selectedWorkspaceClientProvider),
        ),
      ],
    )
      ..listen(workspaceContextProvider, (_, _) {})
      ..listen(authStateProvider, (_, _) {});
  }

  test(
    'SEP-04 (R3): with every W gateway refused, P refreshes, reads and writes '
    'its profile; W answers stale-marked or unavailable, never an empty '
    'success, and nobody is signed out',
    timeout: _limit,
    () async {
      await context();
      final warm = await repo().fetchWindow(
        workspaceId,
        from: from(),
        to: to(),
      );
      expect(_ids(warm), [reservationOf(a)]);
      final personalBefore = await personalContext();

      await _fault('block', 'w');
      // The block is physical: each W gateway refuses a direct request.
      for (final (stack, client) in [(a, aClient), (b, bClient)]) {
        final direct = await _outcome(client.from('reservations').select('id'));
        expect(direct.error, isNotNull, reason: '${stack.role} is blocked');
        expect(classifyReadFailure(direct.error!), ReadFailure.transient);
      }
      for (final s in [p, a, b]) {
        s.wire.paths.clear();
      }

      // P: a session refresh, the profile read and the profile write.
      final refreshed = await personal.auth.refreshSession();
      expect(refreshed.user?.id, subject);
      await container.read(authStateProvider.future);
      final bio = 'Outage profile ${d['run']}';
      container.invalidate(myVisibilityProvider);
      expect(
        (await container.read(myVisibilityProvider.future)).bio,
        isNot(bio),
      );
      await container.read(meActionsProvider).saveAbout('Maker', bio);
      container.invalidate(myVisibilityProvider);
      expect((await container.read(myVisibilityProvider.future)).bio, bio);
      final row = await p.readback
          .from('account_about')
          .select('bio')
          .eq('user_id', subject)
          .single();
      expect(
        row['bio'],
        bio,
        reason: 'the write landed at P during the outage',
      );
      expect(p.wire.count('/rpc/set_my_about'), 1);
      expect(
        [...a.wire.paths, ...b.wire.paths],
        isEmpty,
        reason: 'no P operation waited on a W host',
      );

      // W: the window read before the outage is served and marked not live;
      // a window never read is an error, not an empty list.
      final stale = await repo().fetchWindow(
        workspaceId,
        from: from(),
        to: to(),
      );
      expect(_ids(stale), [reservationOf(a)]);
      expect(
        StaleReads.instance.oldestSavedAt(['resv:']),
        isNotNull,
        reason: 'the screen can say the rows are not live',
      );
      final cold = await _outcome(
        repo().fetchWindow(
          workspaceId,
          from: from().subtract(const Duration(days: 7)),
          to: from().subtract(const Duration(days: 6)),
        ),
      );
      expect(cold.value, isNull, reason: 'an outage is not an empty window');
      expect(classifyReadFailure(cold.error!), ReadFailure.transient);

      // Nobody was signed out, and the personal context did not move.
      expect(personal.auth.currentUser?.id, subject);
      expect(aClient.auth.currentSession, isNotNull);
      expect(bClient.auth.currentSession, isNotNull);
      expect(await personalContext(), personalBefore);

      // Recovery: the same read is live again.
      await _fault('restore', 'w');
      final live = await repo().fetchWindow(
        workspaceId,
        from: from(),
        to: to(),
      );
      expect(_ids(live), [reservationOf(a)]);
      expect(StaleReads.instance.oldestSavedAt(['resv:']), isNull);
      await expectOperationalCountsZeroAtP();
    },
  );

  test(
    'SEP-02 and SEP-04 (R4): W-A stalled, W-B answers while W-A still hangs; one request '
    'reached W-A; its late answer is its own and never W-B\'s',
    timeout: _limit,
    () async {
      final contextA = await context();
      await _fault('stall', 'wa');
      a.wire.paths.clear();
      var lateDone = false;
      final late = repo().fetchWindow(workspaceId, from: from(), to: to());
      unawaited(
        late
            .whenComplete(() => lateDone = true)
            .then<void>((_) {}, onError: (Object _) {}),
      );
      await untilReal(
        () => a.wire.paths.isNotEmpty,
        what: 'the W-A request is sent',
      );

      final watch = Stopwatch()..start();
      select(b, bClient);
      final contextB = await context();
      final fromB = await repo()
          .fetchWindow(workspaceId, from: from(), to: to())
          .timeout(const Duration(seconds: 30));
      watch.stop();
      expect(_ids(fromB), [reservationOf(b)]);
      expect(lateDone, isFalse, reason: 'W-B answered while W-A still hangs');
      expect(contextB!.target.installationId, b.installationId);
      expect(contextB.target.workspaceId, contextA!.target.workspaceId);
      expect(contextB.sameOperationAs(contextA), isFalse);
      expect(
        a.wire.count('/rest/v1/'),
        1,
        reason:
            'one request reached the stalled host, and nothing retried '
            'it: ${a.wire.paths}',
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 30)));

      await _fault('restore', 'wa');
      final lateRows = await late.timeout(const Duration(seconds: 60));
      expect(_ids(lateRows), [
        reservationOf(a),
      ], reason: 'the late answer is W-A\'s, for its own caller');

      // W-B down: its cached window under the equal workspace id and window
      // is W-B's own row, never the late W-A one.
      await _fault('block', 'wb');
      final cachedB = await repo().fetchWindow(
        workspaceId,
        from: from(),
        to: to(),
      );
      expect(_ids(cachedB), [reservationOf(b)]);
      await expectOperationalCountsZeroAtP();
    },
  );

  test(
    'SEP-05 (R11): the personal account switches while a W-A read hangs; the '
    'personal epoch moves, P serves the new account, and the late W-A '
    'answer populates nothing of the new account',
    timeout: _limit,
    () async {
      final contextA = await context();
      final personal1 = await personalContext();
      await _fault('stall', 'wa');
      a.wire.paths.clear();
      final late = repo().fetchWindow(workspaceId, from: from(), to: to());
      unawaited(late.then<void>((_) {}, onError: (Object _) {}));
      await untilReal(
        () => a.wire.paths.isNotEmpty,
        what: 'the W-A request is sent',
      );

      // The switch at P, while W-A hangs: the second P account, whose
      // workspace lives on W-B.
      final second = p.account('user2');
      final switched = await personal.auth.signInWithPassword(
        email: second['email'] as String,
        password: d['password'] as String,
      );
      expect(switched.user?.id, second['id']);
      subject = second['id'] as String;
      select(b, bClient);
      container
        ..invalidate(sessionStateProvider)
        ..invalidate(authStateProvider);
      final personal2 = await personalContext();
      expect(personal2!.identity.subject, subject);
      expect(personal2.personalEpoch, greaterThan(personal1!.personalEpoch));
      expect(personal2.homeInstallationId, personal1.homeInstallationId);
      expect(
        container.read(personalClientProvider),
        same(personal),
        reason: 'one P client lifetime across the switch',
      );

      // P answers the new account while W-A still hangs.
      await container.read(authStateProvider.future);
      p.wire.paths.clear();
      await container
          .read(myVisibilityProvider.future)
          .timeout(const Duration(seconds: 30));
      expect(p.wire.count('/rpc/my_visibility'), greaterThan(0));
      final contextB = await context();
      expect(contextB!.personalEpoch, personal2.personalEpoch);
      expect(contextB.sameOperationAs(contextA!), isFalse);

      await _fault('restore', 'wa');
      final lateRows = await late.timeout(const Duration(seconds: 60));
      expect(
        _ids(lateRows),
        [reservationOf(a)],
        reason: 'the late answer reaches only the caller of the first account',
      );

      // The new account's window was never read: with W-B down it is
      // unavailable, not the late rows of the first account at W-A.
      await _fault('block', 'wb');
      final after = await _outcome(
        repo().fetchWindow(workspaceId, from: from(), to: to()),
      );
      expect(after.value, isNull, reason: 'got ${_ids(after.value)}');
      expect(classifyReadFailure(after.error!), ReadFailure.transient);
      await expectOperationalCountsZeroAtP();
    },
  );

  test(
    'SEP-05 (R11): the host at the same URL identifies as another installation '
    'while a W-A read hangs; the target and its cache namespace change, '
    'and the late answer populates nothing of the new target',
    timeout: _limit,
    () async {
      final before = await context();
      await _fault('stall', 'wa');
      a.wire.paths.clear();
      final late = repo().fetchWindow(workspaceId, from: from(), to: to());
      unawaited(late.then<void>((_) {}, onError: (Object _) {}));
      await untilReal(
        () => a.wire.paths.isNotEmpty,
        what: 'the W-A request is sent',
      );

      // Same URL, same client and account: the verified installation is
      // another one (the stack was replaced).
      resolver.installationId = '${a.installationId}-replaced';
      container.invalidate(workspaceContextProvider);
      await _fault('restore', 'wa');
      final lateRows = await late.timeout(const Duration(seconds: 60));
      expect(_ids(lateRows), [reservationOf(a)]);
      final after = await context();
      expect(after!.target.installationId, '${a.installationId}-replaced');
      expect(after.target, isNot(before!.target));
      expect(
        after.personalEpoch,
        before.personalEpoch,
        reason: 'a W identity change never replaces P',
      );
      expect(after.cacheNamespace, isNot(before.cacheNamespace));
      expect(after.sameOperationAs(before), isFalse);

      // The new target's window was never read: with W-A down it is
      // unavailable, not the late rows of the replaced installation.
      await _fault('block', 'wa');
      final read = await _outcome(
        repo().fetchWindow(workspaceId, from: from(), to: to()),
      );
      expect(read.value, isNull, reason: 'got ${_ids(read.value)}');
      expect(classifyReadFailure(read.error!), ReadFailure.transient);
      await expectOperationalCountsZeroAtP();
    },
  );
  test(
    'SEP-04: W-A blocked, W-B reads live and P answers; nothing waits for '
    'the host that is down',
    timeout: _limit,
    () async {
      await context();
      final warm = await repo().fetchWindow(
        workspaceId,
        from: from(),
        to: to(),
      );
      expect(_ids(warm), [reservationOf(a)]);
      await _fault('block', 'wa');
      for (final s in [p, a, b]) {
        s.wire.paths.clear();
      }

      final watch = Stopwatch()..start();
      select(b, bClient);
      await context();
      final fromB = await repo()
          .fetchWindow(workspaceId, from: from(), to: to())
          .timeout(const Duration(seconds: 30));
      expect(_ids(fromB), [reservationOf(b)]);
      expect(
        b.wire.count('/rest/v1/reservations'),
        greaterThan(0),
        reason: 'W-B answered live, not from a cache',
      );
      await container.read(authStateProvider.future);
      container.invalidate(myVisibilityProvider);
      await container
          .read(myVisibilityProvider.future)
          .timeout(const Duration(seconds: 30));
      watch.stop();
      expect(p.wire.count('/rpc/my_visibility'), greaterThan(0));
      expect(
        a.wire.paths,
        isEmpty,
        reason: 'nothing of W-B or P asked the host that is down',
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 30)));
      await expectOperationalCountsZeroAtP();
    },
  );

  test(
    'SEP-05: the app restored after its process ended serves its persisted '
    'window to the account that read it, and never to another account on '
    'the same target',
    timeout: _limit,
    () async {
      final disk = InMemoryCacheStore();
      final peerClient = await a.signedIn('peer');
      final personal2 = await p.signedIn('user2');
      final first = _Resolver(
        a.installationId,
        aClient,
        a.account('user')['id'] as String,
      );
      ProviderContainer? live;
      addTearDown(() => live?.dispose());
      Future<List<Reservation>> window(ProviderContainer c) => c
          .read(reservationRepositoryProvider)
          .fetchWindow(workspaceId, from: from(), to: to());

      // The process that ended: the first account read W-A's window.
      live = process(
        personalClient: personal,
        personalSubject: subject,
        host: first,
        cache: disk,
      );
      final before = await live
          .read(workspaceContextProvider.future)
          .timeout(const Duration(seconds: 30));
      expect(_ids(await window(live)), [reservationOf(a)]);
      live.dispose();
      live = null;

      // Restored as the same account: the same namespace; with W-A down
      // the persisted window answers, marked not live.
      live = process(
        personalClient: personal,
        personalSubject: subject,
        host: first,
        cache: disk,
      );
      final again = await live
          .read(workspaceContextProvider.future)
          .timeout(const Duration(seconds: 30));
      expect(again!.cacheNamespace, before!.cacheNamespace);
      await _fault('block', 'wa');
      expect(_ids(await window(live)), [reservationOf(a)]);
      expect(StaleReads.instance.oldestSavedAt(['resv:']), isNotNull);
      live.dispose();
      live = null;
      await _fault('restore', 'wa');

      // Restored as another account: the second P account, whose local
      // account at W-A is another member of the same workspace. The same
      // target, a namespace of its own; with W-A down it reads unavailable,
      // never the first account's persisted rows.
      live = process(
        personalClient: personal2,
        personalSubject: p.account('user2')['id'] as String,
        host: _Resolver(
          a.installationId,
          peerClient,
          a.account('peer')['id'] as String,
        ),
        cache: disk,
      );
      final other = await live
          .read(workspaceContextProvider.future)
          .timeout(const Duration(seconds: 30));
      expect(other!.target, before.target);
      expect(other.cacheNamespace, isNot(before.cacheNamespace));
      await _fault('block', 'wa');
      final read = await _outcome(window(live));
      expect(read.value, isNull, reason: 'got ${_ids(read.value)}');
      expect(classifyReadFailure(read.error!), ReadFailure.transient);
      await expectOperationalCountsZeroAtP();
    },
  );
}
