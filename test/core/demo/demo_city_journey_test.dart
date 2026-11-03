// SPDX-License-Identifier: AGPL-3.0-or-later
// Both city links enter the real Demo scope and expose their own plan.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/core/demo/seed/demo_new_york_seed.dart';
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:deskilo/features/money/providers/accounting_connection_providers.dart';
import 'package:deskilo/features/money/providers/asset_providers.dart';
import 'package:deskilo/features/money/providers/book_profile_providers.dart';
import 'package:deskilo/features/money/providers/premises_lease_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

void main() {
  for (final (name, id, floors) in [
    ('london', demoLondonSpaceId, 6),
    ('new-york', demoNewYorkSpaceId, 8),
  ]) {
    testWidgets('$name opens its own plan in the real Demo', (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final journey = DemoJourney.start();
      addTearDown(journey.dispose);
      journey.root
          .read(pendingDemoLinkProvider.notifier)
          .hold(
            DemoLink.parse({
              'space': name,
              'persona': 'owner',
              'to': '/reserve',
            }),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: journey.root,
          child: const DeskiloRoot(),
        ),
      );
      await tester.pumpAndSettle();
      final inner = ProviderScope.containerOf(
        tester.element(find.byType(DeskiloApp)),
      );
      expect(inner.read(currentWorkspaceProvider).value?.id, id);
      final plan = inner.read(floorPlanRepositoryProvider);
      final levels = await plan.fetchLevels(id);
      expect(levels, hasLength(floors));
      final floor = await plan.fetchPlan(levels.first.id);
      final illustration = floor.images.firstWhere(
        (image) => image.id.endsWith('-locator'),
      );
      expect((await plan.fetchPlanImageBytes(illustration.id))?.take(4), [
        137,
        80,
        78,
        71,
      ]);
      final books = await inner
          .read(bookProfileRepositoryProvider)
          .fetchBookProfiles(id);
      expect(
        books.single.authority,
        name == 'london' ? BookAuthority.externalBook : BookAuthority.localBook,
      );
      final connections = await inner
          .read(accountingConnectionRepositoryProvider)
          .fetchConnections(id);
      expect(
        connections.any((c) => c.targetId == 'sage_business_cloud_gb'),
        name == 'london',
      );
      final suppliers = await inner
          .read(supplierRepositoryProvider)
          .fetchSuppliers(id);
      expect(suppliers.any((s) => s.name.contains('Vending')), isTrue);
      expect(suppliers.any((s) => s.name == 'Amazon Business (Demo)'), isTrue);
      expect(suppliers.any((s) => s.name.contains('Drinks Wholesale')), isTrue);
      final purchases = await inner
          .read(purchaseRepositoryProvider)
          .fetchPurchases(id);
      expect(
        purchases.any((p) => p.category == 'Vending machine rental'),
        isTrue,
      );
      expect(purchases.any((p) => p.category.contains('restock')), isTrue);
      final rentalBills = purchases
          .where((p) => p.category == 'Vending machine rental')
          .toList();
      final billedSites = <String?>{};
      for (final index in List.generate(name == 'london' ? 3 : 5, (i) => i)) {
        final bill = rentalBills.firstWhere((p) => p.id.endsWith('-$index'));
        final detail = await inner
            .read(purchaseRepositoryProvider)
            .fetchDetail(id, bill.id);
        billedSites.add(detail.lines.single.costSiteId);
      }
      expect(billedSites, hasLength(name == 'london' ? 3 : 5));
      expect(
        purchases.any((p) => p.category.contains('3D printing materials')),
        isTrue,
      );
      final assets = await inner
          .read(workspaceAssetRepositoryProvider)
          .fetchAssets(id);
      expect(assets, hasLength(name == 'london' ? 3 : 5));
      expect(assets.every((a) => a.description.contains('3D printer')), isTrue);
      final leases = await inner
          .read(premisesLeaseRepositoryProvider)
          .fetchLeases(id);
      expect(
        leases.any((l) => l.supplierId == 'ny-landlord'),
        name == 'new-york',
      );
      if (name == 'new-york') {
        final rent = purchases.firstWhere(
          (p) => p.category == 'Rent and service fees',
        );
        final detail = await inner
            .read(purchaseRepositoryProvider)
            .fetchDetail(id, rent.id);
        expect(detail.obligations.single.paidCents, 680000);
        expect(
          detail.obligations.single.allocations.single.method,
          'bank_transfer',
        );
      }
      expect(find.byType(DeskiloApp), findsOneWidget);
    });
  }
}
