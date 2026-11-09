// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the lifecycle of a workspace: list, create, twin, environment, code, feature flags, dev mode, default, settings and reset, as one mixin composed into
// `SupabaseWorkspaceRepository` (the part-file bodies and their `_xxxImpl`
// forwarders are gone).

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/feature_flags_write.dart';
import '../domain/workspace.dart';
import '../domain/workspace_feature.dart';
import '../domain/workspace_lifecycle_repository.dart';
import '../domain/workspace_overview.dart';
import '../domain/workspace_settings_save.dart';
import 'supabase_workspace_rows.dart';

mixin SupabaseWorkspaceLifecycle on SupabaseWorkspaceRows
    implements WorkspaceLifecycleRepository {
  @override
  Future<List<Workspace>> fetchMyWorkspaces() async {
    final rows = await client.from('workspaces').select();
    return rows.map(workspaceFromRow).toList();
  }

  @override
  Future<bool> isPlatformOwner() async {
    final r = await client.rpc<dynamic>('is_platform_owner');
    return r == true;
  }

  @override
  Future<List<WorkspaceOverview>> fetchAllWorkspaces() async {
    final rows = await client.rpc<dynamic>('list_all_workspaces') as List;
    return [
      for (final r in rows)
        WorkspaceOverview.fromRow(Map<String, dynamic>.from(r as Map)),
    ];
  }

  @override
  Future<List<WorkspaceOwner>> fetchWorkspaceOwners(String workspaceId) async {
    final rows = await client.rpc<dynamic>(
      'workspace_owners',
      params: {'p_workspace_id': workspaceId},
    ) as List;
    return [
      for (final r in rows)
        WorkspaceOwner.fromRow(Map<String, dynamic>.from(r as Map)),
    ];
  }

  @override
  Future<String> createWorkspace({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
    WorkspaceEnvironment environment = WorkspaceEnvironment.development,
    bool withTwin = true,
    String? requestId,
    String? templateId,
  }) async {
    // #1303 — with a request id, creation and the first template are one
    // replayable act (0228).
    final once = requestId != null;
    final result = await client.rpc<dynamic>(
      once ? 'create_workspace_once' : 'create_workspace',
      params: {
        if (once) 'p_client_request_id': requestId,
        if (once) 'p_template_id': templateId,
        'p_name': name,
        'p_country_code': countryCode,
        'p_currency_code': currencyCode,
        'p_timezone': timezone,
        'p_environment': environment.wire,
        // #987 — the dev and the prod, created together.
        'p_with_twin': withTwin,
        // #1063 — Core on, Platform off, written EXPLICITLY at creation.
        // The server takes the object rather than knowing the catalogue:
        // a second copy of it in SQL would disagree with this one within a
        // release.
        // #1550 — created WITH a twin means created showing the couple.
        'p_feature_flags': defaultFeatureFlagsForNewWorkspace(
          withTwin: withTwin,
        ),
      },
    );
    return result as String;
  }

  @override
  Future<String> createWorkspaceTwin(String workspaceId) async {
    // #987 — the missing side of a lone workspace, configuration copied.
    final result = await client.rpc<dynamic>(
      'create_workspace_twin',
      params: {'p_workspace_id': workspaceId},
    );
    return result as String;
  }

  @override
  Future<void> setWorkspaceEnvironment(
    String workspaceId,
    WorkspaceEnvironment environment,
  ) async {
    await client.rpc<dynamic>(
      'set_workspace_environment',
      params: {
        'p_workspace_id': workspaceId,
        'p_environment': environment.wire,
      },
    );
  }

  @override
  Future<void> setFeatureFlags(
    String workspaceId,
    Map<String, bool> flags, {
    Map<String, bool>? expected,
  }) async {
    // #963 — a MERGE (0176): the row keeps every key this write does
    // not name, so a caller holding an older copy of the row can no
    // longer put the other switches back to what it remembered.
    // #1329 — with a read-set, the merge is refused if any of it moved.
    try {
      await client.rpc<dynamic>(
        'set_feature_flags',
        params: {
          'p_workspace_id': workspaceId,
          'p_flags': flags,
          'p_expected': ?expected,
        },
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: a conflict is rethrown typed with its stack; the caller traces and explains it.
      if (e.code == FeatureFlagsConflict.sqlState) {
        final named = e.message.split(':').last;
        Error.throwWithStackTrace(
          FeatureFlagsConflict([
            for (final k in named.split(','))
              if (k.trim().isNotEmpty) k.trim(),
          ]),
          st,
        );
      }
      rethrow;
    }
  }

  // RPC because workspaces_update RLS is owner-only; 0081 admits admins.
  @override
  Future<void> setDevMode(String workspaceId, {required bool enabled}) =>
      client.rpc(
        'set_dev_mode',
        params: {'p_workspace_id': workspaceId, 'p_enabled': enabled},
      );
  @override
  Future<String> setWorkspaceCode(String workspaceId, String code) async {
    final result = await client.rpc<dynamic>(
      'set_workspace_code',
      params: {'p_workspace_id': workspaceId, 'p_code': code},
    );
    return result as String;
  }

  @override
  Future<String?> fetchDefaultWorkspaceId() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await client
        .from('profiles')
        .select('default_workspace_id')
        .eq('id', userId)
        .maybeSingle();
    return row?['default_workspace_id'] as String?;
  }

  @override
  Future<void> setDefaultWorkspaceId(String? workspaceId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client
        .from('profiles')
        .update({'default_workspace_id': workspaceId})
        .eq('id', userId);
  }

  @override
  Future<Workspace> saveWorkspaceSettings(
    String workspaceId,
    WorkspaceSettingsSave save,
  ) async {
    try {
      final result = await client.rpc<dynamic>(
        'save_workspace_settings',
        params: {
          'p_workspace_id': workspaceId,
          'p_expected_modified': save.expectedModifiedAt
              ?.toUtc()
              .toIso8601String(),
          'p_settings': save.toSettings(),
        },
      );
      return workspaceFromRow(
        Map<String, dynamic>.from((result as Map)['workspace'] as Map),
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: a conflict is rethrown typed with its stack; the screen traces and explains it.
      if (e.code == WorkspaceSettingsConflict.sqlState) {
        Error.throwWithStackTrace(const WorkspaceSettingsConflict(), st);
      }
      rethrow;
    }
  }

  @override
  Future<void> resetWorkspace(String workspaceId) async {
    // SECURITY DEFINER RPC (0039); the owner check + all deletes are atomic
    // server-side.
    await client.rpc<dynamic>(
      'reset_workspace',
      params: {'p_workspace_id': workspaceId},
    );
  }
}
