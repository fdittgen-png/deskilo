// SPDX-License-Identifier: AGPL-3.0-or-later
import 'conversation.dart';
import 'member_note.dart';

/// Notes, conversations, participants, messages and search.
///
/// A part of [WorkspaceRepository] (#2597): that interface is the sum of
/// these, so no caller changes.
abstract class ConversationRepository {
  /// Sends a member note (#456, RPC `send_member_note`): to one member,
  /// or — [toMemberId] null — to all admins incl. the owner (the server
  /// requires the sender to be an admin for that).
  Future<void> sendMemberNote(
    String workspaceId, {
    required String? toMemberId,
    required String body,
  });

  /// The notes visible to me in [workspaceId] (RLS scopes: mine,
  /// addressed to me, or admin broadcasts), newest first.
  Future<List<MemberNote>> fetchMyNotes(String workspaceId);

  /// Deletes a note (#467) — RLS allows the sender and the direct
  /// recipient; received broadcasts are refused server-side.
  Future<void> deleteMemberNote(String noteId);

  /// Stamps unread notes ADDRESSED TO ME as read (0105/0108). With
  /// [fromMemberId] only that sender's notes — opening a conversation
  /// reads that exchange, nothing else. Senders see the check turn blue.
  Future<void> markMyNotesRead(String workspaceId, {String? fromMemberId});

  /// The conversation list, newest activity first (RPC
  /// `my_conversations`). One call, not one per thread: the last message
  /// and the unread count are per-viewer, and assembling them in Dart
  /// means a query per row.
  Future<List<Conversation>> fetchConversations(
    String workspaceId, {
    bool includeArchived = false,
  });

  /// #821 — my pin / mute / archive on a thread; null leaves a flag as
  /// it is. Per participant, server-enforced (0146).
  Future<void> setConversationPrefs(
    String conversationId, {
    bool? pinned,
    bool? muted,
    bool? archived,
  });

  /// #821 — reads the thread as unread again: my watermark moves back to
  /// just before the last message from someone else (0146).
  Future<void> markConversationUnread(String conversationId);

  /// The direct thread with [otherMemberId], created if it does not
  /// exist. Idempotent server-side, so two people opening each other at
  /// the same moment share one thread rather than making two.
  Future<String> openDirectConversation(
    String workspaceId, {
    required String otherMemberId,
  });

  /// Creates a group and returns its id. The caller becomes its first
  /// admin; members who are not active in this workspace are skipped
  /// rather than failing the whole call.
  Future<String> createGroupConversation(
    String workspaceId, {
    required String title,
    required List<String> memberIds,
  });

  /// Everyone in a conversation, including those who left — their past
  /// messages stay in the thread and need a name.
  Future<List<ConversationParticipant>> fetchParticipants(
    String conversationId,
  );

  /// Group admins only, server-enforced.
  Future<void> addParticipant(String conversationId, String memberId);

  Future<void> removeParticipant(String conversationId, String memberId);

  /// Leaving never strands a group: if the last admin goes, the
  /// longest-standing participant is promoted server-side.
  Future<void> leaveConversation(String conversationId);

  /// Renames a group and/or sets its photo. An empty [avatarPath]
  /// CLEARS the photo; null leaves it alone — without the distinction
  /// there is no way to remove one.
  Future<void> setConversationMeta(
    String conversationId, {
    String? title,
    String? avatarPath,
  });

  /// Posts into a conversation. Direct threads keep their
  /// `to_member_id`, so read receipts and the push trigger work
  /// unchanged; group messages have no single recipient.
  Future<void> sendConversationMessage(String conversationId, String body);

  /// The messages of one conversation, oldest first.
  Future<List<MemberNote>> fetchConversationMessages(
    String conversationId, {
    int limit = 200,
    DateTime? before,
  });

  /// Opening a conversation: moves my read watermark AND stamps the
  /// direct read receipts, so a 1:1 sender still sees their check turn
  /// blue.
  Future<void> markConversationRead(String conversationId);

  /// Full-text search over message bodies I can see (#687). Returns the
  /// matching messages newest first; the caller resolves them to their
  /// conversations.
  Future<List<MemberNote>> searchMessages(String workspaceId, String query);
}
