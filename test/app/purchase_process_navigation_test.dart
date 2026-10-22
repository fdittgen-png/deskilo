// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2577 C1 — the purchase and the sales side each have a page, opening the
// existing sheets and screens with their own gates: a member keeps their own
// expense, a manager gets the space's doors, and a door nobody may use is
// absent rather than refused later.
import 'package:deskilo/features/money/presentation/screens/money_hubs_screen.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Set<WorkspaceFeature> features = const {},
  Set<WorkspacePermission> rights = const {},
}) => pumpApp(
  tester,
  page,
  overrides: [
    ...standardTestOverrides(
      workspace: FakeWorkspaceRepository.withWorkspace(),
    ),
    enabledFeaturesSyncProvider.overrideWithValue(features),
    myPermissionsProvider.overrideWithValue(rights),
  ],
);

void main() {
  testWidgets('the purchases page keeps the person\'s own expense and adds '
      'the space\'s documents only with purchases on', (tester) async {
    await _pump(tester, const PurchasesHubScreen());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('purchases-hub-own-expense')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('purchases-button')), findsNothing);

    await _pump(
      tester,
      const PurchasesHubScreen(),
      features: {WorkspaceFeature.purchases},
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchases-button')), findsOneWidget);
  });

  testWidgets('the sales page shows a door only to whoever may open it', (
    tester,
  ) async {
    await _pump(tester, const SalesHubScreen());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sales-hub-invoices')), findsOneWidget);
    expect(find.byKey(const ValueKey('sales-hub-billing')), findsNothing);
    expect(find.byKey(const ValueKey('sales-hub-services')), findsNothing);

    await _pump(
      tester,
      const SalesHubScreen(),
      features: {WorkspaceFeature.services},
      rights: {
        WorkspacePermission.manageBilling,
        WorkspacePermission.manageServices,
      },
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sales-hub-billing')), findsOneWidget);
    expect(find.byKey(const ValueKey('sales-hub-services')), findsOneWidget);
  });
}
