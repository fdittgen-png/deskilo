// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 C2 -- the production P profile consumer and the production W
// reservation consumer against THREE real local Supabase stacks: P, W-A
// and W-B, each with its own Postgres, Auth and Storage containers,
// project id, ports and JWT secret (scripts/topology_stacks.sh prepares
// and seeds them; the database job of quality.yml starts them once).
// Requests are real and signed by each stack's Auth; every claim is read
// back from the stack's own database through its service key.
//
// Runs only with DESKILO_TOPOLOGY_FILE pointing at the descriptor the seed
// wrote, and never against anything but those local stacks. The identities
// are independently seeded plumbing users, NOT the one-registration proof
// (#2562); fault, outage and epoch scenarios (SEP-01..06) are #2561's next
// checkpoint and #2560's evidence, not this file's.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/backend/auth_secret_store.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/realtime/realtime_wiring.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';

final _file = Platform.environment['DESKILO_TOPOLOGY_FILE'];

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

/// One physical stack: the signed-in app client (recorded), a service-key
/// client for readback (never the app's path), and the seeded identities.
class _Stack {
  _Stack(this.role, this.installationId, Map<String, dynamic> j)
    : url = j['url'] as String,
      anon = j['anon'] as String,
      service = j['service'] as String,
      user = j['user'] as Map<String, dynamic>,
      stranger = j['stranger'] as Map<String, dynamic>?,
      reservationId = j['reservationId'] as String?,
      timezone = j['timezone'] as String?,
      roles = (j['roles'] as List?)?.cast<String>() ?? const [] {
    client = SupabaseClient(
      url,
      anon,
      httpClient: wire,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    readback = SupabaseClient(url, service, httpClient: http.Client());
  }

  final String role;
  final String installationId;
  final String url;
  final String anon;
  final String service;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? stranger;
  final String? reservationId;
  final String? timezone;

  /// What the seed declared this stack to be (#2561 L1).
  final List<String> roles;
  final wire = _Wire();
  late final SupabaseClient client;
  late final SupabaseClient readback;

  String get userId => user['id'] as String;

  Future<void> signIn(
    SupabaseClient c,
    Map<String, dynamic> who,
    String password,
  ) async {
    final session = await c.auth.signInWithPassword(
      email: who['email'] as String,
      password: password,
    );
    expect(
      session.user?.id,
      who['id'],
      reason: '$role signed in as the seeded account',
    );
  }

  Future<int> rows(String table) async =>
      (await readback.from(table).select('id')).length;

  /// The roles the stack's own database holds, read with its service key.
  Future<List<String>> storedRoles() async {
    final row = await readback
        .from('installation_identity')
        .select('roles')
        .single();
    return (row['roles'] as List).cast<String>();
  }

  /// The anonymous descriptor, as any client reads it before trusting the
  /// installation.
  Future<Map<String, dynamic>> descriptor() async =>
      (await client.rpc<dynamic>('public_network_descriptor') as Map)
          .cast<String, dynamic>();
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

class _Resolver implements WorkspaceHostResolver {
  _Resolver(this.host);
  _Stack host;

  @override
  Future<ResolvedWorkspaceHost> resolve(String workspaceId) async =>
      ResolvedWorkspaceHost(
        installationId: host.installationId,
        client: host.client,
        localUserId: host.userId,
      );
}

void main() {
  if (_file == null) {
    test(
      'the topology stacks',
      () {},
      skip: 'needs the three stacks of the database job; set DESKILO_TOPOLOGY_FILE',
    );
    return;
  }
  late Map<String, dynamic> d;
  late String password;
  late String workspaceId;
  late _Stack p;
  late _Stack a;
  late _Stack b;
  late _Resolver resolver;
  late Workspace current;
  late ProviderContainer container;
  late SupabaseClient stranger;

  Workspace workspaceOf(_Stack s) => Workspace(
    id: workspaceId,
    name: 'Topology ${s.role}',
    countryCode: 'FR',
    currencyCode: 'EUR',
    timezone: s.timezone!,
    inviteCode: 'x',
  );

  /// Selects [s]'s workspace (the local id is equal on W-A and W-B).
  void select(_Stack s) {
    current = workspaceOf(s);
    resolver.host = s;
    container
      ..invalidate(currentWorkspaceProvider)
      ..invalidate(currentSettingsCaptureProvider)
      ..invalidate(workspaceContextProvider);
  }

  setUpAll(() async {
    // flutter_test replaces the HTTP client with one that answers 400.
    HttpOverrides.global = null;
    d = jsonDecode(File(_file!).readAsStringSync()) as Map<String, dynamic>;
    password = d['password'] as String;
    workspaceId = d['workspaceId'] as String;
    p = _Stack('P', 'inst-p', d['p'] as Map<String, dynamic>);
    a = _Stack('W-A', 'inst-wa', d['wa'] as Map<String, dynamic>);
    b = _Stack('W-B', 'inst-wb', d['wb'] as Map<String, dynamic>);
    await p.signIn(p.client, p.user, password);
    await a.signIn(a.client, a.user, password);
    await b.signIn(b.client, b.user, password);
    stranger = SupabaseClient(a.url, a.anon, httpClient: http.Client());
    await a.signIn(stranger, a.stranger!, password);
  });

  setUp(() {
    for (final s in [p, a, b]) {
      s.wire.paths.clear();
    }
    resolver = _Resolver(a);
    current = workspaceOf(a);
    container = ProviderContainer(
      overrides: [
        sessionStateProvider.overrideWith((ref) => Stream.value(p.userId)),
        authStateProvider.overrideWith((ref) => Stream.value(p.userId)),
        bootedBackendUrlProvider.overrideWithValue(p.url),
        contextClientsProvider.overrideWithValue(ContextClients(p.client)),
        connectedInstallationsProvider.overrideWithValue(
          ConnectedInstallations(p.client, const PlatformAuthSecretStore()),
        ),
        installationIdReaderProvider.overrideWithValue((client) async {
          final origin = Uri.parse(client.rest.url).origin;
          return [
            p,
            a,
            b,
          ].firstWhere((s) => Uri.parse(s.url).origin == origin).installationId;
        }),
        workspaceHostResolverProvider.overrideWithValue(resolver),
        settingsSourceProvider.overrideWithValue(_Settings()),
        currentWorkspaceProvider.overrideWith((ref) async => current),
        cacheStoreProvider.overrideWithValue(InMemoryCacheStore()),
        realtimeWorkspaceClientProvider.overrideWith(
          (ref) => ref.watch(selectedWorkspaceClientProvider),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  DateTime from() => DateTime.parse(d['windowFrom'] as String);
  DateTime to() => DateTime.parse(d['windowTo'] as String);

  Future<void> expectOperationalCountsZeroAtP() async {
    for (final table in ['workspaces', 'members', 'reservations', 'invoices']) {
      expect(await p.rows(table), 0, reason: 'P holds no operational $table');
    }
  }

  test('three services: distinct keys, and a token of one stack is refused '
      'by another while its own stack admits it', () async {
    expect({p.anon, a.anon, b.anon}, hasLength(3));
    expect({p.url, a.url, b.url}, hasLength(3));
    Future<int> reservationsWith(_Stack on, SupabaseClient who) async {
      final token = who.auth.currentSession!.accessToken;
      final r = await http.get(
        Uri.parse('${on.url}/rest/v1/reservations?select=id'),
        headers: {'apikey': on.anon, 'Authorization': 'Bearer $token'},
      );
      return r.statusCode;
    }

    expect(
      await reservationsWith(a, a.client),
      200,
      reason: 'positive control',
    );
    expect(
      await reservationsWith(b, b.client),
      200,
      reason: 'positive control',
    );
    expect(
      await reservationsWith(a, b.client),
      401,
      reason: 'W-B token at W-A',
    );
    expect(
      await reservationsWith(b, a.client),
      401,
      reason: 'W-A token at W-B',
    );
    expect(await reservationsWith(a, p.client), 401, reason: 'P token at W-A');
    expect(await reservationsWith(p, a.client), 401, reason: 'W-A token at P');
  });

  test(
    'the own-profile read and write reach P only, and the row is at P',
    () async {
      final sub = container.listen(authStateProvider, (_, _) {});
      addTearDown(sub.close);
      await expectOperationalCountsZeroAtP();
      final bio = 'Topology profile ${d['run']}';

      final before = await container.read(myVisibilityProvider.future);
      expect(before.bio, isNot(bio));
      await container.read(meActionsProvider).saveAbout('Maker', bio);

      // The consumer's own read sees it, and so does the database of P.
      container.invalidate(myVisibilityProvider);
      final after = await container.read(myVisibilityProvider.future);
      expect([after.profession, after.bio], ['Maker', bio]);
      final row = await p.readback
          .from('account_about')
          .select('profession, bio')
          .eq('user_id', p.userId)
          .single();
      expect(row, {'profession': 'Maker', 'bio': bio});

      // Nothing reached a workspace host; no workspace stack holds the text.
      expect(p.wire.count('/rpc/set_my_about'), 1);
      expect(p.wire.count('/rpc/my_visibility'), greaterThanOrEqualTo(2));
      expect(a.wire.paths, isEmpty);
      expect(b.wire.paths, isEmpty);
      for (final w in [a, b]) {
        final copies = await w.readback
            .from('account_about')
            .select('user_id')
            .eq('bio', bio);
        expect(
          copies,
          isEmpty,
          reason: '${w.role} never receives a profile write',
        );
      }
      await expectOperationalCountsZeroAtP();
    },
  );

  test('a reservation read reaches the selected W stack and returns its own '
      'row; the equal local workspace id on W-B reads W-B\'s', () async {
    final sub = container.listen(workspaceContextProvider, (_, _) {});
    addTearDown(sub.close);
    final repo = container.read(reservationRepositoryProvider);

    final fromA = await repo.fetchWindow(workspaceId, from: from(), to: to());
    expect(fromA.map((r) => r.id), [a.reservationId]);
    expect(a.wire.count('/rest/v1/reservations'), greaterThan(0));
    expect(b.wire.count('/rest/v1/reservations'), 0);
    expect(
      p.wire.count('/rest/v1/reservations'),
      0,
      reason: 'the personal home never serves workspace rows',
    );
    final storedA = await a.readback
        .from('reservations')
        .select('id, workspace_id')
        .eq('id', a.reservationId!)
        .single();
    expect(storedA['workspace_id'], workspaceId);

    select(b);
    await container.read(workspaceContextProvider.future);
    final fromB = await container
        .read(reservationRepositoryProvider)
        .fetchWindow(workspaceId, from: from(), to: to());
    expect(fromB.map((r) => r.id), [b.reservationId]);
    expect(b.wire.count('/rest/v1/reservations'), greaterThan(0));

    // The two hosts hold different rows under one workspace id.
    expect(
      await b.readback
          .from('reservations')
          .select('id')
          .eq('id', a.reservationId!),
      isEmpty,
    );
    expect(
      await a.readback
          .from('reservations')
          .select('id')
          .eq('id', b.reservationId!),
      isEmpty,
    );
    expect(p.wire.paths.where((x) => x.contains('/reservations')), isEmpty);
    await expectOperationalCountsZeroAtP();
  });

  test(
    'a wrong target is refused before any request, and nothing changed',
    () async {
      final sub = container.listen(workspaceContextProvider, (_, _) {});
      addTearDown(sub.close);
      final repo = container.read(reservationRepositoryProvider);
      final countsBefore = [
        await a.rows('reservations'),
        await b.rows('reservations'),
      ];
      const wrong = '00000000-0000-4000-8000-0000000e0fff';

      await expectLater(
        repo.fetchWindow(wrong, from: from(), to: to()),
        throwsA(isA<StaleWorkspaceContext>()),
      );
      for (final s in [p, a, b]) {
        expect(
          s.wire.count('/rest/v1/reservations'),
          0,
          reason: '${s.role} saw no request for the wrong target',
        );
      }
      expect([
        await a.rows('reservations'),
        await b.rows('reservations'),
      ], countsBefore);

      // The right target still answers: the refusal was about the target.
      final ok = await repo.fetchWindow(workspaceId, from: from(), to: to());
      expect(ok.map((r) => r.id), [a.reservationId]);
    },
  );

  test('SEP-06: the personal home refuses a workspace creation and writes no '
      'row, a workspace host accepts the same request and stamps its birth '
      'record, a role change over rows is refused, and every stack advertises '
      'its roles', () async {
    // The seed declared the roles through the operator function; each
    // database holds them and each anonymous descriptor advertises them.
    expect(p.roles, ['personal_home'], reason: 'the seed wrote the descriptor');
    expect(await p.storedRoles(), ['personal_home']);
    for (final w in [a, b]) {
      expect(
        await w.storedRoles(),
        ['personal_home', 'workspace_host'],
        reason: '${w.role} keeps both roles',
      );
    }
    final atP = await p.descriptor();
    expect(atP['roles'], ['personal_home']);
    expect(atP['role_capabilities'], ['personal@1']);
    final atA = await a.descriptor();
    expect(atA['roles'], ['personal_home', 'workspace_host']);
    expect(atA['role_capabilities'], ['personal@1', 'workspace@1']);

    // The creation the app performs (create_workspace_once, 0228), signed
    // by the stack's own user, with a request id of this run.
    final requestId =
        '0000000e-5e06-4000-8000-${'${d['run']}'.padLeft(12, '0')}';
    Map<String, Object?> creation(String name) => {
      'p_client_request_id': requestId,
      'p_name': name,
      'p_country_code': 'FR',
      'p_currency_code': 'EUR',
      'p_timezone': 'Europe/Paris',
      'p_with_twin': false,
    };
    Future<int> claimsAtP() async => (await p.readback
            .from('workspace_creation_requests')
            .select('client_request_id'))
        .length;
    await expectOperationalCountsZeroAtP();
    await expectLater(
      p.client.rpc<dynamic>('create_workspace_once', params: creation('SEP-06 refused')),
      throwsA(
        isA<PostgrestException>()
            .having((e) => e.code, 'code', 'DKR01')
            .having((e) => e.message, 'message', contains('personal home')),
      ),
    );
    await expectOperationalCountsZeroAtP();
    expect(await claimsAtP(), 0, reason: 'the claim rolled back with the refusal');

    // Positive control: the same request at W-A is a workspace, born there.
    final created = await a.client.rpc<dynamic>(
      'create_workspace_once',
      params: creation('SEP-06 control ${d['run']}'),
    ) as String;
    final host = await a.readback
        .from('installation_identity')
        .select('installation_id')
        .single();
    final born = await a.readback
        .from('workspaces')
        .select('network_id')
        .eq('id', created)
        .single();
    expect(born['network_id'], '${host['installation_id']}:$created');

    // A role change over W-A's rows is refused, and nothing moved.
    final before = [await a.rows('workspaces'), await a.rows('members')];
    await expectLater(
      a.readback.rpc<dynamic>(
        'operator_set_installation_roles',
        params: {'p_roles': ['personal_home']},
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', 'DKR02')),
    );
    expect(await a.storedRoles(), ['personal_home', 'workspace_host']);
    expect([await a.rows('workspaces'), await a.rows('members')], before);

    // At P the same change is the state it is in: accepted, unchanged.
    final again = await p.readback.rpc<dynamic>(
      'operator_set_installation_roles',
      params: {'p_roles': ['personal_home']},
    ) as Map;
    expect(again['unchanged'], true);
    expect(again['roles'], ['personal_home']);
    await expectOperationalCountsZeroAtP();
  });

  test('a stranger at W-A is denied the rows the member reads, and the rows '
      'exist', () async {
    final member = await a.client
        .from('reservations')
        .select('id')
        .eq('workspace_id', workspaceId);
    final outsider = await stranger
        .from('reservations')
        .select('id')
        .eq('workspace_id', workspaceId);
    final stored = await a.readback
        .from('reservations')
        .select('id')
        .eq('workspace_id', workspaceId)
        .eq('id', a.reservationId!);
    expect(stored, hasLength(1), reason: 'the row exists');
    expect(member.map((r) => r['id']), contains(a.reservationId));
    expect(outsider, isEmpty, reason: 'denied, not absent');
  });
}
