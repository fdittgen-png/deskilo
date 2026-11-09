// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 W1 -- the conversation half of the in-memory workspace repository: the
// notes, threads, participants and messages of the Demo and of the tests, by
// the server's rules (`my_conversations`, `send_conversation_message` 0313,
// `can_read_member_note`). A mixin composed into `FakeWorkspaceRepository`;
// its recording fields keep their names, so no test changes. Who sees what is
// `conversation_visibility.dart`.
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/conversation_repository.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'conversation_visibility.dart';

mixin FakeConversations implements ConversationRepository {
  /// The signed-in member the rules are applied to (the host's field).
  Member get myMember;

  /// Sent member notes (#456), newest last; myNotes returns them
  /// newest-first like the real query.
  final List<MemberNote> memberNotes = [];

  // ── conversations (#687) ────────────────────────────────────────────

  /// Threads the fake knows about, in no particular order — the fake
  /// SORTS on read, exactly as `my_conversations` does, so a test that
  /// depends on ordering exercises the ordering rather than the seed
  /// order.
  final List<Conversation> conversations = [];

  /// Messages per conversation id, oldest first.
  final Map<String, List<MemberNote>> conversationMessages = {};
  final Map<String, List<ConversationParticipant>> participants = {};

  final List<({String conversationId, String body})> sentMessages = [];
  final List<String> readConversations = [];
  final List<({String conversationId, String memberId})> addedParticipants = [];
  final List<({String conversationId, String memberId})> removedParticipants =
      [];
  final List<String> leftConversations = [];
  final List<({String id, String? title, String? avatarPath})> metaWrites = [];

  /// The id [createGroupConversation] hands back; tests that navigate on
  /// it need to know it in advance.
  String nextGroupId = 'conv-group';

  /// #821 — prefs writes and unread marks, in order.
  final List<({String id, bool? pinned, bool? muted, bool? archived})>
      prefsWrites = [];
  final List<String> unreadMarks = [];

  /// Ids passed to [deleteMemberNote], in order (#798).
  final List<String> deletedNotes = [];

  @override
  Future<List<Conversation>> fetchConversations(
    String workspaceId, {
    bool includeArchived = false,
  }) async =>
      [
        for (final c in conversations)
          if (includeArchived || !c.isArchived) ?asSeenByMe(c),
      ]..sort((a, b) {
          // Pinned first, then newest — my_conversations v3 (0146).
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          return b.lastAt.compareTo(a.lastAt);
        });

  @override
  Future<void> setConversationPrefs(
    String conversationId, {
    bool? pinned,
    bool? muted,
    bool? archived,
  }) async {
    prefsWrites.add(
        (id: conversationId, pinned: pinned, muted: muted, archived: archived));
    final i = conversations.indexWhere((c) => c.id == conversationId);
    if (i < 0) return;
    final c = conversations[i];
    conversations[i] = Conversation(
      id: c.id,
      kind: c.kind,
      lastAt: c.lastAt,
      title: c.title,
      avatarPath: c.avatarPath,
      otherMemberId: c.otherMemberId,
      lastBody: c.lastBody,
      lastFromMemberId: c.lastFromMemberId,
      unread: c.unread,
      participantCount: c.participantCount,
      pinnedAt: pinned == null
          ? c.pinnedAt
          : (pinned ? (c.pinnedAt ?? DateTime.utc(2026, 9, 2)) : null),
      muted: muted ?? c.muted,
      archivedAt: archived == null
          ? c.archivedAt
          : (archived ? (c.archivedAt ?? DateTime.utc(2026, 9, 2)) : null),
    );
  }

  @override
  Future<void> markConversationUnread(String conversationId) async {
    unreadMarks.add(conversationId);
    final i = conversations.indexWhere((c) => c.id == conversationId);
    if (i < 0) return;
    final c = conversations[i];
    conversations[i] = Conversation(
      id: c.id,
      kind: c.kind,
      lastAt: c.lastAt,
      title: c.title,
      avatarPath: c.avatarPath,
      otherMemberId: c.otherMemberId,
      lastBody: c.lastBody,
      lastFromMemberId: c.lastFromMemberId,
      unread: c.unread == 0 ? 1 : c.unread,
      participantCount: c.participantCount,
      pinnedAt: c.pinnedAt,
      muted: c.muted,
      archivedAt: c.archivedAt,
    );
  }

  @override
  Future<String> openDirectConversation(
    String workspaceId, {
    required String otherMemberId,
  }) async {
    // Idempotent like the RPC: the same pair must not yield two threads.
    final me = myMember.id;
    final existing = conversations.where((c) {
      if (c.isGroup) return false;
      final people = currentPeople(c.id);
      return people == null
          ? c.otherMemberId == otherMemberId
          : people.containsAll({me, otherMemberId});
    }).firstOrNull;
    if (existing != null) return existing.id;
    final created = Conversation(
      id: 'conv-direct-$otherMemberId',
      kind: ConversationKind.direct,
      otherMemberId: otherMemberId,
      lastAt: DateTime.utc(2026, 8, 27),
    );
    conversations.add(created);
    // #3293 — a direct thread has its two participants, as on the server.
    participants[created.id] = [
      ConversationParticipant(memberId: me, isAdmin: false),
      ConversationParticipant(memberId: otherMemberId, isAdmin: false),
    ];
    // #702 / migration 0130 — the thread INHERITS the pair's existing
    // notes. On the server those notes were written before conversations
    // existed and the backfill stamps them into this one; a fake that
    // hands back an empty thread instead would let the app lose every
    // message older than 0125 without a single test noticing.
    conversationMessages.putIfAbsent(
      created.id,
      () => memberNotes
          .where((n) =>
              !n.isBroadcast &&
              (n.fromMemberId == otherMemberId ||
                  n.toMemberId == otherMemberId))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
    );
    return created.id;
  }

  @override
  Future<String> createGroupConversation(
    String workspaceId, {
    required String title,
    required List<String> memberIds,
  }) async {
    conversations.add(Conversation(
      id: nextGroupId,
      kind: ConversationKind.group,
      title: title,
      lastAt: DateTime.utc(2026, 8, 27),
      participantCount: memberIds.length + 1,
    ));
    participants[nextGroupId] = [
      // #3293 — the creator is the signed-in member.
      ConversationParticipant(memberId: myMember.id, isAdmin: true),
      for (final id in memberIds)
        ConversationParticipant(memberId: id, isAdmin: false),
    ];
    return nextGroupId;
  }

  @override
  Future<List<ConversationParticipant>> fetchParticipants(
    String conversationId,
  ) async =>
      participants[conversationId] ?? const [];

  @override
  Future<void> addParticipant(String conversationId, String memberId) async {
    addedParticipants.add((conversationId: conversationId, memberId: memberId));
    participants.putIfAbsent(conversationId, () => []).add(
          ConversationParticipant(memberId: memberId, isAdmin: false),
        );
  }

  @override
  Future<void> removeParticipant(
    String conversationId,
    String memberId,
  ) async {
    removedParticipants
        .add((conversationId: conversationId, memberId: memberId));
    participants[conversationId] = [
      for (final p in participants[conversationId] ??
          const <ConversationParticipant>[])
        if (p.memberId == memberId)
          ConversationParticipant(
            memberId: p.memberId,
            isAdmin: p.isAdmin,
            leftAt: DateTime.utc(2026, 8, 27),
          )
        else
          p,
    ];
  }

  @override
  Future<void> leaveConversation(String conversationId) async =>
      leftConversations.add(conversationId);

  @override
  Future<void> setConversationMeta(
    String conversationId, {
    String? title,
    String? avatarPath,
  }) async =>
      metaWrites
          .add((id: conversationId, title: title, avatarPath: avatarPath));

  @override
  Future<void> sendConversationMessage(
    String conversationId,
    String body,
  ) async {
    // #3293 — as send_conversation_message: only a current participant
    // sends, and a direct message goes to the OTHER person.
    final me = myMember.id;
    final people = currentPeople(conversationId);
    if (people != null && !people.contains(me)) {
      throw const PostgrestException(
        message: 'not a participant of this conversation',
        code: '42501',
      );
    }
    sentMessages.add((conversationId: conversationId, body: body));
    // #702 — a conversation message IS a member note, as it is on the
    // server: `send_conversation_message` inserts into `member_notes`
    // with the conversation stamped on it. The fake used to write only
    // into its own thread map, so a caller that checked what was SENT
    // saw nothing — and the direct thread's recipient was lost, which
    // is the one field a 1:1 message is about.
    final direct = conversations
        .where((c) => c.id == conversationId && !c.isGroup)
        .firstOrNull;
    final note = MemberNote(
      id: 'msg-${sentMessages.length}',
      // #3293 — signed by whoever sends it, in their space.
      workspaceId: myMember.workspaceId,
      fromMemberId: me,
      toMemberId: direct == null
          ? null
          : people?.firstWhere((id) => id != me, orElse: () => me) ??
              direct.otherMemberId,
      body: body,
      createdAt: DateTime.utc(2026, 8, 27, 12, sentMessages.length),
      conversationId: conversationId,
    );
    memberNotes.add(note);
    conversationMessages.putIfAbsent(conversationId, () => []).add(note);
  }

  @override
  Future<List<MemberNote>> fetchConversationMessages(
    String conversationId, {
    int limit = 200,
    DateTime? before,
  }) async {
    // #3293 — only what the signed-in member may read.
    final all = [
      for (final n in conversationMessages[conversationId] ?? const <MemberNote>[])
        if (mayReadNote(n)) n,
    ];
    final older = before == null
        ? all
        : [for (final n in all) if (n.createdAt.isBefore(before)) n];
    // The newest [limit], oldest first — like the paged query.
    return older.length <= limit
        ? List.of(older)
        : older.sublist(older.length - limit);
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    readConversations.add(conversationId);
    // Mirrors mark_conversation_read (0126): messages addressed TO me
    // get their receipt, and only once — re-opening must not move a
    // stamp that already exists, or the sender watches the read time
    // drift every time the reader glances at the thread.
    for (var i = 0; i < memberNotes.length; i++) {
      final n = memberNotes[i];
      if (n.toMemberId == myMember.id && n.readAt == null) {
        memberNotes[i] = MemberNote(
          id: n.id,
          workspaceId: n.workspaceId,
          fromMemberId: n.fromMemberId,
          toMemberId: n.toMemberId,
          body: n.body,
          createdAt: n.createdAt,
          readAt: DateTime.utc(2026, 5, 12, 10),
          conversationId: n.conversationId,
        );
      }
    }
  }

  @override
  Future<List<MemberNote>> searchMessages(
    String workspaceId,
    String query,
  ) async {
    // Blank is nothing, not everything — the same call the real one
    // makes, and the one a test for "empty box shows nothing" needs.
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];
    return [
      for (final list in conversationMessages.values)
        for (final note in list)
          if (note.body.toLowerCase().contains(trimmed)) note,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> sendMemberNote(
    String workspaceId, {
    required String? toMemberId,
    required String body,
  }) async {
    memberNotes.add(MemberNote(
      id: 'note-${memberNotes.length + 1}',
      workspaceId: workspaceId,
      fromMemberId: myMember.id, // #3293
      toMemberId: toMemberId,
      body: body,
      createdAt: DateTime.utc(2026, 8, 4, 12, memberNotes.length),
    ));
  }

  /// #3293 — the notes the signed-in member may read, as
  /// can_read_member_note answers: what they sent or were sent, the admin
  /// broadcast for an administrator or owner, and a conversation's
  /// messages for its participants (a conversation whose roster the fake
  /// was never given stays readable, as the suite's tests seed them).
  @override
  Future<List<MemberNote>> fetchMyNotes(String workspaceId) async => [
        for (final n in memberNotes.reversed)
          if (mayReadNote(n)) n,
      ];

  @override
  Future<void> deleteMemberNote(String noteId) async {
    deletedNotes.add(noteId);
    memberNotes.removeWhere((n) => n.id == noteId);
    // A deleted note leaves its THREAD too — the server deletes the row,
    // and a fake that kept it there would let the thread show a message
    // the database no longer has.
    for (final thread in conversationMessages.values) {
      thread.removeWhere((n) => n.id == noteId);
    }
  }

  /// Whether the WhatsApp mirror channel is configured (0106 probe) —
  /// defaults true so the settings switch shows no warning in tests
  /// that don't care.
  /// Read receipts (0105): notes addressed to me ([myMember], the
  /// fake's signed-in member) get their read stamp.
  @override
  Future<void> markMyNotesRead(String workspaceId,
      {String? fromMemberId}) async {
    for (var i = 0; i < memberNotes.length; i++) {
      final n = memberNotes[i];
      if (n.toMemberId == myMember.id &&
          n.readAt == null &&
          (fromMemberId == null || n.fromMemberId == fromMemberId)) {
        memberNotes[i] = MemberNote(
          id: n.id,
          workspaceId: n.workspaceId,
          fromMemberId: n.fromMemberId,
          toMemberId: n.toMemberId,
          body: n.body,
          createdAt: n.createdAt,
          readAt: DateTime.utc(2026, 8, 9, 12),
        );
      }
    }
  }
}
