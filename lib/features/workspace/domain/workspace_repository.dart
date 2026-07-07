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
}
