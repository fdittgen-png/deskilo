// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../money/providers/purchase_order_providers.dart';
import '../../workspace/providers/operation_context_providers.dart';
import '../application/stock_walk.dart';
import '../data/supabase_stock_config_commands.dart';
import '../data/supabase_stock_operations.dart';
import '../data/supabase_stock_queries.dart';
import '../data/supabase_stock_receiving_commands.dart';
import '../domain/stock_config_commands.dart';
import '../domain/stock_operations.dart';
import '../domain/stock_page.dart';
import '../domain/stock_queries.dart';
import '../domain/stock_receiving.dart';

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

/// #4169 -- the stock configuration of the selected business: what is read to
/// edit, and the guarded saves. The Demo and the tests replace it.
final stockConfigCommandsProvider = Provider<StockConfigCommands>(
  (ref) => SupabaseStockConfigCommands(ref.watch(selectedWorkspaceClientProvider)),
);

/// #4171 -- receiving a delivery into stock: the put-away commands of the
/// selected business. The Demo and the tests replace it.
final stockReceivingCommandsProvider = Provider<StockReceivingCommands>(
  (ref) => SupabaseStockReceivingCommands(ref.watch(selectedWorkspaceClientProvider)),
);

/// What was put away of the deliveries of one order, read again after each
/// put-away.
final orderPutAwayProvider = FutureProvider.autoDispose
    .family<List<ReceiptAllocation>, ({String workspaceId, String orderId})>(
      (ref, key) {
        // read again when the deliveries are (a delivery recorded with its put-away)
        ref.watch(purchaseOrderReceiptsProvider(key.workspaceId));
        return ref.watch(stockReceivingCommandsProvider).allocationsOfOrder(key.workspaceId, key.orderId);
      },
      retry: (_, _) => null,
    );

/// #4170 -- the stock commands of the selected business: transfers, take-out,
/// and the transfers still on their way. The Demo and the tests replace it.
final stockOperationsProvider = Provider<StockOperations>(
  (ref) => SupabaseStockOperations(ref.watch(selectedWorkspaceClientProvider)),
);

/// The transfers of a business that are not fully received.
final openTransfersProvider = FutureProvider.autoDispose
    .family<List<StockTransfer>, String>(
      (ref, workspaceId) => ref.watch(stockOperationsProvider).openTransfers(workspaceId),
      retry: (_, _) => null,
    );
