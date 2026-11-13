// SPDX-License-Identifier: AGPL-3.0-or-later
// The fixture owns mutable commercial stores. Changing persona rebuilds the
// provider scope and its permissions without resetting bills, orders or banks.
import 'data/accounting_connection_repository.dart';
import 'data/asset_valuation_repository.dart';
import 'data/bank_statement_demo_seed.dart';
import 'data/bank_statement_repository.dart';
import 'data/book_period_repository.dart';
import 'data/book_profile_repository.dart';
import 'data/einvoice_inbox_repository.dart';
import 'data/lease_commitment_repository.dart';
import 'data/premises_lease_repository.dart';
import 'data/purchase_repository.dart';
import 'data/room_rental_repository.dart';
import 'data/supplier_repository.dart';
import 'data/workspace_asset_repository.dart';
import 'demo_analysis_overrides.dart';
import 'demo_fixture.dart';
import 'demo_purchase_order_overrides.dart';
import 'demo_space_pick.dart';
import 'seed/demo_asset_seed.dart';
import 'seed/demo_book_period_seed.dart';
import 'seed/demo_city_bank_seed.dart';
import 'seed/demo_city_books_seed.dart';
import 'seed/demo_city_purchase_seed.dart';
import 'seed/demo_lease_seed.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_main_books_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_room_seed.dart';
import 'seed/demo_second_space_seed.dart';

typedef DemoMainBooks = ({
  DemoPurchasing purchasing,
  FakeBookProfileRepository books,
  FakePremisesLeaseRepository lease,
  FakeWorkspaceAssetRepository assets,
});

DemoMainBooks _seedMainBooks(DemoFixture fixture) {
  final purchasing = seedDemoPurchasing(fixture.seededAt, money: fixture.money, plan: (fixture.workspaces, fixture.floorPlan), actor: () => fixture.activeMemberId, workspaceId: demoFirstSpaceId);
  return (
    purchasing: purchasing,
    // #1869 in memory; #2365 posts the demo money and its supplier bills.
    books: demoMainBooks(fixture, purchasing),
    // #2569 — the lease the demo space holds as tenant.
    lease: seedDemoLease(fixture.seededAt),
    // #2576 — the equipment the demo space bought.
    assets: seedDemoAssets(fixture.seededAt),
  );
}

typedef DemoCommerceStores = ({
  DemoMainBooks main,
  DemoSpaces<DemoPurchasing> buying,
  DemoPurchaseOrderSpaces orders,
  DemoSpaces<DemoSpaceContracts> contracts,
  DemoSpaces<FakeBookProfileRepository> books,
  DemoSpaces<FakeBookPeriodRepository> periods,
  DemoSpaces<FakeAccountingConnectionRepository> accounting,
  DemoSpaces<FakeBankStatementRepository> bankStatements,
  DemoSpaceBooks leipzig,
  DemoSpaceBooks twin,
});

DemoCommerceStores seedDemoCommerce(DemoFixture fixture) {
  final main = _seedMainBooks(fixture);
  final purchasing = main.purchasing;
  final mainBooks = main.books;
  final mainLease = main.lease;
  final mainAssets = main.assets;
  final bookPeriods = seedDemoBookPeriods(
    fixture.seededAt,
    actor: fixture.actor.memberId,
  );
  final londonPurchasing = cityPurchasing(
    fixture.seededAt,
    spec: (workspaceId: demoLondonSpaceId, prefix: 'uk', country: 'GB', currency: 'GBP',
      years: 3, vatPercent: 20),
    actor: () => fixture.activeMemberId,
    siteIds: [demoLondonSiteId, 'uk-site-islington', 'uk-site-hackney'],
  );
  final nyPurchasing = cityPurchasing(
    fixture.seededAt,
    spec: (workspaceId: demoNewYorkSpaceId, prefix: 'ny', country: 'US', currency: 'USD',
      years: 4, vatPercent: 0), tenant: true,
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
    spec: (workspaceId: demoLondonSpaceId, siteId: demoLondonSiteId,
      country: 'GB', currency: 'GBP'), external: true,
    purchases: londonPurchasing.purchases,
  );
  final nyBooks = cityBooks(
    fixture.newYork.money,
    fixture.seededAt,
    spec: (workspaceId: demoNewYorkSpaceId, siteId: 'ny-site-main',
      country: 'US', currency: 'USD'), external: false,
    purchases: nyPurchasing.purchases,
  );
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
    prefix: 'uk', currency: 'GBP', years: 3, vatPercent: 20,
    sites: ['Camden Yard', 'Islington Studio', 'Hackney Studio'],
  );
  final nyAssets = cityAssets(
    fixture.seededAt,
    prefix: 'ny', currency: 'USD', years: 4, vatPercent: 0,
    sites: [
      'Hudson House',
      'Brooklyn Studio',
      'Queens Studio',
      'Bronx Studio',
      'Harlem Studio',
    ],
  );
  final londonRooms = FakeRoomRentalRepository(currency: 'GBP');
  final nyRooms = FakeRoomRentalRepository(currency: 'USD');
  final homeRooms = seedDemoRooms(fixture.seededAt);
  final twin = _twinStores(fixture);
  final leipzig = _leipzigStores(fixture);
  final DemoSpaces<DemoPurchasing> buying = (
    home: purchasing,
    leipzig: leipzig.purchasing,
    london: londonPurchasing,
    newYork: nyPurchasing,
    zurich: fixture.zurich.purchasing,
    milan: fixture.milan.purchasing,
    twin: fixture.twin.purchasing,
  );
  final orderSpaces = demoPurchaseOrderSpaces(fixture, buying);
  final leipzigBooks = FakeBookProfileRepository(money: fixture.secondSpace.money,
    purchases: leipzig.purchasing.purchases, country: 'DE');
  final leipzigPeriods = FakeBookPeriodRepository(today: fixture.seededAt);
  final leipzigAccounting = FakeAccountingConnectionRepository(
    books: leipzigPeriods, today: fixture.seededAt);
  final DemoSpaces<FakeAccountingConnectionRepository> accountingSpaces = (
    home: homeAccounting, leipzig: leipzigAccounting, london: londonAccounting,
    newYork: nyAccounting, zurich: fixture.zurich.accounting,
    milan: fixture.milan.accounting, twin: twin.accounting,
  );
  final DemoSpaces<DemoSpaceContracts> contracts = (
    home: (assets: mainAssets, lease: mainLease, rooms: homeRooms),
    leipzig: leipzig.books.contracts,
    london: (assets: londonAssets, lease: londonLease, rooms: londonRooms),
    newYork: (assets: nyAssets, lease: nyLease, rooms: nyRooms),
    zurich: (assets: fixture.zurich.assets, lease: fixture.zurich.lease, rooms: fixture.zurich.rooms),
    milan: (assets: fixture.milan.assets, lease: fixture.milan.lease, rooms: fixture.milan.rooms),
    twin: (assets: twin.assets, lease: twin.lease, rooms: twin.rooms),
  );
  return (
    main: main, buying: buying, orders: orderSpaces, contracts: contracts,
    bankStatements: _seedBankStatements(fixture),
    books: (home: mainBooks, leipzig: leipzigBooks, london: londonBooks,
      newYork: nyBooks, zurich: fixture.zurich.books, milan: fixture.milan.books,
      twin: twin.books),
    periods: (home: bookPeriods, leipzig: leipzigPeriods,
      london: londonAccounting.books, newYork: nyAccounting.books,
      zurich: fixture.zurich.periods, milan: fixture.milan.periods,
      twin: twin.periods),
    accounting: accountingSpaces, leipzig: leipzig.books,
    twin: (contracts: contracts.twin, valuations: twin.valuations,
      commitments: twin.commitments),
  );
}

DemoSpaces<FakeBankStatementRepository> _seedBankStatements(DemoFixture fixture) {
  final today = fixture.seededAt;
  return (
    home: seedDemoBankStatements(fixture.money, today),
    leipzig: FakeBankStatementRepository(money: fixture.secondSpace.money, today: today),
    london: seedCityBankStatement(fixture.london.money, today, 'uk', 'GBP'),
    newYork: seedCityBankStatement(fixture.newYork.money, today, 'ny', 'USD'),
    zurich: seedCityBankStatement(fixture.zurich.money, today, 'ch', 'CHF'),
    milan: seedCityBankStatement(fixture.milan.money, today, 'it', 'EUR'),
    twin: FakeBankStatementRepository(money: fixture.twin.money, today: today),
  );
}

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
