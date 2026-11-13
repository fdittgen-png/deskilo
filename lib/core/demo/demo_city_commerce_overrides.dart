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
import 'data/accounting_connection_repository.dart';
import 'data/asset_valuation_repository.dart';
import 'data/book_period_repository.dart';
import 'data/book_profile_repository.dart';
import 'data/customer_kpi_repository.dart';
import 'data/einvoice_inbox_repository.dart';
import 'data/item_kpi_repository.dart';
import 'data/kpi_repositories.dart';
import 'data/lease_commitment_repository.dart';
import 'data/money_repository.dart';
import 'data/premises_lease_repository.dart';
import 'data/purchase_order_repository.dart';
import 'data/purchase_repository.dart';
import 'data/reservation_repository.dart';
import 'data/room_rental_repository.dart';
import 'data/sales_kpi_repository.dart';
import 'data/supplier_repository.dart';
import 'data/vendor_kpi_repository.dart';
import 'data/workspace_asset_repository.dart';
import 'demo_analysis_overrides.dart';
import 'demo_fixture.dart';
import 'demo_purchase_order_overrides.dart';
import 'demo_purchasing_overrides.dart';
import 'demo_space_pick.dart';
import 'seed/demo_book_period_seed.dart';
import 'seed/demo_city_books_seed.dart';
import 'seed/demo_city_purchase_seed.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_room_seed.dart';
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

List<Override> demoCityCommerceOverrides(
  DemoFixture fixture,
  DemoPurchasing purchasing,
  FakeBookProfileRepository mainBooks,
  FakePremisesLeaseRepository mainLease,
  FakeWorkspaceAssetRepository mainAssets,
) {
  final bookPeriods = seedDemoBookPeriods(
    fixture.seededAt,
    actor: fixture.actor.memberId,
  );
  final londonPurchasing = cityPurchasing(
    fixture.seededAt,
    tenant: false,
    actor: () => fixture.activeMemberId,
    siteIds: [demoLondonSiteId, 'uk-site-islington', 'uk-site-hackney'],
  );
  final nyPurchasing = cityPurchasing(
    fixture.seededAt,
    tenant: true,
    actor: () => fixture.activeMemberId,
    siteIds: [
      'ny-site-main',
      'ny-site-brooklyn',
      'ny-site-queens',
      'ny-site-bronx',
      'ny-site-harlem',
    ],
  );
  final londonBooks = cityBooks(
    fixture.london.money,
    fixture.seededAt,
    workspaceId: demoLondonSpaceId,
    siteId: demoLondonSiteId,
    external: true,
    purchases: londonPurchasing.purchases,
  );
  final nyBooks = cityBooks(
    fixture.newYork.money,
    fixture.seededAt,
    workspaceId: demoNewYorkSpaceId,
    siteId: 'ny-site-main',
    external: false,
    purchases: nyPurchasing.purchases,
  );
  final zurichBuying = tradeCityPurchasing(demoZurich, fixture.seededAt, actor: () => fixture.activeMemberId);
  final milanBuying = tradeCityPurchasing(demoMilan, fixture.seededAt, actor: () => fixture.activeMemberId);
  final zurichBooks = _tradeBooks(demoZurich, fixture.zurich.money, fixture.seededAt, zurichBuying.purchases);
  final milanBooks = _tradeBooks(demoMilan, fixture.milan.money, fixture.seededAt, milanBuying.purchases);
  final zurichAccounting = cityAccounting(fixture.seededAt, sage: false);
  final milanAccounting = cityAccounting(fixture.seededAt, sage: false);
  final londonAccounting = cityAccounting(fixture.seededAt, sage: true);
  final nyAccounting = cityAccounting(fixture.seededAt, sage: false);
  final homeAccounting = seedDemoAccountingConnections(
    bookPeriods,
    fixture.seededAt,
  );
  final londonLease = FakePremisesLeaseRepository();
  final nyLease = newYorkLease(fixture.seededAt);
  final londonAssets = cityAssets(
    fixture.seededAt,
    tenant: false,
    sites: ['Camden Yard', 'Islington Studio', 'Hackney Studio'],
  );
  final nyAssets = cityAssets(
    fixture.seededAt,
    tenant: true,
    sites: [
      'Hudson House',
      'Brooklyn Studio',
      'Queens Studio',
      'Bronx Studio',
      'Harlem Studio',
    ],
  );
  final zurichAssets = _tradeAssets(demoZurich, fixture.seededAt);
  final milanAssets = _tradeAssets(demoMilan, fixture.seededAt);
  final londonRooms = FakeRoomRentalRepository(currency: 'GBP');
  final nyRooms = FakeRoomRentalRepository(currency: 'USD');
  final zurichRooms = FakeRoomRentalRepository(currency: demoZurich.currency);
  final milanRooms = FakeRoomRentalRepository(currency: demoMilan.currency);
  final homeRooms = seedDemoRooms(fixture.seededAt);
  final twin = _twinStores(fixture);
  final leipzig = _leipzigStores(fixture);
  final DemoSpaces<DemoPurchasing> buying = (
    home: purchasing,
    leipzig: leipzig.purchasing,
    london: londonPurchasing,
    newYork: nyPurchasing,
    zurich: zurichBuying,
    milan: milanBuying,
    twin: fixture.twin.purchasing,
  );
  final orderSpaces = demoPurchaseOrderSpaces(fixture, purchasing, london: londonPurchasing, newYork: nyPurchasing, zurich: zurichBuying, milan: milanBuying, leipzig: leipzig.purchasing);
  // Leipzig keeps the main space's books and accounting connection.
  T choose<T>(Ref ref, T home, T london, T ny, T zurich, T milan, T devTwin) => demoPickSpace(
    ref,
    (home: home, leipzig: home, london: london, newYork: ny, zurich: zurich, milan: milan, twin: devTwin),
  );
  final DemoSpaces<DemoSpaceContracts> contracts = (
    home: (assets: mainAssets, lease: mainLease, rooms: homeRooms),
    leipzig: leipzig.books.contracts,
    london: (assets: londonAssets, lease: londonLease, rooms: londonRooms),
    newYork: (assets: nyAssets, lease: nyLease, rooms: nyRooms),
    zurich: (assets: zurichAssets, lease: FakePremisesLeaseRepository(), rooms: zurichRooms),
    milan: (assets: milanAssets, lease: FakePremisesLeaseRepository(), rooms: milanRooms),
    twin: (assets: twin.assets, lease: twin.lease, rooms: twin.rooms),
  );
  return [
    eInvoiceInboxRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, buying).inbox,
    ),
    ...demoPurchasingOverrides(
      purchasing,
      leipzig: leipzig.purchasing,
      london: londonPurchasing,
      newYork: nyPurchasing,
      zurich: zurichBuying,
      milan: milanBuying,
      twin: fixture.twin.purchasing,
    ),
    // #3307 — the orders to their suppliers.
    ...demoPurchaseOrderOverrides(orderSpaces),
    bookProfileRepositoryProvider.overrideWith(
      (ref) => choose(ref, mainBooks, londonBooks, nyBooks, zurichBooks, milanBooks, twin.books),
    ),
    retentionHoldRepositoryProvider.overrideWithValue(fixture.holds),
    // #2365 last year's books, closed and exported; #2370 the studio's Pennylane connection.
    bookPeriodRepositoryProvider.overrideWith(
      (ref) =>
          choose(ref, bookPeriods, londonAccounting.books, nyAccounting.books, zurichAccounting.books, milanAccounting.books, twin.periods),
    ),
    accountingConnectionRepositoryProvider.overrideWith(
      (ref) {
        final accounting = choose(
          ref,
          homeAccounting,
          londonAccounting,
          nyAccounting,
          zurichAccounting,
          milanAccounting,
          twin.accounting,
        );
        // #3336 — retiring and reopening are the owner's, as on the server
        return accounting
          ..isOwner = () => ref.read(myMemberProvider).value?.isOwner ?? false;
      },
    ),
    ..._contractOverrides(fixture, contracts),
    ..._kpiOverrides(fixture, buying, orderSpaces),
    ...demoBookFigureOverrides(
      fixture,
      buying,
      contracts,
      leipzig: leipzig.books,
      twin: (
        contracts: contracts.twin,
        valuations: twin.valuations,
        commitments: twin.commitments,
      ),
    ),
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

/// #3797 — Leipzig's own purchases, register, lease and rooms, empty: a
/// space a few weeks old has bought nothing yet, and says so.
({DemoPurchasing purchasing, DemoSpaceBooks books}) _leipzigStores(
  DemoFixture fixture,
) => (
  purchasing: DemoPurchasing(
    suppliers: FakeSupplierRepository(),
    inbox: FakeEInvoiceInboxRepository(),
    purchases: FakePurchaseRepository(
      actor: () => fixture.activeMemberId,
      workspaceId: demoSecondSpaceId,
    ),
  ),
  books: (
    contracts: (
      assets: FakeWorkspaceAssetRepository(),
      lease: FakePremisesLeaseRepository(),
      rooms: FakeRoomRentalRepository(),
    ),
    valuations: FakeAssetValuationRepository(),
    commitments: FakeLeaseCommitmentRepository(),
  ),
);

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

/// #3302 — the twin's books, lease, assets and rentals are its own, and
/// empty: nothing of production answers for the development side.
({
  FakeBookProfileRepository books,
  FakePremisesLeaseRepository lease,
  FakeWorkspaceAssetRepository assets,
  FakeBookPeriodRepository periods,
  FakeAccountingConnectionRepository accounting,
  FakeRoomRentalRepository rooms,
  FakeAssetValuationRepository valuations,
  FakeLeaseCommitmentRepository commitments,
})
_twinStores(DemoFixture fixture) {
  final twinBookPeriods = FakeBookPeriodRepository(today: fixture.seededAt);
  return (
    books: FakeBookProfileRepository(money: fixture.twin.money, purchases: fixture.twin.purchasing.purchases),
    lease: FakePremisesLeaseRepository(),
    assets: FakeWorkspaceAssetRepository(),
    periods: twinBookPeriods,
    accounting: FakeAccountingConnectionRepository(books: twinBookPeriods, today: fixture.seededAt),
    rooms: FakeRoomRentalRepository(),
    valuations: FakeAssetValuationRepository(),
    commitments: FakeLeaseCommitmentRepository(),
  );
}

/// #3832 — a trade city's book: kept locally, in its own currency.
FakeBookProfileRepository _tradeBooks(
  DemoTradeCity city,
  FakeMoneyRepository money,
  DateTime now,
  FakePurchaseRepository purchases,
) => cityBooks(
  money,
  now,
  workspaceId: city.id,
  siteId: city.siteIds.first,
  external: false,
  purchases: purchases,
  country: city.countryCode,
  currency: city.currency,
  years: DemoTradeCity.years,
);

/// #3832 — the printers each site of a trade city bought, as its bills say.
FakeWorkspaceAssetRepository _tradeAssets(DemoTradeCity city, DateTime now) =>
    cityAssets(
      now,
      tenant: false,
      sites: city.siteNames,
      prefix: city.prefix,
      currency: city.currency,
      years: DemoTradeCity.years,
    );
