// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 A — the Web-BI area's registry: which real analytics consumers
// exist, under which functional area, behind which feature and right.
//
// Only finished consumers are registered; an area with no module is not
// shown, so the BI page never presents a placeholder as a dashboard.
// Every module's read is authorized again by the server (#1921).
//
// Pure Dart.
library;

import 'bi_query.dart';
import 'kpi_contract.dart';
import 'workspace_feature.dart';
import 'workspace_permission.dart';

/// The functional areas of the BI page, in menu order (#1923).
enum BiArea {
  overview,
  capacity,
  people,
  finance,
  treasury,
  operations,
  planning,
  saved,
}

/// One registered analytics consumer.
class BiModule {
  const BiModule({
    required this.id,
    required this.area,
    required this.feature,
    required this.permissions,
    required this.aggregation,
    this.grains = const {BiGrain.month, BiGrain.quarter, BiGrain.year},
    this.comparisons = const {
      BiComparison.none,
      BiComparison.previousPeriod,
      BiComparison.previousYear,
      BiComparison.custom,
    },
    this.groupings = const {},
    this.drill,
  });

  /// Stable id — the KPI id when the module shows one KPI.
  final String id;
  final BiArea area;
  final WorkspaceFeature feature;

  /// Every right the module needs (mirrors the KPI registry, #1921).
  final Set<WorkspacePermission> permissions;

  /// How the figure combines over groups and time (#1918, B).
  final KpiAggregation aggregation;

  /// What the shared toolbar may ask of this module (#1923 B). An
  /// option outside these is refused with its reason, never ignored.
  final Set<BiGrain> grains;
  final Set<BiComparison> comparisons;

  /// Dimension names from [biDimensions].
  final Set<String> groupings;

  /// Where the figure comes from, for the reader allowed to go there.
  final BiDrill? drill;

  /// Why [context] cannot be answered by this module; empty when it can.
  Set<BiUnsupported> unsupported(BiQueryContext context) => {
    if (!grains.contains(context.grain)) BiUnsupported.grain,
    if (!comparisons.contains(context.comparison)) BiUnsupported.comparison,
    if (context.groupBy case final g? when !groupings.contains(g))
      BiUnsupported.grouping,
  };
}

/// The part of a context a module cannot answer.
enum BiUnsupported { grain, comparison, grouping }

/// A drill-through to the existing screen the figure is made from. The
/// target screen applies its own rights; [permission] decides whether
/// the link is offered or explained as restricted.
class BiDrill {
  const BiDrill({required this.route, required this.permission});

  final String route;
  final WorkspacePermission permission;
}

/// The registered modules. A new dashboard adds itself here.
const biModules = <BiModule>[
  BiModule(
    id: 'capacity.seat_utilisation',
    area: BiArea.capacity,
    feature: WorkspaceFeature.capacityKpi,
    permissions: {WorkspacePermission.viewAnalytics},
    aggregation: KpiAggregation.ratioOfSums,
    groupings: {'level'},
    // Offered seat time is made of the opening hours and closures set
    // there; that screen is where the denominator comes from.
    drill: BiDrill(
      route: '/availability',
      permission: WorkspacePermission.workspaceSettings,
    ),
  ),
  // #1924 — the treasurer's two figures, from the money report's own
  // predicates; the drill-through opens that report.
  BiModule(
    id: 'finance.invoiced',
    area: BiArea.finance,
    feature: WorkspaceFeature.workspaceStatus,
    permissions: {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    },
    aggregation: KpiAggregation.sum,
    drill: BiDrill(
      route: '/money/status',
      permission: WorkspacePermission.viewFinances,
    ),
  ),
  BiModule(
    id: 'finance.collected',
    area: BiArea.finance,
    feature: WorkspaceFeature.workspaceStatus,
    permissions: {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    },
    aggregation: KpiAggregation.sum,
    drill: BiDrill(
      route: '/money/status',
      permission: WorkspacePermission.viewFinances,
    ),
  ),
];

/// The modules [features] and [permissions] allow, in registry order.
List<BiModule> visibleBiModules(
  Set<WorkspaceFeature> features,
  Set<WorkspacePermission> permissions,
) => [
  for (final m in biModules)
    if (features.contains(m.feature) && permissions.containsAll(m.permissions))
      m,
];

/// Whether the BI area exists for this reader: at least one module they may
/// see. It is on every platform — the Android app had it, and it must stay
/// reachable there (the web-only rule of #1923 is lifted).
bool biAvailable({
  required Set<WorkspaceFeature> features,
  required Set<WorkspacePermission> permissions,
}) => visibleBiModules(features, permissions).isNotEmpty;
