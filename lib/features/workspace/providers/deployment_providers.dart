// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_deployment_repository.dart';
import '../domain/deployment.dart';

part 'deployment_providers.g.dart';

/// #988 — the deployment boundary; its own file so the pair features
/// never contend on workspace_providers.dart.
@Riverpod(keepAlive: true)
DeploymentRepository deploymentRepository(Ref ref) =>
    SupabaseDeploymentRepository(Supabase.instance.client);
