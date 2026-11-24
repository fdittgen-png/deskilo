// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/server_names.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_commands.dart';
import '../domain/stock_variants.dart';
import 'stock_rpc.dart';

/// #4169 (A1) -- `save_stock_item_v1` and `save_stock_location_v1` behind the
/// port, and the table reads that fill the editors. A refusal of the server
/// becomes the typed failure the screen shows under its field; nothing is
/// ever reported saved that was not.
class SupabaseStockConfigCommands implements StockConfigCommands {
  SupabaseStockConfigCommands(this._client);

  final SupabaseClient _client;

  @override
  Future<StockItemConfig?> item(String workspaceId, String itemId) async {
    final rows = await StockRpc(_client).rows('services', () => _client
        .from(ServerTable.services)
        .select(
          'id, stock_revision, stockable, purchasable, sellable, '
          'inventory_unit, tracking, shelf_life_days',
        )
        .eq('workspace_id', workspaceId)
        .eq('id', itemId)
        .order('id'));
    if (rows.isEmpty) return null;
    final r = JsonReader.of(rows.first, context: 'services');
    final units = await StockRpc(_client).rows('item_units', () => _client
        .from('item_units')
        .select('unit, factor_num, factor_den, default_purchase, default_sale')
        .eq('workspace_id', workspaceId)
        .eq('item_id', itemId)
        .order('unit')
        .order('id'));
    final codes = await StockRpc(_client).rows('item_codes', () => _client
        .from('item_codes')
        .select('code, kind, unit')
        .eq('workspace_id', workspaceId)
        .eq('item_id', itemId)
        .order('code')
        .order('id'));
    return StockItemConfig(
      itemId: r.string('id'),
      revision: r.integer('stock_revision'),
      stockable: r.boolOr('stockable', fallback: false),
      purchasable: r.boolOr('purchasable', fallback: false),
      sellable: r.boolOr('sellable', fallback: true),
      inventoryUnit: r.string('inventory_unit'),
      tracking: r.stringOr('tracking', 'none'),
      shelfLifeDays: r.intOrNull('shelf_life_days'),
      units: [for (final u in units) StockUnitDraft.fromJson(u)],
      codes: [for (final c in codes) StockCodeDraft.fromJson(c)],
    );
  }

  @override
  Future<List<StockPlaceConfig>> places(String workspaceId) async {
    final kinds = await StockRpc(_client).rows('stock_location_kinds', () => _client.from('stock_location_kinds').select('key, virtual').order('key'));
    final virtual = {
      for (final k in kinds)
        if (JsonReader.of(k, context: 'stock_location_kinds').boolOr('virtual', fallback: false))
          JsonReader.of(k, context: 'stock_location_kinds').string('key'),
    };
    final rows = await StockRpc(_client).rows('stock_locations', () => _client
        .from(ServerTable.stockLocations)
        .select(
          'id, revision, kind, code, name, barcode, parent_id, active, receives_from_suppliers, pick_role, address_path',
        )
        .eq('workspace_id', workspaceId)
        .order('code')
        .order('id'));
    return [
      for (final row in rows)
        StockPlaceConfig.fromJson({
          ...row,
          'virtual': virtual.contains(row['kind']),
        }),
    ];
  }

  @override
  Future<StockSaved> saveItem(
    String workspaceId,
    StockItemConfig config,
    String requestId,
  ) => _save('save_stock_item_v1', {
    'p_workspace_id': workspaceId,
    'p_item_id': config.itemId,
    'p_expected_revision': config.revision,
    'p_request_id': requestId,
    'p_item': config.toSave(),
  }, 'item_id');

  @override
  Future<StockSaved> savePlace(
    String workspaceId, {
    required Map<String, Object?> place,
    required String requestId,
    String? placeId,
    int? expectedRevision,
  }) => _save('save_stock_location_v1', {
    'p_workspace_id': workspaceId,
    'p_place_id': placeId,
    'p_expected_revision': expectedRevision,
    'p_request_id': requestId,
    'p_place': place,
  }, 'place_id');

  @override
  Future<List<StockDimension>> dimensions(String workspaceId) async {
    final dimensions = await StockRpc(_client).rows('item_dimensions', () => _client
        .from('item_dimensions')
        .select('id, revision, name, active')
        .eq('workspace_id', workspaceId)
        .order('name')
        .order('id'));
    final values = await StockRpc(_client).rows('item_dimension_values', () => _client
        .from('item_dimension_values')
        .select('id, dimension_id, label, active')
        .eq('workspace_id', workspaceId)
        .order('label')
        .order('id'));
    return [
      for (final d in dimensions)
        () {
          final r = JsonReader.of(d, context: 'item_dimensions');
          return StockDimension(
            id: r.string('id'),
            revision: r.integer('revision'),
            name: r.string('name'),
            active: r.boolOr('active', fallback: true),
            values: [
              for (final v in values)
                if (JsonReader.of(v, context: 'item_dimension_values').string('dimension_id') == r.string('id'))
                  StockDimensionValue.fromJson(v),
            ],
          );
        }(),
    ];
  }

  @override
  Future<List<StockVariant>> variants(String workspaceId, String itemId) async {
    final rows = await StockRpc(_client).rows('item_variants', () => _client
        .from('item_variants')
        .select('id, price_cents, active, item_variant_values(dimension_id, value_id)')
        .eq('workspace_id', workspaceId)
        .eq('item_id', itemId)
        .order('canonical')
        .order('id'));
    final dims = await dimensions(workspaceId);
    String labelOf(Map<String, String> values) {
      final parts = <(String, String)>[
        for (final d in dims)
          if (values[d.id] case final valueId?)
            (
              d.name,
              d.values.where((v) => v.id == valueId).map((v) => v.label).firstOrNull ?? '',
            ),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      return parts.map((p) => '${p.$1}: ${p.$2}').join(' · ');
    }

    return [
      for (final row in rows)
        () {
          final r = JsonReader.of(row, context: 'item_variants');
          final values = {
            for (final p in r.list('item_variant_values'))
              JsonReader.of(p, context: 'item_variant_values').string('dimension_id'):
                  JsonReader.of(p, context: 'item_variant_values').string('value_id'),
          };
          return StockVariant(
            id: r.string('id'),
            values: values,
            priceCents: r.intOrNull('price_cents'),
            active: r.boolOr('active', fallback: true),
            label: labelOf(values),
          );
        }(),
    ];
  }

  @override
  Future<List<StockSupplierRef>> suppliers(String workspaceId) async {
    final rows = await StockRpc(_client).pages('suppliers', () => _client
        .from(ServerTable.suppliers)
        .select('id, name')
        .eq('workspace_id', workspaceId)
        .order('name')
        .order('id'));
    return [
      for (final row in rows)
        () {
          final r = JsonReader.of(row, context: 'suppliers');
          return StockSupplierRef(id: r.string('id'), name: r.stringOr('name'));
        }(),
    ];
  }

  @override
  Future<List<SupplierItemMapping>> mappings(String workspaceId) async {
    final rows = await StockRpc(_client).rows('supplier_item_mappings', () => _client
        .from('supplier_item_mappings')
        .select('id, revision, supplier_id, item_id, variant_id, article_ref, purchase_unit, active')
        .eq('workspace_id', workspaceId)
        .order('article_ref')
        .order('id'));
    return [for (final row in rows) SupplierItemMapping.fromJson(row)];
  }

  @override
  Future<StockSaved> saveDimension(
    String workspaceId, {
    required Map<String, Object?> dimension,
    required String requestId,
    String? dimensionId,
    int? expectedRevision,
  }) => _save('save_item_dimension_v1', {
    'p_workspace_id': workspaceId,
    'p_dimension_id': dimensionId,
    'p_expected_revision': expectedRevision,
    'p_request_id': requestId,
    'p_dimension': dimension,
  }, 'dimension_id');

  @override
  Future<StockSaved> saveVariants(
    String workspaceId,
    String itemId, {
    required List<StockVariant> variants,
    required int expectedRevision,
    required String requestId,
  }) => _save('save_item_variants_v1', {
    'p_workspace_id': workspaceId,
    'p_item_id': itemId,
    'p_expected_revision': expectedRevision,
    'p_request_id': requestId,
    'p_variants': [for (final v in variants) v.toJson()],
  }, 'item_id');

  @override
  Future<StockSaved> saveMapping(
    String workspaceId, {
    required Map<String, Object?> mapping,
    required String requestId,
    String? mappingId,
    int? expectedRevision,
  }) => _save('save_supplier_item_mapping_v1', {
    'p_workspace_id': workspaceId,
    'p_mapping_id': mappingId,
    'p_expected_revision': expectedRevision,
    'p_request_id': requestId,
    'p_mapping': mapping,
  }, 'mapping_id');

  Future<StockSaved> _save(
    String rpc,
    Map<String, Object?> params,
    String idKey,
  ) async {
    return StockRpc(_client).guard('a stock command', () async {
      final answer = await _client.rpc<Object?>(rpc, params: params);
      final r = JsonReader.of(answer, context: rpc);
      return (
        id: r.string(idKey),
        revision: r.integer('revision'),
        replayed: r.boolOr('replayed', fallback: false),
      );
    });
  }
}
