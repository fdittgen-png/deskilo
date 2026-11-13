// SPDX-License-Identifier: AGPL-3.0-or-later
// Orders and receipts use the same suppliers, catalogue and currency as the
// purchasing graph. A new space or a development twin starts with no orders.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/money/domain/service_item.dart';
import '../../features/money/providers/purchase_order_providers.dart';
import 'data/purchase_order_repository.dart';
import 'demo_fixture.dart';
import 'demo_space_pick.dart';
import 'seed/demo_purchase_order_seed.dart';
import 'seed/demo_purchase_seed.dart';

typedef DemoPurchaseOrderSpaces = DemoSpaces<FakePurchaseOrderRepository>;

DemoPurchaseOrderSpaces demoPurchaseOrderSpaces(
  DemoFixture fixture, DemoSpaces<DemoPurchasing> purchasing,
) {
  FakePurchaseOrderRepository space(
    DemoPurchasing buying, List<ServiceItem> Function() services,
    String currency, double vatPercent, {bool seeded = true}
  ) {
    final repo = FakePurchaseOrderRepository(
      suppliers: () => buying.suppliers.suppliers, services: services,
      now: () => fixture.seededAt, currency: currency,
    );
    if (seeded) seedDemoPurchaseOrders(repo, fixture.seededAt, vatPercent: vatPercent);
    return repo;
  }
  return (
    home: space(purchasing.home, () => fixture.money.services, 'EUR', 20),
    london: space(purchasing.london, () => fixture.london.money.services, 'GBP', 20),
    newYork: space(purchasing.newYork, () => fixture.newYork.money.services, 'USD', 0),
    zurich: space(purchasing.zurich, () => fixture.zurich.money.services,
      fixture.zurich.spec.currency, fixture.zurich.spec.vatPercent),
    milan: space(purchasing.milan, () => fixture.milan.money.services,
      fixture.milan.spec.currency, fixture.milan.spec.vatPercent),
    leipzig: space(purchasing.leipzig, () => fixture.secondSpace.money.services,
      'EUR', 0, seeded: false),
    twin: space(purchasing.twin, () => fixture.twin.money.services,
      'EUR', 20, seeded: false),
  );
}

List<Override> demoPurchaseOrderOverrides(DemoPurchaseOrderSpaces spaces) => [
  purchaseOrderRepositoryProvider.overrideWith((ref) => demoPickSpace(ref, spaces)),
];
