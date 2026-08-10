// SPDX-License-Identifier: 0BSD

/// A short member-to-member notification (#456, migration 0089).
/// [toMemberId] null = broadcast to all admins incl. the owner.
class MemberNote {
  const MemberNote({
    required this.id,
    required this.workspaceId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  factory MemberNote.fromRow(Map<String, dynamic> row) => MemberNote(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        fromMemberId: row['from_member_id'] as String,
        toMemberId: row['to_member_id'] as String?,
        body: row['body'] as String? ?? '',
        createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
        readAt: row['read_at'] == null
            ? null
            : DateTime.parse(row['read_at'] as String).toUtc(),
      );

  final String id;
  final String workspaceId;
  final String fromMemberId;
  final String? toMemberId;
  final String body;
  final DateTime createdAt;

  /// When the DIRECT recipient read it (0105); null = delivered only.
  /// Broadcasts have many readers and never carry a read stamp.
  final DateTime? readAt;

  bool get isBroadcast => toMemberId == null;
}

/// Rules shared with `send_member_note` (0089); pinned by test.
abstract final class MemberNoteRules {
  static const int maxLength = 500;
}
