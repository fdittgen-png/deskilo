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
import '../../features/stock/presentation/stock_expiry_screen.dart';
import '../../features/stock/presentation/stock_item_page.dart';
import '../../features/stock/presentation/stock_items_screen.dart';
import '../../features/stock/presentation/stock_movement_screen.dart';
import '../../features/stock/presentation/stock_places_screen.dart';
import '../../features/stock/presentation/stock_reorder_screen.dart';
import '../../features/stock/presentation/stock_screen.dart';
import '../../features/stock/presentation/stock_settings_screen.dart';
import '../../features/stock/presentation/stock_transfers_screen.dart';
import '../../features/stock/presentation/stock_units_screen.dart';
import '../../features/stock/presentation/stock_value_screen.dart';
import '../../features/stock/presentation/stock_where_is_screen.dart';
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
  const expiryAccess = RouteAccess(
    features: [WorkspaceFeature.stockManagement, WorkspaceFeature.stockExpiryReport],
    to: '/reserve',
  );
  const unitsAccess = RouteAccess(
    features: [WorkspaceFeature.stockManagement, WorkspaceFeature.stockHandlingUnits],
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
          // #4480 — one item at its own address: beside the list on a wide window, a page of its own on a phone.
          routes: [
            GoRoute(path: ':itemId', redirect: env.guard(access), pageBuilder: stockItemRoutePage),
          ],
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
        // #4431 — the expiry report: what is expired at a date or expires after it, printed from the report engine.
        GoRoute(
          path: 'expiry',
          redirect: env.guard(expiryAccess),
          builder: (context, state) => const StockExpiryScreen(),
        ),
        // #4435 — the handling units: pallets, cartons and boxes moved with their whole content, repackaged, traceable.
        GoRoute(
          path: 'units',
          redirect: env.guard(unitsAccess),
          builder: (context, state) => const StockUnitsScreen(),
        ),
        GoRoute(
          path: 'movements/:id',
          redirect: env.guard(access),
          builder: (context, state) =>
              StockMovementScreen(movementId: state.pathParameters['id'] ?? ''),
        ),
        // #4434 — where an item (or one of its lots) is, now or on a past day.
        GoRoute(
          path: 'where/:itemId',
          redirect: env.guard(access),
          builder: (context, state) => StockWhereIsScreen(itemId: state.pathParameters['itemId'] ?? '', lotId: state.uri.queryParameters['lot']),
        ),
      ],
    ),
  ];
}
