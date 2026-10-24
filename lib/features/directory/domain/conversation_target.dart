// SPDX-License-Identifier: AGPL-3.0-or-later
import 'messenger.dart';

/// What the messenger's thread pane shows: a conversation of the inbox,
/// or a person the directory offered for a new discussion (whose
/// conversation the first message opens).
///
/// Two targets with the same [key] are the same conversation on the same
/// source: the pane keeps one thread for it, whatever the layout.
sealed class ConversationTarget {
  const ConversationTarget();

  /// Qualified by source and family, so the same local id on two servers
  /// (or in two families) never names one thread.
  String get key;
}

/// A row of the unified inbox.
final class InboxTarget extends ConversationTarget {
  const InboxTarget(this.entry, {this.peer});
  final InboxEntry entry;

  /// The other person of an account conversation — who a reply goes to —
  /// when the row did not name them and the source's list did.
  final String? peer;

  @override
  String get key => 'entry|${entry.key}';
}

/// A person picked in the directory: the conversation with them on
/// [source] ('' is this server), found or opened by the thread itself.
final class PersonTarget extends ConversationTarget {
  const PersonTarget({
    required this.source,
    required this.recipient,
    required this.name,
    this.conversation,
  });

  final String source, recipient, name;

  /// The conversation when the directory already knows it.
  final String? conversation;

  @override
  String get key => 'person|$source|$recipient';
}

/// The key a composer's unsent text is kept under: the conversation on its
/// source and family, or — before the first message opened it — the person
/// it will go to. Never only the local id: two sources may reuse one.
String conversationDraftKey({
  required String source,
  required MessageContextKind kind,
  required String contextId,
  String? peer,
}) => contextId.isNotEmpty
    ? '$source|${kind.wire}|$contextId'
    : '$source|${kind.wire}|peer:${peer ?? ''}';
