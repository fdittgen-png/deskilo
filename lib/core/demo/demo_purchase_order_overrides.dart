// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase orders of each purchasing space of the Demo, in its
// own currency, to its own suppliers, with its own catalogue; Leipzig
// orders nothing yet. Nothing is sent from the Demo.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/money/domain/service_item.dart';
import '../../features/money/providers/purchase_order_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'data/purchase_order_repository.dart';
import 'demo_fixture.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_purchase_order_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_second_space_seed.dart';

List<Override> demoPurchaseOrderOverrides(
  DemoFixture fixture,
  DemoPurchasing home, {
  required DemoPurchasing london,
  required DemoPurchasing newYork,
}) {
  FakePurchaseOrderRepository space(
    DemoPurchasing purchasing,
    List<ServiceItem> Function() services,
    String currency, {
    bool seeded = true,
  }) {
    final repo = FakePurchaseOrderRepository(
      suppliers: () => purchasing.suppliers.suppliers,
      services: services,
      now: () => fixture.seededAt,
      currency: currency,
    );
    if (seeded) seedDemoPurchaseOrders(repo, fixture.seededAt);
    return repo;
  }

  final homeOrders = space(home, () => fixture.money.services, 'EUR');
  final londonOrders = space(
    london,
    () => fixture.london.money.services,
    'GBP',
  );
  final nyOrders = space(newYork, () => fixture.newYork.money.services, 'USD');
  final leipzigOrders = space(
    home,
    () => fixture.secondSpace.money.services,
    'EUR',
    seeded: false,
  );
  return [
    purchaseOrderRepositoryProvider.overrideWith(
      (ref) => switch (ref.watch(currentWorkspaceProvider).value?.id) {
        demoLondonSpaceId => londonOrders,
        demoNewYorkSpaceId => nyOrders,
        demoSecondSpaceId => leipzigOrders,
        _ => homeOrders,
      },
    ),
  ];
}
