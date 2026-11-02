// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3070 — the drawer's "Purchases & suppliers" group: the purchases hub, the
// suppliers screen and the approvals queue with its count, each present only
// for who may open its page, and absent (not refused) when the feature is off.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/purchase_approval_reads.dart';
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

PurchaseSummary _doc(String id, PurchaseState state) => PurchaseSummary(
  id: id,
  kind: PurchaseKind.bill,
  state: state,
  category: '',
  reference: id,
  currency: 'EUR',
);

class _ApprovalReads implements PurchaseApprovalReads {
  _ApprovalReads({this.refuse = false});
  final bool refuse;
  final requests = <String>[];

  @override
  Future<PurchaseApprovalPage> page(
    String workspaceId, {
    PurchaseApprovalCursor? after,
  }) async {
    requests.add(workspaceId);
    if (refuse) throw StateError('approval read refused');
    return PurchaseApprovalPage(
      rows: [
        _doc('a', PurchaseState.pending),
        _doc('b', PurchaseState.pending),
      ],
      count: 2,
      version: 'test',
    );
  }

  @override
  Future<PurchaseApprovalDetail> detail(
    String workspaceId,
    String purchaseId,
  ) => throw UnimplementedError();
}

Future<void> _open(
  WidgetTester tester, {
  required Map<String, dynamic> flags,
  required bool manager,
  required _ApprovalReads approvals,
  Set<WorkspacePermission>? permissions,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  workspace.myMember = workspace.myMember.copyWith(
    isOwner: manager,
    isAdmin: manager,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace),
        webShellProvider.overrideWithValue(true),
        if (permissions != null) myPermissionsProvider.overrideWithValue(permissions),
        purchaseApprovalReadsProvider.overrideWithValue(approvals),
        purchasesProvider.overrideWith(
          (ref, id) async => [
            _doc('a', PurchaseState.pending),
            _doc('b', PurchaseState.pending),
            _doc('c', PurchaseState.approved),
          ],
        ),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
}

Future<void> _expandGroup(WidgetTester tester) async {
  final scrollable = find.descendant(
    of: find.byKey(const ValueKey('shell-drawer')),
    matching: find.byType(Scrollable),
  );
  final group = find.text('Purchases & suppliers');
  await tester.scrollUntilVisible(group, 80, scrollable: scrollable);
  await tester.tap(group);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a manager finds the hub, the suppliers and the approvals '
      'queue with its count under one group', (tester) async {
    final approvals = _ApprovalReads();
    await _open(
      tester,
      flags: const {'purchases': true, 'supplyExpenses': true},
      manager: true,
      approvals: approvals,
    );
    await _expandGroup(tester);
    expect(find.byKey(const ValueKey('drawer-purchases')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-suppliers')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-purchases-to-pay')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('drawer-purchase-approvals')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('drawer-purchase-approvals')),
        matching: find.text('2'),
      ),
      findsOneWidget,
      reason: 'the server-scoped bill count is shown',
    );
    expect(approvals.requests, isNotEmpty);
  });

  testWidgets('a refused approval count shows unavailable, not zero', (
    tester,
  ) async {
    final approvals = _ApprovalReads(refuse: true);
    await _open(
      tester,
      flags: const {'purchases': true, 'supplyExpenses': true},
      manager: true,
      approvals: approvals,
    );
    await _expandGroup(tester);
    final entry = find.byKey(const ValueKey('drawer-purchase-approvals'));
    expect(
      find.descendant(of: entry, matching: find.byIcon(Icons.error_outline)),
      findsOneWidget,
    );
    expect(find.descendant(of: entry, matching: find.text('0')), findsNothing);
    expect(approvals.requests, isNotEmpty);
  });

  for (final permission in [
    WorkspacePermission.viewFinances,
    WorkspacePermission.managePurchases,
  ]) {
    testWidgets('wide reader $permission can open the To-pay entry', (tester) async {
      await _open(tester,
        flags: const {'purchases': true, 'supplyExpenses': true},
        manager: false,
        approvals: _ApprovalReads(),
        permissions: {permission},
      );
      await _expandGroup(tester);
      expect(find.byKey(const ValueKey('drawer-purchases-to-pay')), findsOneWidget);
    });
  }

  testWidgets('To pay is absent when purchases is off even for a wide reader', (tester) async {
    await _open(tester,
      flags: const {'purchases': false, 'supplyExpenses': true},
      manager: true,
      approvals: _ApprovalReads(),
    );
    await _expandGroup(tester);
    expect(find.byKey(const ValueKey('drawer-suppliers')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-purchases-to-pay')), findsNothing);
  });

  testWidgets('billing permission alone does not grant workspace-wide payables', (tester) async {
    await _open(tester,
      flags: const {'purchases': true, 'supplyExpenses': true},
      manager: false,
      approvals: _ApprovalReads(),
      permissions: {WorkspacePermission.manageBilling},
    );
    await _expandGroup(tester);
    expect(find.byKey(const ValueKey('drawer-suppliers')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-purchases-to-pay')), findsNothing);
  });

  testWidgets('an approver alone never sees workspace-wide payables', (tester) async {
    await _open(tester,
      flags: const {'purchases': true, 'supplyExpenses': true},
      manager: false,
      approvals: _ApprovalReads(),
      permissions: {WorkspacePermission.approveExpenses},
    );
    await _expandGroup(tester);
    expect(find.byKey(const ValueKey('drawer-purchase-approvals')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-purchases-to-pay')), findsNothing);
  });

  testWidgets('the suppliers and the approvals are absent when their '
      'features are off', (tester) async {
    await _open(
      tester,
      flags: const {'purchases': false, 'supplyExpenses': false},
      manager: true,
      approvals: _ApprovalReads(),
    );
    expect(find.text('Purchases & suppliers'), findsNothing);
    expect(find.byKey(const ValueKey('drawer-suppliers')), findsNothing);
    expect(find.byKey(const ValueKey('drawer-purchases-to-pay')), findsNothing);
    expect(
      find.byKey(const ValueKey('drawer-purchase-approvals')),
      findsNothing,
    );
  });

  testWidgets('a member without management rights keeps neither the '
      'suppliers nor the approvals', (tester) async {
    await _open(
      tester,
      flags: const {'purchases': true, 'supplyExpenses': true},
      manager: false,
      approvals: _ApprovalReads(),
    );
    expect(find.byKey(const ValueKey('drawer-suppliers')), findsNothing);
    expect(find.byKey(const ValueKey('drawer-purchases-to-pay')), findsNothing);
    expect(
      find.byKey(const ValueKey('drawer-purchase-approvals')),
      findsNothing,
    );
  });
}
