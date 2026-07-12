// SPDX-License-Identifier: MIT
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace_import.dart';
import '../domain/workspace_xml.dart';

/// Supabase impl of the owner-only XML import boundary (#165/#180): the
/// whole floor-plan replace + accessory-catalog upsert runs inside the
/// `import_floor_plan_v2` RPC (migration 0027) so it is transactional —
/// either everything lands or nothing. Always the v2 RPC: a parsed v1
/// file simply carries an empty catalog, and an empty `p_accessories`
/// behaves exactly like the v1 import (0023's 2-arg function stays in
/// place for older clients).
class SupabaseWorkspaceImportRepository implements WorkspaceImportRepository {
  SupabaseWorkspaceImportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> importFloorPlan(
    String workspaceId,
    WorkspaceXmlData data,
  ) async {
    await _client.rpc<dynamic>('import_floor_plan_v2', params: {
      'p_workspace_id': workspaceId,
      'p_plan': workspaceXmlPlanToJson(data.levels),
      'p_accessories': workspaceXmlAccessoriesToJson(data.accessories),
    });
  }
}
