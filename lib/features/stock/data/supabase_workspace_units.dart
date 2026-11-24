// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace_units.dart';
import 'stock_rpc.dart';

/// #4442 -- the units of a business behind the port: the rows under the business's own row security, and the two commands
/// that maintain them. A refusal arrives as the stock configuration's typed failure (`StockConfigRefused`: the field and the
/// reason); an answer of the wrong shape throws, it is never shown as "no units".
class SupabaseWorkspaceUnits implements WorkspaceUnits {
  SupabaseWorkspaceUnits(this._client);

  final SupabaseClient _client;

  StockRpc get _rpc => StockRpc(_client);

  @override
  Future<List<WorkspaceUnit>> units(String workspaceId) => _rpc.guard('workspace_units', () async {
    final rows = await _client
        .from('workspace_units')
        .select('code, label, dimension, factor_num, factor_den, un_ece_code, built_in, archived, sort_order')
        .eq('workspace_id', workspaceId)
        .order('sort_order', ascending: true)
        .order('code', ascending: true);
    return [for (final row in rows) WorkspaceUnit.fromJson(row)];
  });

  @override
  Future<WorkspaceUnit> save(String workspaceId, {required String requestId, required UnitDraft draft}) async => WorkspaceUnit.fromJson(
    await _rpc.object('workspace_unit_save_v1', {'p_workspace_id': workspaceId, 'p_request_id': requestId, 'p_unit': draft.toJson()}),
  );

  @override
  Future<void> archive(String workspaceId, {required String requestId, required String code, required bool archived}) async {
    await _rpc.object('workspace_unit_archive_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_code': code,
      'p_archived': archived,
    });
  }
}
