// SPDX-License-Identifier: MIT
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// The active workspace. Multi-workspace switching arrives later; until
/// then the first (usually only) workspace is active (spec §2).
@Riverpod(keepAlive: true)
Future<Workspace?> currentWorkspace(Ref ref) async {
  final workspaces = await ref.watch(myWorkspacesProvider.future);
  return workspaces.isEmpty ? null : workspaces.first;
}

/// The signed-in user's membership (roles!) in the active workspace.
@Riverpod(keepAlive: true)
Future<Member?> myMember(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return null;
  return ref.watch(workspaceRepositoryProvider).fetchMyMember(workspace.id);
}
