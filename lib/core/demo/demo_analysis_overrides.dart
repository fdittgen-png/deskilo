// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3785 — the analyses the Demo used to answer "no server in this mode":
// the cost figures, the cost allocation and the overview's own figures,
// each computed from the space being looked at, with its own stores, in
// its own currency.
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/workspace/providers/cost_allocation_providers.dart';
import '../../features/workspace/providers/kpi_providers.dart';
import '../../features/workspace/providers/overview_kpi_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'data/demo_cost_allocation_repository.dart';
import 'data/demo_cost_kpi_repository.dart';
import 'data/demo_overview_kpi_repository.dart';
import 'data/floor_plan_repository.dart';
import 'demo_fixture.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_twin_seed.dart';

/// The cost sources of each of the Demo's five spaces.
typedef DemoSpaceCosts = ({
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

/// The cost figures and the cost allocation of each space, from [costs].
List<Override> demoCostAnalysisOverrides(
  DemoFixture fixture,
  DemoSpaceCosts costs,
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
  ];
}

/// The overview's own figures of each space, from its members, requests
/// and invoices.
Override demoOverviewAnalysisOverride(DemoFixture fixture) {
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
