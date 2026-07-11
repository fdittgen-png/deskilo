// SPDX-License-Identifier: MIT
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace_import.dart';
import '../domain/workspace_xml.dart';

/// Supabase impl of the owner-only XML import boundary (#165): the whole
/// floor-plan replace runs inside the `import_floor_plan` RPC (migration
/// 0023) so it is transactional — either everything lands or nothing.
class SupabaseWorkspaceImportRepository implements WorkspaceImportRepository {
  SupabaseWorkspaceImportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> importFloorPlan(
    String workspaceId,
    WorkspaceXmlData data,
  ) async {
    await _client.rpc<dynamic>('import_floor_plan', params: {
      'p_workspace_id': workspaceId,
      'p_plan': workspaceXmlPlanToJson(data.levels),
    });
  }
}
