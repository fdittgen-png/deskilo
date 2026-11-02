// SPDX-License-Identifier: AGPL-3.0-or-later
// #3070: the existing Demo supplier exposes an outstanding and a settled
// bill through the same supplier screen and scoped payable list.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/features/money/presentation/screens/suppliers_screen.dart';
import 'package:deskilo/features/money/providers/supplier_balance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

void main() {
  testWidgets('Demo owner opens the cleaning supplier and reads its bills', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final journey = DemoJourney.start();
    addTearDown(journey.dispose);
    journey.root
        .read(pendingDemoLinkProvider.notifier)
        .hold(
          DemoLink.parse({
            'space': 'pezenas',
            'persona': 'owner',
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
    final suppliers = find.byKey(const ValueKey('suppliers-button'));
    await tester.ensureVisible(suppliers);
    await tester.tap(suppliers);
    await tester.pumpAndSettle();
    expect(find.byType(SuppliersScreen), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SuppliersScreen)),
    );
    final balances = await container.read(
      supplierBalancesProvider('ws-1').future,
    );
    final cleaning = balances.singleWhere(
      (b) => b.supplierId == 'demo-supplier-cleaning' && b.currency == 'EUR',
    );
    expect(cleaning.remainingCents, 4400);
    expect(
      find.byKey(const ValueKey('supplier-balance-demo-supplier-cleaning')),
      findsOneWidget,
    );
    final door = find.byKey(
      const ValueKey('supplier-payables-demo-supplier-cleaning'),
    );
    await tester.ensureVisible(door);
    await tester.tap(door);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('payable-demo-payable-demo-bill-cleaning')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('payable-demo-payable-demo-bill-cleaning-paid'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('payable-demo-payable-demo-bill-bank')),
      findsNothing,
    );
  });
}
