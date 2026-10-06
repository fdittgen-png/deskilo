// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/server_error.dart';
import '../domain/account_group.dart';
import '../domain/group_details.dart';
import '../domain/message_marks.dart';
import '../domain/messenger.dart';
import '../domain/messenger_repository.dart';

/// #1824 — what a person asks the messenger to do, decided once.
///
/// The widgets say "send this", "forward that there", "lock it"; this
/// decides what is a valid request and which call it is. The server
/// re-checks every rule — a locked message, a flag switched off, a
/// conversation the caller left — and its refusal is what counts.
class MessengerActions {
  const MessengerActions(this.repository);
  final MessengerRepository repository;

  /// The refusal the server worded, or null for a fault — so a thread
  /// can say WHY instead of "try again".
  static MessengerRefusal? refusalOf(Object error) =>
      MessengerRefusal.of(serverErrorMessage(error));

  String _body(String body) {
    final text = body.trim();
    if (text.isEmpty || text.length > MessengerRules.maxBody) {
      throw ArgumentError('invalid message');
    }
    return text;
  }

  // ── blocks (0387) ───────────────────────────────────────────────────
  Future<List<BlockedAccount>> myBlocks() => repository.myBlocks();
  Future<void> blockAccount(String user) => repository.blockAccount(user);
  Future<void> unblockAccount(String user) => repository.unblockAccount(user);

  // ── a workspace conversation's own preferences (0386) ──────────────
  Future<void> setConversationFlags(
    String conversation, {
    bool? pinned,
    bool? muted,
    bool? archived,
  }) =>
      repository.setConversationFlags(conversation,
          pinned: pinned, muted: muted, archived: archived);

  Future<void> markConversationUnread(String conversation) =>
      repository.markConversationUnread(conversation);

  // ── groups of people (0384) ─────────────────────────────────────────
  Future<String> createGroup(String title, List<String> users) {
    final name = title.trim();
    if (name.isEmpty || name.length > 60) throw ArgumentError('invalid group name');
    if (users.isEmpty) throw ArgumentError('people required');
    return repository.createGroup(name, users);
  }

  Future<AccountGroupInfo> groupInfo(String group) => repository.groupInfo(group);
  Future<List<GroupMember>> groupMembers(String group) =>
      repository.groupMembers(group);
  Future<void> addGroupMember(String group, String user) =>
      repository.addGroupMember(group, user);
  Future<void> removeGroupMember(String group, String user) =>
      repository.removeGroupMember(group, user);
  Future<void> leaveGroup(String group) => repository.leaveGroup(group);
  Future<void> setGroupMeta(String group,
          {String? title, String? description, bool? announceOnly}) =>
      repository.setGroupMeta(group,
          title: title?.trim(),
          description: description?.trim(),
          announceOnly: announceOnly);
  Future<void> setGroupAdmin(String group, String user, {required bool admin}) =>
      repository.setGroupAdmin(group, user, admin: admin);
  Future<void> deleteGroupMessage(String message) =>
      repository.deleteGroupMessage(message);
  Future<GroupReach> groupReach(String message) => repository.groupReach(message);

  // ── running a group (0383) ──────────────────────────────────────────
  Future<ConversationDetails> conversationDetails(String id) =>
      repository.conversationDetails(id);
  Future<void> setConversationDetails(String id,
          {required String description, required bool announceOnly}) =>
      repository.setConversationDetails(id,
          description: description.trim(), announceOnly: announceOnly);
  Future<void> setParticipantAdmin(String id, String memberId,
          {required bool admin}) =>
      repository.setParticipantAdmin(id, memberId, admin: admin);
  Future<MessageReach> messageReach(String messageId) =>
      repository.messageReach(messageId);

  // ── reactions, stars and edits (0382) ───────────────────────────────
  Future<MessageMarks> marks(String contextWire, String contextId) =>
      repository.marks(contextWire, contextId);
  Future<void> react(MessageKind kind, String messageId, String? emoji) =>
      repository.react(kind, messageId, emoji);
  Future<bool> toggleStar(MessageKind kind, String messageId) =>
      repository.toggleStar(kind, messageId);
  Future<void> edit(MessageKind kind, String messageId, String body) =>
      repository.edit(kind, messageId, _body(body));

  Future<String> startInquiry(String workspace, String body) {
    if (workspace.isEmpty) throw ArgumentError('workspace required');
    return repository.startInquiry(workspace, _body(body));
  }

  /// Sends into the conversation [kind]/[contextId]. An account
  /// conversation is addressed by the other person ([peer]): the server
  /// finds or opens the conversation between the two.
  ///
  /// Answers the conversation the message landed in — for an account
  /// conversation that did not exist yet, the one the server just opened.
  Future<String> send({
    required MessageContextKind kind,
    required String contextId,
    required String body,
    String? peer,
  }) async {
    final text = _body(body);
    switch (kind) {
      case MessageContextKind.account:
        if (peer == null || peer.isEmpty) {
          throw ArgumentError('recipient required');
        }
        return repository.sendAccountMessage(peer, text);
      case MessageContextKind.inquiryIn || MessageContextKind.inquiryOut:
        if (contextId.isEmpty) throw ArgumentError('inquiry required');
        await repository.sendInquiryMessage(contextId, text);
        return contextId;
      case MessageContextKind.space:
        if (contextId.isEmpty) throw ArgumentError('conversation required');
        await repository.sendSpaceMessage(contextId, text);
        return contextId;
      case MessageContextKind.accountGroup:
        if (contextId.isEmpty) throw ArgumentError('group required');
        await repository.sendGroupMessage(contextId, text);
        return contextId;
    }
  }

  /// A page of the conversation, newest first; [before] asks for the
  /// page older than that message. A space conversation read from the
  /// inbox shows its newest page only.
  Future<List<ContextMessage>> messages(
    MessageContextKind kind,
    String contextId, {
    ContextMessage? before,
  }) => switch (kind) {
    MessageContextKind.account => repository.accountMessages(
      contextId,
      beforeAt: before?.createdAt,
      beforeId: before?.id,
    ),
    MessageContextKind.inquiryIn ||
    MessageContextKind.inquiryOut => repository.inquiryMessages(
      contextId,
      beforeAt: before?.createdAt,
      beforeId: before?.id,
    ),
    MessageContextKind.space =>
      before == null
          ? repository.spaceMessages(contextId)
          : Future.value(const <ContextMessage>[]),
    MessageContextKind.accountGroup => repository.groupMessages(
      contextId,
      beforeAt: before?.createdAt,
      beforeId: before?.id,
    ),
  };

  /// Opening a conversation reads it: the other side's receipt moves and
  /// my unread count drops.
  Future<void> markRead(MessageContextKind kind, String contextId) =>
      switch (kind) {
        MessageContextKind.account => repository.markAccountConversationRead(
          contextId,
        ),
        MessageContextKind.inquiryIn ||
        MessageContextKind.inquiryOut => repository.markInquiryRead(contextId),
        MessageContextKind.space => repository.markSpaceConversationRead(
          contextId,
        ),
        MessageContextKind.accountGroup => repository.markGroupRead(contextId),
      };

  /// Forwards [message] into [target]. Refused here already when the
  /// message is a system line or locked — the action is not even
  /// offered then, and a stale screen must not get further than that.
  Future<String> forward(ContextMessage message, InboxEntry target) =>
      forwardById(
        kind: message.kind,
        messageId: message.id,
        locked: !message.forwardable,
        target: target,
      );

  Future<String> forwardById({
    required MessageKind kind,
    required String messageId,
    required InboxEntry target,
    bool locked = false,
  }) {
    if (locked) throw StateError('message is locked against forwarding');
    return repository.forward(
      kind: kind,
      messageId: messageId,
      targetKind: target.kind,
      targetId: target.contextId,
    );
  }

  Future<void> setForwardLock(
    MessageKind kind,
    String messageId, {
    required bool locked,
  }) => repository.setForwardLock(kind, messageId, locked);

  Future<List<MessageEvent>> history(MessageKind kind, String messageId) =>
      repository.history(kind, messageId);

  Future<void> recordScreenCapture(MessageContextKind kind, String contextId) =>
      repository.recordScreenCapture(kind, contextId);

  /// Only my own account message, and only an ordinary one.
  Future<void> deleteAccountMessage(ContextMessage message) {
    if (!message.mine ||
        message.isNotice ||
        message.kind != MessageKind.accountMessage) {
      throw StateError('only your own message can be deleted');
    }
    return repository.deleteAccountMessage(message.id);
  }

  Future<void> closeInquiry(String inquiry) => repository.closeInquiry(inquiry);
}
