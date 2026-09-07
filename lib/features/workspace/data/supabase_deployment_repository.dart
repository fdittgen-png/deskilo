// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/deployment.dart';

/// #988 — the deployment engine over the RPCs of migration 0186.
class SupabaseDeploymentRepository implements DeploymentRepository {
  SupabaseDeploymentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<DeployableEntity>> entities() async {
    final result = await _client.rpc<dynamic>('deployable_entities');
    return [
      for (final e in result as List? ?? const [])
        DeployableEntity.fromJson(e as Map),
    ];
  }

  @override
  Future<DeploymentPreview> preview(
      String fromWorkspaceId, String toWorkspaceId, List<String> entities) async {
    final result = await _client.rpc<dynamic>('preview_deployment', params: {
      'p_from': fromWorkspaceId,
      'p_to': toWorkspaceId,
      'p_entities': entities,
    });
    return DeploymentPreview.fromJson(result as Map);
  }

  @override
  Future<String> deploy(
      String fromWorkspaceId, String toWorkspaceId, List<String> entities) async {
    final result = await _client.rpc<dynamic>('deploy_entities', params: {
      'p_from': fromWorkspaceId,
      'p_to': toWorkspaceId,
      'p_entities': entities,
    });
    return '${(result as Map)['id'] ?? ''}';
  }

  @override
  Future<void> rollback(String deploymentId) async {
    await _client.rpc<dynamic>('rollback_deployment', params: {
      'p_deployment_id': deploymentId,
    });
  }

  @override
  Future<List<Deployment>> journal(String pairId) async {
    final rows = await _client
        .from('deployments')
        .select()
        .eq('pair_id', pairId)
        .order('created_at', ascending: false)
        .limit(30);
    return [for (final r in rows) Deployment.fromRow(r)];
  }
}
