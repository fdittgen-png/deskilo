// SPDX-License-Identifier: MIT
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/active_workspace_store.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/supabase_workspace_repository.dart';
import '../domain/member.dart';
import '../domain/workspace.dart';
import '../domain/workspace_repository.dart';

part 'workspace_providers.g.dart';

@Riverpod(keepAlive: true)
WorkspaceRepository workspaceRepository(Ref ref) =>
    SupabaseWorkspaceRepository(Supabase.instance.client);

@Riverpod(keepAlive: true)
Future<List<Workspace>> myWorkspaces(Ref ref) async {
  final signedIn = ref.watch(authStateProvider).value != null;
  if (!signedIn) return const [];
  return ref.watch(workspaceRepositoryProvider).fetchMyWorkspaces();
}

/// The persisted active-profile choice (#89). Falls back to the first
/// workspace when nothing was chosen yet or the choice no longer exists.
@Riverpod(keepAlive: true)
class ActiveWorkspaceId extends _$ActiveWorkspaceId {
  @override
  Future<String?> build() =>
      ref.watch(activeWorkspaceStoreProvider).read();

  Future<void> select(String workspaceId) async {
    await ref.read(activeWorkspaceStoreProvider).write(workspaceId);
    state = AsyncData(workspaceId);
  }
}

/// The active workspace (profile).
@Riverpod(keepAlive: true)
Future<Workspace?> currentWorkspace(Ref ref) async {
  final workspaces = await ref.watch(myWorkspacesProvider.future);
  if (workspaces.isEmpty) return null;
  final chosenId = await ref.watch(activeWorkspaceIdProvider.future);
  return workspaces.where((w) => w.id == chosenId).firstOrNull ??
      workspaces.first;
}

/// All memberships of the active workspace (owner management + event
/// decider computation, #107).
@riverpod
Future<List<Member>> workspaceMembers(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(workspaceRepositoryProvider).fetchMembers(workspace.id);
}

/// All my membership rows across workspaces — one per profile (#89).
@Riverpod(keepAlive: true)
Future<List<Member>> myMemberships(Ref ref) async {
  final signedIn = ref.watch(authStateProvider).value != null;
  if (!signedIn) return const [];
  return ref.watch(workspaceRepositoryProvider).fetchMyMembers();
}

/// The signed-in user's membership (roles!) in the active workspace.
@Riverpod(keepAlive: true)
Future<Member?> myMember(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return null;
  return ref.watch(workspaceRepositoryProvider).fetchMyMember(workspace.id);
}
