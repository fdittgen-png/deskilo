// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Running a workspace group (0383): its description, whether only admins
// post, and who a message reached.

class ConversationDetails {
  const ConversationDetails({this.description = '', this.announceOnly = false});
  final String description;
  final bool announceOnly;

  static const ConversationDetails none = ConversationDetails();

  factory ConversationDetails.fromJson(Map<String, dynamic> json) =>
      ConversationDetails(
        description: json['description'] as String? ?? '',
        announceOnly: json['announce_only'] == true,
      );
}

/// Who a message reached: the participants whose last read is at or after it,
/// and those it has not reached yet. Visible to the author only.
class MessageReach {
  const MessageReach({
    required this.sentAt,
    this.readers = const [],
    this.pending = const [],
  });

  final DateTime sentAt;
  final List<({String memberId, DateTime readAt})> readers;
  final List<String> pending;

  factory MessageReach.fromJson(Map<String, dynamic> json) => MessageReach(
        sentAt: DateTime.parse(json['sent_at'] as String).toUtc(),
        readers: [
          for (final r in (json['readers'] as List<dynamic>? ?? const []))
            (
              memberId: (r as Map)['member_id'] as String,
              readAt: DateTime.parse(r['read_at'] as String).toUtc(),
            ),
        ],
        pending: [
          for (final id in (json['pending'] as List<dynamic>? ?? const []))
            id as String,
        ],
      );
}
