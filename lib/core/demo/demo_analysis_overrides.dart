// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3785 — the analyses the Demo used to answer "no server in this mode":
// the cost figures, the cost allocation and the overview's own figures,
// each computed from the space being looked at, with its own stores, in
// its own currency.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' show Invoice;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/money/providers/asset_valuation_providers.dart';
import '../../features/money/providers/premises_lease_providers.dart';
import '../../features/workspace/providers/cost_allocation_providers.dart';
import '../../features/workspace/providers/kpi_providers.dart';
import '../../features/workspace/providers/overview_kpi_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'data/asset_valuation_repository.dart';
import 'data/demo_cost_allocation_repository.dart';
import 'data/demo_cost_kpi_repository.dart';
import 'data/demo_overview_kpi_repository.dart';
import 'data/floor_plan_repository.dart';
import 'data/lease_commitment_repository.dart';
import 'data/workspace_asset_repository.dart';
import 'demo_fixture.dart';
import 'seed/demo_city_books_seed.dart';
import 'seed/demo_lease_seed.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_twin_seed.dart';
import 'seed/demo_valuation_seed.dart';

/// The cost sources of each of the Demo's five spaces.
typedef _SpaceCosts = ({
  DemoCostSources home,
  DemoCostSources leipzig,
  DemoCostSources london,
  DemoCostSources newYork,
  DemoCostSources twin,
});

/// The one of [home], [leipzig], [london], [newYork], [twin] that belongs
/// to the space being looked at.
T _pick<T>(Ref ref, T home, T leipzig, T london, T newYork, T twin) =>
    switch (ref.watch(currentWorkspaceProvider).value?.id) {
      demoSecondSpaceId => leipzig,
      demoLondonSpaceId => london,
      demoNewYorkSpaceId => newYork,
      demoTwinSpaceId => twin,
      _ => home,
    };

/// The space's currency as its workspace record states it.
String Function(String) _currencyOf(DemoFixture fixture) =>
    (id) =>
        fixture.workspaces.workspaces
            .where((w) => w.id == id)
            .firstOrNull
            ?.currencyCode ??
        '';

/// The cost figures and the cost allocation of each space, from [costs],
/// and the overview's own figures.
List<Override> _analysisOverrides(
  DemoFixture fixture,
  _SpaceCosts costs,
) {
  final now = fixture.seededAt;
  final currencyOf = _currencyOf(fixture);
  DemoCostAllocationRepository allocation(
    DemoCostSources s,
    FakeFloorPlanRepository plan,
  ) => DemoCostAllocationRepository(
    purchases: s.purchases,
    plan: plan,
    currencyOf: currencyOf,
    now: now,
  );
  // One store of rules per space, kept for the session.
  final allocations = (
    allocation(costs.home, fixture.floorPlan),
    allocation(costs.leipzig, fixture.secondSpace.floorPlan),
    allocation(costs.london, fixture.london.floorPlan),
    allocation(costs.newYork, fixture.newYork.floorPlan),
    allocation(costs.twin, fixture.twin.floorPlan),
  );
  return [
    costKpiRepositoryProvider.overrideWith((ref) {
      final sources = _pick(
        ref,
        costs.home,
        costs.leipzig,
        costs.london,
        costs.newYork,
        costs.twin,
      );
      return DemoCostKpiRepository(
        sources: sources,
        currencyOf: currencyOf,
        features: () => ref.read(enabledFeaturesSyncProvider),
        now: now,
      );
    }),
    costAllocationRepositoryProvider.overrideWith(
      (ref) => _pick(
        ref,
        allocations.$1,
        allocations.$2,
        allocations.$3,
        allocations.$4,
        allocations.$5,
      ),
    ),
    _overviewOverride(fixture),
  ];
}

/// The overview's own figures of each space, from its members, requests
/// and invoices.
Override _overviewOverride(DemoFixture fixture) {
  final now = fixture.seededAt;
  final spaces = (
    DemoOverviewKpiRepository(
      workspaces: fixture.workspaces,
      events: fixture.events,
      money: fixture.money,
      now: now,
    ),
    DemoOverviewKpiRepository(
      workspaces: fixture.secondSpace.workspaces,
      events: fixture.secondSpace.events,
      money: fixture.secondSpace.money,
      now: now,
    ),
    DemoOverviewKpiRepository(
      workspaces: fixture.london.workspaces,
      events: fixture.london.events,
      money: fixture.london.money,
      now: now,
    ),
    DemoOverviewKpiRepository(
      workspaces: fixture.newYork.workspaces,
      events: fixture.newYork.events,
      money: fixture.newYork.money,
      now: now,
    ),
    DemoOverviewKpiRepository(
      workspaces: fixture.twin.workspaces,
      events: fixture.twin.events,
      money: fixture.twin.money,
      now: now,
    ),
  );
  return overviewKpiRepositoryProvider.overrideWith(
    (ref) => _pick(ref, spaces.$1, spaces.$2, spaces.$3, spaces.$4, spaces.$5),
  );
}

/// #2576 the accountant's valuations of each space's equipment, #2575 what
/// its lease still expects, and #3785 the analyses the Demo computes: the
/// cost figures from them, the cost allocation, the overview's own figures.
List<Override> demoBookFigureOverrides(
  DemoFixture fixture,
  ({DemoPurchasing home, DemoPurchasing london, DemoPurchasing newYork})
  purchasing,
  ({
    FakeWorkspaceAssetRepository home,
    FakeWorkspaceAssetRepository london,
    FakeWorkspaceAssetRepository newYork,
  })
  assets,
  ({
    FakeWorkspaceAssetRepository assets,
    FakeAssetValuationRepository valuations,
    FakeLeaseCommitmentRepository commitments,
  })
  twin,
) {
  final valuations = (
    home: seedDemoValuations(fixture.seededAt),
    london: FakeAssetValuationRepository(),
    newYork: FakeAssetValuationRepository(),
  );
  final commitments = (
    home: seedDemoCommitments(fixture.seededAt),
    london: FakeLeaseCommitmentRepository(),
    newYork: newYorkCommitments(fixture.seededAt),
  );
  T choose<T>(Ref ref, T home, T london, T ny, T devTwin) =>
      switch (ref.watch(currentWorkspaceProvider).value?.id) {
        demoLondonSpaceId => london,
        demoNewYorkSpaceId => ny,
        demoTwinSpaceId => devTwin,
        _ => home,
      };
  DemoCostSources sources(
    DemoPurchasing p,
    List<Invoice> Function() invoices,
    FakeWorkspaceAssetRepository a,
    FakeAssetValuationRepository v,
    FakeLeaseCommitmentRepository c,
  ) => (
    purchases: p.purchases,
    invoices: invoices,
    assets: a,
    valuations: v,
    commitments: c,
  );
  final home = sources(
    purchasing.home,
    () => fixture.money.invoices,
    assets.home,
    valuations.home,
    commitments.home,
  );
  return [
    assetValuationRepositoryProvider.overrideWith(
      (ref) => choose(
        ref,
        valuations.home,
        valuations.london,
        valuations.newYork,
        twin.valuations,
      ),
    ),
    leaseCommitmentRepositoryProvider.overrideWith(
      (ref) => choose(
        ref,
        commitments.home,
        commitments.london,
        commitments.newYork,
        twin.commitments,
      ),
    ),
    // Leipzig reads the purchases, the register and the lease of Pézenas,
    // as its pages do, and its own invoices.
    ..._analysisOverrides(fixture, (
      home: home,
      leipzig: (
        purchases: home.purchases,
        invoices: () => fixture.secondSpace.money.invoices,
        assets: home.assets,
        valuations: home.valuations,
        commitments: home.commitments,
      ),
      london: sources(
        purchasing.london,
        () => fixture.london.money.invoices,
        assets.london,
        valuations.london,
        commitments.london,
      ),
      newYork: sources(
        purchasing.newYork,
        () => fixture.newYork.money.invoices,
        assets.newYork,
        valuations.newYork,
        commitments.newYork,
      ),
      twin: (
        purchases: fixture.twin.purchasing.purchases,
        invoices: () => fixture.twin.money.invoices,
        assets: twin.assets,
        valuations: twin.valuations,
        commitments: twin.commitments,
      ),
    )),
  ];
}
