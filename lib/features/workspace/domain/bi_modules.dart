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
  });

  /// Stable id — the KPI id when the module shows one KPI.
  final String id;
  final BiArea area;
  final WorkspaceFeature feature;

  /// Every right the module needs (mirrors the KPI registry, #1921).
  final Set<WorkspacePermission> permissions;
}

/// The registered modules. A new dashboard adds itself here.
const biModules = <BiModule>[
  BiModule(
    id: 'capacity.seat_utilisation',
    area: BiArea.capacity,
    feature: WorkspaceFeature.capacityKpi,
    permissions: {WorkspacePermission.viewAnalytics},
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

/// Whether the BI area exists for this reader on this platform: the web
/// build only (a native app with the menu chosen is not the web), and at
/// least one module.
bool biAvailable({
  required bool platformIsWeb,
  required Set<WorkspaceFeature> features,
  required Set<WorkspacePermission> permissions,
}) => platformIsWeb && visibleBiModules(features, permissions).isNotEmpty;
