// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/stock_operations.dart';
import 'stock_refusals.dart';

/// #4170 (B) -- the stock commands behind the port: `stock_transfer_v1`,
/// `stock_transfer_load_v1`, `stock_transfer_receive_v1`, `stock_consume_v1`,
/// `stock_loss_v1` and `stock_fefo_proposal_v1`, and the transfers still on
/// their way. A refusal of the server becomes the typed failure the screen
/// shows under its field; an answer that is not the shape promised throws
/// rather than showing an empty result.
class SupabaseStockOperations implements StockOperations {
  SupabaseStockOperations(this._client);

  final SupabaseClient _client;

  @override
  Future<List<StockTransfer>> openTransfers(String workspaceId) async {
    final transfers = await _client
        .from('stock_transfers')
        .select('id, from_location_id, to_location_id, status, revision, created_datetime')
        .eq('workspace_id', workspaceId)
        .neq('status', 'received')
        .order('created_datetime');
    if (transfers.isEmpty) return const [];
    final ids = [for (final t in transfers) '${t['id']}'];
    final lines = await _client
        .from('stock_transfer_lines')
        .select('id, transfer_id, item_id, variant_id, lot_id, loaded, received')
        .eq('workspace_id', workspaceId)
        .inFilter('transfer_id', ids)
        .order('id');
    final items = await _client
        .from('services')
        .select('id, name, inventory_unit')
        .eq('workspace_id', workspaceId)
        .inFilter('id', {for (final l in lines) '${l['item_id']}'}.toList());
    final places = await _client
        .from('stock_locations')
        .select('id, code')
        .eq('workspace_id', workspaceId)
        .inFilter('id', {
          for (final t in transfers) ...['${t['from_location_id']}', '${t['to_location_id']}'],
        }.toList());
    final itemById = {for (final i in items) '${i['id']}': i};
    final codeById = {for (final p in places) '${p['id']}': '${p['code']}'};
    return [
      for (final t in transfers)
        _transfer(JsonReader.of(t, context: 'stock_transfers'), lines, itemById, codeById),
    ];
  }

  StockTransfer _transfer(
    JsonReader t,
    List<Map<String, dynamic>> lines,
    Map<String, Map<String, dynamic>> items,
    Map<String, String> codes,
  ) {
    final id = t.string('id');
    return StockTransfer(
      id: id,
      fromLocationId: t.string('from_location_id'),
      fromCode: codes[t.string('from_location_id')] ?? '',
      toLocationId: t.string('to_location_id'),
      toCode: codes[t.string('to_location_id')] ?? '',
      status: t.string('status'),
      loadedAt: DateTime.parse(t.string('created_datetime')),
      revision: t.integer('revision'),
      lines: [
        for (final raw in lines)
          if ('${raw['transfer_id']}' == id) _line(JsonReader.of(raw, context: 'stock_transfer_lines'), items),
      ],
    );
  }

  StockTransferLine _line(JsonReader r, Map<String, Map<String, dynamic>> items) {
    final item = items[r.string('item_id')];
    return StockTransferLine(
      id: r.string('id'),
      itemId: r.string('item_id'),
      itemName: '${item?['name'] ?? ''}',
      unit: '${item?['inventory_unit'] ?? ''}',
      variantId: r.stringOrNull('variant_id'),
      lotId: r.stringOrNull('lot_id'),
      loaded: ExactQuantity.parse(r.string('loaded')),
      received: ExactQuantity.parse(r.string('received')),
    );
  }

  @override
  Future<StockCommandResult> transfer(String workspaceId, List<StockLineDraft> lines, String requestId) =>
      _command('stock_transfer_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_lines': [for (final l in lines) l.toJson()],
      });

  @override
  Future<StockCommandResult> load(
    String workspaceId,
    String toLocationId,
    List<StockLineDraft> lines,
    String requestId,
  ) => _command('stock_transfer_load_v1', {
    'p_workspace_id': workspaceId,
    'p_request_id': requestId,
    'p_to_location_id': toLocationId,
    'p_lines': [for (final l in lines) l.toJson()],
  });

  @override
  Future<StockCommandResult> receive(
    String workspaceId,
    String transferId,
    List<StockReceiveDraft> lines,
    String requestId,
  ) => _command('stock_transfer_receive_v1', {
    'p_workspace_id': workspaceId,
    'p_request_id': requestId,
    'p_transfer_id': transferId,
    'p_lines': [
      for (final l in lines)
        {'line_id': l.lineId, 'quantity': l.quantity, 'to': ?l.toLocationId},
    ],
  });

  @override
  Future<StockCommandResult> takeOut(
    String workspaceId,
    StockTakeOutReason reason,
    List<StockLineDraft> lines,
    String requestId,
  ) => _command(
    reason == StockTakeOutReason.loss ? 'stock_loss_v1' : 'stock_consume_v1',
    {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_lines': [for (final l in lines) l.toJson()],
    },
  );

  @override
  Future<StockProposal> proposal(
    String workspaceId, {
    required String itemId,
    required String locationId,
    required String quantity,
    String? variantId,
  }) async {
    try {
      final answer = await _client.rpc<Object?>(
        'stock_fefo_proposal_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_item_id': itemId,
          'p_variant_id': variantId,
          'p_location_id': locationId,
          'p_quantity': quantity,
        },
      );
      final r = JsonReader.of(answer, context: 'stock_fefo_proposal_v1');
      return StockProposal(
        lots: [
          for (final raw in r.list('lots'))
            _lot(JsonReader.of(raw, context: 'stock_fefo_proposal_v1.lots')),
        ],
        short: ExactQuantity.parse(r.string('short')),
      );
    } on PostgrestException catch (e, stack) {
      TraceLogger.instance.warn('stock', 'a lot proposal was refused: ${e.code}', stackTrace: stack);
      throwStockFailure(e, stack);
    }
  }

  StockLotProposal _lot(JsonReader r) => StockLotProposal(
    lotId: r.stringOrNull('lot_id'),
    lotCode: r.stringOrNull('lot_code'),
    expiresOn: r.stringOrNull('expires_on'),
    expired: r.boolOr('expired', fallback: false),
    available: ExactQuantity.parse(r.string('available')),
    take: ExactQuantity.parse(r.string('take')),
  );

  Future<StockCommandResult> _command(String rpc, Map<String, Object?> params) async {
    try {
      final answer = await _client.rpc<Object?>(rpc, params: params);
      final r = JsonReader.of(answer, context: rpc);
      return (
        requestId: r.string('request_id'),
        movements: r.list('movements').length,
        transferId: r.stringOrNull('transfer_id'),
        status: r.stringOrNull('status'),
      );
    } on PostgrestException catch (e, stack) {
      TraceLogger.instance.warn('stock', 'a stock command was refused: ${e.code}', stackTrace: stack);
      throwStockFailure(e, stack);
    }
  }
}
