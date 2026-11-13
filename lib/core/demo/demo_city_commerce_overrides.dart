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
import 'data/sales_kpi_repository.dart';
import 'data/vendor_kpi_repository.dart';
import 'demo_analysis_overrides.dart';
import 'demo_fixture.dart';
import 'demo_purchase_order_overrides.dart';
import 'demo_purchasing_overrides.dart';
import 'demo_space_pick.dart';
import 'seed/demo_purchase_seed.dart';

DemoCapacityKpiRepository demoCapacityKpi(Ref ref, DemoFixture fixture) {
  final key = demoOpenSpace(ref);
  return DemoCapacityKpiRepository(
    plan: fixture.spaceFloorPlans.at(key),
    reservations: fixture.spaceReservations.at(key),
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
  // #3294 step 3 — the sales figures of each space, from its own invoices and
  // the rooms it rents (Leipzig rents none).
  salesKpiRepositoryProvider.overrideWith((ref) {
    final key = demoOpenSpace(ref);
    final money = fixture.spaceMoney.at(key);
    final bookings = fixture.spaceReservations.at(key);
    return DemoSalesKpiRepository(
      invoices: () => money.invoices,
      rooms: contracts.at(key).rooms,
      bookings: () => bookings.reservations,
      roomsEnabled: () => ref
          .read(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.externalRooms),
      now: fixture.seededAt,
      currency: key.currency,
    );
  }),
];

/// #2582 — the purchase figures over each space's own documents, in its own
/// currency; #3797 Leipzig's are its own (none yet).
List<Override> _kpiOverrides(
  DemoFixture fixture,
  DemoSpaces<DemoPurchasing> buying,
  DemoPurchaseOrderSpaces orderSpaces,
) {
  final now = fixture.seededAt;
  final purchase = demoSpacesOf(
    (key) => DemoPurchaseKpiRepository(
      purchases: buying.at(key).purchases,
      now: now,
      currency: key.currency,
    ),
  );
  return [
    // #3294 — the customer figures of each space, from its own money, under
    // the reader's rights as the server would decide them.
    customerKpiRepositoryProvider.overrideWith((ref) {
      final key = demoOpenSpace(ref);
      return DemoCustomerKpiRepository(
        money: fixture.spaceMoney.at(key),
        now: now,
        currency: key.currency,
        namesVisible: () => ref
            .read(myPermissionsProvider)
            .contains(WorkspacePermission.viewPersonalData),
        dunningEnabled: () => ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.dunning),
      );
    }),
    purchaseKpiRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, purchase),
    ),
    // #3294 step 4 — the item figures over each space's own purchases and
    // the sales of its catalogue items, in its own currency.
    itemKpiRepositoryProvider.overrideWith((ref) {
      final key = demoOpenSpace(ref);
      final money = fixture.spaceMoney.at(key);
      return DemoItemKpiRepository(
        purchases: buying.at(key).purchases,
        invoices: () => money.invoices,
        services: () => money.services,
        now: now,
        currency: key.currency,
      );
    }),
    // #3294 step 2 — the vendor figures over each space's own purchases and
    // orders, in its own currency (#3302 the twin has none).
    vendorKpiRepositoryProvider.overrideWith((ref) {
      final key = demoOpenSpace(ref);
      return DemoVendorKpiRepository(
        purchases: buying.at(key).purchases,
        now: now,
        currency: key.currency,
        orders: key == DemoSpaceKey.twin ? null : orderSpaces.at(key),
      );
    }),
  ];
}
