// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/active_workspace_store.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/supabase_workspace_repository.dart';
import '../domain/booking_granularity.dart';
import '../domain/closure_day.dart';
import '../domain/member.dart';
import '../domain/workspace.dart';
import '../domain/workspace_feature.dart';
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

/// ISO weekdays (1=Mon..7=Sun) the active workspace is open on (#127).
@riverpod
Future<List<int>> openWeekdays(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [1, 2, 3, 4, 5];
  return ref
      .watch(workspaceRepositoryProvider)
      .fetchOpenWeekdays(workspace.id);
}

/// Booking-granularity rule of the active workspace (#200); flexible
/// while no workspace is selected or the key is absent.
@riverpod
Future<BookingGranularity> bookingGranularity(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return BookingGranularity.flexible;
  return ref
      .watch(workspaceRepositoryProvider)
      .fetchBookingGranularity(workspace.id);
}

/// One-off closure days of the active workspace, ordered by day (#127).
@riverpod
Future<List<ClosureDay>> closureDays(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref
      .watch(workspaceRepositoryProvider)
      .fetchClosureDays(workspace.id);
}

/// The active workspace's admin invite code — null for non-owners
/// (owner-only RLS on workspace_admin_invites, 0030).
@riverpod
Future<String?> adminInviteCode(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return null;
  return ref
      .watch(workspaceRepositoryProvider)
      .adminInviteCode(workspace.id);
}

/// Features enabled for the active workspace (#146). Deriving from
/// [currentWorkspace] is what makes flags "apply on connect": switching
/// profiles (#89) or refetching workspaces recomputes the set with the
/// new workspace's flags — no extra plumbing. No workspace = defaults.
@Riverpod(keepAlive: true)
Future<Set<WorkspaceFeature>> enabledFeatures(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  return resolveEnabledFeatures(workspace?.featureFlags ?? const {});
}

/// Sync convenience over [enabledFeatures] for build methods and router
/// redirects. While the workspace is still loading it falls back to ALL
/// registry defaults (everything ON) so the shell never flashes a
/// reduced tab bar.
@Riverpod(keepAlive: true)
Set<WorkspaceFeature> enabledFeaturesSync(Ref ref) =>
    ref.watch(enabledFeaturesProvider).value ??
    resolveEnabledFeatures(const {});

/// The signed-in user's membership (roles!) in the active workspace.
@Riverpod(keepAlive: true)
Future<Member?> myMember(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return null;
  return ref.watch(workspaceRepositoryProvider).fetchMyMember(workspace.id);
}
