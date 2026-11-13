// SPDX-License-Identifier: AGPL-3.0-or-later
// City-specific purchasing and accounting repositories for the Demo.
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/money/providers/accounting_connection_providers.dart';
import '../../features/money/providers/asset_providers.dart';
import '../../features/money/providers/book_period_providers.dart';
import '../../features/money/providers/book_profile_providers.dart';
import '../../features/money/providers/einvoice_inbox_providers.dart';
import '../../features/money/providers/premises_lease_providers.dart';
import '../../features/money/providers/room_rental_providers.dart';
import '../../features/workspace/domain/kpi_vendors.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/customer_kpi_providers.dart';
import '../../features/workspace/providers/item_kpi_providers.dart';
import '../../features/workspace/providers/kpi_providers.dart';
import '../../features/workspace/providers/sales_kpi_providers.dart';
import '../../features/workspace/providers/vendor_kpi_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'data/customer_kpi_repository.dart';
import 'data/item_kpi_repository.dart';
import 'data/kpi_repositories.dart';
import 'data/money_repository.dart';
import 'data/purchase_order_repository.dart';
import 'data/reservation_repository.dart';
import 'data/room_rental_repository.dart';
import 'data/sales_kpi_repository.dart';
import 'data/vendor_kpi_repository.dart';
import 'demo_analysis_overrides.dart';
import 'demo_fixture.dart';
import 'demo_purchase_order_overrides.dart';
import 'demo_purchasing_overrides.dart';
import 'demo_space_pick.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_trade_city_seed.dart';
import 'seed/demo_twin_seed.dart';

DemoCapacityKpiRepository demoCapacityKpi(Ref ref, DemoFixture fixture) {
  final id = ref.watch(currentWorkspaceProvider).value?.id;
  final (plan, reservations) = switch (id) {
    demoSecondSpaceId => (fixture.secondSpace.floorPlan, fixture.secondSpace.reservations),
    demoLondonSpaceId => (fixture.london.floorPlan, fixture.london.reservations),
    demoNewYorkSpaceId => (fixture.newYork.floorPlan, fixture.newYork.reservations),
    demoZurichSpaceId => (fixture.zurich.floorPlan, fixture.zurich.reservations),
    demoMilanSpaceId => (fixture.milan.floorPlan, fixture.milan.reservations),
    demoTwinSpaceId => (fixture.twin.floorPlan, fixture.twin.reservations),
    null || '' || demoFirstSpaceId => (fixture.floorPlan, fixture.reservations),
    _ => throw StateError('unknown demo space: $id'),
  };
  return DemoCapacityKpiRepository(
    plan: plan,
    reservations: reservations,
    now: fixture.seededAt,
    closureDays: fixture.workspaces.closureDays,
  );
}

/// The Demo's commerce, routed to the stores each space keeps on the fixture
/// (demo_space_stores.dart): a switch of persona rebuilds this scope and
/// reaches the same stores again (#3865).
List<Override> demoCityCommerceOverrides(DemoFixture fixture) {
  final stores = fixture.stores;
  final DemoSpaces<DemoPurchasing> buying = demoMapSpaces(stores, (s) => s.buying);
  final DemoSpaces<DemoSpaceBooks> figures = demoMapSpaces(stores, (s) => s.figures);
  final DemoSpaces<DemoSpaceContracts> contracts = demoMapSpaces(stores, (s) => s.figures.contracts);
  final orderSpaces = demoMapSpaces(stores, (s) => s.orders);
  return [
    eInvoiceInboxRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, buying).inbox,
    ),
    ...demoPurchasingOverrides(buying.home, spaces: buying),
    // #3307 — the orders to their suppliers.
    ...demoPurchaseOrderOverrides(orderSpaces),
    // #3866 — every space reads its own books and accounting connection.
    bookProfileRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, demoMapSpaces(stores, (s) => s.books)),
    ),
    retentionHoldRepositoryProvider.overrideWithValue(fixture.holds),
    bookPeriodRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, demoMapSpaces(stores, (s) => s.periods)),
    ),
    accountingConnectionRepositoryProvider.overrideWith(
      (ref) {
        final accounting = demoPickSpace(ref, demoMapSpaces(stores, (s) => s.accounting));
        // #3336 — retiring and reopening are the owner's, as on the server
        return accounting
          ..isOwner = () => ref.read(myMemberProvider).value?.isOwner ?? false;
      },
    ),
    ..._contractOverrides(fixture, contracts),
    ..._kpiOverrides(fixture, buying, orderSpaces),
    ...demoBookFigureOverrides(fixture, buying, figures),
  ];
}

/// The lease, the register and the rented rooms each space holds (#3797:
/// Leipzig's its own), and #3294 step 3 the sales figures from each space's
/// invoices and rooms.
List<Override> _contractOverrides(
  DemoFixture fixture,
  DemoSpaces<DemoSpaceContracts> contracts,
) => [
  premisesLeaseRepositoryProvider.overrideWith(
    (ref) => demoPickSpace(ref, contracts).lease,
  ),
  workspaceAssetRepositoryProvider.overrideWith(
    (ref) => demoPickSpace(ref, contracts).assets,
  ),
  // #2568 — the rooms the demo space rents.
  roomRentalRepositoryProvider.overrideWith(
    (ref) => demoPickSpace(ref, contracts).rooms,
  ),
  _salesOverride(fixture, (
    home: contracts.home.rooms,
    leipzig: contracts.leipzig.rooms,
    london: contracts.london.rooms,
    ny: contracts.newYork.rooms,
    zurich: contracts.zurich.rooms,
    milan: contracts.milan.rooms,
    twin: contracts.twin.rooms,
  )),
];

/// #2582 — the purchase figures over each space's own documents, in its own
/// currency; #3797 Leipzig's are its own (none yet).
List<Override> _kpiOverrides(
  DemoFixture fixture,
  DemoSpaces<DemoPurchasing> buying,
  DemoPurchaseOrderSpaces orderSpaces,
) {
  final now = fixture.seededAt;
  final DemoSpaces<DemoPurchaseKpiRepository> purchase = (
    home: DemoPurchaseKpiRepository(purchases: buying.home.purchases, now: now),
    leipzig: DemoPurchaseKpiRepository(
      purchases: buying.leipzig.purchases,
      now: now,
    ),
    london: DemoPurchaseKpiRepository(
      purchases: buying.london.purchases,
      now: now,
      currency: 'GBP',
    ),
    newYork: DemoPurchaseKpiRepository(
      purchases: buying.newYork.purchases,
      now: now,
      currency: 'USD',
    ),
    zurich: DemoPurchaseKpiRepository(
      purchases: buying.zurich.purchases,
      now: now,
      currency: demoZurich.currency,
    ),
    milan: DemoPurchaseKpiRepository(
      purchases: buying.milan.purchases,
      now: now,
      currency: demoMilan.currency,
    ),
    twin: DemoPurchaseKpiRepository(purchases: buying.twin.purchases, now: now),
  );
  // #3294 — the customer figures of each of the four spaces, from its own
  // money, under the reader's rights as the server would decide them.
  DemoCustomerKpiRepository customers(
    Ref ref,
    FakeMoneyRepository money,
    String currency,
  ) => DemoCustomerKpiRepository(
    money: money,
    now: now,
    currency: currency,
    namesVisible: () => ref
        .read(myPermissionsProvider)
        .contains(WorkspacePermission.viewPersonalData),
    dunningEnabled: () =>
        ref.read(enabledFeaturesSyncProvider).contains(WorkspaceFeature.dunning),
  );
  // #3294 step 4 — the item figures over each space's own purchases and
  // the sales of its catalogue items, in its own currency.
  DemoItemKpiRepository items(
    DemoPurchasing p,
    FakeMoneyRepository money, [
    String currency = 'EUR',
  ]) => DemoItemKpiRepository(
    purchases: p.purchases,
    invoices: () => money.invoices,
    services: () => money.services,
    now: now,
    currency: currency,
  );
  // #3294 step 2 — the vendor figures over each space's own purchases and
  // orders, in its own currency.
  DemoVendorKpiRepository vendors(
    DemoPurchasing p,
    FakePurchaseOrderRepository orders, [
    String currency = 'EUR',
  ]) => DemoVendorKpiRepository(
    purchases: p.purchases,
    now: now,
    currency: currency,
    orders: orders,
  );
  return [
    customerKpiRepositoryProvider.overrideWith(
      (ref) => switch (ref.watch(currentWorkspaceProvider).value?.id) {
        demoSecondSpaceId => customers(ref, fixture.secondSpace.money, 'EUR'),
        demoLondonSpaceId => customers(ref, fixture.london.money, 'GBP'),
        demoNewYorkSpaceId => customers(ref, fixture.newYork.money, 'USD'),
        demoZurichSpaceId => customers(ref, fixture.zurich.money, demoZurich.currency),
        demoMilanSpaceId => customers(ref, fixture.milan.money, demoMilan.currency),
        demoTwinSpaceId => customers(ref, fixture.twin.money, 'EUR'),
        _ => customers(ref, fixture.money, 'EUR'),
      },
    ),
    purchaseKpiRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, purchase),
    ),
    itemKpiRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (
        home: () => items(buying.home, fixture.money),
        leipzig: () => items(buying.leipzig, fixture.secondSpace.money),
        london: () => items(buying.london, fixture.london.money, 'GBP'),
        newYork: () => items(buying.newYork, fixture.newYork.money, 'USD'),
        zurich: () => items(buying.zurich, fixture.zurich.money, demoZurich.currency),
        milan: () => items(buying.milan, fixture.milan.money, demoMilan.currency),
        twin: () => items(buying.twin, fixture.twin.money),
      ))(),
    ),
    vendorKpiRepositoryProvider.overrideWith(
      (ref) => demoPickSpace<VendorKpiRepository Function()>(ref, (
        home: () => vendors(buying.home, orderSpaces.home),
        leipzig: () => vendors(buying.leipzig, orderSpaces.leipzig),
        london: () => vendors(buying.london, orderSpaces.london, 'GBP'),
        newYork: () => vendors(buying.newYork, orderSpaces.newYork, 'USD'),
        zurich: () => vendors(buying.zurich, orderSpaces.zurich, demoZurich.currency),
        milan: () => vendors(buying.milan, orderSpaces.milan, demoMilan.currency),
        // #3302 — the twin's own (empty) purchases, and no orders.
        twin: () => DemoVendorKpiRepository(
          purchases: buying.twin.purchases,
          now: now,
        ),
      ))(),
    ),
  ];
}

/// #3294 step 3 — the sales figures of each space, from its own invoices
/// and the rooms it rents; Leipzig rents none.
Override _salesOverride(
  DemoFixture fixture,
  ({
    FakeRoomRentalRepository home,
    FakeRoomRentalRepository leipzig,
    FakeRoomRentalRepository london,
    FakeRoomRentalRepository ny,
    FakeRoomRentalRepository zurich,
    FakeRoomRentalRepository milan,
    FakeRoomRentalRepository twin,
  })
  rooms,
) => salesKpiRepositoryProvider.overrideWith((ref) {
      DemoSalesKpiRepository sales(
        FakeMoneyRepository money,
        FakeRoomRentalRepository rooms,
        FakeReservationRepository bookings,
        String currency,
      ) => DemoSalesKpiRepository(
        invoices: () => money.invoices,
        rooms: rooms,
        bookings: () => bookings.reservations,
        roomsEnabled: () => ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.externalRooms),
        now: fixture.seededAt,
        currency: currency,
      );
      return switch (ref.watch(currentWorkspaceProvider).value?.id) {
        demoSecondSpaceId => sales(
          fixture.secondSpace.money,
          rooms.leipzig,
          fixture.secondSpace.reservations,
          'EUR',
        ),
        demoLondonSpaceId => sales(
          fixture.london.money,
          rooms.london,
          fixture.london.reservations,
          'GBP',
        ),
        demoNewYorkSpaceId => sales(
          fixture.newYork.money,
          rooms.ny,
          fixture.newYork.reservations,
          'USD',
        ),
        demoZurichSpaceId => sales(
          fixture.zurich.money,
          rooms.zurich,
          fixture.zurich.reservations,
          demoZurich.currency,
        ),
        demoMilanSpaceId => sales(
          fixture.milan.money,
          rooms.milan,
          fixture.milan.reservations,
          demoMilan.currency,
        ),
        demoTwinSpaceId => sales(
          fixture.twin.money,
          rooms.twin,
          fixture.twin.reservations,
          'EUR',
        ),
        _ => sales(fixture.money, rooms.home, fixture.reservations, 'EUR'),
      };
    });
