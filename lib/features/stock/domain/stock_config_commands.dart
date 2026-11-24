// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (A1) -- the port of the stock configuration: what is read to edit,
// and the two guarded, idempotent saves. A save that changes nothing throws a
// [StockConfigFailure]; it never reports success.
import 'stock_config.dart';
import 'stock_drafts.dart';
import 'stock_variants.dart';

abstract interface class StockConfigCommands {
  /// The stock side of one item, with its revision, units and codes.
  Future<StockItemConfig?> item(String workspaceId, String itemId);

  /// Every place of the business, the virtual ones marked.
  Future<List<StockPlaceConfig>> places(String workspaceId);

  /// Saves the item as [config] (the units and codes are the complete lists),
  /// read at [config]'s revision; [requestId] makes a retry answer once.
  Future<StockSaved> saveItem(
    String workspaceId,
    StockItemConfig config,
    String requestId,
  );

  /// #4402 -- makes a NEW item in one command: its service, its stock settings and its home place, all or none.
  /// [requestId] makes a retry answer the item it first made. The answer names the item and its stock revision.
  Future<StockSaved> createItem(
    String workspaceId,
    NewStockItemDraft item,
    String requestId,
  );

  /// Creates a place ([placeId] and [expectedRevision] null) or saves one
  /// read at [expectedRevision].
  Future<StockSaved> savePlace(
    String workspaceId, {
    required StockPlaceDraft place,
    required String requestId,
    String? placeId,
    int? expectedRevision,
  });

  /// The dimensions of the business, with their values.
  Future<List<StockDimension>> dimensions(String workspaceId);

  /// The variants of one item.
  Future<List<StockVariant>> variants(String workspaceId, String itemId);

  /// The suppliers of the business, by name, for the mapping editor.
  Future<List<StockSupplierRef>> suppliers(String workspaceId);

  /// The supplier article mappings of the business.
  Future<List<SupplierItemMapping>> mappings(String workspaceId);

  /// Saves a dimension and its complete list of values (null for a new one),
  /// read at [expectedRevision].
  Future<StockSaved> saveDimension(
    String workspaceId, {
    required StockDimension dimension,
    required String requestId,
    String? dimensionId,
    int? expectedRevision,
  });

  /// Saves the complete list of variants of [itemId], read at the item's
  /// [expectedRevision].
  Future<StockSaved> saveVariants(
    String workspaceId,
    String itemId, {
    required List<StockVariant> variants,
    required int expectedRevision,
    required String requestId,
  });

  /// Maps a supplier's article to an item, by an explicit save.
  Future<StockSaved> saveMapping(
    String workspaceId, {
    required SupplierMappingDraft mapping,
    required String requestId,
    String? mappingId,
    int? expectedRevision,
  });
}
