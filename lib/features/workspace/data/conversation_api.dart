// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/conversation.dart';
import '../domain/member_note.dart';

/// The conversation half of the workspace repository (#687).
///
/// A mixin rather than a second repository, because it is not a second
/// repository: these are workspace methods that happen to be about
/// messaging, and splitting them behind their own interface would make
/// every caller decide which of two objects to ask. It lives in its own
/// FILE because supabase_workspace_repository.dart was at its length
/// budget, and "everything about conversations" is a real boundary
/// rather than an arbitrary cut.
mixin ConversationApi {
  /// The client, provided by the class this is mixed into.
  ///
  /// A mixin cannot see a private field of its host, so the host exposes
  /// one getter rather than every method here taking a client parameter
  /// it would only pass straight through.
  SupabaseClient get conversationClient;

    Future<List<Conversation>> fetchConversations(String workspaceId) async {
    final rows = await conversationClient.rpc<dynamic>(
      'my_conversations',
      params: {'p_workspace_id': workspaceId},
    );
    return [
      for (final row in (rows as List? ?? const []))
        Conversation.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  }

    Future<String> openDirectConversation(
    String workspaceId, {
    required String otherMemberId,
  }) async =>
      (await conversationClient.rpc<dynamic>('direct_conversation', params: {
        'p_workspace_id': workspaceId,
        'p_other_member_id': otherMemberId,
      }))
          .toString();

    Future<String> createGroupConversation(
    String workspaceId, {
    required String title,
    required List<String> memberIds,
  }) async =>
      (await conversationClient.rpc<dynamic>('create_group_conversation', params: {
        'p_workspace_id': workspaceId,
        'p_title': title,
        'p_member_ids': memberIds,
      }))
          .toString();

    Future<List<ConversationParticipant>> fetchParticipants(
    String conversationId,
  ) async {
    final rows = await conversationClient
        .from('conversation_participants')
        .select()
        .eq('conversation_id', conversationId)
        .order('joined_at');
    return [
      for (final row in rows)
        ConversationParticipant.fromRow(Map<String, dynamic>.from(row)),
    ];
  }

    Future<void> addParticipant(String conversationId, String memberId) =>
      conversationClient.rpc<void>('add_conversation_participant', params: {
        'p_conversation_id': conversationId,
        'p_member_id': memberId,
      });

    Future<void> removeParticipant(String conversationId, String memberId) =>
      conversationClient.rpc<void>('remove_conversation_participant', params: {
        'p_conversation_id': conversationId,
        'p_member_id': memberId,
      });

    Future<void> leaveConversation(String conversationId) =>
      conversationClient.rpc<void>('leave_conversation', params: {
        'p_conversation_id': conversationId,
      });

    Future<void> setConversationMeta(
    String conversationId, {
    String? title,
    String? avatarPath,
  }) =>
      conversationClient.rpc<void>('set_conversation_meta', params: {
        'p_conversation_id': conversationId,
        'p_title': title,
        'p_avatar_path': avatarPath,
      });

    Future<void> sendConversationMessage(String conversationId, String body) =>
      conversationClient.rpc<void>('send_conversation_message', params: {
        'p_conversation_id': conversationId,
        'p_body': body,
      });

    Future<List<MemberNote>> fetchConversationMessages(
    String conversationId,
  ) async {
    final rows = await conversationClient
        .from('member_notes')
        .select()
        .eq('conversation_id', conversationId)
        // Oldest first: a thread reads downwards, and reversing it in
        // Dart on every rebuild is work the index already did.
        .order('created_at');
    return [
      for (final row in rows)
        MemberNote.fromRow(Map<String, dynamic>.from(row)),
    ];
  }

    Future<void> markConversationRead(String conversationId) =>
      conversationClient.rpc<void>('mark_conversation_read', params: {
        'p_conversation_id': conversationId,
      });

    Future<List<MemberNote>> searchMessages(
    String workspaceId,
    String query,
  ) async {
    final trimmed = query.trim();
    // A blank search is not "everything" — it is nothing yet. Returning
    // the whole history would make the results list flash the entire
    // workspace between keystrokes.
    if (trimmed.isEmpty) return const [];
    final rows = await conversationClient
        .from('member_notes')
        .select()
        .eq('workspace_id', workspaceId)
        // 'simple' matches the index built in 0125; a different config
        // here would silently fall back to a sequential scan.
        .textSearch('body', _prefixQuery(trimmed), config: 'simple')
        .order('created_at', ascending: false)
        .limit(100);
    return [
      for (final row in rows)
        MemberNote.fromRow(Map<String, dynamic>.from(row)),
    ];
  }

  /// Turns typed words into a prefix tsquery: `mee tom` -> `mee:* & tom:*`.
  ///
  /// Prefix matching is what makes search feel live — nobody finishes a
  /// word before expecting results. Punctuation is stripped rather than
  /// escaped because a stray `&` or `!` in a search box is a typo, not
  /// an operator someone meant.
  static String _prefixQuery(String input) => input
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((word) => word.isNotEmpty)
      .map((word) => '$word:*')
      .join(' & ');

  // ── the pre-#687 note methods ───────────────────────────────────────
  //
  // They live here because they are the SAME feature: a note is a
  // message, and `send_member_note` is still what an admin broadcast
  // uses. Leaving them behind would have split messaging across two
  // files by nothing more than the date they were written.

    Future<void> sendMemberNote(
    String workspaceId, {
    required String? toMemberId,
    required String body,
  }) async {
    await conversationClient.rpc<void>('send_member_note', params: {
      'p_workspace_id': workspaceId,
      'p_to_member_id': toMemberId,
      'p_body': body,
    });
  }


    Future<void> deleteMemberNote(String noteId) async {
    await conversationClient.from('member_notes').delete().eq('id', noteId);
  }


    Future<void> markMyNotesRead(String workspaceId,
      {String? fromMemberId}) async {
    await conversationClient.rpc<void>('mark_member_notes_read', params: {
      'p_workspace_id': workspaceId,
      'p_from_member_id': ?fromMemberId,
    });
  }


    Future<List<MemberNote>> fetchMyNotes(String workspaceId) async {
    final rows = await conversationClient
        .from('member_notes')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false)
        .limit(30);
    return rows.map(MemberNote.fromRow).toList();
  }
}
