// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_reversals.dart';
import 'stock_rpc.dart';

/// #4172 (B) -- the returns, corrections and counts behind the port:
/// `stock_reversible_v1`, `stock_return_v1`, `stock_counts_v1`,
/// `stock_count_record_v1` and `stock_count_decide_v1`. A refusal of the server
/// reaches the screen as it came (its code names the words); an answer that is
/// not the shape promised throws rather than showing an empty result.
class SupabaseStockReversals implements StockReversals {
  SupabaseStockReversals(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String rpc, Map<String, Object?> params) => StockRpc(_client).run(rpc, params);

  @override
  Future<Map<String, StockReversible>> reversible(String workspaceId, List<String> movementIds) async {
    final answer = await _call('stock_reversible_v1', {
      'p_workspace_id': workspaceId,
      'p_movement_ids': movementIds,
    });
    final list = answer is List ? answer : throw StateError('stock_reversible_v1 answered no list');
    return {
      for (final raw in list)
        ..._reversible(JsonReader.of(raw, context: 'stock_reversible_v1')),
    };
  }

  Map<String, StockReversible> _reversible(JsonReader r) => {
    r.string('movement_id'): StockReversible(
      movementId: r.string('movement_id'),
      reason: r.string('reason'),
      quantity: ExactQuantity.parse(r.string('quantity')),
      reversed: ExactQuantity.parse(r.string('reversed')),
      remaining: ExactQuantity.parse(r.string('remaining')),
      reversals: [
        for (final x in r.list('reversals'))
          _entry(JsonReader.of(x, context: 'stock_reversible_v1.reversals')),
      ],
    ),
  };

  StockReversalEntry _entry(JsonReader r) => StockReversalEntry(
    returnId: r.string('return_id'),
    lineId: r.string('return_line_id'),
    kind: r.string('kind'),
    quantity: ExactQuantity.parse(r.string('quantity')),
    movementId: r.string('movement_id'),
  );

  @override
  Future<StockReturnResult> makeReturn(
    String workspaceId,
    String returnId,
    StockReturnKind kind,
    List<StockReturnLineDraft> lines,
    String requestId,
  ) async {
    final answer = await _call('stock_return_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_return_id': returnId,
      'p_kind': kind.wire,
      'p_lines': [
        for (final l in lines)
          {
            'return_line_id': l.lineId,
            'source_movement_id': l.sourceMovementId,
            'quantity': l.quantity,
            if (l.locationId != null) 'location': l.locationId,
            if (l.note.isNotEmpty) 'note': l.note,
          },
      ],
    });
    final r = JsonReader.of(answer, context: 'stock_return_v1');
    final written = [for (final x in r.list('lines')) JsonReader.of(x, context: 'stock_return_v1.lines')];
    return (
      returnId: r.string('return_id'),
      movementIds: [for (final w in written) w.string('movement_id')],
      remaining: written.isEmpty ? ExactQuantity.zero : ExactQuantity.parse(written.last.string('remaining')),
    );
  }

  @override
  Future<List<StockCountRow>> counts(String workspaceId) async {
    final answer = await _call('stock_counts_v1', {'p_workspace_id': workspaceId});
    final list = answer is List ? answer : throw StateError('stock_counts_v1 answered no list');
    return [for (final raw in list) _count(JsonReader.of(raw, context: 'stock_counts_v1'))];
  }

  StockCountRow _count(JsonReader r) => StockCountRow(
    countId: r.string('count_id'),
    itemId: r.string('item_id'),
    variantId: r.stringOrNull('variant_id'),
    lotId: r.stringOrNull('lot_id'),
    locationId: r.string('location_id'),
    observed: ExactQuantity.parse(r.string('observed')),
    baseline: ExactQuantity.parse(r.string('baseline')),
    state: StockCountState.fromWire(r.string('state')),
    stale: r.boolOr('stale', fallback: false),
    reason: r.stringOr('reason'),
    authorMemberId: r.string('author_member_id'),
    decidedByMemberId: r.stringOrNull('decided_by_member_id'),
    decidedAt: r.stringOrNull('decided_at') == null ? null : r.dateTime('decided_at'),
    movementId: r.stringOrNull('movement_id'),
  );

  @override
  Future<void> recordCount(String workspaceId, StockCountDraft draft) async {
    await _call('stock_count_record_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': draft.requestId,
      'p_count_id': draft.countId,
      'p_scope': {
        'item_id': draft.itemId,
        'location_id': draft.locationId,
        'variant_id': ?draft.variantId,
        'lot_id': ?draft.lotId,
      },
      'p_observed': draft.observed,
      'p_reason': draft.reason,
    });
  }

  @override
  Future<void> decideCount(
    String workspaceId,
    String countId,
    StockCountDecision decision,
    String requestId, {
    String note = '',
  }) async {
    await _call('stock_count_decide_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_count_id': countId,
      'p_decision': decision.name,
      'p_note': note,
    });
  }
}
