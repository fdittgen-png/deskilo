// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3293 — who the fake's conversations and notes are for: the rules of
// my_conversations, send_conversation_message (0313) and
// can_read_member_note, applied to whoever the Demo persona is.
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';

import 'fake_conversations.dart';

extension DemoConversationVisibility on FakeConversations {
  /// #3293 — [c] as my_conversations answers the signed-in member, or
  /// null when they are not in it now: its roster's current people (a
  /// direct thread with no roster is its two people, read off its
  /// messages), with the other person of a direct thread the one who is
  /// not me. A thread the fake was given no roster and no message for
  /// stays listed, as the suite seeds them.
  Conversation? asSeenByMe(Conversation c) {
    final me = myMember.id;
    final people = currentPeople(c.id);
    if (people == null) return c;
    if (!people.contains(me)) return null;
    if (c.isGroup || c.otherMemberId != me) return c;
    // The opener's row names me as the other person: I see the opener.
    return Conversation(
      id: c.id,
      kind: c.kind,
      lastAt: c.lastAt,
      otherMemberId: people.firstWhere((id) => id != me, orElse: () => me),
      lastBody: c.lastBody,
      lastFromMemberId: c.lastFromMemberId,
      unread: c.lastFromMemberId == me ? 0 : c.unread,
      participantCount: c.participantCount,
      pinnedAt: c.pinnedAt,
      muted: c.muted,
      archivedAt: c.archivedAt,
    );
  }

  /// The people of [conversationId] who have not left it (at [at], when
  /// given: who was in it then), or null when the fake knows neither its
  /// roster nor, for a direct thread, any message of it.
  Set<String>? currentPeople(String conversationId, {DateTime? at}) {
    final roster = participants[conversationId];
    if (roster != null) {
      return {
        for (final p in roster)
          if (p.leftAt == null || (at != null && p.leftAt!.isAfter(at)))
            p.memberId,
      };
    }
    final direct = conversations.any(
      (c) => c.id == conversationId && !c.isGroup,
    );
    final people = {
      if (direct)
        for (final n
            in conversationMessages[conversationId] ??
                const <MemberNote>[]) ...[n.fromMemberId, ?n.toMemberId],
    };
    return people.isEmpty ? null : people;
  }

  bool mayReadNote(MemberNote n) {
    final me = myMember.id;
    if (n.fromMemberId == me) return true;
    final conversation = n.conversationId;
    if (conversation != null) {
      // can_read_member_note: a participant who had not left when it was
      // written; a thread the fake knows nothing of stays readable.
      final people = currentPeople(conversation, at: n.createdAt);
      return people == null || people.contains(me) || n.toMemberId == me;
    }
    if (n.toMemberId == me) return true;
    return n.toMemberId == null && (myMember.isAdmin || myMember.isOwner);
  }
}
