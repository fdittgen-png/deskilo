// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_repository.dart';

// #2386 — part 3 of FakeWorkspaceRepository, split out of workspace_repository.dart so no
// file holds the whole class.
extension _FakeWorkspaceRepositoryPart3 on FakeWorkspaceRepository {

  Future<void> _clearWorkspaceEmblemImpl(String workspaceId) async {
    emblems.remove(workspaceId);
  }

  Future<Map<String, dynamic>> _setWorkspaceBrandingImpl(
    String workspaceId,
    Map<String, dynamic> delta,
  ) async {
    // The server merges into the row, so the fake starts from what the
    // workspace carries — not from an empty map, which would make a
    // reset of one key look like a reset of all of them.
    final stored = workspaces.where((w) => w.id == workspaceId).firstOrNull;
    final current = Map<String, dynamic>.from(
        brandings[workspaceId] ?? stored?.branding ?? const {});
    for (final e in delta.entries) {
      if (e.value == null) {
        current.remove(e.key);
      } else {
        current[e.key] = e.value;
      }
    }
    final mine = WorkspaceSymbol.of(current);
    if (mine != null &&
        symbolClashes(mine, [
          for (final w in workspaces)
            if (w.id != workspaceId) brandings[w.id] ?? w.branding,
        ])) {
      throw const WorkspaceSymbolTaken();
    }
    brandings[workspaceId] = current;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(branding: current);
    return current;
  }

  Future<Map<String, dynamic>> _fetchLexiconImpl(String workspaceId) async =>
      {for (final e in (lexicons[workspaceId] ?? {}).entries) e.key: e.value};

  Future<void> _setLexiconTermImpl(
    String workspaceId,
    String locale,
    String key,
    String? text,
  ) async {
    final byLocale = lexicons.putIfAbsent(workspaceId, () => {});
    final terms = byLocale.putIfAbsent(locale, () => {});
    if (text == null) {
      terms.remove(key);
    } else {
      terms[key] = text;
    }
  }

  Future<BookingPolicies> _fetchBookingPoliciesImpl(String workspaceId) async =>
      bookingPolicies[workspaceId] ?? const BookingPolicies();

  Future<void> _setBookingPolicyImpl(
    String workspaceId,
    String key, {
    required bool enabled,
  }) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = switch (key) {
      BookingPolicies.allowPastBookingsKey =>
        p.copyWith(allowPastBookings: enabled),
      // #634: grid_within_hours is read-only legacy — no writer.
      BookingPolicies.adminCheckOutKey => p.copyWith(adminCheckOut: enabled),
      _ => p,
    };
  }

  Future<void> _setSimultaneousReservationsImpl(
    String workspaceId,
    int value,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] =
        p.copyWith(simultaneousReservations: value);
  }

  Future<void> _setBookingLimitImpl(
    String workspaceId,
    String key,
    int value,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = switch (key) {
      BookingPolicies.advanceHorizonDaysKey =>
        p.copyWith(advanceHorizonDays: value),
      BookingPolicies.minDurationMinutesKey =>
        p.copyWith(minDurationMinutes: value),
      BookingPolicies.maxDurationMinutesKey =>
        p.copyWith(maxDurationMinutes: value),
      _ => p,
    };
  }

  Future<void> _setLegendProfileImpl(
    String workspaceId,
    LegendProfile profile,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = p.copyWith(legendProfile: profile);
  }

  Future<void> _setOutsideHoursModeImpl(
    String workspaceId,
    OutsideHoursMode mode,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = p.copyWith(outsideHoursMode: mode);
  }

  Future<List<Conversation>> _fetchConversationsImpl(
    String workspaceId, {
    bool includeArchived = false,
  }) async =>
      [
        for (final c in conversations)
          if (includeArchived || !c.isArchived) c,
      ]..sort((a, b) {
          // Pinned first, then newest — my_conversations v3 (0146).
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          return b.lastAt.compareTo(a.lastAt);
        });

  Future<void> _setConversationPrefsImpl(
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

  Future<void> _markConversationUnreadImpl(String conversationId) async {
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

  Future<String> _openDirectConversationImpl(
    String workspaceId, {
    required String otherMemberId,
  }) async {
    // Idempotent like the RPC: the same pair must not yield two threads.
    final existing = conversations
        .where((c) => !c.isGroup && c.otherMemberId == otherMemberId)
        .firstOrNull;
    if (existing != null) return existing.id;
    final created = Conversation(
      id: 'conv-direct-$otherMemberId',
      kind: ConversationKind.direct,
      otherMemberId: otherMemberId,
      lastAt: DateTime.utc(2026, 8, 27),
    );
    conversations.add(created);
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

  Future<String> _createGroupConversationImpl(
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
      const ConversationParticipant(memberId: 'member-1', isAdmin: true),
      for (final id in memberIds)
        ConversationParticipant(memberId: id, isAdmin: false),
    ];
    return nextGroupId;
  }

  Future<List<ConversationParticipant>> _fetchParticipantsImpl(
    String conversationId,
  ) async =>
      participants[conversationId] ?? const [];

  Future<void> _addParticipantImpl(String conversationId, String memberId) async {
    addedParticipants.add((conversationId: conversationId, memberId: memberId));
    participants.putIfAbsent(conversationId, () => []).add(
          ConversationParticipant(memberId: memberId, isAdmin: false),
        );
  }

  Future<void> _removeParticipantImpl(
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

  Future<void> _leaveConversationImpl(String conversationId) async =>
      leftConversations.add(conversationId);

  Future<void> _setConversationMetaImpl(
    String conversationId, {
    String? title,
    String? avatarPath,
  }) async =>
      metaWrites
          .add((id: conversationId, title: title, avatarPath: avatarPath));

  Future<void> _sendConversationMessageImpl(
    String conversationId,
    String body,
  ) async {
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
      workspaceId: 'workspace-1',
      fromMemberId: 'member-1',
      toMemberId: direct?.otherMemberId,
      body: body,
      createdAt: DateTime.utc(2026, 8, 27, 12, sentMessages.length),
    );
    memberNotes.add(note);
    conversationMessages.putIfAbsent(conversationId, () => []).add(note);
  }

  Future<List<MemberNote>> _fetchConversationMessagesImpl(
    String conversationId, {
    int limit = 200,
    DateTime? before,
  }) async {
    final all = conversationMessages[conversationId] ?? const <MemberNote>[];
    final older = before == null
        ? all
        : [for (final n in all) if (n.createdAt.isBefore(before)) n];
    // The newest [limit], oldest first — like the paged query.
    return older.length <= limit
        ? List.of(older)
        : older.sublist(older.length - limit);
  }

  Future<void> _markConversationReadImpl(String conversationId) async {
    readConversations.add(conversationId);
    // Mirrors mark_conversation_read (0126): messages addressed TO me
    // get their receipt, and only once — re-opening must not move a
    // stamp that already exists, or the sender watches the read time
    // drift every time the reader glances at the thread.
    for (var i = 0; i < memberNotes.length; i++) {
      final n = memberNotes[i];
      if (n.toMemberId == 'member-1' && n.readAt == null) {
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

  Future<List<MemberNote>> _searchMessagesImpl(
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

  Future<void> _sendMemberNoteImpl(
    String workspaceId, {
    required String? toMemberId,
    required String body,
  }) async {
    memberNotes.add(MemberNote(
      id: 'note-${memberNotes.length + 1}',
      workspaceId: workspaceId,
      fromMemberId: 'member-1',
      toMemberId: toMemberId,
      body: body,
      createdAt: DateTime.utc(2026, 8, 4, 12, memberNotes.length),
    ));
  }

  Future<List<MemberNote>> _fetchMyNotesImpl(String workspaceId) async =>
      memberNotes.reversed.toList();

  Future<void> _deleteMemberNoteImpl(String noteId) async {
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
  /// Read receipts (0105): notes addressed to me ('member-1', the
  /// fake's signed-in member) get their read stamp.
  Future<void> _markMyNotesReadImpl(String workspaceId,
      {String? fromMemberId}) async {
    for (var i = 0; i < memberNotes.length; i++) {
      final n = memberNotes[i];
      if (n.toMemberId == 'member-1' &&
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
