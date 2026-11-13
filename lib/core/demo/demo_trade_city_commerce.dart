// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3832 - the purchase side, the book, the accounting connection and the
// register of a trade city (Zurich, Milan): its own stores, in its own
// currency, kept locally. It rents no premises and no rooms yet.
import 'data/accounting_connection_repository.dart';
import 'data/book_profile_repository.dart';
import 'data/premises_lease_repository.dart';
import 'data/room_rental_repository.dart';
import 'demo_analysis_overrides.dart';
import 'demo_fixture.dart';
import 'demo_trade_city_space.dart';
import 'seed/demo_city_books_seed.dart';
import 'seed/demo_city_purchase_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_trade_city_seed.dart';

typedef DemoTradeStores = ({
  DemoPurchasing buying,
  FakeBookProfileRepository books,
  FakeAccountingConnectionRepository accounting,
  DemoSpaceContracts contracts,
});

DemoTradeStores demoTradeCityStores(
  DemoFixture fixture,
  DemoTradeCity city,
  DemoTradeCityData data,
) {
  final now = fixture.seededAt;
  final buying = tradeCityPurchasing(
    city,
    now,
    actor: () => fixture.activeMemberId,
  );
  return (
    buying: buying,
    books: cityBooksOf(data.money, now, (
      workspaceId: city.id,
      siteId: city.siteIds.first,
      external: false,
      country: city.countryCode,
      currency: city.currency,
      years: DemoTradeCity.years,
    ), purchases: buying.purchases),
    accounting: cityAccounting(now, sage: false),
    contracts: (
      assets: cityAssets(
        now,
        tenant: false,
        sites: city.siteNames,
        prefix: city.prefix,
        currency: city.currency,
        years: DemoTradeCity.years,
      ),
      lease: FakePremisesLeaseRepository(),
      rooms: FakeRoomRentalRepository(currency: city.currency),
    ),
  );
}
