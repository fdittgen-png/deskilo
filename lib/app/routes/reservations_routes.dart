// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: deep links to a referenced reservation or space.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../features/reservations/domain/space_code.dart';
import '../../features/reservations/presentation/screens/period_reservations_screen.dart';
import '../../features/reservations/presentation/screens/reference_link_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the reservations feature.
List<RouteBase> reservationsRoutes(RouteEnv env) {
  return [
    GoRoute(
      path: '/res/:id',
      // #1151 — the deep links ride the memberNotifications gate the
      // comment above always claimed; now the route does too.
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.memberNotifications]),
      ),
      builder: (context, state) =>
          ReferenceLinkScreen.reservation(id: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/space/:kind/:id',
      // #1151 — the deep links ride the memberNotifications gate the
      // comment above always claimed; now the route does too.
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.memberNotifications]),
      ),
      builder: (context, state) => ReferenceLinkScreen.space(
        kind:
            SpaceKind.values.asNameMap()[state.pathParameters['kind'] ?? ''] ??
            SpaceKind.seat,
        id: state.pathParameters['id'] ?? '',
      ),
    ),
      // #2578 — the bookings behind the capacity figure, for its months.
    GoRoute(
      path: '/reservations/period',
      redirect: env.guard(
        const RouteAccess(
          permission: WorkspacePermission.viewAnalytics,
          features: [WorkspaceFeature.capacityKpi],
        ),
      ),
      builder: (context, state) => PeriodReservationsScreen(
        fromMonth: state.uri.queryParameters['from'] ?? '',
        toMonth: state.uri.queryParameters['to'] ?? '',
      ),
    ),
];
}
