// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C5 — one host of my own documents is read through THAT host's own
// client: a connected installation through its origin, never another's;
// one not connected here, or answering as another installation, is
// refused. The limits are the personal home's own platform settings.
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_target.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/settings/active_settings.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/money/data/host_finance_reader.dart';
import 'package:deskilo/features/money/domain/finance_hosts.dart';
import 'package:deskilo/features/money/providers/finance_host_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _far = FinanceHost(
  installationId: 'inst-w-b',
  workspaceIds: ['ws-9'],
  labels: ['Lyon'],
);
const _connectedFar = ConnectedInstallation(
  endpoint: BackendEndpoint('https://w-b.test', 'sb_publishable_b'),
  account: 'local-b',
  installationId: 'inst-w-b',
);

class _Resolver implements WorkspaceHostResolver {
  _Resolver(this.installationId, this.client);

  final String installationId;
  final SupabaseClient client;
  final asked = <String>[];

  @override
  Future<ResolvedWorkspaceHost> resolve(String workspaceId) async {
    asked.add(workspaceId);
    return ResolvedWorkspaceHost(
      installationId: installationId,
      client: client,
      localUserId: 'local-b',
    );
  }
}

/// A host answering `my_finance_overview` with one CHF invoice and one
/// reminder, and `my_financial_activity` with one payment (or refusing it
/// when [paymentsDown]), recording what it was asked.
SupabaseClient _host(List<String> requests, {bool paymentsDown = false}) =>
    SupabaseClient(
  'https://w-b.test',
  'sb_publishable_b',
  httpClient: MockClient((request) async {
    requests.add('${request.url.host}${request.url.path}');
    if (request.url.path.endsWith('my_financial_activity')) {
      if (paymentsDown) {
        return http.Response(
          jsonEncode({'message': 'down', 'code': 'XX000'}),
          500,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      final params = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode([
          {
            'id': 'pay-b',
            'workspace_id': 'ws-9',
            'workspace_name': 'Lyon',
            'occurred_at': '2026-09-03T00:00:00Z',
            'reference': 'R-${params['p_kind']}',
            'description': 'Card',
            'currency': 'CHF',
            'status': 'succeeded',
            'amount_cents': 8000,
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    return http.Response(
      jsonEncode({
        'invoices': [
          {
            'id': 'b1',
            'workspace_id': 'ws-9',
            'workspace_name': 'Lyon',
            'number': 'L-1',
            'issued_at': '2026-09-01T00:00:00Z',
            'total_cents': 8000,
            'paid_cents': 0,
            'currency': 'CHF',
            'state': 'open',
          },
        ],
        'reminders': [
          {
            'id': 'r-b',
            'invoice_id': 'b1',
            'invoice_number': 'L-1',
            'workspace_name': 'Lyon',
            'sent_at': '2026-09-02T00:00:00Z',
            'level': 1,
            'automatic': true,
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }),
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

List<SettingDefinition> _rows() => [
  SettingDefinition(
    key: 'personal.read_concurrency',
    type: SettingType.integer,
    defaultValue: 3,
    group: 'personal',
    scopes: const {SettingScope.platform},
  ),
  SettingDefinition(
    key: 'personal.read_timeout_seconds',
    type: SettingType.integer,
    defaultValue: 7,
    group: 'personal',
    scopes: const {SettingScope.platform},
  ),
];

void main() {
  group('the host of a source', () {
    test('a connected host is asked through its own origin, on its own '
        'client, for my_finance_overview', () async {
      final requests = <String>[];
      final client = _host(requests);
      addTearDown(client.dispose);
      final origins = <String?>[];
      final resolver = _Resolver('inst-w-b', client);
      final reader = HostFinanceReader(
        hostOf: (host) => resolveFinanceHost(
          host,
          connected: () async => const [_connectedFar],
          resolverFor: (origin) {
            origins.add(origin);
            return resolver;
          },
        ),
      );
      final overview = await reader.overview(_far);
      expect(origins, ['https://w-b.test']);
      expect(resolver.asked, ['ws-9']);
      expect(requests, [
        'w-b.test/rest/v1/rpc/my_finance_overview',
        'w-b.test/rest/v1/rpc/my_financial_activity',
      ]);
      expect(overview.invoices.single.currency, 'CHF');
      expect(overview.invoices.single.totalCents, 8000);
      // C6 — the host's payments and reminders come with its invoices, each
      // identified by workspace and id.
      final payment = overview.payments.single;
      expect((payment.workspaceId, payment.id), ('ws-9', 'pay-b'));
      expect(payment.reference, 'R-payments');
      final reminder = overview.reminders.single;
      expect((reminder.workspaceId, reminder.id), ('ws-9', 'r-b'));
    });

    test('a host that refuses my payments fails as a whole: no invoices '
        'without their payments', () async {
      final requests = <String>[];
      final client = _host(requests, paymentsDown: true);
      addTearDown(client.dispose);
      final reader = HostFinanceReader(
        hostOf: (_) async => ResolvedWorkspaceHost(
          installationId: 'inst-w-b',
          client: client,
          localUserId: 'local-b',
        ),
      );
      await expectLater(reader.overview(_far), throwsA(anything));
      expect(requests.last, 'w-b.test/rest/v1/rpc/my_financial_activity');
    });

    test('a host not connected here is refused, no resolver asked', () async {
      var resolved = false;
      await expectLater(
        resolveFinanceHost(
          _far,
          connected: () async => const [],
          resolverFor: (_) {
            resolved = true;
            throw StateError('not asked');
          },
        ),
        throwsA(isA<FinanceHostUnavailable>()),
      );
      expect(resolved, isFalse);
    });

    test('a host that answers as another installation is refused before '
        'anything is read', () async {
      final requests = <String>[];
      final client = _host(requests);
      addTearDown(client.dispose);
      final reader = HostFinanceReader(
        hostOf: (_) async => ResolvedWorkspaceHost(
          installationId: 'inst-other',
          client: client,
          localUserId: 'local-b',
        ),
      );
      await expectLater(
        reader.overview(_far),
        throwsA(isA<FinanceHostUnavailable>()),
      );
      expect(requests, isEmpty);
    });
  });

  group('the limits', () {
    Future<FinanceReadLimits> limits(SettingsSet? settings) {
      final container = ProviderContainer(
        overrides: [
          platformSettingsProvider.overrideWith((ref) async => settings),
        ],
      );
      addTearDown(container.dispose);
      return container.read(financeReadLimitsProvider.future);
    }

    test('are the personal home\'s platform settings', () async {
      final read = await limits(SettingsSet.defaults(_rows()));
      expect(read.concurrency, 3);
      expect(read.timeout, const Duration(seconds: 7));
    });

    test('a registry without the rows fails typed, once', () async {
      await expectLater(
        limits(SettingsSet.defaults(const [])),
        throwsA(isA<UnknownSetting>()),
      );
    });

    test('signed out, there are none', () async {
      await expectLater(limits(null), throwsA(isA<FinanceHostUnavailable>()));
    });
  });
}
