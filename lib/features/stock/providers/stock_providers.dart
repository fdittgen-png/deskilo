// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/providers/operation_context_providers.dart';
import '../application/stock_walk.dart';
import '../data/supabase_stock_queries.dart';
import '../domain/stock_page.dart';
import '../domain/stock_queries.dart';

/// #4161 -- the stock reads of the selected business. The Demo and the tests
/// replace it.
final stockQueriesProvider = Provider<StockQueries>(
  (ref) => SupabaseStockQueries(ref.watch(selectedWorkspaceClientProvider)),
);

/// What is on hand, a page at a time, for the filters chosen.
final stockOnHandWalkProvider = NotifierProvider.autoDispose
    .family<StockWalk<StockOnHandRow>, StockWalkState<StockOnHandRow>, StockFilters>(
      (filters) => StockWalk<StockOnHandRow>(
        filters,
        (ref) {
          final queries = ref.read(stockQueriesProvider);
          return (after) => queries.onHandPage(
            filters.workspaceId,
            itemId: filters.itemId,
            locationId: filters.locationId,
            after: after,
          );
        },
      ),
    );

/// The movements, newest first, a page at a time, for the filters chosen.
final stockMovementsWalkProvider = NotifierProvider.autoDispose
    .family<StockWalk<StockMovementRow>, StockWalkState<StockMovementRow>, StockFilters>(
      (filters) => StockWalk<StockMovementRow>(
        filters,
        (ref) {
          final queries = ref.read(stockQueriesProvider);
          return (after) => queries.movementsPage(
            filters.workspaceId,
            itemId: filters.itemId,
            locationId: filters.locationId,
            after: after,
          );
        },
      ),
    );

/// The places of a business, for the place filter.
final stockPlacesProvider = FutureProvider.autoDispose
    .family<List<StockPlace>, String>(
      (ref, workspaceId) => ref.watch(stockQueriesProvider).places(workspaceId),
      retry: (_, _) => null,
    );

/// The stock items of a business, for the item filter.
final stockItemsProvider = FutureProvider.autoDispose
    .family<List<StockItem>, String>(
      (ref, workspaceId) => ref.watch(stockQueriesProvider).items(workspaceId),
      retry: (_, _) => null,
    );

/// One movement by its address, or null when there is none.
final stockMovementProvider = FutureProvider.autoDispose
    .family<StockMovementRow?, ({String workspaceId, String id})>(
      (ref, key) =>
          ref.watch(stockQueriesProvider).movement(key.workspaceId, key.id),
      retry: (_, _) => null,
    );
