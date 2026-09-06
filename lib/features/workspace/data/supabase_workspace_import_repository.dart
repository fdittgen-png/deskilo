// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace_import.dart';
import '../domain/workspace_xml.dart';

/// Supabase impl of the owner-only XML import boundary (#165/#180): the
/// whole floor-plan replace + accessory-catalog upsert runs inside the
/// `import_floor_plan_v3` RPC (migration 0177 — v2's shape plus the #916
/// attributes) so it is transactional — either everything lands or
/// nothing. A parsed v1/v2 file simply carries defaults for the v3
/// attributes and an empty catalog behaves exactly like the v1 import.
/// The configuration (#916) travels through its own two RPCs, which
/// never refuse over reservations.
class SupabaseWorkspaceImportRepository implements WorkspaceImportRepository {
  SupabaseWorkspaceImportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> importFloorPlan(
    String workspaceId,
    WorkspaceXmlData data,
  ) async {
    await _client.rpc<dynamic>('import_floor_plan_v3', params: {
      'p_workspace_id': workspaceId,
      'p_plan': workspaceXmlPlanToJson(data.levels),
      'p_accessories': workspaceXmlAccessoriesToJson(data.accessories),
    });
  }

  @override
  Future<Map<String, Object?>> exportConfiguration(String workspaceId) async {
    final result = await _client.rpc<dynamic>(
      'export_workspace_configuration',
      params: {'p_workspace_id': workspaceId},
    );
    return Map<String, Object?>.from(result as Map);
  }

  @override
  Future<void> importConfiguration(
    String workspaceId,
    Map<String, Object?> configuration,
  ) async {
    await _client.rpc<dynamic>('import_workspace_configuration', params: {
      'p_workspace_id': workspaceId,
      'p_configuration': configuration,
    });
  }
}
