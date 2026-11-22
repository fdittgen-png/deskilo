// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B), #4299 -- the Stock route list: the records at `/stock`, the movement
// log, the items, the places and the stock settings, and one movement at its own
// address. One GoRoute and its RouteAccess each; router.dart
// composes the list. The feature and the permission the server asks are asked
// here too, so the entry, the link and the read agree.
import 'package:go_router/go_router.dart';

import '../../features/stock/application/stock_view.dart';
import '../../features/stock/presentation/stock_entry.dart';
import '../../features/stock/presentation/stock_items_screen.dart';
import '../../features/stock/presentation/stock_movement_screen.dart';
import '../../features/stock/presentation/stock_places_screen.dart';
import '../../features/stock/presentation/stock_reorder_screen.dart';
import '../../features/stock/presentation/stock_screen.dart';
import '../../features/stock/presentation/stock_settings_screen.dart';
import '../../features/stock/presentation/stock_transfers_screen.dart';
import '../../features/stock/presentation/stock_value_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the stockManagement feature.
List<RouteBase> stockRoutes(RouteEnv env) {
  const access = RouteAccess(
    features: [WorkspaceFeature.stockManagement],
    to: '/reserve',
  );
  const reorderAccess = RouteAccess(
    features: [WorkspaceFeature.stockManagement, WorkspaceFeature.stockReorder],
    to: '/reserve',
  );
  return [
    GoRoute(
      path: '/stock',
      redirect: env.guard(access),
      builder: (context, state) => StockEntry(itemId: state.uri.queryParameters['item']),
      routes: [
        // #4299 — the pages of the Stock group, each at its own address.
        GoRoute(
          path: 'movements',
          redirect: env.guard(access),
          builder: (context, state) => const StockScreen(tab: StockTab.movements),
        ),
        GoRoute(
          path: 'items',
          redirect: env.guard(access),
          builder: (context, state) => const StockItemsScreen(),
        ),
        GoRoute(
          path: 'places',
          redirect: env.guard(access),
          builder: (context, state) => const StockPlacesScreen(),
        ),
        GoRoute(
          path: 'settings',
          redirect: env.guard(access),
          builder: (context, state) => const StockSettingsScreen(),
        ),
        // #4294 — what is low and what to order: the stock, and the reorder points on top.
        GoRoute(
          path: 'reorder',
          redirect: env.guard(reorderAccess),
          builder: (context, state) => const StockReorderScreen(),
        ),
        // #4173 — the operational value of what is on hand, for who may see what goods cost.
        GoRoute(
          path: 'value',
          redirect: env.guard(access),
          builder: (context, state) => const StockValueScreen(),
        ),
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
