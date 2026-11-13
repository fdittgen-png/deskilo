// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3785 — the analyses the Demo used to answer "no server in this mode":
// the cost figures, the cost allocation and the overview's own figures,
// each computed from the space being looked at, with its own stores, in
// its own currency. #3797 — each space's own purchases, register and lease
// (Leipzig's are empty), and each space's month and day read on the Demo's
// clock in the space's own time zone, as the server reads them.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' show Invoice;
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/money/providers/asset_valuation_providers.dart';
import '../../features/money/providers/premises_lease_providers.dart';
import '../../features/workspace/domain/workspace.dart';
import '../../features/workspace/providers/cost_allocation_providers.dart';
import '../../features/workspace/providers/kpi_providers.dart';
import '../../features/workspace/providers/overview_kpi_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'data/asset_valuation_repository.dart';
import 'data/demo_cost_allocation_repository.dart';
import 'data/demo_cost_kpi_repository.dart';
import 'data/demo_overview_kpi_repository.dart';
import 'data/event_repository.dart';
import 'data/floor_plan_repository.dart';
import 'data/lease_commitment_repository.dart';
import 'data/money_repository.dart';
import 'data/premises_lease_repository.dart';
import 'data/room_rental_repository.dart';
import 'data/workspace_asset_repository.dart';
import 'data/workspace_repository.dart';
import 'demo_fixture.dart';
import 'demo_space_pick.dart';
import 'seed/demo_purchase_seed.dart';

/// A field of the space's workspace record, by its id.
String Function(String) _recordOf(
  DemoFixture fixture,
  String Function(Workspace workspace) field,
) =>
    (id) => switch (fixture.workspaces.workspaces
        .where((w) => w.id == id)
        .firstOrNull) {
      final w? => field(w),
      null => '',
    };

/// The cost figures and the cost allocation of each space, from [costs],
/// and the overview's own figures.
List<Override> _analysisOverrides(
  DemoFixture fixture,
  DemoSpaces<DemoCostSources> costs,
) {
  final now = fixture.seededAt;
  final currencyOf = _recordOf(fixture, (w) => w.currencyCode);
  final timezoneOf = _recordOf(fixture, (w) => w.timezone);
  DemoCostAllocationRepository allocation(
    DemoCostSources s,
    FakeFloorPlanRepository plan,
  ) => DemoCostAllocationRepository(
    purchases: s.purchases,
    plan: plan,
    currencyOf: currencyOf,
    timezoneOf: timezoneOf,
    now: now,
  );
  // One store of rules per space, kept for the session.
  final DemoSpaces<DemoCostAllocationRepository> allocations = (
    home: allocation(costs.home, fixture.floorPlan),
    leipzig: allocation(costs.leipzig, fixture.secondSpace.floorPlan),
    london: allocation(costs.london, fixture.london.floorPlan),
    newYork: allocation(costs.newYork, fixture.newYork.floorPlan),
    zurich: allocation(costs.zurich, fixture.zurich.floorPlan),
    milan: allocation(costs.milan, fixture.milan.floorPlan),
    twin: allocation(costs.twin, fixture.twin.floorPlan),
  );
  return [
    costKpiRepositoryProvider.overrideWith(
      (ref) => DemoCostKpiRepository(
        sources: demoPickSpace(ref, costs),
        currencyOf: currencyOf,
        timezoneOf: timezoneOf,
        features: () => ref.read(enabledFeaturesSyncProvider),
        now: now,
      ),
    ),
    costAllocationRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, allocations),
    ),
    _overviewOverride(fixture, timezoneOf),
  ];
}

/// The overview's own figures of each space, from its members, requests
/// and invoices.
Override _overviewOverride(
  DemoFixture fixture,
  String Function(String) timezoneOf,
) {
  DemoOverviewKpiRepository space(
    FakeWorkspaceRepository workspaces,
    FakeEventRepository events,
    FakeMoneyRepository money,
  ) => DemoOverviewKpiRepository(
    workspaces: workspaces,
    events: events,
    money: money,
    now: fixture.seededAt,
    timezoneOf: timezoneOf,
  );
  final DemoSpaces<DemoOverviewKpiRepository> spaces = (
    home: space(fixture.workspaces, fixture.events, fixture.money),
    leipzig: space(
      fixture.secondSpace.workspaces,
      fixture.secondSpace.events,
      fixture.secondSpace.money,
    ),
    london: space(
      fixture.london.workspaces,
      fixture.london.events,
      fixture.london.money,
    ),
    newYork: space(
      fixture.newYork.workspaces,
      fixture.newYork.events,
      fixture.newYork.money,
    ),
    zurich: space(
      fixture.zurich.workspaces,
      fixture.zurich.events,
      fixture.zurich.money,
    ),
    milan: space(
      fixture.milan.workspaces,
      fixture.milan.events,
      fixture.milan.money,
    ),
    twin: space(fixture.twin.workspaces, fixture.twin.events, fixture.twin.money),
  );
  return overviewKpiRepositoryProvider.overrideWith(
    (ref) => demoPickSpace(ref, spaces),
  );
}

/// One space's equipment register, lease and rented rooms.
typedef DemoSpaceContracts = ({
  FakeWorkspaceAssetRepository assets,
  FakePremisesLeaseRepository lease,
  FakeRoomRentalRepository rooms,
});

/// One space's contracts with the accountant's valuations of its equipment
/// and what its lease and rooms still expect.
typedef DemoSpaceBooks = ({
  DemoSpaceContracts contracts,
  FakeAssetValuationRepository valuations,
  FakeLeaseCommitmentRepository commitments,
});

/// #2576 the accountant's valuations of each space's equipment, #2575 what
/// its lease still expects, and #3785 the analyses the Demo computes: the
/// cost figures from them, the cost allocation, the overview's own figures.
/// The main space's book values come with its monthly closing (#3794), its
/// commitments with the service charge and the studio (#3794).
List<Override> demoBookFigureOverrides(
  DemoFixture fixture,
  DemoSpaces<DemoPurchasing> purchasing,
  DemoSpaces<DemoSpaceBooks> figures,
) {
  final DemoSpaces<DemoSpaceContracts> spaces = demoMapSpaces(figures, (f) => f.contracts);
  final DemoSpaces<FakeAssetValuationRepository> valuations = demoMapSpaces(figures, (f) => f.valuations);
  final DemoSpaces<FakeLeaseCommitmentRepository> commitments = demoMapSpaces(figures, (f) => f.commitments);
  DemoCostSources sources(
    DemoPurchasing p,
    List<Invoice> Function() invoices,
    DemoSpaceContracts c,
    FakeAssetValuationRepository v,
    FakeLeaseCommitmentRepository l,
  ) => (
    purchases: p.purchases,
    invoices: invoices,
    assets: c.assets,
    valuations: v,
    commitments: l,
    leases: c.lease,
    rooms: c.rooms,
  );
  return [
    assetValuationRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, valuations),
    ),
    leaseCommitmentRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, commitments),
    ),
    ..._analysisOverrides(fixture, (
      home: sources(
        purchasing.home,
        () => fixture.money.invoices,
        spaces.home,
        valuations.home,
        commitments.home,
      ),
      leipzig: sources(
        purchasing.leipzig,
        () => fixture.secondSpace.money.invoices,
        spaces.leipzig,
        valuations.leipzig,
        commitments.leipzig,
      ),
      london: sources(
        purchasing.london,
        () => fixture.london.money.invoices,
        spaces.london,
        valuations.london,
        commitments.london,
      ),
      newYork: sources(
        purchasing.newYork,
        () => fixture.newYork.money.invoices,
        spaces.newYork,
        valuations.newYork,
        commitments.newYork,
      ),
      zurich: sources(
        purchasing.zurich,
        () => fixture.zurich.money.invoices,
        spaces.zurich,
        valuations.zurich,
        commitments.zurich,
      ),
      milan: sources(
        purchasing.milan,
        () => fixture.milan.money.invoices,
        spaces.milan,
        valuations.milan,
        commitments.milan,
      ),
      twin: sources(
        purchasing.twin,
        () => fixture.twin.money.invoices,
        spaces.twin,
        valuations.twin,
        commitments.twin,
      ),
    )),
  ];
}
