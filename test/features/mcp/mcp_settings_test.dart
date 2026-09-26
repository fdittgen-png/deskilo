// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1626 — the owner's policy: server state shown, groups by process,
// Save sends the expected revision with one mutation id, a concurrent
// change is reviewed, not overwritten; broadening says existing
// assistants need fresh consent; with mcpAccess off it can only narrow.
// #1627 — approvals need a real second factor; a wrong code decides
// nothing; one decision id per request. #1628 — the person's own
// eligibility and connections: remove one workspace, disconnect only
// after confirming.
import 'package:deskilo/core/demo/data/identity_binding_repository.dart';
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/core/demo/data/mcp_connection_repository.dart';
import 'package:deskilo/features/auth/domain/database_capabilities.dart';
import 'package:deskilo/features/mcp/application/eligibility_review.dart';
import 'package:deskilo/features/mcp/application/mcp_policy_editor.dart';
import 'package:deskilo/features/mcp/domain/mcp_admin.dart';
import 'package:deskilo/features/mcp/domain/mcp_connection.dart';
import 'package:deskilo/features/mcp/presentation/assistants_screen.dart';
import 'package:deskilo/features/mcp/presentation/eligibility_review_screen.dart';
import 'package:deskilo/features/mcp/presentation/mcp_policy_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<void> pump(
  WidgetTester tester,
  Widget home,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(800, 2000);
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

McpPolicy policy(
  String ws, {
  bool feature = true,
  int revision = 1,
  Set<String> ops = const {'get_capabilities'},
}) => McpPolicy(
  workspaceId: ws,
  revision: revision,
  enabled: revision > 0,
  operations: ops,
  targetCeiling: 'own',
  featureEnabled: feature,
  available: const [
    'get_capabilities',
    'create_reservation',
    'request_refund',
    'request_member_status_change',
    'respond_to_validation',
  ],
);

const _request = EligibilityRequest(
  requestId: 'r-1',
  userId: 'u-1',
  email: 'ada@deskilo.test',
  revision: 2,
);

void main() {
  group('grouping and DTOs', () {
    test('operations fall into their process groups', () {
      expect(mcpOperationGroup('create_reservation'), McpOperationGroup.own);
      expect(mcpOperationGroup('request_refund'), McpOperationGroup.financial);
      expect(
        mcpOperationGroup('request_subscription_change'),
        McpOperationGroup.membership,
      );
      expect(
        mcpOperationGroup('get_validation'),
        McpOperationGroup.validations,
      );
    });
    test('a stale save is its own outcome; anything unknown is a conflict', () {
      expect(
        PolicySaveResult.fromJson({
          'status': 'conflict',
          'reason': 'stale_revision',
          'revision': 4,
        }).status,
        PolicySaveStatus.stale,
      );
      expect(
        PolicySaveResult.fromJson({'status': 'weird'}).status,
        PolicySaveStatus.conflict,
      );
      expect(
        eligibilityDecisionFromJson({'status': 'decided'}),
        EligibilityDecisionStatus.decided,
      );
      expect(
        eligibilityDecisionFromJson(null),
        EligibilityDecisionStatus.refused,
      );
    });
  });

  group('the owner policy (#1626)', () {
    testWidgets(
      'shows the server state, saves once with the expected revision',
      (tester) async {
        final workspace = FakeWorkspaceRepository.withWorkspace();
        final ws = workspace.workspaces.first.id;
        final admin = FakeMcpAdminRepository(policy: policy(ws));
        await pump(
          tester,
          const McpPolicyScreen(),
          standardTestOverrides(workspace: workspace, mcpAdmin: admin),
        );
        expect(find.text('Financial requests'), findsOneWidget);
        expect(find.text('Membership requests'), findsOneWidget);
        final refund = find.byKey(
          const ValueKey('mcp-policy-op-request_refund'),
        );
        expect(tester.widget<CheckboxListTile>(refund).value, isFalse);
        await tester.tap(refund);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('mcp-policy-broadening')),
          findsOneWidget,
          reason:
              'adding a service says connected assistants need fresh consent',
        );
        await tester.tap(find.byKey(const ValueKey('mcp-policy-save')));
        await tester.pumpAndSettle();
        expect(admin.saves.single.expected, 1);
        expect(admin.saves.single.operations, {
          'get_capabilities',
          'request_refund',
        });
        expect(find.byKey(const ValueKey('mcp-policy-saved')), findsOneWidget);
      },
    );

    testWidgets(
      'a concurrent change is a conflict to review, never an overwrite',
      (tester) async {
        final workspace = FakeWorkspaceRepository.withWorkspace();
        final admin = FakeMcpAdminRepository(
          policy: policy(workspace.workspaces.first.id),
        )..nextSave = PolicySaveStatus.stale;
        await pump(
          tester,
          const McpPolicyScreen(),
          standardTestOverrides(workspace: workspace, mcpAdmin: admin),
        );
        await tester.tap(find.byKey(const ValueKey('mcp-policy-save')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('mcp-policy-stale')), findsOneWidget);
      },
    );

    testWidgets('with mcpAccess off, services cannot be switched on', (
      tester,
    ) async {
      final workspace = FakeWorkspaceRepository.withWorkspace();
      final admin = FakeMcpAdminRepository(
        policy: policy(
          workspace.workspaces.first.id,
          feature: false,
          revision: 0,
          ops: {},
        ),
      );
      await pump(
        tester,
        const McpPolicyScreen(),
        standardTestOverrides(workspace: workspace, mcpAdmin: admin),
      );
      expect(
        find.byKey(const ValueKey('mcp-policy-feature-off')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('mcp-policy-enabled')),
            )
            .onChanged,
        isNull,
      );
    });

    test(
      'a retried save keeps its mutation id; a new draft gets a new one',
      () {
        final base = policy('w');
        final a = McpPolicyDraft.from(base);
        final b = McpPolicyDraft.from(base);
        expect(a.mutationId, isNot(b.mutationId));
        expect(a.expectedRevision, 1);
      },
    );
  });

  group('eligibility review (#1627)', () {
    testWidgets('a decision waits for a verified second factor', (
      tester,
    ) async {
      final identity = FakeIdentityBindingRepository()
        ..capabilities = const DatabaseCapabilities(
          eligibility: McpEligibility.notRequested,
          databaseAdministrator: true,
        );
      final admin = FakeMcpAdminRepository(requests: [_request]);
      final factor = FakeSecondFactorRepository();
      await pump(
        tester,
        const EligibilityReviewScreen(),
        standardTestOverrides(
          identityBinding: identity,
          mcpAdmin: admin,
          secondFactor: factor,
        ),
      );
      expect(find.text('ada@deskilo.test'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mcp-review-approve-r-1')));
      await tester.pumpAndSettle();
      expect(
        factor.enrollments,
        1,
        reason: 'no authenticator yet: one is enrolled',
      );
      expect(find.byKey(const ValueKey('mfa-secret')), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('mfa-code')), '000000');
      await tester.tap(find.byKey(const ValueKey('mfa-verify')));
      await tester.pumpAndSettle();
      expect(admin.decisions, isEmpty, reason: 'a wrong code decides nothing');

      await tester.enterText(find.byKey(const ValueKey('mfa-code')), '123456');
      await tester.tap(find.byKey(const ValueKey('mfa-verify')));
      await tester.pumpAndSettle();
      expect(admin.decisions.single.approve, isTrue);
      expect(
        find.byKey(const ValueKey('mcp-review-outcome-decided')),
        findsOneWidget,
      );
    });

    testWidgets('a non-administrator is told, and sees no queue', (
      tester,
    ) async {
      await pump(
        tester,
        const EligibilityReviewScreen(),
        standardTestOverrides(),
      );
      expect(find.byKey(const ValueKey('mcp-review-message')), findsOneWidget);
    });

    test(
      'one decision id per request and answer; no aal2, no decision',
      () async {
        final admin = FakeMcpAdminRepository(requests: [_request, _request]);
        final factor = FakeSecondFactorRepository();
        final review = EligibilityReview(admin, factor);
        expect(
          await review.decide(_request, approve: true),
          EligibilityDecisionStatus.refused,
        );
        factor.aal2 = true;
        await review.decide(_request, approve: true);
        await review.decide(_request, approve: true);
        expect(admin.decisions.map((d) => d.decisionId).toSet(), hasLength(1));
      },
    );
  });

  group('connected assistants (#1628)', () {
    FakeMcpConnectionRepository connections() =>
        FakeMcpConnectionRepository()
          ..live.add(
            const McpConnectionInfo(
              clientId: 'claude',
              clientName: 'Test assistant',
              workspaces: [
                ConsentWorkspace(
                  id: 'wa',
                  name: 'Kraftwerk',
                  operations: ['check_in'],
                ),
                ConsentWorkspace(
                  id: 'wb',
                  name: 'Atelier',
                  operations: ['list_my_invoices'],
                ),
              ],
            ),
          );

    testWidgets('removing one workspace leaves the connection', (tester) async {
      final r = connections();
      await pump(
        tester,
        const AssistantsScreen(),
        standardTestOverrides(mcpConnections: r),
      );
      expect(find.text('Kraftwerk'), findsOneWidget);
      expect(find.text('Check you in'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mcp-remove-claude-wa')));
      await tester.pumpAndSettle();
      expect(r.calls, ['revokeScope:claude:wa']);
    });

    testWidgets('disconnecting asks first; cancelling does nothing', (
      tester,
    ) async {
      final r = connections();
      await pump(
        tester,
        const AssistantsScreen(),
        standardTestOverrides(mcpConnections: r),
      );
      await tester.tap(find.byKey(const ValueKey('mcp-disconnect-claude')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(r.calls, isEmpty);
      await tester.tap(find.byKey(const ValueKey('mcp-disconnect-claude')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mcp-disconnect-confirm')));
      await tester.pumpAndSettle();
      expect(r.calls, ['disconnect:claude']);
      expect(
        find.byKey(const ValueKey('mcp-connections-none')),
        findsOneWidget,
      );
    });

    testWidgets(
      'a person asks for eligibility; the answer is "requested", never approved',
      (tester) async {
        final identity = FakeIdentityBindingRepository()
          ..capabilities = const DatabaseCapabilities(
            eligibility: McpEligibility.notRequested,
          );
        await pump(
          tester,
          const AssistantsScreen(),
          standardTestOverrides(identityBinding: identity),
        );
        await tester.tap(find.byKey(const ValueKey('mcp-eligibility-request')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('mcp-eligibility-requested')),
          findsOneWidget,
        );
      },
    );
  });
}
