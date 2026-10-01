// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/mcp/mcp_endpoint.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/assistant_setup.dart';
import '../domain/mcp_client.dart';
import '../domain/mcp_context.dart';
import 'mcp_providers.dart';

part 'assistant_setup_providers.g.dart';

/// #1827 — the setup checklist for one person on one workspace. The four
/// server answers are asked in parallel; one that fails is `unavailable`
/// on its step, never a reason to hide the others. A switch of workspace,
/// account or installation while they are pending discards the answer.
@riverpod
Future<AssistantSetup> assistantSetup(Ref ref, McpContextRef context) async {
  final commands = ref.watch(mcpCommandsProvider);
  final features = ref.watch(enabledFeaturesSyncProvider);
  final permissions = ref.watch(myPermissionsProvider);
  Future<T?> maybe<T>(Future<T> Function(McpRepositories r) q) => commands
      .read(context, q)
      .then<T?>(
        (v) => v,
        onError: (Object e) {
          if (e is McpContextSuperseded) throw e;
          return null;
        },
      );
  final results = await (
    maybe((r) => r.identity.status()),
    maybe((r) => r.identity.databaseCapabilities()),
    maybe((r) => r.admin.policy(context.workspaceId)),
    maybe((r) => r.connections.connections()),
  ).wait;
  return AssistantSetup.derive(
    workspaceId: context.workspaceId,
    identity: results.$1,
    capabilities: results.$2,
    policy: results.$3,
    connections: results.$4,
    featureOn: features.contains(WorkspaceFeature.mcpAccess),
    canConfigure: permissions.contains(WorkspacePermission.manageConfiguration),
    canManageIntegrations: permissions.contains(
      WorkspacePermission.manageIntegrations,
    ),
  );
}

/// #1827 — the connector URL of the backend this process talks to; null
/// in Demo and tests, which run without one.
@riverpod
Uri? mcpConnectorUrl(Ref ref) =>
    mcpConnectorUri(ref.watch(bootedBackendUrlProvider));
