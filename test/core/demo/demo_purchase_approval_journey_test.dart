// SPDX-License-Identifier: AGPL-3.0-or-later
// #3070: a Demo approver opens a pending supplier bill, decides it and sees
// the queue refresh; member receipts stay in the separate validation flow.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/purchase_approval_reads.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_seed.dart';
import 'package:deskilo/features/money/presentation/screens/purchase_approvals_screen.dart';
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/demo_journey.dart';

void main() {
  testWidgets('Demo bill opens, is decided, and leaves the queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final demo = seedDemoPurchasing(DateTime(2026, 11, 2));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseApprovalAccessProvider.overrideWith((ref, id) => true),
          purchaseRepositoryProvider.overrideWithValue(demo.purchases),
          purchaseApprovalReadsProvider.overrideWithValue(
            FakePurchaseApprovalReads(demo.purchases),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PurchaseApprovalsView(workspaceId: 'ws-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('approval-demo-bill-approval')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('approval-demo-receipt-pending')),
      findsNothing,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PurchaseApprovalsView)),
    );
    final first = await container.read(
      purchaseApprovalPageProvider((workspaceId: 'ws-1', after: null)).future,
    );
    await tester.tap(find.byKey(const ValueKey('approval-demo-bill-approval')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-line-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('purchase-approve')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('approval-demo-bill-approval')),
      findsNothing,
    );
    final after = await container.read(
      purchaseApprovalPageProvider((workspaceId: 'ws-1', after: null)).future,
    );
    expect(after.count, first.count - 1);
  });
  testWidgets(
    'Demo approver-only reaches the queue and decides another maker bill',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final journey = DemoJourney.start(persona: DemoPersona.member);
      addTearDown(journey.dispose);
      final spaces = journey.fixture.workspaces.workspaces;
      final home = spaces.indexWhere((w) => w.id == 'ws-1');
      spaces[home] = spaces[home].copyWith(
        rolePermissions: {
          'member': ['approveExpenses', 'viewMyMoney'],
        },
      );
      journey.root
          .read(pendingDemoLinkProvider.notifier)
          .hold(
            DemoLink.parse({
              'space': 'pezenas',
              'persona': 'member',
              'to': '/money/purchases',
            }),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: journey.root,
          child: const DeskiloRoot(),
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/money/purchases/approvals');
      await tester.pumpAndSettle();
      expect(find.byType(PurchaseApprovalsScreen), findsOneWidget);
      expect(find.text('Supplier bills to approve'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PurchaseApprovalsScreen)),
      );
      final permissions = container.read(myPermissionsProvider);
      expect(permissions, contains(WorkspacePermission.approveExpenses));
      expect(permissions, isNot(contains(WorkspacePermission.managePurchases)));
      expect(permissions, isNot(contains(WorkspacePermission.viewFinances)));
      final before = await container.read(
        purchaseApprovalPageProvider((workspaceId: 'ws-1', after: null)).future,
      );
      final row = find.byKey(const ValueKey('approval-demo-bill-approval'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('purchase-line-1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('purchase-approve')));
      await tester.pumpAndSettle();
      final after = await container.read(
        purchaseApprovalPageProvider((workspaceId: 'ws-1', after: null)).future,
      );
      expect(after.count, before.count - 1);
      expect(
        find.byKey(const ValueKey('approval-demo-bill-approval')),
        findsNothing,
      );
    },
  );
  test(
    'Demo changes eligible own bills with actor and the configured threshold',
    () async {
      var actor = 'member-3';
      var threshold = 58;
      final demo = seedDemoPurchasing(
        DateTime(2026, 11, 2),
        actor: () => actor,
      );
      final reads = FakePurchaseApprovalReads(
        demo.purchases,
        thresholdUnits: (_) async => threshold,
      );
      expect(
        (await reads.page('ws-1')).rows
            .any((d) => d.id == 'demo-bill-approval'),
        isFalse,
      );
      threshold = 59;
      final detail = await reads.detail('ws-1', 'demo-bill-approval');
      expect(detail.canApprove, isTrue);
      expect(detail.canReject, isFalse);
      actor = 'member-2';
      expect(
        (await reads.detail('ws-1', 'demo-bill-approval')).canReject,
        isTrue,
      );
      await expectLater(reads.page('other'), throwsStateError);
    },
  );
}
