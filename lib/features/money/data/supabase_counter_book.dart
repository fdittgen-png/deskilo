// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/counter_book.dart';
import 'supabase_counter_till.dart' show counterReceiptsTable;
import 'supabase_till_drawer.dart' show counterTillSessionsTable;

/// #4185 -- the counter's book behind the port: the receipts, their lines, tenders and refunds are read under their
/// row policies (issueInvoices or viewFinances, the counter feature on); the goods taken back are read where the stock
/// may be read, and are none otherwise. Every write is one of the counter's commands.
class SupabaseCounterBook implements CounterBookPort {
  SupabaseCounterBook(this._client);

  final SupabaseClient _client;

  /// How many issued receipts the book shows, newest first.
  static const int issuedShown = 60;

  Future<Object?> _call(String fn, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(fn, params: params);
    } on Object catch (e, stack) {
      TraceLogger.instance.warn('money', 'the counter book was refused', error: e, stackTrace: stack);
      rethrow;
    }
  }

  List<Map<String, Object?>> _rows(Object? rows) => [for (final r in rows as List) Map<String, Object?>.from(r as Map)];

  @override
  Future<CounterBook> book(String workspaceId) async {
    final issued = _rows(await _client
        .from(counterReceiptsTable)
        .select('id, kind, state, currency, total_minor, tax_minor, revision, number, finalized_at, corrects_receipt_id, till_session_id, frozen')
        .eq('workspace_id', workspaceId)
        .eq('state', 'finalized')
        .order('finalized_at', ascending: false)
        .limit(issuedShown));
    // the drafts a card authorization was asked for: the ones a lost answer can leave waiting
    final cardDrafts = _rows(await _client
        .from('counter_tenders')
        .select('receipt_id')
        .eq('workspace_id', workspaceId)
        .eq('kind', 'card')
        .neq('state', 'refused'));
    final issuedIds = {for (final r in issued) r['id'] as String};
    final draftIds = {for (final t in cardDrafts) t['receipt_id'] as String}.difference(issuedIds);
    final drafts = draftIds.isEmpty
        ? <Map<String, Object?>>[]
        : _rows(await _client
              .from(counterReceiptsTable)
              .select('id, kind, state, currency, total_minor, tax_minor, revision, number, finalized_at, corrects_receipt_id, till_session_id, frozen')
              .eq('workspace_id', workspaceId)
              .eq('state', 'draft')
              .inFilter('id', draftIds.toList()));
    final all = [...drafts, ...issued];
    if (all.isEmpty) return const CounterBook([]);
    final ids = [for (final r in all) r['id'] as String];
    final lines = _rows(await _client
        .from('counter_receipt_lines')
        .select('id, receipt_id, line_no, corrects_line_id, gross_minor, frozen')
        .eq('workspace_id', workspaceId)
        .inFilter('receipt_id', ids)
        .order('line_no'));
    final tenders = _rows(await _client
        .from('counter_tenders')
        .select('id, receipt_id, part, kind, amount_minor, state, reconciliation, provider_key, provider_ref')
        .eq('workspace_id', workspaceId)
        .inFilter('receipt_id', ids)
        .order('part'));
    final refunds = _rows(await _client.from('counter_refunds').select('receipt_id, amount_minor').eq('workspace_id', workspaceId).inFilter('receipt_id', ids));
    final sessions = {for (final r in all) if (r['till_session_id'] != null) r['till_session_id'] as String};
    final tillOf = <String, String>{};
    if (sessions.isNotEmpty) {
      for (final s in _rows(await _client.from(counterTillSessionsTable).select('id, till_id').inFilter('id', sessions.toList()))) {
        tillOf[s['id'] as String] = s['till_id'] as String;
      }
    }
    final returned = await _returned(workspaceId, ids);
    final linesOf = <String, List<CounterBookLine>>{};
    for (final l in lines) {
      (linesOf[l['receipt_id'] as String] ??= []).add(CounterBookLine.fromJson(l));
    }
    final tendersOf = <String, List<CounterBookTender>>{};
    for (final t in tenders) {
      (tendersOf[t['receipt_id'] as String] ??= []).add(CounterBookTender.fromJson(t));
    }
    final refundedOf = <String, int>{};
    for (final f in refunds) {
      final id = f['receipt_id'] as String;
      refundedOf[id] = (refundedOf[id] ?? 0) + ((f['amount_minor'] as num?)?.toInt() ?? 0);
    }
    return CounterBook([
      for (final r in all)
        CounterBookReceipt.fromJson(
          r,
          lines: linesOf[r['id']] ?? const [],
          tenders: tendersOf[r['id']] ?? const [],
          tillId: tillOf[r['till_session_id']],
          refundedMinor: refundedOf[r['id']] ?? 0,
          returned: {
            for (final l in linesOf[r['id']] ?? const <CounterBookLine>[])
              if (returned.containsKey(l.id)) l.id: counterQuantityText(returned[l.id]!),
          },
        ),
    ]);
  }

  /// The goods already taken back per correction line, in millionths. A reader who may not read the stock sees none:
  /// the return command bounds what is taken back again on the server.
  Future<Map<String, int>> _returned(String workspaceId, List<String> receiptIds) async {
    try {
      final rows = _rows(await _client
          .from('stock_movements')
          .select('counter_line_id, quantity:entered_quantity::text')
          .eq('workspace_id', workspaceId)
          .eq('reason', 'return_in')
          .inFilter('counter_receipt_id', receiptIds));
      final out = <String, int>{};
      for (final m in rows) {
        final line = m['counter_line_id'] as String?;
        if (line == null) continue;
        out[line] = (out[line] ?? 0) + counterQuantityUnits('${m['quantity'] ?? '0'}');
      }
      return out;
    } on Object catch (e, stack) {
      TraceLogger.instance.warn('money', 'the goods taken back are not readable here', error: e, stackTrace: stack);
      // empty-ok: only the 'left to take back' hint is lost; the server bounds every return again
      return const {};
    }
  }

  @override
  Future<String> correct(String workspaceId, {required String requestId, required String originalId, required List<CounterBookQuantity> lines, required String reason}) async {
    final out = await _call('counter_receipt_correct_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_original_id': originalId,
      'p_body': {'lines': [for (final l in lines) l.toJson()], 'reason': reason},
    });
    return '${(out as Map)['number'] ?? ''}';
  }

  @override
  Future<void> refund(String workspaceId, {required String requestId, required String correctionId, required List<CounterRefundPart> parts}) =>
      _call('counter_refund_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_correction_id': correctionId,
        'p_refunds': [for (final p in parts) p.toJson()],
      });

  @override
  Future<void> returnGoods(String workspaceId, {required String requestId, required String correctionId, required List<CounterBookQuantity> lines}) =>
      _call('counter_goods_return_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_correction_id': correctionId,
        'p_lines': [for (final l in lines) l.toJson()],
      });

  @override
  Future<void> resolveTender(String workspaceId, {required String requestId, required String tenderId, required String outcome, required String providerRef}) =>
      _call('counter_tender_resolve_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_tender_id': tenderId,
        'p_outcome': outcome,
        'p_provider_ref': providerRef,
      });

  @override
  Future<void> reconcileTender(String workspaceId, {required String requestId, required String tenderId}) =>
      _call('counter_tender_reconcile_v1', {'p_workspace_id': workspaceId, 'p_request_id': requestId, 'p_tender_id': tenderId});

  @override
  Future<String> complete(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<String> tenderIds}) async {
    final out = await _call('counter_receipt_finalize_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_receipt_id': receiptId,
      'p_expected_revision': expectedRevision,
      'p_tenders': [for (final id in tenderIds) {'tender_id': id}],
    });
    return '${(out as Map)['number'] ?? ''}';
  }
}
