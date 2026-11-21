// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B) -- the Stock route list: the records at `/stock`, and one movement
// at its own address. One GoRoute and its RouteAccess each; router.dart
// composes the list. The feature and the permission the server asks are asked
// here too, so the entry, the link and the read agree.
import 'package:go_router/go_router.dart';

import '../../features/stock/presentation/stock_entry.dart';
import '../../features/stock/presentation/stock_movement_screen.dart';
import '../../features/stock/presentation/stock_transfers_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the stockManagement feature.
List<RouteBase> stockRoutes(RouteEnv env) {
  const access = RouteAccess(
    features: [WorkspaceFeature.stockManagement],
    to: '/reserve',
  );
  return [
    GoRoute(
      path: '/stock',
      redirect: env.guard(access),
      builder: (context, state) => StockEntry(itemId: state.uri.queryParameters['item']),
      routes: [
        GoRoute(
          path: 'transfers',
          redirect: env.guard(access),
          builder: (context, state) => const StockTransfersScreen(),
        ),
        GoRoute(
          path: 'movements/:id',
          redirect: env.guard(access),
          builder: (context, state) =>
              StockMovementScreen(movementId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
  ];
}
