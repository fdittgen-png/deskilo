// SPDX-License-Identifier: AGPL-3.0-or-later
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
  // #1218 — the repository is watched BEFORE the gap: a bare
  // `ref.watch` on the far side of an await throws outright if the
  // provider was disposed while the future was in flight.
  final repository = ref.watch(workspaceRepositoryProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return traced(
    'messaging',
    'conversations',
    () => repository.fetchConversations(
          workspace.id,
        ),
  );
}

/// #821 — the archived threads, on demand (the Archived filter).
@riverpod
Future<List<Conversation>> archivedConversations(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  final all = await ref.watch(workspaceRepositoryProvider).fetchConversations(
        workspace.id,
        includeArchived: true,
      );
  return [for (final c in all) if (c.isArchived) c];
}

/// #821 — the composer's unsent text per conversation, kept for the
/// session so a thread closed mid-sentence reopens on that sentence.
@Riverpod(keepAlive: true)
class ConversationDrafts extends _$ConversationDrafts {
  @override
  Map<String, String> build() {
    // Bound to the workspace it was made in: a switch starts it over.
    resetOnWorkspaceSwitch(ref, () => state = const {});
    return const {};
  }

  String? of(String conversationId) => state[conversationId];

  void set(String conversationId, String text) {
    if (text.trim().isEmpty) {
      if (!state.containsKey(conversationId)) return;
      state = {...state}..remove(conversationId);
    } else {
      state = {...state, conversationId: text};
    }
  }
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

/// Full-text search over messages I can see (#687).
///
/// Keyed by the query string, so Riverpod caches per term and typing
/// backwards re-uses what was already fetched.
@riverpod
Future<List<MemberNote>> messageSearch(Ref ref, String query) async {
  // #1218 — the repository is watched BEFORE the gap: a bare
  // `ref.watch` on the far side of an await throws outright if the
  // provider was disposed while the future was in flight.
  final repository = ref.watch(workspaceRepositoryProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return traced(
    'messaging',
    'message search',
    () => repository.searchMessages(
          workspace.id,
          query,
        ),
  );
}

/// `now` for relative timestamps in the list, read once per build rather
/// than per row — twenty rows asking the clock separately can straddle a
/// minute boundary and render two different "now"s.
@riverpod
DateTime conversationNow(Ref ref) => ref.watch(clockProvider).now();
