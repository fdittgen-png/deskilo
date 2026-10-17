// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a thread draws besides the words (0382): the reactions on each
// message, my own stars, and which messages were corrected after sending.
import '../../../core/data/json_reader.dart';

/// One emoji on one message: how many people chose it, and whether I did.
class ReactionCount {
  const ReactionCount(this.emoji, this.count, {this.mine = false});
  final String emoji;
  final int count;
  final bool mine;
}

class MessageMarks {
  const MessageMarks({
    this.reactions = const {},
    this.starred = const {},
    this.edited = const {},
  });

  /// By message id, most chosen first.
  final Map<String, List<ReactionCount>> reactions;
  final Set<String> starred;
  final Set<String> edited;

  static const MessageMarks none = MessageMarks();

  /// The emoji I put on [messageId], if any.
  String? myReaction(String messageId) => [
        for (final r in reactions[messageId] ?? const <ReactionCount>[])
          if (r.mine) r.emoji,
      ].firstOrNull;

  /// #2387 — read through [JsonReader]; [context] names the RPC.
  factory MessageMarks.fromJson(
    Map<String, dynamic> json, {
    String context = 'message_marks_in',
  }) {
    final r = JsonReader(json, context: context);
    final byMessage = <String, List<ReactionCount>>{};
    for (final row in r.objects('reactions', (row) => row)) {
      byMessage
          .putIfAbsent(row.string('message_id'), () => [])
          .add(ReactionCount(
            row.string('emoji'),
            row.intOrNull('count') ?? 1,
            mine: row.boolOr('mine', fallback: false),
          ));
    }
    for (final list in byMessage.values) {
      list.sort((a, b) => b.count.compareTo(a.count));
    }
    return MessageMarks(
      reactions: byMessage,
      starred: r.strings('starred').toSet(),
      edited: r.strings('edited').toSet(),
    );
  }
}

/// The quick reactions offered on a message.
const List<String> kQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// A bookmarked message, as `my_starred_messages` returns it.
class StarredMessage {
  const StarredMessage({
    required this.kind,
    required this.messageId,
    required this.body,
    required this.authorName,
    required this.contextLabel,
    required this.sentAt,
  });

  final String kind, messageId, body, authorName, contextLabel;
  final DateTime sentAt;

  factory StarredMessage.fromJson(
    Map<String, dynamic> json, {
    String context = 'my_starred_messages',
  }) {
    final r = JsonReader(json, context: context);
    return StarredMessage(
      kind: r.stringOr('message_kind'),
      messageId: r.stringOr('message_id'),
      body: r.stringOr('body'),
      authorName: r.stringOr('author_name'),
      contextLabel: r.stringOr('context_label'),
      sentAt: r.dateTimeOrNull('sent_at')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
