// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4402 -- what a stock screen reads before it can show a sheet, composed here instead of in the widgets: the item an
// editor edits with the settings it keeps against its group, the dimensions and variants of an item, its supplier
// articles, where it stands in its group, the variants a sheet offers, whether its pieces carry a tag each, and the
// stock side of a put-away. The screens ask for what they show; the ports (Supabase or the Demo) are called here.
import '../../../core/trace/guarded.dart';
import '../domain/item_groups.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_commands.dart';
import '../domain/stock_page.dart';
import '../domain/stock_queries.dart';
import '../domain/stock_variants.dart';

/// The item of a variants editor: its settings, the business's dimensions and the item's variants.
typedef StockVariantsRead = ({StockItemConfig? item, List<StockDimension> dimensions, List<StockVariant> variants});

/// The supplier articles of one item, with what their editor chooses from.
typedef StockMappingsRead = ({
  StockItemConfig item,
  List<SupplierItemMapping> mappings,
  List<StockSupplierRef> suppliers,
  List<StockVariant> variants,
});

/// Where an item stands in its group: the groups to choose from, what it takes from its group, and its revision.
typedef StockGroupRead = ({List<ItemGroup> groups, ItemEffective effective, int revision});

/// The stock side of a put-away: the places, and per delivered line the item, its active variants and whether
/// its pieces carry a tag each.
typedef StockPutAwayRead = ({
  List<StockPlace> places,
  Map<int, StockItemConfig> items,
  Map<int, List<StockVariant>> variants,
  Set<int> perUnit,
});

class StockReads {
  const StockReads(this._config, {this._queries, this._groups});

  final StockConfigCommands _config;
  final StockQueries? _queries;

  /// Null when the business keeps no item groups.
  final ItemGroups? _groups;

  StockQueries get _readQueries => _queries ?? (throw StateError('the stock queries are not wired for this read'));

  /// The stock side of one item.
  Future<StockItemConfig?> item(String workspaceId, String itemId) => _config.item(workspaceId, itemId);

  /// The places of the business, the virtual ones marked.
  Future<List<StockPlaceConfig>> places(String workspaceId) => _config.places(workspaceId);

  /// The services that may start being kept in stock.
  Future<List<StockItem>> unstocked(String workspaceId) => _readQueries.unstocked(workspaceId);

  /// The settings in which the item keeps a value of its own against its group; none without groups or a group.
  Future<Set<String>> ownValues(String workspaceId, String itemId) async {
    final groups = _groups;
    if (groups == null) return const {};
    final effective = await groups.effective(workspaceId, itemId);
    if (effective.groupId == null) return const {};
    return {for (final e in effective.params.entries) if (e.value.own) e.key};
  }

  /// Whether the item's effective tag mode (its own, its group's, the business's) is one tag per piece.
  Future<bool> tagsEachPiece(String workspaceId, String itemId) async {
    final groups = _groups;
    if (groups == null) return false;
    return (await groups.effective(workspaceId, itemId)).params['tag_mode']?.value == 'per_unit';
  }

  /// The business's dimensions (colour, size).
  Future<List<StockDimension>> dimensions(String workspaceId) => _config.dimensions(workspaceId);

  /// The variants of an item a sheet offers: the active ones the server has saved.
  Future<List<StockVariant>> activeVariants(String workspaceId, String itemId) async => [
    for (final v in await _config.variants(workspaceId, itemId))
      if (v.id != null && v.active) v,
  ];

  Future<StockVariantsRead> variantsOf(String workspaceId, String itemId) async => (
    item: await _config.item(workspaceId, itemId),
    dimensions: await _config.dimensions(workspaceId),
    variants: await _config.variants(workspaceId, itemId),
  );

  /// Throws a [StateError] when the item is gone.
  Future<StockMappingsRead> mappingsOf(String workspaceId, String itemId) async {
    final item = await _config.item(workspaceId, itemId);
    if (item == null) throw StateError('the item is gone');
    return (
      item: item,
      mappings: [for (final m in await _config.mappings(workspaceId)) if (m.itemId == itemId) m],
      suppliers: await _config.suppliers(workspaceId),
      variants: await _config.variants(workspaceId, itemId),
    );
  }

  /// Needs the item groups.
  Future<StockGroupRead> groupOf(String workspaceId, String itemId) async {
    final groups = _groups ?? (throw StateError('the item groups are not wired for this read'));
    return (
      groups: await groups.groups(workspaceId),
      effective: await groups.effective(workspaceId, itemId),
      revision: (await _config.item(workspaceId, itemId))?.revision ?? 0,
    );
  }

  /// [lines]: the delivered lines by number, with the service each names (null: a line of no item).
  Future<StockPutAwayRead> putAway(String workspaceId, Map<int, String?> lines) async {
    final places = await _readQueries.places(workspaceId);
    final items = <int, StockItemConfig>{};
    final variants = <int, List<StockVariant>>{};
    final perUnit = <int>{};
    for (final MapEntry(key: lineNo, value: id) in lines.entries) {
      if (id == null) continue;
      final item = await _config.item(workspaceId, id);
      if (item == null || !item.stockable) continue;
      items[lineNo] = item;
      variants[lineNo] = [for (final v in await _config.variants(workspaceId, id)) if (v.active) v];
      // a tag mode that could not be read leaves the line untagged: the server then refuses the put-away and says why
      final perPiece = await guardRead(
        domain: 'stock',
        message: 'the tag mode of an item could not be read',
        read: () => tagsEachPiece(workspaceId, id),
        fallback: (_) => false,
      );
      if (perPiece) perUnit.add(lineNo);
    }
    return (places: places, items: items, variants: variants, perUnit: perUnit);
  }
}
