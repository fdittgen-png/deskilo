// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../domain/workspace_asset.dart';

/// The equipment register and its RPCs (0491, 0493). Reading checks the
/// right on the server; every write derives actor and rights there.
class SupabaseWorkspaceAssetRepository implements WorkspaceAssetRepository {
  const SupabaseWorkspaceAssetRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<WorkspaceAsset>> fetchAssets(String workspaceId) async {
    final json = await _client.rpc<Object?>(
      'workspace_assets_v1',
      params: {'p_workspace_id': workspaceId},
    );
    return [
      for (final a in JsonReader.of(json, context: 'workspace assets').list('assets'))
        WorkspaceAsset.fromJson(a),
    ];
  }

  @override
  Future<List<AssetCandidateLine>> fetchCandidateLines(String workspaceId) async {
    final json = await _client.rpc<Object?>(
      'asset_candidate_lines_v1',
      params: {'p_workspace_id': workspaceId},
    );
    return [
      for (final l in JsonReader.of(json, context: 'asset candidate lines').list('lines'))
        AssetCandidateLine.fromJson(l),
    ];
  }

  @override
  Future<WorkspaceAsset> register(
    String workspaceId, {
    required String purchaseId,
    required int lineNo,
    required String description,
    required String requestId,
  }) async => WorkspaceAsset.fromJson(
    await _client.rpc<Object?>(
      'register_asset_candidate_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_purchase_id': purchaseId,
        'p_line_no': lineNo,
        'p_description': description,
        'p_request_id': requestId,
      },
    ),
  );

  @override
  Future<WorkspaceAsset> decide(
    String workspaceId,
    AssetDecisionCommand command,
  ) async => WorkspaceAsset.fromJson(
    await _client.rpc<Object?>('decide_asset_v1', params: command.toParams(workspaceId)),
  );
}
