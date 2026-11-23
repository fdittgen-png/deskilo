// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/item_groups.dart';
import 'stock_rpc.dart';

/// #4361 -- the item group functions behind the port. A refusal arrives as a typed failure; an answer of the
/// wrong shape throws, it is never shown as "no groups".
class SupabaseItemGroups implements ItemGroups {
  SupabaseItemGroups(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String fn, Map<String, Object?> params) => StockRpc(_client).run(fn, params);

  @override
  Future<List<ItemGroup>> groups(String workspaceId) async {
    final answer = await _call('item_groups_v1', {'p_workspace_id': workspaceId});
    if (answer is! List) throw const FormatException('item_groups_v1 did not answer a list');
    return [for (final g in answer) ItemGroup.fromJson(g)];
  }

  @override
  Future<GroupSaved> save(String workspaceId, {required String requestId, required String groupId, required int expectedRevision, required Map<String, Object?> body, bool apply = true}) async =>
      GroupSaved.fromJson(await _call('item_group_save_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_group_id': groupId,
        'p_expected_revision': expectedRevision,
        'p_body': body,
        'p_apply': apply,
      }));

  @override
  Future<GroupAssigned> assign(String workspaceId, {required String requestId, required String itemId, required int expectedRevision, required String? groupId, bool apply = true}) async =>
      GroupAssigned.fromJson(await _call('item_group_assign_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_item_id': itemId,
        'p_expected_revision': expectedRevision,
        'p_group_id': groupId,
        'p_apply': apply,
      }));

  @override
  Future<void> setOverride(String workspaceId, String requestId, ItemOverride change) async {
    await _call('item_override_save_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_item_id': change.itemId,
      'p_expected_revision': change.expectedRevision,
      'p_parameter': change.parameter,
      'p_mode': change.mode,
      'p_value': change.value,
    });
  }

  @override
  Future<void> delete(String workspaceId, {required String requestId, required String groupId, required int expectedRevision}) async {
    await _call('item_group_delete_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_group_id': groupId,
      'p_expected_revision': expectedRevision,
    });
  }

  @override
  Future<ItemEffective> effective(String workspaceId, String itemId) async =>
      ItemEffective.fromJson(await _call('item_effective_settings_v1', {'p_workspace_id': workspaceId, 'p_item_id': itemId}));

  @override
  Future<List<GroupHistoryRow>> history(String workspaceId, {String? groupId, String? itemId, int limit = 50}) async {
    final answer = await _call('item_group_history_v1', {'p_workspace_id': workspaceId, 'p_group_id': groupId, 'p_item_id': itemId, 'p_limit': limit});
    if (answer is! List) throw const FormatException('item_group_history_v1 did not answer a list');
    return [for (final r in answer) GroupHistoryRow.fromJson(r)];
  }
}
