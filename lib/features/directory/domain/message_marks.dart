// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a thread draws besides the words (0382): the reactions on each
// message, my own stars, and which messages were corrected after sending.

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

  factory MessageMarks.fromJson(Map<String, dynamic> json) {
    final byMessage = <String, List<ReactionCount>>{};
    for (final raw in (json['reactions'] as List<dynamic>? ?? const [])) {
      final row = raw as Map<String, dynamic>;
      byMessage
          .putIfAbsent(row['message_id'] as String, () => [])
          .add(ReactionCount(
            row['emoji'] as String,
            (row['count'] as num?)?.toInt() ?? 1,
            mine: row['mine'] == true,
          ));
    }
    for (final list in byMessage.values) {
      list.sort((a, b) => b.count.compareTo(a.count));
    }
    return MessageMarks(
      reactions: byMessage,
      starred: {
        for (final id in (json['starred'] as List<dynamic>? ?? const []))
          id as String,
      },
      edited: {
        for (final id in (json['edited'] as List<dynamic>? ?? const []))
          id as String,
      },
    );
  }
}

/// How long the author may correct a message.
const Duration kMessageEditWindow = Duration(minutes: 15);

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

  factory StarredMessage.fromJson(Map<String, dynamic> j) => StarredMessage(
        kind: j['message_kind'] as String? ?? '',
        messageId: j['message_id'] as String? ?? '',
        body: j['body'] as String? ?? '',
        authorName: j['author_name'] as String? ?? '',
        contextLabel: j['context_label'] as String? ?? '',
        sentAt: DateTime.tryParse(j['sent_at'] as String? ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}
