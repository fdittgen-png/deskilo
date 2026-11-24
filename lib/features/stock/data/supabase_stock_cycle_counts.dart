// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_cycle_counts.dart';
import 'stock_rpc.dart';

/// #4295 -- the cycle counts behind the port: the plans as the table the server lets a stock manager
/// read, and `stock_count_plan_save_v1`, `stock_count_tasks_v1`, `stock_count_task_v1`,
/// `stock_cycle_count_line_v1`, `stock_cycle_skip_line_v1` and `stock_count_history_v1`. A refusal of the
/// server reaches the screen as it came; an answer of the wrong shape throws, never shown as empty.
class SupabaseStockCycleCounts implements StockCycleCounts {
  SupabaseStockCycleCounts(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String rpc, Map<String, Object?> params) => StockRpc(_client).run(rpc, params);

  List<Object?> _list(Object? answer, String rpc) => answer is List ? answer : throw StateError('$rpc answered no list');

  @override
  Future<List<CountPlan>> plans(String workspaceId) async {
    final rows = await StockRpc(_client).rows(
      'the count plans',
      _client
          .from('stock_count_plans')
          .select('id, name, scope_kind, location_ids, item_ids, high_value_minor, interval_days, next_due_on, active')
          .eq('workspace_id', workspaceId)
          .order('next_due_on'),
    );
    return [for (final row in rows) CountPlan.fromRow(row)];
  }

  @override
  Future<void> savePlan(String workspaceId, CountPlanDraft d) async {
    await _call('stock_count_plan_save_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': d.requestId,
      'p_plan_id': d.planId,
      'p_body': {
        'name': d.name,
        'scope_kind': d.scope.wire,
        'location_ids': d.locationIds,
        'item_ids': d.itemIds,
        'high_value_minor': d.highValueMinor,
        'interval_days': d.intervalDays,
        'next_due_on': d.nextDueOn,
        'active': d.active,
      },
    });
  }

  @override
  Future<List<CountTaskSummary>> tasks(String workspaceId, {CountTaskState? state}) async {
    final answer = await _call('stock_count_tasks_v1', {'p_workspace_id': workspaceId, 'p_state': state?.name});
    return [for (final raw in _list(answer, 'stock_count_tasks_v1')) CountTaskSummary.fromJson(JsonReader.of(raw, context: 'stock_count_tasks_v1'))];
  }

  @override
  Future<CountTask> task(String workspaceId, String taskId) async =>
      CountTask.fromJson(await _call('stock_count_task_v1', {'p_workspace_id': workspaceId, 'p_task_id': taskId}));

  @override
  Future<CountLineResult> countLine(String workspaceId, String lineId, String observed, String requestId) async =>
      CountLineResult.fromJson(
        await _call('stock_cycle_count_line_v1', {
          'p_workspace_id': workspaceId,
          'p_request_id': requestId,
          'p_line_id': lineId,
          'p_observed': observed,
        }),
      );

  @override
  Future<CountLineResult> skipLine(String workspaceId, String lineId, String reason, String requestId) async =>
      CountLineResult.fromJson(
        await _call('stock_cycle_skip_line_v1', {
          'p_workspace_id': workspaceId,
          'p_request_id': requestId,
          'p_line_id': lineId,
          'p_reason': reason,
        }),
      );

  @override
  Future<List<CountHistoryRow>> history(String workspaceId) async {
    final answer = await _call('stock_count_history_v1', {'p_workspace_id': workspaceId});
    return [for (final raw in _list(answer, 'stock_count_history_v1')) CountHistoryRow.fromJson(JsonReader.of(raw, context: 'stock_count_history_v1'))];
  }

  @override
  Future<BulkCountResult> countByTagRead(String workspaceId, {required String requestId, required String taskId, required List<String> codes}) async =>
      BulkCountResult.fromJson(
        await _call('stock_count_tag_read_v1', {
          'p_workspace_id': workspaceId,
          'p_request_id': requestId,
          'p_task_id': taskId,
          'p_codes': codes,
        }),
      );
}
