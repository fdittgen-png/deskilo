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
import 'demo_space_pick.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_purchase_order_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_trade_city_seed.dart';

/// The purchase orders of each Demo space (#3307), kept so the vendor figures
/// (#3294 step 5) read the same orders and receipts the screens show.
typedef DemoPurchaseOrderSpaces = ({
  FakePurchaseOrderRepository home,
  FakePurchaseOrderRepository london,
  FakePurchaseOrderRepository newYork,
  FakePurchaseOrderRepository zurich,
  FakePurchaseOrderRepository milan,
  FakePurchaseOrderRepository leipzig,
});

DemoPurchaseOrderSpaces demoPurchaseOrderSpaces(
  DemoFixture fixture,
  DemoSpaces<DemoPurchasing> buying,
) {
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

  return (
    home: space(buying.home, () => fixture.money.services, 'EUR'),
    london: space(buying.london, () => fixture.london.money.services, 'GBP'),
    newYork: space(buying.newYork, () => fixture.newYork.money.services, 'USD'),
    // #3832 — the trade cities order nothing yet: bills only.
    zurich: space(buying.zurich, () => fixture.zurich.money.services, demoZurich.currency, seeded: false),
    milan: space(buying.milan, () => fixture.milan.money.services, demoMilan.currency, seeded: false),
    leipzig: space(
      buying.leipzig,
      () => fixture.secondSpace.money.services,
      'EUR',
      seeded: false,
    ),
  );
}

List<Override> demoPurchaseOrderOverrides(DemoPurchaseOrderSpaces spaces) {
  return [
    purchaseOrderRepositoryProvider.overrideWith(
      (ref) => switch (ref.watch(currentWorkspaceProvider).value?.id) {
        demoLondonSpaceId => spaces.london,
        demoNewYorkSpaceId => spaces.newYork,
        demoZurichSpaceId => spaces.zurich,
        demoMilanSpaceId => spaces.milan,
        demoSecondSpaceId => spaces.leipzig,
        _ => spaces.home,
      },
    ),
  ];
}
