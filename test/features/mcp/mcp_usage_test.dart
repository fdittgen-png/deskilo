// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1630 — assistant usage read back as counts: the owner's policy screen
// shows the workspace's last 30 days, the assistants screen the person's
// own use today; Demo (no rows) shows zeros; an answer for another
// workspace is refused, not shown.
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/core/demo/data/mcp_connection_repository.dart';
import 'package:deskilo/features/mcp/domain/mcp_admin.dart';
import 'package:deskilo/features/mcp/domain/mcp_usage.dart';
import 'package:deskilo/features/mcp/presentation/assistants_screen.dart';
import 'package:deskilo/features/mcp/presentation/mcp_policy_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

McpPolicy _policy(String ws) => McpPolicy(
  workspaceId: ws,
  revision: 1,
  enabled: true,
  operations: const {'get_capabilities'},
  targetCeiling: 'own',
  featureEnabled: true,
  available: const ['get_capabilities', 'request_subscription_change'],
);

String _figure(WidgetTester tester, Finder scope, String key) {
  final column = find.descendant(
    of: scope,
    matching: find.byKey(ValueKey('mcp-usage-$key')),
  );
  return tester
      .widget<Text>(
        find.descendant(of: column.first, matching: find.byType(Text)).first,
      )
      .data!;
}

void main() {
  group('DTOs', () {
    test('a person\'s usage parses per assistant, today\'s counts apart', () {
      final list = McpClientUsage.listFromJson({
        'clients': [
          {
            'client_id': 'claude',
            'client_name': 'Test assistant',
            'requests_today': 9,
            'refusals': 3,
            'applied': 2,
            'pending_validation': 1,
            'last_used_at': '2026-09-28T10:00:00Z',
          },
          {'no_client': true},
        ],
      });
      expect(list, hasLength(1));
      expect(list.single.today.requests, 9);
      expect(list.single.today.refusals, 3);
      expect(list.single.today.applied, 2);
      expect(list.single.today.pendingValidation, 1);
      expect(list.single.lastUsedAt, DateTime.utc(2026, 9, 28, 10));
      expect(McpClientUsage.listFromJson(null), isEmpty);
    });

    test('a workspace summary totals per operation, busiest first', () {
      final u = McpWorkspaceUsage.fromJson({
        'workspace_id': 'w',
        'rows': [
          {
            'day': '2026-09-28',
            'operation': 'get_capabilities',
            'requests': 8,
            'refusals': 3,
          },
          {
            'day': '2026-09-28',
            'operation': 'request_subscription_change',
            'requests': 3,
            'applied': 2,
            'pending_validation': 1,
          },
          {
            'day': '2026-09-26',
            'operation': 'request_subscription_change',
            'requests': 6,
          },
        ],
      });
      expect(u.workspaceId, 'w');
      expect(u.total.requests, 17);
      expect(u.total.refusals, 3);
      expect(u.total.applied, 2);
      expect(u.total.pendingValidation, 1);
      expect(u.byOperation.map((o) => o.operation), [
        'request_subscription_change',
        'get_capabilities',
      ]);
      expect(u.byOperation.first.counts.requests, 9);
    });
  });

  group('the owner\'s usage card', () {
    testWidgets('shows the workspace\'s 30-day counts', (tester) async {
      final workspace = FakeWorkspaceRepository.withWorkspace();
      final ws = workspace.workspaces.first.id;
      final admin = FakeMcpAdminRepository(policy: _policy(ws))
        ..usage = [
          (
            day: DateTime.utc(2026, 9, 28),
            operation: 'get_capabilities',
            counts: const McpUsageCounts(requests: 8, refusals: 3),
          ),
          (
            day: DateTime.utc(2026, 9, 28),
            operation: 'request_subscription_change',
            counts: const McpUsageCounts(
              requests: 3,
              applied: 2,
              pendingValidation: 1,
            ),
          ),
        ];
      await _pump(
        tester,
        const McpPolicyScreen(),
        standardTestOverrides(workspace: workspace, mcpAdmin: admin),
      );
      final card = find.byKey(const ValueKey('mcp-usage-workspace'));
      expect(card, findsOneWidget);
      expect(find.text('Assistant use, last 30 days'), findsOneWidget);
      expect(_figure(tester, card, 'requests'), '11');
      expect(_figure(tester, card, 'refusals'), '3');
      expect(_figure(tester, card, 'applied'), '2');
      expect(_figure(tester, card, 'pending'), '1');
      expect(
        find.byKey(const ValueKey('mcp-usage-op-get_capabilities')),
        findsOneWidget,
      );
    });

    testWidgets('Demo has no usage: zeros', (tester) async {
      final workspace = FakeWorkspaceRepository.withWorkspace();
      final admin = FakeMcpAdminRepository(
        policy: _policy(workspace.workspaces.first.id),
      );
      await _pump(
        tester,
        const McpPolicyScreen(),
        standardTestOverrides(workspace: workspace, mcpAdmin: admin),
      );
      final card = find.byKey(const ValueKey('mcp-usage-workspace'));
      for (final key in ['requests', 'refusals', 'applied', 'pending']) {
        expect(_figure(tester, card, key), '0');
      }
    });

    testWidgets('an answer for another workspace is refused, not shown', (
      tester,
    ) async {
      final workspace = FakeWorkspaceRepository.withWorkspace();
      final admin = _ForeignUsage(
        policy: _policy(workspace.workspaces.first.id),
      );
      await _pump(
        tester,
        const McpPolicyScreen(),
        standardTestOverrides(workspace: workspace, mcpAdmin: admin),
      );
      expect(
        find.byKey(const ValueKey('mcp-usage-workspace-unavailable')),
        findsOneWidget,
      );
      expect(find.text('42'), findsNothing);
    });
  });

  group('the person\'s own usage', () {
    testWidgets('one card per assistant with today\'s counts', (tester) async {
      final r = FakeMcpConnectionRepository()
        ..usage.add(
          McpClientUsage(
            clientId: 'claude',
            clientName: 'Test assistant',
            today: const McpUsageCounts(
              requests: 9,
              refusals: 3,
              applied: 2,
              pendingValidation: 1,
            ),
            lastUsedAt: DateTime.utc(2026, 9, 28, 10),
          ),
        );
      await _pump(
        tester,
        const AssistantsScreen(),
        standardTestOverrides(mcpConnections: r),
      );
      expect(find.text('Your assistant use today'), findsOneWidget);
      final card = find.byKey(const ValueKey('mcp-usage-client-claude'));
      await tester.scrollUntilVisible(card, 200);
      expect(_figure(tester, card, 'requests'), '9');
      expect(_figure(tester, card, 'refusals'), '3');
      expect(_figure(tester, card, 'applied'), '2');
      expect(_figure(tester, card, 'pending'), '1');
      expect(find.textContaining('Last used'), findsOneWidget);
    });

    testWidgets('Demo: nobody used an assistant, zeros', (tester) async {
      await _pump(
        tester,
        const AssistantsScreen(),
        standardTestOverrides(mcpConnections: FakeMcpConnectionRepository()),
      );
      expect(find.byKey(const ValueKey('mcp-usage-mine-none')), findsOneWidget);
      final mine = find.byKey(const ValueKey('mcp-usage-mine'));
      expect(_figure(tester, mine, 'requests'), '0');
    });
  });
}

class _ForeignUsage extends FakeMcpAdminRepository {
  _ForeignUsage({super.policy});

  @override
  Future<McpWorkspaceUsage> workspaceUsage(String workspaceId) async =>
      const McpWorkspaceUsage(
        workspaceId: 'someone-else',
        rows: [
          (
            day: null,
            operation: 'get_capabilities',
            counts: McpUsageCounts(requests: 42),
          ),
        ],
      );
}
