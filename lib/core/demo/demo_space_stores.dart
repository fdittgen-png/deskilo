// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3865 — what each Demo space keeps for the whole session: its purchases,
// suppliers, received invoices, orders, bank statement, book profile, book
// periods, accounting connection, lease, register and rooms. The stores
// live on the fixture, which outlives a change of persona, so what a
// visitor recorded is still there after "View as"; a Reset builds a new
// fixture and so gives the seeded state. The scope only routes to them
// (demo_city_commerce_overrides.dart, demo_space_routing.dart).
//
// #3302, #3797, #3866 — the two spaces that start empty, the development
// twin and Leipzig, have stores of their own: a record made in one is never
// read, or written, in another.
import '../../features/money/domain/customer_statement.dart' show CustomerStatementReader;
import 'data/accounting_connection_repository.dart';
import 'data/asset_valuation_repository.dart';
import 'data/bank_statement_demo_seed.dart';
import 'data/bank_statement_repository.dart';
import 'data/book_period_repository.dart';
import 'data/book_profile_repository.dart';
import 'data/demo_cost_allocation_repository.dart';
import 'data/einvoice_inbox_repository.dart';
import 'data/lease_commitment_repository.dart';
import 'data/money/demo_customer_statement.dart';
import 'data/money_repository.dart';
import 'data/premises_lease_repository.dart';
import 'data/purchase_order_repository.dart';
import 'data/purchase_repository.dart';
import 'data/room_rental_repository.dart';
import 'data/supplier_repository.dart';
import 'data/workspace_asset_repository.dart';
import 'demo_analysis_overrides.dart';
import 'demo_fixture.dart';
import 'demo_guest_pass_overrides.dart';
import 'demo_purchase_order_overrides.dart';
import 'demo_space_ids.dart';
import 'demo_spaces.dart';
import 'demo_trade_city_commerce.dart';
import 'demo_trade_city_space.dart';
import 'seed/demo_asset_seed.dart';
import 'seed/demo_book_period_seed.dart';
import 'seed/demo_city_bank_seed.dart';
import 'seed/demo_city_books_seed.dart';
import 'seed/demo_city_purchase_seed.dart';
import 'seed/demo_lease_seed.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_main_books_seed.dart';
import 'seed/demo_practice_seed.dart' show demoPracticeCountry;
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_room_seed.dart';
import 'seed/demo_trade_city_seed.dart';
import 'seed/demo_valuation_seed.dart';

/// One space's session stores.
class DemoSpaceStores {
  DemoSpaceStores({
    required this.fixture,
    required this.key,
    required this.buying,
    required this.orders,
    required this.bank,
    required this.books,
    required this.periods,
    required this.accounting,
    required this.figures,
  });

  final DemoFixture fixture;
  final DemoSpaceKey key;
  final DemoPurchasing buying;
  final FakePurchaseOrderRepository orders;
  final FakeBankStatementRepository bank;
  final FakeBookProfileRepository books;
  final FakeBookPeriodRepository periods;
  final FakeAccountingConnectionRepository accounting;
  final DemoSpaceBooks figures;

  /// #3846 — kept for the session like the rest, so the rules a visitor
  /// records for the cost allocation survive a switch of persona.
  late final DemoCostAllocationRepository allocation = demoCostAllocation(
    fixture,
    key,
    buying.purchases,
  );

  /// #3846 — the passes the space sells, and the rights they are sold under.
  late final DemoGuestPasses guestPasses = demoGuestPasses(fixture, key);

  /// #3846 — the customer statement of the space's own money.
  late final CustomerStatementReader statement = demoCustomerStatementReader(
    fixture.space(key),
  );
}

/// The stores of the space [key], built for [fixture]'s session (when first
/// read, see `DemoFixture.stores`).
DemoSpaceStores buildDemoSpaceStores(DemoFixture fixture, DemoSpaceKey key) =>
    switch (key) {
      DemoSpaceKey.home => _home(fixture, _orders(fixture)),
      DemoSpaceKey.leipzig => _leipzig(fixture),
      DemoSpaceKey.london => _london(fixture, _orders(fixture)),
      DemoSpaceKey.newYork => _newYork(fixture, _orders(fixture)),
      DemoSpaceKey.zurich => _trade(fixture, DemoSpaceKey.zurich, demoZurich, fixture.zurich),
      DemoSpaceKey.milan => _trade(fixture, DemoSpaceKey.milan, demoMilan, fixture.milan),
      DemoSpaceKey.practice => _practice(fixture),
      DemoSpaceKey.twin => _twin(fixture),
    };

_Orders _orders(DemoFixture fixture) =>
    (buying, money, currency, {seeded = false}) =>
        demoPurchaseOrders(fixture, buying, money, currency, seeded: seeded);

/// An empty space's stores: no orders, no bank statement yet.
DemoSpaceStores _empty(
  DemoFixture fixture,
  DemoSpaceKey key,
  DemoPurchasing buying,
  _EmptySpaceStores books,
  FakeMoneyRepository money,
) => DemoSpaceStores(
  fixture: fixture,
  key: key,
  buying: buying,
  orders: demoPurchaseOrders(fixture, buying, money, 'EUR'),
  bank: FakeBankStatementRepository(money: money, today: fixture.seededAt),
  books: books.books,
  periods: books.periods,
  accounting: books.accounting,
  figures: books.figures,
);

DemoSpaceStores _leipzig(DemoFixture fixture) {
  final buying = _leipzigPurchasing(fixture);
  return _empty(
    fixture,
    DemoSpaceKey.leipzig,
    buying,
    _leipzigStores(fixture, buying),
    fixture.secondSpace.money,
  );
}

/// #3863 — the practice's own purchases and books, empty: it buys nothing
/// in the Demo yet.
DemoSpaceStores _practice(DemoFixture fixture) {
  final buying = DemoPurchasing(
    suppliers: FakeSupplierRepository(),
    inbox: FakeEInvoiceInboxRepository(),
    purchases: FakePurchaseRepository(
      actor: () => fixture.activeMemberId,
      workspaceId: demoPracticeSpaceId,
    ),
  );
  return _empty(
    fixture,
    DemoSpaceKey.practice,
    buying,
    _emptyBooks(
      fixture,
      FakeBookProfileRepository(
        money: fixture.practice.money,
        purchases: buying.purchases,
        country: demoPracticeCountry,
      ),
    ),
    fixture.practice.money,
  );
}

DemoSpaceStores _twin(DemoFixture fixture) => _empty(
  fixture,
  DemoSpaceKey.twin,
  fixture.twin.purchasing,
  _twinStores(fixture),
  fixture.twin.money,
);

typedef _Orders =
    FakePurchaseOrderRepository Function(
      DemoPurchasing buying,
      FakeMoneyRepository money,
      String currency, {
      bool seeded,
    });

DemoSpaceStores _home(DemoFixture fixture, _Orders orders) {
  final now = fixture.seededAt;
  final buying = seedDemoPurchasing(
    now,
    money: fixture.money,
    plan: (fixture.workspaces, fixture.floorPlan),
    actor: () => fixture.activeMemberId,
    workspaceId: demoFirstSpaceId,
  );
  // #2365 last year's books, closed and exported; #2370 the studio's
  // Pennylane connection.
  final periods = seedDemoBookPeriods(now, actor: fixture.actor.memberId);
  return DemoSpaceStores(
    fixture: fixture,
    key: DemoSpaceKey.home,
    buying: buying,
    orders: orders(buying, fixture.money, 'EUR', seeded: true),
    bank: seedDemoBankStatements(fixture.money, now),
    // #1869 in memory; #2365 posts the demo money and its supplier bills.
    books: demoMainBooks(fixture, buying),
    periods: periods,
    accounting: seedDemoAccountingConnections(periods, now),
    figures: (
      contracts: (
        // #2569 the lease the space holds as tenant, #2576 the equipment it
        // bought, #2568 the rooms it rents.
        assets: seedDemoAssets(now),
        lease: seedDemoLease(now),
        rooms: seedDemoRooms(now),
      ),
      valuations: seedDemoBookValues(now),
      commitments: seedDemoCommitments(now),
    ),
  );
}

DemoSpaceStores _london(DemoFixture fixture, _Orders orders) {
  final now = fixture.seededAt;
  final buying = cityPurchasing(
    now,
    tenant: false,
    actor: () => fixture.activeMemberId,
    siteIds: [demoLondonSiteId, 'uk-site-islington', 'uk-site-hackney'],
  );
  final accounting = cityAccounting(now, sage: true);
  return DemoSpaceStores(
    fixture: fixture,
    key: DemoSpaceKey.london,
    buying: buying,
    orders: orders(buying, fixture.london.money, 'GBP', seeded: true),
    bank: seedCityBankStatement(fixture.london.money, now, 'uk', 'GBP'),
    books: cityBooks(
      fixture.london.money,
      now,
      workspaceId: demoLondonSpaceId,
      siteId: demoLondonSiteId,
      external: true,
      purchases: buying.purchases,
    ),
    periods: accounting.books,
    accounting: accounting,
    figures: (
      contracts: (
        assets: cityAssets(
          now,
          tenant: false,
          sites: ['Camden Yard', 'Islington Studio', 'Hackney Studio'],
        ),
        lease: FakePremisesLeaseRepository(),
        rooms: FakeRoomRentalRepository(currency: 'GBP'),
      ),
      valuations: FakeAssetValuationRepository(),
      commitments: FakeLeaseCommitmentRepository(),
    ),
  );
}

DemoSpaceStores _newYork(DemoFixture fixture, _Orders orders) {
  final now = fixture.seededAt;
  final buying = cityPurchasing(
    now,
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
  final accounting = cityAccounting(now, sage: false);
  return DemoSpaceStores(
    fixture: fixture,
    key: DemoSpaceKey.newYork,
    buying: buying,
    orders: orders(buying, fixture.newYork.money, 'USD', seeded: true),
    bank: seedCityBankStatement(fixture.newYork.money, now, 'ny', 'USD'),
    books: cityBooks(
      fixture.newYork.money,
      now,
      workspaceId: demoNewYorkSpaceId,
      siteId: 'ny-site-main',
      external: false,
      purchases: buying.purchases,
    ),
    periods: accounting.books,
    accounting: accounting,
    figures: (
      contracts: (
        assets: cityAssets(
          now,
          tenant: true,
          sites: [
            'Hudson House',
            'Brooklyn Studio',
            'Queens Studio',
            'Bronx Studio',
            'Harlem Studio',
          ],
        ),
        lease: newYorkLease(now),
        rooms: FakeRoomRentalRepository(currency: 'USD'),
      ),
      valuations: FakeAssetValuationRepository(),
      commitments: newYorkCommitments(now),
    ),
  );
}

/// #3832 — a trade city's stores, in its own currency; it orders nothing yet.
DemoSpaceStores _trade(
  DemoFixture fixture,
  DemoSpaceKey key,
  DemoTradeCity city,
  DemoTradeCityData data,
) {
  final trade = demoTradeCityStores(fixture, city, data);
  return DemoSpaceStores(
    fixture: fixture,
    key: key,
    buying: trade.buying,
    orders: demoPurchaseOrders(
      fixture,
      trade.buying,
      data.money,
      city.currency,
    ),
    bank: seedCityBankStatement(
      data.money,
      fixture.seededAt,
      city.prefix,
      city.currency,
    ),
    books: trade.books,
    periods: trade.accounting.books,
    accounting: trade.accounting,
    figures: (
      contracts: trade.contracts,
      valuations: FakeAssetValuationRepository(),
      commitments: FakeLeaseCommitmentRepository(),
    ),
  );
}

/// One empty space's books: the profile over its own money, the periods and
/// the accounting connection that closes them, and its contracts.
typedef _EmptySpaceStores = ({
  FakeBookProfileRepository books,
  FakeBookPeriodRepository periods,
  FakeAccountingConnectionRepository accounting,
  DemoSpaceBooks figures,
});

/// #3302 — the twin's books, lease, assets and rentals are its own, and
/// empty: nothing of production answers for the development side.
_EmptySpaceStores _twinStores(DemoFixture fixture) => _emptyBooks(
  fixture,
  FakeBookProfileRepository(
    money: fixture.twin.money,
    purchases: fixture.twin.purchasing.purchases,
  ),
);

/// #3797 — Leipzig's own purchases, empty: a space a few weeks old has
/// bought nothing yet, and says so.
DemoPurchasing _leipzigPurchasing(DemoFixture fixture) => DemoPurchasing(
  suppliers: FakeSupplierRepository(),
  inbox: FakeEInvoiceInboxRepository(),
  purchases: FakePurchaseRepository(
    actor: () => fixture.activeMemberId,
    workspaceId: demoSecondSpaceId,
  ),
);

/// #3866 — Leipzig's own books over its own money and purchases, empty.
_EmptySpaceStores _leipzigStores(
  DemoFixture fixture,
  DemoPurchasing purchasing,
) => _emptyBooks(
  fixture,
  FakeBookProfileRepository(
    money: fixture.secondSpace.money,
    purchases: purchasing.purchases,
    country: fixture.secondSpace.workspaces.workspaces.first.countryCode,
  ),
);

_EmptySpaceStores _emptyBooks(
  DemoFixture fixture,
  FakeBookProfileRepository profile,
) {
  final periods = FakeBookPeriodRepository(today: fixture.seededAt);
  return (
    books: profile,
    periods: periods,
    accounting: FakeAccountingConnectionRepository(
      books: periods,
      today: fixture.seededAt,
    ),
    figures: (
      contracts: (
        assets: FakeWorkspaceAssetRepository(),
        lease: FakePremisesLeaseRepository(),
        rooms: FakeRoomRentalRepository(),
      ),
      valuations: FakeAssetValuationRepository(),
      commitments: FakeLeaseCommitmentRepository(),
    ),
  );
}
