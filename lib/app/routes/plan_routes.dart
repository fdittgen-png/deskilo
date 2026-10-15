// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: the retired /plan path and the accessories catalogue.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../features/plan/presentation/screens/accessories_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the plan feature.
List<RouteBase> planRoutes(RouteEnv env) {
  return [
    // #687 — /plan outlived its tab. Kept as a REDIRECT rather than
    // deleted: "Show on plan" (#182/#576), any stored shortcut and any
    // link someone already sent all point at it, and a dead path is a
    // worse answer than the map they were asking for.
    GoRoute(path: '/plan', redirect: (context, state) => '/reserve'),
    GoRoute(
      // Owner AND admins (#167, epic decision): catalog management is a
      // canAdminister capability, not owner-only.
      path: '/accessories',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.accessorySupplements],
          permission: WorkspacePermission.manageServices,
          bypass: RoleBypass.administrator,
        ),
      ),
      builder: (context, state) => const AccessoriesScreen(),
    ),
  ];
}
