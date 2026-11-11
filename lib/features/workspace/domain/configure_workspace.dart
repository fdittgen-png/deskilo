// SPDX-License-Identifier: AGPL-3.0-or-later
import 'workspace_feature.dart';
import 'workspace_permission.dart';

/// #3282 — where "Configure workspace" leads [permissions]: the guide (its
/// overview, tasks and advanced settings) for whoever may configure, as its
/// routes require; else the deepest page the reader may open — the
/// workspace's settings, the switches, the plan. Null: nothing to configure.
String? configureWorkspaceRoute({
  required Set<WorkspacePermission> permissions,
  required Set<WorkspaceFeature> features,
  required bool setupOpen,
}) {
  bool may(WorkspacePermission p) => permissions.contains(p);
  if (setupOpen && may(WorkspacePermission.manageConfiguration)) {
    return '/setup';
  }
  if (may(WorkspacePermission.workspaceSettings)) return '/workspace-settings';
  if (may(WorkspacePermission.manageConfiguration)) return '/features';
  if (features.contains(WorkspaceFeature.placeBooking) &&
      may(WorkspacePermission.manageSites)) {
    return '/editor';
  }
  return null;
}
