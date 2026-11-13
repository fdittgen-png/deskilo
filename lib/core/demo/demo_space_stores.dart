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
import 'data/accounting_connection_repository.dart';
import 'data/asset_valuation_repository.dart';
import 'data/bank_statement_demo_seed.dart';
import 'data/bank_statement_repository.dart';
import 'data/book_period_repository.dart';
import 'data/book_profile_repository.dart';
import 'data/einvoice_inbox_repository.dart';
import 'data/lease_commitment_repository.dart';
import 'data/money_repository.dart';
import 'data/premises_lease_repository.dart';
import 'data/purchase_order_repository.dart';
import 'data/purchase_repository.dart';
import 'data/room_rental_repository.dart';
import 'data/supplier_repository.dart';
import 'data/workspace_asset_repository.dart';
import 'demo_analysis_overrides.dart';
import 'demo_fixture.dart';
import 'demo_purchase_order_overrides.dart';
import 'demo_space_pick.dart';
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
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_room_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_trade_city_seed.dart';
import 'seed/demo_valuation_seed.dart';

/// One space's session stores.
class DemoSpaceStores {
  const DemoSpaceStores({
    required this.buying,
    required this.orders,
    required this.bank,
    required this.books,
    required this.periods,
    required this.accounting,
    required this.figures,
  });

  final DemoPurchasing buying;
  final FakePurchaseOrderRepository orders;
  final FakeBankStatementRepository bank;
  final FakeBookProfileRepository books;
  final FakeBookPeriodRepository periods;
  final FakeAccountingConnectionRepository accounting;
  final DemoSpaceBooks figures;
}

/// Every space's stores, built once for [fixture]'s session.
DemoSpaces<DemoSpaceStores> buildDemoSpaceStores(DemoFixture fixture) {
  final now = fixture.seededAt;
  FakeBankStatementRepository emptyBank(FakeMoneyRepository money) =>
      FakeBankStatementRepository(money: money, today: now);
  FakePurchaseOrderRepository orders(
    DemoPurchasing buying,
    FakeMoneyRepository money,
    String currency, {
    bool seeded = false,
  }) => demoPurchaseOrders(fixture, buying, money, currency, seeded: seeded);
  DemoSpaceStores empty(
    DemoPurchasing buying,
    _EmptySpaceStores books,
    FakeMoneyRepository money,
  ) => DemoSpaceStores(
    buying: buying,
    orders: orders(buying, money, 'EUR'),
    bank: emptyBank(money),
    books: books.books,
    periods: books.periods,
    accounting: books.accounting,
    figures: books.figures,
  );
  final leipzigBuying = _leipzigPurchasing(fixture);
  return (
    home: _home(fixture, orders),
    leipzig: empty(
      leipzigBuying,
      _leipzigStores(fixture, leipzigBuying),
      fixture.secondSpace.money,
    ),
    london: _london(fixture, orders),
    newYork: _newYork(fixture, orders),
    zurich: _trade(fixture, demoZurich, fixture.zurich),
    milan: _trade(fixture, demoMilan, fixture.milan),
    twin: empty(fixture.twin.purchasing, _twinStores(fixture), fixture.twin.money),
  );
}

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
  DemoTradeCity city,
  DemoTradeCityData data,
) {
  final trade = demoTradeCityStores(fixture, city, data);
  return DemoSpaceStores(
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
