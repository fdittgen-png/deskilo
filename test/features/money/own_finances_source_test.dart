// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances reads each host for its own documents: the personal home
// for the installation the app is signed in to, and — only while the
// selected workspace lives on a connected installation — that host, on the
// selected workspace's own client. A host that does not answer is named
// above the lists while the others stay on screen; without a connected
// selection the connected repository is never asked.
import 'dart:convert';

import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/presentation/screens/my_finances_screen.dart';
import 'package:deskilo/features/money/providers/account_activity_providers.dart';
import 'package:deskilo/features/money/providers/credit_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/screens/my_finances_screen.dart' show invoice;

/// A repository that counts how often it was asked.
class _Host extends FakeAccountActivityRepository {
  int reads = 0;

  @override
  Future<FinanceOverview> overview() {
    reads++;
    return super.overview();
  }
}

const _remote = 'https://two.example';

Future<({_Host home, _Host remote})> pump(
  WidgetTester tester, {
  bool remoteDown = false,
}) async {
  final home = _Host()
    ..financeOverview = FinanceOverview(invoices: [invoice('p1')]);
  final remote = _Host()
    ..unavailable = remoteDown
    ..financeOverview = FinanceOverview(
      invoices: [invoice('w1', ws: 'Remote Two')],
    );
  await pumpApp(
    tester,
    const MyFinancesScreen(),
    size: const Size(800, 1400),
    overrides: [
      ...standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        accountActivity: home,
      ),
      selectedWorkspaceAccountActivityRepositoryProvider.overrideWithValue(
        remote,
      ),
    ],
  );
  await tester.pumpAndSettle();
  return (home: home, remote: remote);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MyFinancesScreen)));

Future<void> _selectRemote(WidgetTester tester) async {
  _container(tester)
      .read(selectedWorkspaceHostProvider.notifier)
      .select('ws-Remote Two', _remote);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without a connected selection only the personal home answers', (
    tester,
  ) async {
    final hosts = await pump(tester);
    expect(find.byKey(const ValueKey('finances-invoice-p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-invoice-w1')), findsNothing);
    expect(hosts.home.reads, 1);
    expect(
      hosts.remote.reads,
      0,
      reason: 'no connected installation is selected: nothing to ask',
    );
  });

  testWidgets(
    'a selected connected workspace adds its own documents, read on its '
    'own repository',
    (tester) async {
      final hosts = await pump(tester);
      await _selectRemote(tester);
      expect(find.byKey(const ValueKey('finances-invoice-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('finances-invoice-w1')), findsOneWidget);
      expect(hosts.remote.reads, 1);
      expect(
        find.byKey(const ValueKey('finances-source-unavailable-two.example')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a connected host that does not answer is named; the personal home\'s '
    'documents stay, and the banner retries that host',
    (tester) async {
      final hosts = await pump(tester, remoteDown: true);
      await _selectRemote(tester);
      expect(
        find.byKey(const ValueKey('finances-invoice-p1')),
        findsOneWidget,
        reason: 'a healthy source renders while another stalls',
      );
      expect(
        find.byKey(const ValueKey('finances-retry')),
        findsNothing,
        reason: 'one host down is not the whole overview failing',
      );
      final banner = find.byKey(
        const ValueKey('finances-source-unavailable-two.example'),
      );
      expect(banner, findsOneWidget);
      expect(find.textContaining('two.example'), findsOneWidget);

      hosts.remote.unavailable = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(hosts.remote.reads, 2);
      expect(find.byKey(const ValueKey('finances-invoice-w1')), findsOneWidget);
      expect(banner, findsNothing);
    },
  );

  test(
    'the selected workspace repository runs my_finance_overview on the '
    'selected workspace\'s client — that installation answers, no other',
    () async {
      final requests = <String>[];
      final client = SupabaseClient(
        'https://w.example',
        'sb_publishable_w',
        httpClient: MockClient((request) async {
          requests.add('${request.url.host}${request.url.path}');
          return http.Response(
            jsonEncode({
              'invoices': [
                {
                  'id': 'w1',
                  'workspace_id': 'ws-w',
                  'workspace_name': 'W',
                  'number': 'W-1',
                  'issued_at': '2026-09-01T00:00:00Z',
                  'total_cents': 100,
                  'paid_cents': 0,
                  'currency': 'CHF',
                  'state': 'open',
                },
              ],
              'reminders': <Object>[],
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final container = ProviderContainer(
        overrides: [moneyClientProvider.overrideWithValue(client)],
      );
      addTearDown(() async {
        container.dispose();
        await client.dispose();
      });
      final overview = await container
          .read(selectedWorkspaceAccountActivityRepositoryProvider)
          .overview();
      expect(requests, ['w.example/rest/v1/rpc/my_finance_overview']);
      expect(overview.invoices.single.currency, 'CHF');
    },
  );

  test('merging two hosts keeps each document once and both unavailable '
      'marks', () {
    final a = FinanceOverview(invoices: [invoice('1'), invoice('2')]);
    final b = FinanceOverview(invoices: [invoice('2'), invoice('3')])
        .withUnavailable('https://three.example');
    final merged = a.merge(b);
    expect(merged.invoices.map((i) => i.id), ['1', '2', '3']);
    expect(merged.unavailableSources, ['https://three.example']);
    expect(merged.inWorkspace('ws-Office A').unavailableSources, [
      'https://three.example',
    ], reason: 'a filter keeps the fact that a host did not answer');
  });
}
