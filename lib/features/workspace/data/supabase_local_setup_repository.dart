// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/local_setup.dart';
import '../domain/workspace_readiness.dart';

/// #1656 — template_local_needs and workspace_local_readiness (0280).
class SupabaseLocalSetupRepository implements LocalSetupRepository {
  const SupabaseLocalSetupRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<LocalSlot>> templateNeeds(String templateId) async =>
      LocalSlot.listFromJson(
        await _client.rpc<Object?>(
          'template_local_needs',
          params: {'p_template_id': templateId},
        ),
      );

  @override
  Future<List<LocalSlot>> readiness(String workspaceId) async =>
      LocalSlot.listFromJson(
        await _client.rpc<Object?>(
          'workspace_local_readiness',
          params: {'p_workspace_id': workspaceId},
        ),
      );

  @override
  Future<List<ReadinessSection>> sections(String workspaceId) async =>
      ReadinessSection.listFromJson(
        await _client.rpc<Object?>(
          'workspace_readiness',
          params: {'p_workspace_id': workspaceId},
        ),
      );
}
