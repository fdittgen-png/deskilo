// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/time/clock.dart';
import '../../../core/trace/traced.dart';
import '../domain/conversation.dart';
import '../domain/member_note.dart';
import 'workspace_providers.dart';

part 'conversation_providers.g.dart';

/// The conversation list of the active workspace (#687), newest activity
/// first — the order the server already applied, never re-sorted here.
///
/// Derived from [currentWorkspace] like every other workspace-scoped
/// provider, so switching profiles recomputes it with no extra plumbing.
@riverpod
Future<List<Conversation>> conversations(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return traced(
    'messaging',
    'conversations',
    () => ref.watch(workspaceRepositoryProvider).fetchConversations(
          workspace.id,
        ),
  );
}

/// Total unread across every conversation — the badge on the Messages
/// destination.
///
/// Summed from the list rather than counted separately: two queries that
/// answer "how many unread" independently is how a badge ends up
/// disagreeing with the screen it points at.
@riverpod
int unreadMessages(Ref ref) {
  final list = ref.watch(conversationsProvider).value ?? const [];
  return list.fold(0, (sum, c) => sum + c.unread);
}

/// The messages of one conversation, oldest first.
@riverpod
Future<List<MemberNote>> conversationMessages(
  Ref ref,
  String conversationId,
) =>
    traced(
      'messaging',
      'conversation messages',
      () => ref
          .watch(workspaceRepositoryProvider)
          .fetchConversationMessages(conversationId),
    );

/// The roster of one conversation.
@riverpod
Future<List<ConversationParticipant>> conversationParticipants(
  Ref ref,
  String conversationId,
) =>
    traced(
      'messaging',
      'participants',
      () => ref
          .watch(workspaceRepositoryProvider)
          .fetchParticipants(conversationId),
    );

/// The direct conversation with one member, resolved by the server
/// (#702) — `direct_conversation` returns the existing thread or opens
/// one on first use.
///
/// A read that can WRITE, deliberately: "the conversation with Ana" has
/// to name a row before a thread can render, and a pair who have never
/// spoken has no row yet. The alternative is a screen that shows an
/// empty thread with no id and cannot send anything from it.
@riverpod
Future<String?> directConversationId(Ref ref, String memberId) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return null;
  return traced(
    'messaging',
    'direct conversation',
    () => ref.watch(workspaceRepositoryProvider).openDirectConversation(
          workspace.id,
          otherMemberId: memberId,
        ),
  );
}

/// Full-text search over messages I can see (#687).
///
/// Keyed by the query string, so Riverpod caches per term and typing
/// backwards re-uses what was already fetched.
@riverpod
Future<List<MemberNote>> messageSearch(Ref ref, String query) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return traced(
    'messaging',
    'message search',
    () => ref.watch(workspaceRepositoryProvider).searchMessages(
          workspace.id,
          query,
        ),
  );
}

/// Re-reads everything a sent or received message can change: the list
/// (order, preview, unread) and the open thread.
///
/// One function because they always move together — a refresh that
/// updated the thread and not the list is how a conversation shows a new
/// message inside and a stale preview outside.
void invalidateConversations(Ref ref, {String? conversationId}) {
  ref.invalidate(conversationsProvider);
  if (conversationId != null) {
    ref.invalidate(conversationMessagesProvider(conversationId));
  }
}

/// `now` for relative timestamps in the list, read once per build rather
/// than per row — twenty rows asking the clock separately can straddle a
/// minute boundary and render two different "now"s.
@riverpod
DateTime conversationNow(Ref ref) => ref.watch(clockProvider).now();
