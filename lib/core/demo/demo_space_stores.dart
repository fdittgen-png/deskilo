// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3302, #3797, #3866 — the stores of the two spaces that start empty: the
// development twin and Leipzig. Each has its own purchases, register,
// lease, rooms, book profile, book periods and accounting connection, so a
// record made in one is never read, or written, in another.
import 'data/accounting_connection_repository.dart';
import 'data/asset_valuation_repository.dart';
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
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_second_space_seed.dart';

/// One empty space's books: the profile over its own money, the periods and
/// the accounting connection that closes them, and its contracts.
typedef DemoEmptySpaceStores = ({
  FakeBookProfileRepository books,
  FakeBookPeriodRepository periods,
  FakeAccountingConnectionRepository accounting,
  DemoSpaceBooks figures,
});

/// #3302 — the twin's books, lease, assets and rentals are its own, and
/// empty: nothing of production answers for the development side.
DemoEmptySpaceStores twinStores(DemoFixture fixture) => _emptyBooks(
  fixture,
  FakeBookProfileRepository(
    money: fixture.twin.money,
    purchases: fixture.twin.purchasing.purchases,
  ),
);

/// #3797 — Leipzig's own purchases, empty: a space a few weeks old has
/// bought nothing yet, and says so.
DemoPurchasing leipzigPurchasing(DemoFixture fixture) => DemoPurchasing(
  suppliers: FakeSupplierRepository(),
  inbox: FakeEInvoiceInboxRepository(),
  purchases: FakePurchaseRepository(
    actor: () => fixture.activeMemberId,
    workspaceId: demoSecondSpaceId,
  ),
);

/// #3866 — Leipzig's own books over its own money and purchases, empty.
DemoEmptySpaceStores leipzigStores(
  DemoFixture fixture,
  DemoPurchasing purchasing,
) => _emptyBooks(
  fixture,
  FakeBookProfileRepository(
    money: fixture.secondSpace.money,
    purchases: purchasing.purchases,
    country: 'DE',
  ),
);

DemoEmptySpaceStores _emptyBooks(
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
