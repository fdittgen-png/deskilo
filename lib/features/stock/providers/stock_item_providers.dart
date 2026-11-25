// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4480 -- what the item's page and the items list read beside the registry: which items are at or below their
// reorder point, the group an item is in, its variants and its supplier articles. Each is read through the ports the editors
// use (StockReads, the item groups), so the page and its editors agree.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/stock_reads.dart';
import '../domain/stock_reorder.dart';
import '../domain/stock_variants.dart';
import 'stock_providers.dart';

/// One item of one business.
typedef StockItemKey = ({String workspaceId, String itemId});

/// The registry rows (by `StockRegistryRow.key`) at or below a reorder point, where the business keeps reorder
/// points; none otherwise, and none while the list is unread.
final stockLowKeysProvider = Provider.autoDispose.family<Set<String>, String>((
  ref,
  workspaceId,
) {
  final features = ref.watch(enabledFeaturesSyncProvider);
  if (!features.contains(WorkspaceFeature.stockReorder)) return const {};
  final low =
      ref.watch(stockLowProvider(workspaceId)).value ??
      const <StockLowRow>[]; // empty-ok: an unread list marks nothing low
  return {
    for (final r in low)
      if (r.variantId == null) r.itemId else '${r.itemId}-${r.variantId}',
  };
});

/// The name of the group the item is in; null when it is in none.
final stockItemGroupNameProvider = FutureProvider.autoDispose
    .family<String?, StockItemKey>((ref, key) async {
      final groups = ref.watch(itemGroupsProvider);
      final effective = await groups.effective(key.workspaceId, key.itemId);
      final id = effective.groupId;
      if (id == null) return null;
      final all = await groups.groups(key.workspaceId);
      return all.where((g) => g.id == id).firstOrNull?.name;
    });

/// The item's variants in use, as its variants editor saved them.
final stockItemVariantsProvider = FutureProvider.autoDispose
    .family<List<StockVariant>, StockItemKey>(
      (ref, key) =>
          StockReads(ref.watch(stockConfigCommandsProvider))
              .activeVariants(key.workspaceId, key.itemId),
    );

/// The supplier articles of the item, with the suppliers they name.
final stockItemMappingsProvider = FutureProvider.autoDispose
    .family<StockMappingsRead, StockItemKey>(
      (ref, key) =>
          StockReads(ref.watch(stockConfigCommandsProvider))
              .mappingsOf(key.workspaceId, key.itemId),
    );
