// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/server_error.dart';
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
