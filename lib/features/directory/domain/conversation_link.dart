// SPDX-License-Identifier: AGPL-3.0-or-later
import 'inbox_composition.dart';
import 'inbox_sources.dart';
import 'messenger.dart';

/// A link to one conversation of the messenger: `/me/messages?conversation=`
/// followed by the conversation's qualified key — its source ('' is this
/// server), its family and its id, as [InboxEntry.key] writes them — so the
/// same local id on two servers or in two families never names one thread.
class ConversationLink {
  const ConversationLink({
    required this.source,
    required this.kind,
    required this.contextId,
  });

  /// The query parameter that carries the link.
  static const parameter = 'conversation';

  /// The link [value] names, or null when it is not one.
  static ConversationLink? parse(String? value) {
    final parts = value?.split('|');
    if (parts == null || parts.length != 3) return null;
    final kind = MessageContextKind.fromWire(parts[1]);
    if (kind == null || parts[2].isEmpty) return null;
    return ConversationLink(source: parts[0], kind: kind, contextId: parts[2]);
  }

  final String source;
  final MessageContextKind kind;
  final String contextId;

  String get key => '$source|${kind.wire}|$contextId';
}

/// What the source of a [ConversationLink] answered about it.
enum LinkVerdict {
  /// The source has not answered yet: nothing opens meanwhile.
  pending,

  /// The source lists the conversation for this person.
  authorized,

  /// The source answered and does not list it for this person: it is not
  /// theirs, or it does not exist. Nothing opens.
  refused,

  /// The source could not be asked: nothing opens.
  unreachable,
}

/// The conversation [link] names, if its own source lists it in [inbox] —
/// the inbox each source reads for the signed-in person alone, so a
/// conversation opens only once the server that holds it has said it is
/// theirs. Never another source's word, never a row the person was not
/// given.
(LinkVerdict, InboxEntry?) authorizeLink(
  UnifiedInbox inbox,
  ConversationLink link,
) {
  final entry = inbox.entries.where((e) => e.key == link.key).firstOrNull;
  if (entry != null) return (LinkVerdict.authorized, entry);
  if (inbox is! ComposedInbox) {
    return (
      inbox.unavailable.isEmpty ? LinkVerdict.refused : LinkVerdict.unreachable,
      null,
    );
  }
  final slots = [
    for (final s in inbox.sources)
      if (s.source == link.source && s.state != InboxSlotState.absent) s,
  ];
  if (slots.any((s) => s.state == InboxSlotState.reading)) {
    return (LinkVerdict.pending, null);
  }
  return (
    slots.any((s) => s.state == InboxSlotState.loaded)
        ? LinkVerdict.refused
        : LinkVerdict.unreachable,
    null,
  );
}
