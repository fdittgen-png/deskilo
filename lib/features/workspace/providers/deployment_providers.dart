// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/deploy_configuration.dart';
import '../data/supabase_deployment_repository.dart';
import '../domain/deployment.dart';
import 'operation_context_providers.dart';

part 'deployment_providers.g.dart';

/// #988 — the deployment boundary; its own file so the pair features
/// never contend on workspace_providers.dart.
@Riverpod(keepAlive: true)
DeploymentRepository deploymentRepository(Ref ref) =>
    SupabaseDeploymentRepository(ref.watch(selectedWorkspaceClientProvider));

/// #1449 — the deployment's own decisions: the closed selection, and a
/// deploy that can only write what a preview described.
@riverpod
Deployments deployments(Ref ref) =>
    Deployments(ref.watch(deploymentRepositoryProvider));
