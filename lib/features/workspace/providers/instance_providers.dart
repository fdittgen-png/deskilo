// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/instance_roles.dart';
import '../data/supabase_instance_repository.dart';
import '../domain/instance_responsibles.dart';

part 'instance_providers.g.dart';

/// #1829 — the instance owner and delegates (0314).
@Riverpod(keepAlive: true)
InstanceRepository instanceRepository(Ref ref) =>
    SupabaseInstanceRepository(Supabase.instance.client);

/// Who answers for this installation, as the server says now. Refreshed by
/// invalidation after a delegation, a withdrawal or a claim.
@riverpod
Future<InstanceResponsibles> instanceResponsibles(Ref ref) =>
    ref.watch(instanceRepositoryProvider).responsibles();

/// What the owner asks of the instance's roles (#1829).
@Riverpod(keepAlive: true)
InstanceRoles instanceRoles(Ref ref) =>
    InstanceRoles(ref.watch(instanceRepositoryProvider));
