// SPDX-License-Identifier: AGPL-3.0-or-later
import 'account_group.dart';
import 'group_details.dart';
import 'message_marks.dart';
import 'messenger.dart';

/// #1824 — the context-bound messenger on ONE server.
///
/// One instance per server: the unified inbox asks every connected
/// server's instance and merges the answers (`mergeInboxes`). A forward
/// never crosses servers — the source and the target are written in one
/// transaction on the server both live on.
abstract interface class MessengerRepository {
  /// `my_inbox`: every conversation I take part in on this server.
  Future<List<Map<String, dynamic>>> inbox();

  /// Pin / mute / archive of a workspace conversation, kept by the server
  /// (`set_conversation_prefs`); null leaves a flag as it is.
  Future<void> setConversationFlags(
    String conversation, {
    bool? pinned,
    bool? muted,
    bool? archived,
  });

  /// Marks a workspace conversation unread again (`mark_conversation_unread`).
  Future<void> markConversationUnread(String conversation);

  /// The workspaces I share with [user] (both active members): where the
  /// references of a conversation with them may point (0381).
  Future<List<({String id, String name})>> sharedWorkspaces(String user);

  // ── inquiries ─────────────────────────────────────────────────────
  Future<List<HostRosterEntry>> hostRoster(String workspace);
  Future<String> startInquiry(String workspace, String body);
  Future<String> sendInquiryMessage(String inquiry, String body);
  Future<List<InquirySummary>> myInquiries();
  Future<List<InquirySummary>> workspaceInquiries(String workspace);
  Future<List<ContextMessage>> inquiryMessages(
    String inquiry, {
    DateTime? beforeAt,
    String? beforeId,
  });
  Future<void> markInquiryRead(String inquiry);
  Future<void> closeInquiry(String inquiry);

  // ── what a chat does besides words (0382) ─────────────────────────
  /// Reactions, my stars and the edited messages of one context
  /// ([contextWire]: `conversation | account_conversation | inquiry`).
  Future<MessageMarks> marks(String contextWire, String contextId);
  Future<void> react(MessageKind kind, String messageId, String? emoji);
  Future<bool> toggleStar(MessageKind kind, String messageId);
  Future<void> edit(MessageKind kind, String messageId, String body);
  Future<List<StarredMessage>> starred();

  // ── groups of people (0384) ───────────────────────────────────────
  Future<String> createGroup(String title, List<String> users);
  Future<AccountGroupInfo> groupInfo(String group);
  Future<List<GroupMember>> groupMembers(String group);
  Future<void> addGroupMember(String group, String user);
  Future<void> removeGroupMember(String group, String user);
  Future<void> leaveGroup(String group);
  Future<void> setGroupMeta(
    String group, {
    String? title,
    String? description,
    bool? announceOnly,
  });
  Future<void> setGroupAdmin(String group, String user, {required bool admin});
  Future<List<ContextMessage>> groupMessages(
    String group, {
    DateTime? beforeAt,
    String? beforeId,
  });
  Future<String> sendGroupMessage(String group, String body);
  Future<void> markGroupRead(String group);
  Future<void> deleteGroupMessage(String message);
  Future<GroupReach> groupReach(String message);
  Future<List<({String id, String name})>> groupSharedWorkspaces(String group);

  // ── running a group (0383) ────────────────────────────────────────
  Future<ConversationDetails> conversationDetails(String conversationId);
  Future<void> setConversationDetails(
    String conversationId, {
    required String description,
    required bool announceOnly,
  });
  Future<void> setParticipantAdmin(
    String conversationId,
    String memberId, {
    required bool admin,
  });
  Future<MessageReach> messageReach(String messageId);

  // ── forwarding and history ────────────────────────────────────────
  Future<String> forward({
    required MessageKind kind,
    required String messageId,
    required MessageContextKind targetKind,
    required String targetId,
  });
  Future<void> setForwardLock(MessageKind kind, String messageId, bool locked);
  Future<List<MessageEvent>> history(MessageKind kind, String messageId);

  /// [kind] names the CONTEXT (`conversation | account_conversation |
  /// inquiry`), the words a forward target uses.
  Future<void> recordScreenCapture(MessageContextKind kind, String contextId);

  // ── account messages ──────────────────────────────────────────────
  Future<List<ContextMessage>> accountMessages(
    String conversation, {
    DateTime? beforeAt,
    String? beforeId,
  });
  Future<String> sendAccountMessage(String recipient, String body);
  Future<void> markAccountConversationRead(String conversation);
  Future<void> deleteAccountMessage(String message);

  // ── a space conversation read from the unified inbox ──────────────
  Future<List<ContextMessage>> spaceMessages(String conversation);
  Future<void> sendSpaceMessage(String conversation, String body);
  Future<void> markSpaceConversationRead(String conversation);
}
