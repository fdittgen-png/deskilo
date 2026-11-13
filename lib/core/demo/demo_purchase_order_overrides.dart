// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase orders of each purchasing space of the Demo, in its
// own currency, to its own suppliers, with its own catalogue; Leipzig
// orders nothing yet. Nothing is sent from the Demo.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/money/providers/purchase_order_providers.dart';
import 'data/money_repository.dart';
import 'data/purchase_order_repository.dart';
import 'demo_fixture.dart';
import 'demo_space_pick.dart';
import 'seed/demo_purchase_order_seed.dart';
import 'seed/demo_purchase_seed.dart';

/// The purchase orders of each Demo space (#3307), kept on the fixture so the
/// vendor figures (#3294 step 5) read the same orders and receipts the
/// screens show.
typedef DemoPurchaseOrderSpaces = DemoSpaces<FakePurchaseOrderRepository>;

/// One space's orders to its own suppliers, over its own catalogue and in its
/// own currency; [seeded] orders come with the space, none otherwise.
FakePurchaseOrderRepository demoPurchaseOrders(
  DemoFixture fixture,
  DemoPurchasing purchasing,
  FakeMoneyRepository money,
  String currency, {
  bool seeded = false,
}) {
  final repo = FakePurchaseOrderRepository(
    suppliers: () => purchasing.suppliers.suppliers,
    services: () => money.services,
    now: () => fixture.seededAt,
    currency: currency,
  );
  if (seeded) seedDemoPurchaseOrders(repo, fixture.seededAt);
  return repo;
}

List<Override> demoPurchaseOrderOverrides(DemoPurchaseOrderSpaces spaces) => [
  purchaseOrderRepositoryProvider.overrideWith(
    (ref) => demoPickSpace(ref, spaces),
  ),
];
