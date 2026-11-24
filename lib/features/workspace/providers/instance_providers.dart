// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/context_client_providers.dart';
import '../application/instance_roles.dart';
import '../data/supabase_instance_repository.dart';
import '../domain/instance_responsibles.dart';
import '../domain/instance_trace_report.dart';

part 'instance_providers.g.dart';

/// #1829 — the instance owner and delegates (0314).
@Riverpod(keepAlive: true)
InstanceRepository instanceRepository(Ref ref) =>
    SupabaseInstanceRepository(ref.watch(personalClientProvider));

/// Who answers for this installation, as the server says now. Refreshed by
/// invalidation after a delegation, a withdrawal or a claim.
@riverpod
Future<InstanceResponsibles> instanceResponsibles(Ref ref) =>
    ref.watch(instanceRepositoryProvider).responsibles();

/// #4416 — one page of the error reports, older than [before] (null: the
/// newest), for the installation's operator.
final instanceTraceReportsProvider = FutureProvider.autoDispose
    .family<List<InstanceTraceReport>, DateTime?>(
      (ref, before) =>
          ref.watch(instanceRepositoryProvider).traceReports(before: before),
    );

/// What the owner asks of the instance's roles (#1829).
@Riverpod(keepAlive: true)
InstanceRoles instanceRoles(Ref ref) =>
    InstanceRoles(ref.watch(instanceRepositoryProvider));
