// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 C2 — the cost allocation over Supabase (0531): the period's
// allocation, the rules with every revision, and appending one.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cost_allocation_rules.dart';
import '../domain/kpi_contract.dart';

class SupabaseCostAllocationRepository implements CostAllocationRepository {
  SupabaseCostAllocationRepository(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String fn, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(fn, params: params);
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the card or the editor shows it.
      if (e.code == '42501') {
        Error.throwWithStackTrace(const KpiForbidden(), st);
      }
      rethrow;
    }
  }

  @override
  Future<CostAllocationKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final row = await _call('kpi_cost_allocation', {
      'p_workspace_id': workspaceId,
      'p_from': fromMonth,
      'p_to': toMonth,
    });
    return costAllocationFromJson(Map<String, Object?>.from(row! as Map));
  }

  @override
  Future<List<AllocationRule>> rules(String workspaceId) async {
    final rows = await _call('cost_allocation_rules_v1', {
      'p_workspace_id': workspaceId,
    });
    return [for (final row in rows! as List) allocationRuleFromJson(row)];
  }

  @override
  Future<AllocationRule> save(
    String workspaceId, {
    required String? ruleId,
    required int expectedRevision,
    required AllocationRuleDraft draft,
    required String requestId,
  }) async {
    final row = await _call('save_cost_allocation_rule_v1', {
      'p_workspace_id': workspaceId,
      'p_rule_id': ruleId,
      'p_expected_revision': expectedRevision,
      'p_rule': draft.toJson(),
      'p_request_id': requestId,
    });
    return allocationRuleFromJson(row);
  }
}
