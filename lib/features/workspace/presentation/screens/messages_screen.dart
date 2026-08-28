// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../providers/conversation_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/conversation_row.dart';
import 'message_search_screen.dart';
import '../widgets/conversation_thread.dart';
import '../widgets/new_conversation_sheet.dart';

/// THE MESSAGING CENTRE (#687) — every conversation in one list, people
/// and groups together, newest activity first.
///
/// Ordered by the SERVER and never re-sorted here. `my_conversations`
/// already returns them by `last_message_at desc`, and a second opinion
/// in Dart is how a list ends up disagreeing with the unread badge that
/// was computed from the same query.
///
/// People and groups interleave rather than sitting in sections: the
/// owner asked for WhatsApp's list, and the reason it works is that the
/// thing you wrote in five minutes ago is at the top whatever kind it
/// is. Sectioning buries it.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final conversations = ref.watch(conversationsProvider);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    // Once per build, not per row.
    final now = ref.watch(conversationNowProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.messagesTitle ?? 'Messages'),
        actions: [
          IconButton(
            key: const ValueKey('messages-search'),
            tooltip: l10n?.messageSearchTitle ?? 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MessageSearchScreen(),
              ),
            ),
          ),
        ],
      ),
      // #687 — the way to START one. Without it the centre could only
      // show conversations that already existed, and its own empty state
      // had to send people to a different screen to make the first.
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('new-conversation'),
        tooltip: l10n?.newConversationTitle ?? 'New conversation',
        onPressed: () async {
          await showNewConversationSheet(context, ref);
          ref.invalidate(conversationsProvider);
        },
        child: const Icon(Icons.edit_outlined),
      ),
      body: switch (conversations) {
        AsyncData(value: final list) when list.isEmpty => _empty(context, l10n),
        AsyncData(value: final list) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView.separated(
              key: const ValueKey('conversation-list'),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final conversation = list[index];
                return ConversationRow(
                  conversation: conversation,
                  myMemberId: myMemberId,
                  names: names,
                  now: now,
                  onTap: () => _open(context, ref, conversation.id),
                );
              },
            ),
          ),
        // The generic line, like every other screen: a raw provider
        // error is a stack trace shown to a member who can do nothing
        // with it, and it can carry the workspace's own data.
        AsyncError() => Center(
            child: Padding(
              padding: AppSpacing.lgAll,
              child: Text(
                l10n?.workspaceGenericError ??
                    'Something went wrong. Please try again.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }

  Widget _empty(BuildContext context, AppLocalizations? l10n) => Center(
        child: Padding(
          padding: AppSpacing.lgAll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n?.messagesEmpty ?? 'No conversations yet.',
                key: const ValueKey('conversation-list-empty'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              // Says where to START one. An empty state that only reports
              // emptiness leaves someone looking for a button that is on
              // another screen.
              Text(
                // Points at the button on THIS screen, not another one.
                l10n?.messagesEmptyHint ??
                    'Tap the pencil to write to someone, or start a group.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );

  /// Opening marks it read server-side, then refreshes the list so the
  /// badge and the row weight settle without a manual pull.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    String conversationId,
  ) async {
    await showConversationThread(context, ref, conversationId: conversationId);
    ref.invalidate(conversationsProvider);
  }
}
