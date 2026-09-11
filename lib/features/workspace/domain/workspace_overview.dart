import '../../../core/data/system_columns.dart';
// SPDX-License-Identifier: 0BSD
//
// #937 — what the PLATFORM owner sees of a workspace they are not in:
// enough to recognise it and to know whom to write to, nothing of what
// happens inside. Both rows come from definer RPCs (0166) that refuse
// anyone else, and reading the owners is logged for the workspace's own
// owners to see.

/// One row of `list_all_workspaces`.
class WorkspaceOverview implements SystemStamped {
  const WorkspaceOverview({
    required this.id,
    required this.name,
    this.environment = 'dev',
    this.pairId = '',
    this.memberCount = 0,
    this.ownerCount = 0,
    this.isMember = false,
    this.system = SystemColumns.none,
  });

  /// #992 — the server's stamp on this row.
  @override
  final SystemColumns system;

  final String id;
  final String name;

  /// `'dev'` or `'prod'` — the wire value of the workspace's environment.
  final String environment;

  /// #987 — the twin's shared id, or '' for a workspace that has no
  /// twin. Without it this list showed a dev and its prod as two
  /// unrelated workspaces with the same name, while the list of
  /// workspaces you belong to had rendered the pair as ONE row with a
  /// DEV/PROD toggle since #987.
  final String pairId;
  final int memberCount;
  final int ownerCount;

  /// Whether the caller is a member: their own workspaces are listed as
  /// usual; the others are what this row exists for.
  final bool isMember;

  bool get isDevelopment => environment != 'prod';

  /// Part of a dev/prod couple rather than a workspace standing alone.
  bool get isPaired => pairId.isNotEmpty;

  factory WorkspaceOverview.fromRow(Map<String, dynamic> row) =>
      WorkspaceOverview(
        system: SystemColumns.fromRow(row),
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        environment: row['environment'] as String? ?? 'dev',
        pairId: row['pair_id'] as String? ?? '',
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
