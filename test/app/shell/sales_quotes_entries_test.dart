// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 3) -- a feature reached only by typing its address is not finished:
// Quotes and Billing customers each have an entry in the Sales group, present
// only when their feature is on and the person holds a right their page asks
// for, and absent (not refused) otherwise.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<void> _open(
  WidgetTester tester, {
  required Map<String, dynamic> flags,
  Set<WorkspacePermission>? permissions,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace),
        webShellProvider.overrideWithValue(true),
        if (permissions != null) myPermissionsProvider.overrideWithValue(permissions),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
}

Future<void> _expandSales(WidgetTester tester) async {
  final scrollable = find.descendant(
    of: find.byKey(const ValueKey('shell-drawer')),
    matching: find.byType(Scrollable),
  );
  final group = find.text('Sales & collections');
  await tester.scrollUntilVisible(group, 80, scrollable: scrollable);
  await tester.tap(group);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an issuer finds Quotes and Billing customers in the Sales group '
      'when their features are on', (tester) async {
    await _open(
      tester,
      flags: const {'invoicing': true, 'customerQuotes': true, 'billingCustomers': true},
    );
    await _expandSales(tester);
    expect(find.byKey(const ValueKey('drawer-quotes')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-billing-customers')), findsOneWidget);
  });

  testWidgets('with a feature off its entry is absent, not refused',
      (tester) async {
    await _open(
      tester,
      flags: const {'invoicing': true, 'customerQuotes': false, 'billingCustomers': true},
    );
    await _expandSales(tester);
    expect(find.byKey(const ValueKey('drawer-quotes')), findsNothing);
    expect(find.byKey(const ValueKey('drawer-billing-customers')), findsOneWidget);
  });

  testWidgets('a person without a right their pages ask for sees neither entry',
      (tester) async {
    await _open(
      tester,
      flags: const {'invoicing': true, 'customerQuotes': true, 'billingCustomers': true},
      permissions: const {WorkspacePermission.makeReservations},
    );
    expect(find.byKey(const ValueKey('drawer-quotes')), findsNothing);
    expect(find.byKey(const ValueKey('drawer-billing-customers')), findsNothing);
  });
}
