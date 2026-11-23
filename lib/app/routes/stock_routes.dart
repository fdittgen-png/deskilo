// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B), #4299 -- the Stock route list: the records at `/stock`, the movement
// log, the items, the places and the stock settings, and one movement at its own
// address. One GoRoute and its RouteAccess each; router.dart
// composes the list. The feature and the permission the server asks are asked
// here too, so the entry, the link and the read agree.
import 'package:go_router/go_router.dart';

import '../../features/stock/application/stock_view.dart';
import '../../features/stock/presentation/item_groups_screen.dart';
import '../../features/stock/presentation/stock_count_task_screen.dart';
import '../../features/stock/presentation/stock_counts_screen.dart';
import '../../features/stock/presentation/stock_cycle_counts_screen.dart';
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
  const countsAccess = RouteAccess(
    features: [WorkspaceFeature.stockManagement, WorkspaceFeature.stockCounts],
    to: '/reserve',
  );
  const reorderAccess = RouteAccess(
    features: [WorkspaceFeature.stockManagement, WorkspaceFeature.stockReorder],
    to: '/reserve',
  );
  const cycleAccess = RouteAccess(
    features: [WorkspaceFeature.stockManagement, WorkspaceFeature.stockCounts, WorkspaceFeature.stockCycleCounts],
    to: '/reserve',
  );
  const groupsAccess = RouteAccess(
    features: [WorkspaceFeature.stockManagement, WorkspaceFeature.stockItemGroups],
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
          builder: (context, state) => StockItemsScreen(addFirst: state.uri.queryParameters['add'] == '1'),
        ),
        GoRoute(
          path: 'places',
          redirect: env.guard(access),
          builder: (context, state) => StockPlacesScreen(addFirst: state.uri.queryParameters['add'] == '1'),
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
        // #4172 — the counts and their approval, where the feature is on.
        GoRoute(
          path: 'counts',
          redirect: env.guard(countsAccess),
          builder: (context, state) => const StockCountsScreen(),
        ),
        // #4295 — scheduled cycle counts: what to count (blind), the plans and the history.
        GoRoute(
          path: 'cycle-counts',
          redirect: env.guard(cycleAccess),
          builder: (context, state) => const StockCycleCountsScreen(),
          routes: [
            GoRoute(
              path: ':taskId',
              redirect: env.guard(cycleAccess),
              builder: (context, state) => StockCountTaskScreen(taskId: state.pathParameters['taskId'] ?? ''),
            ),
          ],
        ),
        // #4361 — item groups: shared settings that items inherit and may override.
        GoRoute(
          path: 'groups',
          redirect: env.guard(groupsAccess),
          builder: (context, state) => const ItemGroupsScreen(),
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
