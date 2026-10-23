// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/supabase_local_setup_repository.dart';
import '../domain/local_setup.dart';
import '../domain/setup_status.dart';
import '../domain/workspace_readiness.dart';
import 'operation_context_providers.dart';

part 'local_setup_providers.g.dart';

/// #1656 group 5 — the local setup a template needs and a space lacks.
@Riverpod(keepAlive: true)
LocalSetupRepository localSetupRepository(Ref ref) =>
    SupabaseLocalSetupRepository(ref.watch(selectedWorkspaceClientProvider));

@riverpod
Future<List<LocalSlot>> templateLocalNeeds(Ref ref, String templateId) =>
    ref.watch(localSetupRepositoryProvider).templateNeeds(templateId);

/// Only the slots still to fill, required first.
@riverpod
Future<List<LocalSlot>> workspaceLocalGaps(Ref ref, String workspaceId) async {
  final all = await ref
      .watch(localSetupRepositoryProvider)
      .readiness(workspaceId);
  return [
    for (final s in all)
      if (s.filled == false && s.kind != LocalSlotKind.unknown) s,
  ]..sort((a, b) => (b.required ? 1 : 0) - (a.required ? 1 : 0));
}

/// #1658 — every local slot the space's switched-on features need,
/// filled or not: what a space applying its template will need too.
@riverpod
Future<List<LocalSlot>> workspaceLocalSlots(Ref ref, String workspaceId) async => [
  for (final s in await ref.watch(localSetupRepositoryProvider).readiness(workspaceId))
    if (s.kind != LocalSlotKind.unknown) s,
];

/// #2869 — the setup guide's status: every step and the four milestones.
@riverpod
Future<SetupStatus> workspaceSetupStatus(Ref ref, String workspaceId) =>
    ref.watch(localSetupRepositoryProvider).setupStatus(workspaceId);

/// #1636 — every setup section of the space, in the server's order.
@riverpod
Future<List<ReadinessSection>> workspaceReadiness(Ref ref, String workspaceId) =>
    ref.watch(localSetupRepositoryProvider).sections(workspaceId);
