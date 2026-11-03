// SPDX-License-Identifier: AGPL-3.0-or-later
// City-specific purchasing and accounting repositories for the Demo.
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/money/providers/accounting_connection_providers.dart';
import '../../features/money/providers/asset_providers.dart';
import '../../features/money/providers/asset_valuation_providers.dart';
import '../../features/money/providers/book_period_providers.dart';
import '../../features/money/providers/book_profile_providers.dart';
import '../../features/money/providers/einvoice_inbox_providers.dart';
import '../../features/money/providers/premises_lease_providers.dart';
import '../../features/money/providers/room_rental_providers.dart';
import '../../features/workspace/domain/kpi_purchases.dart';
import '../../features/workspace/providers/kpi_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'data/asset_valuation_repository.dart';
import 'data/book_profile_repository.dart';
import 'data/demo_cost_kpi_repository.dart';
import 'data/kpi_repositories.dart';
import 'data/lease_commitment_repository.dart';
import 'data/premises_lease_repository.dart';
import 'data/room_rental_repository.dart';
import 'data/workspace_asset_repository.dart';
import 'demo_fixture.dart';
import 'demo_purchasing_overrides.dart';
import 'seed/demo_book_period_seed.dart';
import 'seed/demo_city_books_seed.dart';
import 'seed/demo_city_purchase_seed.dart';
import 'seed/demo_lease_seed.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_room_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_valuation_seed.dart';

DemoCapacityKpiRepository demoCapacityKpi(Ref ref, DemoFixture fixture) {
  final id = ref.watch(currentWorkspaceProvider).value?.id;
  final (plan, reservations) = switch (id) {
    demoSecondSpaceId => (fixture.secondSpace.floorPlan, fixture.secondSpace.reservations),
    demoLondonSpaceId => (fixture.london.floorPlan, fixture.london.reservations),
    demoNewYorkSpaceId => (fixture.newYork.floorPlan, fixture.newYork.reservations),
    null || '' || demoFirstSpaceId => (fixture.floorPlan, fixture.reservations),
    _ => throw StateError('unknown demo space: $id'),
  };
  return DemoCapacityKpiRepository(
    plan: plan, reservations: reservations, now: fixture.seededAt,
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
  final londonRooms = FakeRoomRentalRepository(currency: 'GBP');
  final nyRooms = FakeRoomRentalRepository(currency: 'USD');
  final londonValuations = FakeAssetValuationRepository();
  final nyValuations = FakeAssetValuationRepository();
  final londonCommitments = FakeLeaseCommitmentRepository();
  final nyCommitments = newYorkCommitments(fixture.seededAt);
  final homeRooms = seedDemoRooms(fixture.seededAt);
  final homeValuations = seedDemoValuations(fixture.seededAt);
  final homeCommitments = seedDemoCommitments(fixture.seededAt);
  final homePurchaseKpi = DemoPurchaseKpiRepository(
    purchases: purchasing.purchases,
    now: fixture.seededAt,
  );
  final londonPurchaseKpi = DemoPurchaseKpiRepository(
    purchases: londonPurchasing.purchases,
    now: fixture.seededAt,
    currency: 'GBP',
  );
  final nyPurchaseKpi = DemoPurchaseKpiRepository(
    purchases: nyPurchasing.purchases,
    now: fixture.seededAt,
    currency: 'USD',
  );
  final londonCostKpi = DemoCostKpiRepository(
    purchases: londonPurchasing.purchases,
    invoices: () => fixture.london.money.invoices,
    now: fixture.seededAt,
    currency: 'GBP',
  );
  final nyCostKpi = DemoCostKpiRepository(
    purchases: nyPurchasing.purchases,
    invoices: () => fixture.newYork.money.invoices,
    now: fixture.seededAt,
    currency: 'USD',
  );
  T choose<T>(Ref ref, T home, T london, T ny) =>
      switch (ref.watch(currentWorkspaceProvider).value?.id) {
        demoLondonSpaceId => london,
        demoNewYorkSpaceId => ny,
        _ => home,
      };
  return [
    eInvoiceInboxRepositoryProvider.overrideWith(
      (ref) => choose(
        ref,
        purchasing.inbox,
        londonPurchasing.inbox,
        nyPurchasing.inbox,
      ),
    ),
    ...demoPurchasingOverrides(
      purchasing,
      london: londonPurchasing,
      newYork: nyPurchasing,
    ),
    bookProfileRepositoryProvider.overrideWith(
      (ref) => choose(ref, mainBooks, londonBooks, nyBooks),
    ),
    retentionHoldRepositoryProvider.overrideWithValue(fixture.holds),
    premisesLeaseRepositoryProvider.overrideWith(
      (ref) => choose(ref, mainLease, londonLease, nyLease),
    ),
    workspaceAssetRepositoryProvider.overrideWith(
      (ref) => choose(ref, mainAssets, londonAssets, nyAssets),
    ),
    // #2365 last year's books, closed and exported; #2370 the studio's Pennylane connection.
    bookPeriodRepositoryProvider.overrideWith(
      (ref) =>
          choose(ref, bookPeriods, londonAccounting.books, nyAccounting.books),
    ),
    accountingConnectionRepositoryProvider.overrideWith(
      (ref) => choose(ref, homeAccounting, londonAccounting, nyAccounting),
    ),
    // #2568 — the rooms the demo space rents.
    roomRentalRepositoryProvider.overrideWith(
      (ref) => choose(ref, homeRooms, londonRooms, nyRooms),
    ),
    // #2576 — the accountant's valuations of the demo space's equipment.
    assetValuationRepositoryProvider.overrideWith(
      (ref) => choose(ref, homeValuations, londonValuations, nyValuations),
    ),
    leaseCommitmentRepositoryProvider.overrideWith(
      (ref) => choose(ref, homeCommitments, londonCommitments, nyCommitments),
    ),
    // #2582 — the purchase figures over these documents.
    purchaseKpiRepositoryProvider.overrideWith(
      (ref) => choose(ref, homePurchaseKpi, londonPurchaseKpi, nyPurchaseKpi),
    ),
    // The cost figures of the two cities, over their own documents and
    // invoices; the older spaces still have no server to read them from.
    costKpiRepositoryProvider.overrideWith(
      (ref) => choose<CostKpiRepository>(
        ref,
        const UnavailableCostKpiRepository(),
        londonCostKpi,
        nyCostKpi,
      ),
    ),
  ];
}
