// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: deep links to a referenced reservation or space.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../features/reservations/domain/space_code.dart';
import '../../features/reservations/presentation/screens/reference_link_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
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
  ];
}
