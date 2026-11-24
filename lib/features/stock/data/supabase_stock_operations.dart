// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_operations.dart';
import 'stock_rpc.dart';

/// #4170 (B) -- the stock commands behind the port: `stock_transfer_v1`,
/// `stock_transfer_load_v1`, `stock_transfer_receive_v1`, `stock_consume_v1`,
/// `stock_loss_v1` and `stock_fefo_proposal_v1`, and the transfers still on
/// their way. A refusal of the server becomes the typed failure the screen
/// shows under its field; an answer that is not the shape promised throws
/// rather than showing an empty result.
class SupabaseStockOperations implements StockOperations {
  SupabaseStockOperations(this._client);

  final SupabaseClient _client;

  /// #4401 -- one call: the open transfers with their two places and their lines, each line with its item, through
  /// the foreign keys (paged over the transfers; a transfer's lines come whole, ordered by id).
  @override
  Future<List<StockTransfer>> openTransfers(String workspaceId) async {
    final transfers = await StockRpc(_client).pages(
      'stock_transfers',
      () => _client
          .from('stock_transfers')
          .select(
            'id, from_location_id, to_location_id, status, revision, created_datetime, '
            'from_place:stock_locations!stock_transfers_workspace_id_from_location_id_fkey(code), '
            'to_place:stock_locations!stock_transfers_workspace_id_to_location_id_fkey(code), '
            'stock_transfer_lines(id, item_id, variant_id, lot_id, loaded::text, received::text, '
            'services!stock_transfer_lines_workspace_id_item_id_fkey(name, inventory_unit))',
          )
          .eq('workspace_id', workspaceId)
          .neq('status', 'received')
          .order('id', referencedTable: 'stock_transfer_lines', ascending: true)
          .order('created_datetime', ascending: true)
          .order('id', ascending: true),
    );
    return [for (final t in transfers) _transfer(JsonReader.of(t, context: 'stock_transfers'))];
  }

  StockTransfer _transfer(JsonReader t) => StockTransfer(
    id: t.string('id'),
    fromLocationId: t.string('from_location_id'),
    fromCode: t.objectOrNull('from_place')?.stringOr('code') ?? '',
    toLocationId: t.string('to_location_id'),
    toCode: t.objectOrNull('to_place')?.stringOr('code') ?? '',
    status: t.string('status'),
    loadedAt: DateTime.parse(t.string('created_datetime')),
    revision: t.integer('revision'),
    lines: t.objects('stock_transfer_lines', _line),
  );

  StockTransferLine _line(JsonReader r) {
    // the item a line moves, embedded; one the reader may not see comes back empty and is named by its id
    final item = r.objectOrNull('services');
    return StockTransferLine(
      id: r.string('id'),
      itemId: r.string('item_id'),
      itemName: item?.stringOr('name') ?? '',
      unit: item?.stringOr('inventory_unit') ?? '',
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
    return StockRpc(_client).guard('a lot proposal', () async {
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
    });
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
    return StockRpc(_client).guard('a stock command', () async {
      final answer = await _client.rpc<Object?>(rpc, params: params);
      final r = JsonReader.of(answer, context: rpc);
      return (
        requestId: r.string('request_id'),
        movements: r.list('movements').length,
        transferId: r.stringOrNull('transfer_id'),
        status: r.stringOrNull('status'),
      );
    });
  }
}
