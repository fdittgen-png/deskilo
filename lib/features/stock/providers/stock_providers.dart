// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/active_settings.dart';
import '../../../core/settings/setting_defaults.g.dart';
import '../../money/providers/purchase_order_providers.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/stock_walk.dart';
import '../data/supabase_item_groups.dart';
import '../data/supabase_stock_code_resolver.dart';
import '../data/supabase_stock_config_commands.dart';
import '../data/supabase_stock_cycle_counts.dart';
import '../data/supabase_stock_operations.dart';
import '../data/supabase_stock_queries.dart';
import '../data/supabase_stock_receiving_commands.dart';
import '../data/supabase_stock_registry.dart';
import '../data/supabase_stock_reorder.dart';
import '../data/supabase_stock_reversals.dart';
import '../data/supabase_stock_tags.dart';
import '../data/supabase_stock_trace.dart';
import '../data/supabase_stock_trace_chain.dart';
import '../domain/item_groups.dart';
import '../domain/stock_code_resolver.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_commands.dart';
import '../domain/stock_cycle_counts.dart';
import '../domain/stock_operations.dart';
import '../domain/stock_page.dart';
import '../domain/stock_queries.dart';
import '../domain/stock_receiving.dart';
import '../domain/stock_registry.dart';
import '../domain/stock_reorder.dart';
import '../domain/stock_reversals.dart';
import '../domain/stock_service_creator.dart';
import '../domain/stock_tags.dart';
import '../domain/stock_trace.dart';
import '../domain/stock_trace_chain.dart';

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

/// #4293 -- the character shown between the levels of a place address
/// (`stock.address_separator`); the registry default while the settings load.
final stockAddressSeparatorProvider = Provider<String>((ref) {
  final settings = ref.watch(activeSettingsProvider);
  return settings != null && settings.definitions.containsKey('stock.address_separator')
      ? settings.read<String>('stock.address_separator')
      : SettingDefaults.stockAddressSeparator;
});

/// #4365 -- whether the business sells by weight (`stock.weighed_goods`): a new item is proposed in kilograms.
final stockWeighedGoodsProvider = Provider<bool>((ref) {
  final settings = ref.watch(activeSettingsProvider);
  return settings != null && settings.definitions.containsKey('stock.weighed_goods')
      ? settings.read<bool>('stock.weighed_goods')
      : SettingDefaults.stockWeighedGoods;
});

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

/// #4293 -- the product and place registry of the selected business. The Demo and the tests
/// replace it.
final stockRegistryProvider = Provider<StockRegistry>(
  (ref) => SupabaseStockRegistry(ref.watch(selectedWorkspaceClientProvider)),
);

/// #4294 -- what is low and what to order, for the selected business. The Demo and the tests
/// replace it.
final stockReorderProvider = Provider<StockReorder>(
  (ref) => SupabaseStockReorder(ref.watch(selectedWorkspaceClientProvider)),
);

/// #4294 -- what is low, for the list; read again on a refresh or after a draft was made.
final stockLowProvider = FutureProvider.autoDispose.family<List<StockLowRow>, String>(
  (ref, workspaceId) => ref.watch(stockReorderProvider).low(workspaceId),
  retry: (_, _) => null,
);

/// #4294 -- the reorder points of the business, for the points list.
final stockReorderPointsProvider = FutureProvider.autoDispose.family<List<StockReorderPoint>, String>(
  (ref, workspaceId) => ref.watch(stockReorderProvider).points(workspaceId),
  retry: (_, _) => null,
);

/// #4294 -- what to order, by supplier.
final stockReplenishmentProvider = FutureProvider.autoDispose.family<ReplenishmentList, String>(
  (ref, workspaceId) => ref.watch(stockReorderProvider).replenishment(workspaceId),
  retry: (_, _) => null,
);

/// #4361 -- the item groups of the selected business (the Demo keeps its own in memory).
final itemGroupsProvider = Provider<ItemGroups>(
  (ref) => SupabaseItemGroups(ref.watch(selectedWorkspaceClientProvider)),
);

/// #4361 -- the groups of [workspaceId], for the screens.
final itemGroupListProvider = FutureProvider.autoDispose.family<List<ItemGroup>, String>(
  (ref, workspaceId) => ref.watch(itemGroupsProvider).groups(workspaceId),
);

/// #4359 -- what a scanned code names, for the selected workspace (the Demo answers from its own ledger).
final stockCodeResolverProvider = Provider<StockCodeResolver>(
  (ref) => SupabaseStockCodeResolver(ref.watch(selectedWorkspaceClientProvider)),
);

/// #4359 -- whether a goods sheet listens to a scanner in keyboard mode: the `stockScanning` feature of the
/// business. The app wires it to the feature; a test or the Demo can switch it.
final stockScanningProvider = Provider<bool>((ref) => ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.stockScanning));

/// #4363 -- the tags of the selected workspace's stock (the Demo keeps its own in memory).
final stockTagsStoreProvider = Provider<StockTags>(
  (ref) => SupabaseStockTags(ref.watch(selectedWorkspaceClientProvider)),
);

/// #4363 -- whether tags (RFID/NFC) are used: the `stockTags` feature of the business. The tag sheets and the
/// NFC button show only with it on.
final stockTagsProvider = Provider<bool>((ref) => ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.stockTags));

/// #4359 -- whether a repeated scan adds one (the default) or asks for the quantity: the business's
/// `stock.repeated_scan` setting (`add_one` | `ask_quantity`).
final stockScanAddsOneProvider = Provider<bool>((ref) {
  final settings = ref.watch(activeSettingsProvider);
  final value = settings != null && settings.definitions.containsKey('stock.repeated_scan')
      ? settings.read<String>('stock.repeated_scan')
      : SettingDefaults.stockRepeatedScan;
  return value != 'ask_quantity';
});

/// #4173 -- the trace of goods to their documents and the operational value, for the selected
/// business. The Demo and the tests replace it.
final stockTraceReaderProvider = Provider<StockTraceReader>(
  (ref) => SupabaseStockTrace(ref.watch(selectedWorkspaceClientProvider)),
);

/// #4432 -- the whole chain of a lot or a piece (0923).
final stockTraceChainReaderProvider = Provider<StockTraceChainReader>(
  (ref) => SupabaseStockTraceChain(ref.watch(selectedWorkspaceClientProvider)),
);

/// #4432 -- the chain of the lot (or, without a lot, the pieces) a movement belongs to.
final stockMovementChainProvider = FutureProvider.autoDispose.family<TraceChain, ({String workspaceId, String movementId})>(
  (ref, key) => ref.watch(stockTraceChainReaderProvider).chain(key.workspaceId, movementId: key.movementId),
  retry: (_, _) => null,
);

/// #4173 -- the trace of one movement.
final stockTraceProvider = FutureProvider.autoDispose.family<StockTraceAnswer, ({String workspaceId, String movementId})>(
  (ref, key) => ref.watch(stockTraceReaderProvider).trace(key.workspaceId, key.movementId),
  retry: (_, _) => null,
);

/// #4173 -- the operational value on hand now, for a reader who may see what goods cost.
final stockValuationProvider = FutureProvider.autoDispose.family<StockValuation, String>(
  (ref, workspaceId) => ref.watch(stockTraceReaderProvider).valuation(workspaceId),
  retry: (_, _) => null,
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

/// Every place of a business with its kind and the place it is inside, for
/// the sheets that choose where goods come from and go to.
final stockPlaceConfigsProvider = FutureProvider.autoDispose
    .family<List<StockPlaceConfig>, String>(
      (ref, workspaceId) => ref.watch(stockConfigCommandsProvider).places(workspaceId),
      retry: (_, _) => null,
    );

/// #4172 -- the returns, corrections and counts of the selected business. The
/// Demo and the tests replace it.
final stockReversalsProvider = Provider<StockReversals>(
  (ref) => SupabaseStockReversals(ref.watch(selectedWorkspaceClientProvider)),
);

/// What a movement still allows to be reversed (null while no movement is named).
final stockReversibleProvider = FutureProvider.autoDispose
    .family<StockReversible?, ({String workspaceId, String movementId})>(
      (ref, key) async => (await ref.watch(stockReversalsProvider).reversible(key.workspaceId, [key.movementId]))[key.movementId],
      retry: (_, _) => null,
    );

/// #4295 -- the cycle counts of the selected business: its plans, tasks and history. The Demo and the
/// tests replace it.
final stockCycleCountsProvider = Provider<StockCycleCounts>(
  (ref) => SupabaseStockCycleCounts(ref.watch(selectedWorkspaceClientProvider)),
);

/// The count plans of a business.
final stockCountPlansProvider = FutureProvider.autoDispose.family<List<CountPlan>, String>(
  (ref, workspaceId) => ref.watch(stockCycleCountsProvider).plans(workspaceId),
  retry: (_, _) => null,
);

/// The count tasks of a business, newest due day first.
final stockCountTasksProvider = FutureProvider.autoDispose.family<List<CountTaskSummary>, String>(
  (ref, workspaceId) => ref.watch(stockCycleCountsProvider).tasks(workspaceId),
  retry: (_, _) => null,
);

/// One task's lines (what to count and where; never what the ledger expects).
final stockCountTaskProvider = FutureProvider.autoDispose.family<CountTask, ({String workspaceId, String taskId})>(
  (ref, key) => ref.watch(stockCycleCountsProvider).task(key.workspaceId, key.taskId),
  retry: (_, _) => null,
);

/// When each item at each place was last counted and how exact the counts were.
final stockCountHistoryProvider = FutureProvider.autoDispose.family<List<CountHistoryRow>, String>(
  (ref, workspaceId) => ref.watch(stockCycleCountsProvider).history(workspaceId),
  retry: (_, _) => null,
);

/// The counts of a business, newest first.
final stockCountsProvider = FutureProvider.autoDispose
    .family<List<StockCountRow>, String>(
      (ref, workspaceId) => ref.watch(stockReversalsProvider).counts(workspaceId),
      retry: (_, _) => null,
    );

/// #4350 -- the creation of a new service from the Stock page, wired by the app (the stock never imports
/// the money feature); null where nothing is wired, which offers no "new item".
final stockServiceCreatorProvider = Provider<StockServiceCreator?>((ref) => null);

/// #4364 -- whether bulk reading is on (`stockTagReads`): the counts and the moves offer "Read many tags".
final stockTagReadsProvider = Provider<bool>((ref) => ref.watch(stockTagsProvider) && ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.stockTagReads));

/// #4364 -- the most different tags one bulk read keeps (`stock.tag_read_max_tags`); the registry default while the settings load.
final stockTagReadMaxProvider = Provider<int>((ref) {
  final settings = ref.watch(activeSettingsProvider);
  return settings != null && settings.definitions.containsKey('stock.tag_read_max_tags')
      ? settings.read<int>('stock.tag_read_max_tags')
      : SettingDefaults.stockTagReadMaxTags;
});
