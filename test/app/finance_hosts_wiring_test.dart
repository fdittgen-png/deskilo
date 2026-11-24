// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4218 — the REAL wiring of My finances' commands (not the Demo's
// replacement, and not a stub of the entry provider): two hosts hold the same
// local workspace id, a command captured for each reaches its own host and its
// own business, and a host that cannot be reached or verified is no entry —
// the wiring answers null, never an error thrown past the page.
import 'dart:convert';

import 'package:deskilo/app/finance_hosts_wiring.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/backend/operation_context.dart'
    show WorkspaceTarget;
import 'package:deskilo/core/codes/pg_code.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/features/money/application/finance_selection_commands.dart';
import 'package:deskilo/features/money/providers/finance_selection_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/installation_auth_storage.dart' show MemorySecrets;
import '../helpers/native_federation_flow.dart' show session, user;

const _ws = 'ws-1';

/// One fake installation: its own session, identity, one workspace under the
/// shared local id [_ws] with a name of its own, and the member there.
class _Host {
  _Host(this.name, this.account, this.business) : installationId = 'inst-$name';
  final String name, account, business;
  String installationId;
  final seen = <String>[];

  /// The workspace read answers a server error, or throws a defect.
  bool workspacesFail = false, workspacesDefect = false;

  String get origin => 'https://$name.example';
  BackendEndpoint get endpoint =>
      BackendEndpoint(origin, 'sb_publishable_${name}_target');

  Future<http.Response> handle(http.Request r) async {
    seen.add('${r.method} ${r.url.path}');
    Object? body;
    switch (r.url.path) {
      case '/auth/v1/token':
        body = session(account);
      case '/auth/v1/user':
        body = user(account);
      case '/rest/v1/installation_identity':
        body = {'installation_id': installationId};
      case '/rest/v1/rpc/public_network_descriptor':
        // an older server without the descriptor: connectable, as before
        return http.Response(
          jsonEncode({'code': PgCode.pgrstFunctionNotFound, 'message': 'not found'}),
          404,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      case '/rest/v1/workspaces':
        if (workspacesDefect) throw StateError('a defect, not a host');
        if (workspacesFail) {
          return http.Response(
            jsonEncode({'code': 'XX000', 'message': 'down'}),
            500,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }
        body = [
          {
            'id': _ws,
            'name': business,
            'country_code': 'FR',
            'currency_code': 'EUR',
            'timezone': 'Europe/Paris',
            'invite_code': 'x',
          },
        ];
      case '/rest/v1/members':
        body = {
          'id': 'member-$name',
          'workspace_id': _ws,
          'user_id': account,
          'is_admin': true,
          'is_owner': false,
          'status': 'active',
        };
      case '/rest/v1/rpc/withdraw_payment_declaration':
        body = null;
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

  /// What this host was asked, other than signing in and who it is.
  List<String> get asked => [
    for (final p in seen)
      if (!p.contains('/auth/') && !p.contains('installation_identity')) p,
  ];
}

void main() {
  late _Host home, lyon;
  late SupabaseClient rootClient;
  late ConnectedInstallations pool;
  late ProviderContainer container;

  http.Client wire() => MockClient((r) {
    final host = [
      home,
      lyon,
    ].firstWhere((h) => h.name == r.url.host.split('.').first);
    return host.handle(r);
  });

  Future<FinanceCommandTarget?> enter(String installation) async {
    await container.read(sessionStateProvider.future);
    final target = WorkspaceTarget.local(
      installationId: installation,
      workspaceId: _ws,
    );
    return container.read(financeWorkspaceEntryProvider)(target);
  }

  setUp(() async {
    // Two hosts, ONE local workspace id: the second is the connected one.
    home = _Host('home', 'p-user', 'Atelier');
    lyon = _Host('lyon', 'lyon-user', 'Lyon');
    rootClient = SupabaseClient(
      home.origin,
      'sb_publishable_home',
      httpClient: wire(),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await rootClient.auth.setInitialSession(jsonEncode(session('p-user')));
    pool = ConnectedInstallations(rootClient, MemorySecrets(), transport: wire);
    await pool.connect(lyon.endpoint, 'user@example.test', 'password');
    container = ProviderContainer(
      overrides: [
        sessionStateProvider.overrideWith((ref) => Stream.value('p-user')),
        personalClientProvider.overrideWithValue(rootClient),
        installationIdReaderProvider.overrideWithValue(readInstallationId),
        connectedInstallationsProvider.overrideWithValue(pool),
        financeWorkspaceEntryFromApp,
      ],
    );
    addTearDown(container.dispose);
    // a provider nobody listens to is paused: its stream would never emit
    final keep = container.listen(sessionStateProvider, (_, _) {});
    addTearDown(keep.close);
    home.seen.clear();
    lyon.seen.clear();
  });

  tearDown(() async {
    pool.close();
    await rootClient.dispose();
  });

  test('a command captured for each of two hosts holding the same local '
      'workspace id reaches its own host and its own business', () async {
    final here = await enter('inst-home');
    final there = await enter('inst-lyon');
    expect(here, isNotNull);
    expect(there, isNotNull);
    expect(
      (here!.businessName, there!.businessName),
      ('Atelier', 'Lyon'),
      reason: 'the same local id names a different business on each host',
    );
    expect(
      (here.memberId, there.memberId),
      ('member-home', 'member-lyon'),
      reason: 'my member is the one of that host',
    );
    expect(
      (here.target.financeKey, there.target.financeKey),
      ('inst-home:ws-1', 'inst-lyon:ws-1'),
      reason: 'one identity per host: installation and workspace',
    );
    expect(here.target == there.target, isFalse);

    // A command of each runs on its own host and on no other.
    home.seen.clear();
    lyon.seen.clear();
    await here.commands.withdrawPaymentDeclaration(
      workspaceId: _ws,
      eventId: 'e-1',
    );
    expect(home.asked, ['POST /rest/v1/rpc/withdraw_payment_declaration']);
    expect(lyon.asked, isEmpty);
    home.seen.clear();
    await there.commands.withdrawPaymentDeclaration(
      workspaceId: _ws,
      eventId: 'e-2',
    );
    expect(lyon.asked, ['POST /rest/v1/rpc/withdraw_payment_declaration']);
    expect(
      home.asked,
      isEmpty,
      reason: 'the home host never hears of Lyon\'s command',
    );
    here.release();
    there.release();
  });

  test('a host that is not connected here is no entry, and nothing is '
      'thrown past the page', () async {
    expect(await enter('inst-gone'), isNull);
  });

  test('a host that answers as another installation is not verified: no '
      'entry, and nothing is thrown', () async {
    lyon.installationId = 'inst-replaced';
    expect(await enter('inst-lyon'), isNull);
    expect(home.asked, isEmpty, reason: 'the home host is not asked instead');
  });

  test('a host that fails while it is entered (a server error on its '
      'workspaces) is no entry, and nothing is thrown', () async {
    home.workspacesFail = true;
    expect(await enter('inst-home'), isNull);
  });

  test('a defect is not turned into "cannot be reached": it goes on', () async {
    home.workspacesDefect = true;
    await expectLater(enter('inst-home'), throwsStateError);
  });
}
