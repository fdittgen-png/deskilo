// SPDX-License-Identifier: MIT
import 'member.dart';
import 'workspace.dart';

/// Pure-Dart workspace boundary. Supabase impl in data/, fake in tests.
abstract class WorkspaceRepository {
  /// Workspaces the signed-in user is a non-exited member of.
  Future<List<Workspace>> fetchMyWorkspaces();

  /// Creates a workspace; the caller becomes its owner. Returns the id.
  Future<String> createWorkspace({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
  });

  /// Joins via invite code. Returns the workspace id.
  Future<String> joinWorkspace(String inviteCode);

  /// The signed-in user's membership in [workspaceId], or null.
  Future<Member?> fetchMyMember(String workspaceId);

  /// member id → display name for everyone in the workspace (floor-plan
  /// occupant labels, event actor names, …).
  Future<Map<String, String>> fetchMemberNames(String workspaceId);

  /// All memberships of the workspace (owner management screen).
  Future<List<Member>> fetchMembers(String workspaceId);

  /// Owner-only (RLS-enforced): assign a plan / change membership status.
  Future<void> updateMemberPlan(String memberId, String? planId);
  Future<void> updateMemberStatus(String memberId, MemberStatus status);
}
