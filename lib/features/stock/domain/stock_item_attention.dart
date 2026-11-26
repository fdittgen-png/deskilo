// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4480 -- what an item of the registry asks of someone, most pressing first:
// below its reorder point, no sale price, no home place. The list shows the
// first as a badge on the item's row; the item's page names them all.
import 'stock_registry.dart';

/// One thing an item of the registry needs.
enum StockAttention {
  /// What is on hand is at or below the item's reorder point.
  belowReorder,

  /// The item (or its variant) has no sale price.
  noPrice,

  /// The item (or its variant) has no home place.
  noPlace,
}

/// What [row] needs, most pressing first; [low] holds the keys (`StockRegistryRow.key`) of what is at or below
/// its reorder point.
List<StockAttention> stockAttentionOf(StockRegistryRow row, Set<String> low) =>
    [
      if (low.contains(row.key)) StockAttention.belowReorder,
      if (row.priceCents == null) StockAttention.noPrice,
      if (row.homeLocationId == null) StockAttention.noPlace,
    ];
