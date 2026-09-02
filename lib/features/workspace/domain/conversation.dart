// SPDX-License-Identifier: 0BSD

/// A messaging thread (#687, migrations 0125/0126): a direct exchange
/// with one member, or a named group.
///
/// One type for both, because the conversation LIST shows them
/// interleaved and sorted together — two types would mean two code paths
/// through every row, sort and search result for a difference that is
/// one enum away.
library;

enum ConversationKind {
  /// Exactly two people, no name, no photo, created the moment someone
  /// opens the other's profile. Nobody names or leaves a direct thread.
  direct,

  /// Named, photographed, any number of people, with admins.
  group,
}

ConversationKind conversationKindFromWire(String value) =>
    value == 'group' ? ConversationKind.group : ConversationKind.direct;

/// One row of the conversation list, as `my_conversations` returns it:
/// the thread plus the per-viewer parts (last message, unread count).
class Conversation {
  const Conversation({
    required this.id,
    required this.kind,
    required this.lastAt,
    this.title,
    this.avatarPath,
    this.otherMemberId,
    this.lastBody = '',
    this.lastFromMemberId,
    this.unread = 0,
    this.participantCount = 0,
    this.pinnedAt,
    this.muted = false,
    this.archivedAt,
  });

  factory Conversation.fromRow(Map<String, dynamic> row) => Conversation(
        id: row['id'] as String,
        kind: conversationKindFromWire(row['kind'] as String? ?? 'direct'),
        title: row['title'] as String?,
        avatarPath: row['avatar_path'] as String?,
        otherMemberId: row['other_member_id'] as String?,
        lastBody: row['last_body'] as String? ?? '',
        // #692 — DEFENSIVE, and it is not belt-and-braces: this exact
        // parse threw on a message-less group and took the WHOLE list
        // with it, because one bad row in a `for` inside a list literal
        // fails the entire collection. The screen said "an error
        // occurred" and named nothing.
        //
        // 0127 makes the server side never-null; this makes a future
        // null cost one row's ordering instead of everyone's inbox.
        lastAt: _parseAt(row['last_at']),
        lastFromMemberId: row['last_from_member_id'] as String?,
        unread: (row['unread'] as num?)?.toInt() ?? 0,
        participantCount: (row['participant_count'] as num?)?.toInt() ?? 0,
        // #821 — my view of the thread (0146); absent on older servers.
        pinnedAt: _parseNullableAt(row['pinned_at']),
        muted: row['muted'] == true,
        archivedAt: _parseNullableAt(row['archived_at']),
      );

  static DateTime? _parseNullableAt(Object? value) =>
      value == null ? null : _parseAt(value);

  final String id;
  final ConversationKind kind;

  /// The group's name. Null on a direct thread, which is titled by the
  /// other person — a name that is theirs to change, never ours to
  /// snapshot.
  final String? title;

  /// Object path in the shared `avatars` bucket (0038). Null renders
  /// initials, exactly as a member without a photo does.
  final String? avatarPath;

  /// The other participant, on a direct thread only.
  final String? otherMemberId;

  final String lastBody;
  final DateTime lastAt;
  final String? lastFromMemberId;

  /// Messages from someone else that I have not read.
  final int unread;

  /// Live participants — shown as "N members" under a group's name.
  final int participantCount;

  /// #821 — MY pin, mute and archive on this thread (per participant).
  final DateTime? pinnedAt;
  final bool muted;
  final DateTime? archivedAt;

  bool get isPinned => pinnedAt != null;
  bool get isArchived => archivedAt != null;

  bool get isGroup => kind == ConversationKind.group;
  bool get hasUnread => unread > 0;

  /// Whether the last message is mine. Drives the read-check on the
  /// list row: a check on someone ELSE's message would claim they read
  /// what I sent, which is backwards.
  bool sentByMe(String? myMemberId) =>
      lastFromMemberId != null && lastFromMemberId == myMemberId;
}

/// One member of a conversation, as the roster sheet shows them.
class ConversationParticipant {
  const ConversationParticipant({
    required this.memberId,
    required this.isAdmin,
    this.leftAt,
  });

  factory ConversationParticipant.fromRow(Map<String, dynamic> row) =>
      ConversationParticipant(
        memberId: row['member_id'] as String,
        isAdmin: row['is_admin'] == true,
        leftAt: row['left_at'] == null
            ? null
            : DateTime.parse(row['left_at'] as String).toUtc(),
      );

  final String memberId;
  final bool isAdmin;

  /// Set once they left. They stay listed nowhere, but their past
  /// messages remain in the thread — a group's history developing holes
  /// when someone leaves is worse than a name nobody recognises.
  final DateTime? leftAt;

  bool get isActive => leftAt == null;
}

/// Shared with `create_group_conversation` (0126); pinned by test.
abstract final class ConversationRules {
  static const int maxTitleLength = 80;
}

/// A timestamp that cannot throw.
///
/// The epoch is a deliberate choice for the unparseable case: it sorts
/// the row to the BOTTOM of a newest-first list, where a row the app
/// does not understand belongs — rather than to the top, where it would
/// displace whatever someone actually just wrote.
DateTime _parseAt(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
