// SPDX-License-Identifier: 0BSD
//
// #937 — what the PLATFORM owner sees of a workspace they are not in:
// enough to recognise it and to know whom to write to, nothing of what
// happens inside. Both rows come from definer RPCs (0166) that refuse
// anyone else, and reading the owners is logged for the workspace's own
// owners to see.

/// One row of `list_all_workspaces`.
class WorkspaceOverview {
  const WorkspaceOverview({
    required this.id,
    required this.name,
    this.environment = 'dev',
    this.memberCount = 0,
    this.ownerCount = 0,
    this.isMember = false,
  });

  final String id;
  final String name;

  /// `'dev'` or `'prod'` — the wire value of the workspace's environment.
  final String environment;
  final int memberCount;
  final int ownerCount;

  /// Whether the caller is a member: their own workspaces are listed as
  /// usual; the others are what this row exists for.
  final bool isMember;

  bool get isDevelopment => environment != 'prod';

  factory WorkspaceOverview.fromRow(Map<String, dynamic> row) =>
      WorkspaceOverview(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        environment: row['environment'] as String? ?? 'dev',
        memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
        ownerCount: (row['owner_count'] as num?)?.toInt() ?? 0,
        isMember: row['is_member'] as bool? ?? false,
      );
}

/// One row of `workspace_owners`: a person to write to.
class WorkspaceOwner {
  const WorkspaceOwner({
    required this.memberId,
    required this.name,
    required this.email,
  });

  final String memberId;
  final String name;

  /// Never empty for an owner — 0166 refuses ownership without one.
  final String email;

  factory WorkspaceOwner.fromRow(Map<String, dynamic> row) => WorkspaceOwner(
        memberId: row['member_id'] as String,
        name: row['name'] as String? ?? '',
        email: row['email'] as String? ?? '',
      );
}
