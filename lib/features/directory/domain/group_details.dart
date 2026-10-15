// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Running a workspace group (0383): its description, whether only admins
// post, and who a message reached.

import '../../../core/data/json_reader.dart';

class ConversationDetails {
  const ConversationDetails({this.description = '', this.announceOnly = false});
  final String description;
  final bool announceOnly;

  static const ConversationDetails none = ConversationDetails();

  factory ConversationDetails.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'conversation_details');
    return ConversationDetails(
      description: r.stringOr('description'),
      announceOnly: r.boolOr('announce_only', fallback: false),
    );
  }
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

  factory MessageReach.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'message_info');
    return MessageReach(
      sentAt: r.dateTime('sent_at').toUtc(),
      readers: r.objects(
        'readers',
        (row) => (
          memberId: row.string('member_id'),
          readAt: row.dateTime('read_at').toUtc(),
        ),
      ),
      pending: r.strings('pending'),
    );
  }
}
