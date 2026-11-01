// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3070 — the drawer's "Purchases & suppliers" group: the purchases hub, the
// suppliers screen and the approvals queue with its count, each present only
// for who may open its page, and absent (not refused) when the feature is off.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
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

Future<void> _open(
  WidgetTester tester, {
  required Map<String, dynamic> flags,
  required bool manager,
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
    await _open(
      tester,
      flags: const {'purchases': true, 'supplyExpenses': true},
      manager: true,
    );
    await _expandGroup(tester);
    expect(find.byKey(const ValueKey('drawer-purchases')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-suppliers')), findsOneWidget);
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
      reason: 'two documents wait; the approved one is not counted',
    );
  });

  testWidgets('the suppliers and the approvals are absent when their '
      'features are off', (tester) async {
    await _open(
      tester,
      flags: const {'purchases': false, 'supplyExpenses': false},
      manager: true,
    );
    expect(find.text('Purchases & suppliers'), findsNothing);
    expect(find.byKey(const ValueKey('drawer-suppliers')), findsNothing);
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
    );
    expect(find.byKey(const ValueKey('drawer-suppliers')), findsNothing);
    expect(
      find.byKey(const ValueKey('drawer-purchase-approvals')),
      findsNothing,
    );
  });
}
