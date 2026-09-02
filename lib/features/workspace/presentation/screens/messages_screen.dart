// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/conversation.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/conversation_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/conversation_row.dart';
import 'message_search_screen.dart';
import '../widgets/conversation_thread.dart';
import '../widgets/new_conversation_sheet.dart';

/// #821 — what the chat list shows.
enum InboxFilter { all, unread, archived }

/// THE MESSAGING CENTRE (#687) — every conversation in one list, people
/// and groups together, newest activity first.
///
/// Ordered by the SERVER and never re-sorted here. `my_conversations`
/// already returns them by `last_message_at desc` (pinned first since
/// 0146), and a second opinion in Dart is how a list ends up disagreeing
/// with the unread badge that was computed from the same query.
///
/// #821 — with `messagesHub` on: ONE bar (All · Unread · Archived and
/// the search icon) instead of a second app bar, a long press on a row
/// for pin / mute / mark unread / archive, an empty state per filter and
/// a retry on the error state.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  InboxFilter _filter = InboxFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hub = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.messagesHub);
    final conversations = _filter == InboxFilter.archived && hub
        ? ref.watch(archivedConversationsProvider)
        : ref.watch(conversationsProvider);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    // Once per build, not per row.
    final now = ref.watch(conversationNowProvider);

    final body = switch (conversations) {
      AsyncData(value: final list) => () {
          final shown = hub && _filter == InboxFilter.unread
              ? [for (final c in list) if (c.hasUnread) c]
              : list;
          if (shown.isEmpty) return _empty(context, l10n, hub);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(conversationsProvider);
              ref.invalidate(archivedConversationsProvider);
            },
            child: ListView.separated(
              key: const ValueKey('conversation-list'),
              itemCount: shown.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final conversation = shown[index];
                return ConversationRow(
                  conversation: conversation,
                  myMemberId: myMemberId,
                  names: names,
                  now: now,
                  onTap: () => _open(context, ref, conversation.id),
                  onLongPress:
                      hub ? () => _menu(context, conversation) : null,
                );
              },
            ),
          );
        }(),
      // The generic line, like every other screen: a raw provider
      // error is a stack trace shown to a member who can do nothing
      // with it, and it can carry the workspace's own data.
      AsyncError() => Center(
          child: Padding(
            padding: AppSpacing.lgAll,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                l10n?.workspaceGenericError ??
                    'Something went wrong. Please try again.',
                textAlign: TextAlign.center,
              ),
              if (hub) ...[
                const SizedBox(height: AppSpacing.md),
                // #821 — an error state with a way out.
                OutlinedButton.icon(
                  key: const ValueKey('conversation-list-retry'),
                  onPressed: () {
                    ref.invalidate(conversationsProvider);
                    ref.invalidate(archivedConversationsProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n?.inboxRetry ?? 'Try again'),
                ),
              ],
            ]),
          ),
        ),
      _ => const LoadingView(),
    };

    return Scaffold(
      // No title here: the shell's app bar above already says
      // "Messages". With the hub on, no second bar at all — the filter
      // row carries the search icon.
      appBar: hub
          ? null
          : AppBar(
              toolbarHeight: 48,
              actions: [_searchButton(context, l10n)],
            ),
      // #687 — the way to START one.
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('new-conversation'),
        tooltip: l10n?.newConversationTitle ?? 'New conversation',
        onPressed: () => _compose(context, ref),
        child: const Icon(Icons.edit_outlined),
      ),
      body: Column(children: [
        const HelpHint(HelpHintId.messages),
        if (hub) _filterBar(context, l10n),
        Expanded(child: body),
      ]),
    );
  }

  Widget _searchButton(BuildContext context, AppLocalizations? l10n) =>
      IconButton(
        key: const ValueKey('messages-search'),
        tooltip: l10n?.messageSearchTitle ?? 'Search',
        icon: const Icon(Icons.search),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const MessageSearchScreen(),
          ),
        ),
      );

  /// #821 — ONE bar: the filter and the search, where the second app bar
  /// used to sit with a lone icon.
  Widget _filterBar(BuildContext context, AppLocalizations? l10n) {
    final unread = ref.watch(unreadMessagesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.xs, 0),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in InboxFilter.values) ...[
                FilterChip(
                  key: ValueKey('inbox-filter-${f.name}'),
                  label: Text(switch (f) {
                    InboxFilter.all => l10n?.inboxFilterAll ?? 'All',
                    InboxFilter.unread => unread > 0
                        ? '${l10n?.inboxFilterUnread ?? 'Unread'} · $unread'
                        : (l10n?.inboxFilterUnread ?? 'Unread'),
                    InboxFilter.archived =>
                      l10n?.inboxFilterArchived ?? 'Archived',
                  }),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ]),
          ),
        ),
        _searchButton(context, l10n),
      ]),
    );
  }

  /// An empty state that only reports emptiness leaves someone hunting
  /// for the button, so the empty centre IS the action (#696). With the
  /// hub on, Unread and Archived say their own thing.
  Widget _empty(BuildContext context, AppLocalizations? l10n, bool hub) {
    if (hub && _filter == InboxFilter.unread) {
      return Center(
        child: Padding(
          padding: AppSpacing.lgAll,
          child: Text(
            l10n?.inboxNoUnread ?? 'Nothing unread — you are up to date.',
            key: const ValueKey('conversation-list-no-unread'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (hub && _filter == InboxFilter.archived) {
      return Center(
        child: Padding(
          padding: AppSpacing.lgAll,
          child: Text(
            l10n?.inboxNoArchived ?? 'No archived conversations.',
            key: const ValueKey('conversation-list-no-archived'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SingleChildScrollView(
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              key: const ValueKey('conversation-list-empty-compose'),
              onPressed: () => _compose(context, ref),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n?.newConversationTitle ?? 'New conversation'),
            ),
          ],
        ),
      ),
    );
  }

  /// #821 — the row's menu: pin, mute, mark unread, archive — each one
  /// a server-side preference of MINE on the thread (0146).
  Future<void> _menu(BuildContext context, Conversation c) async {
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const ValueKey('conversation-menu-pin'),
            leading: Icon(c.isPinned
                ? Icons.push_pin_outlined
                : Icons.push_pin),
            title: Text(c.isPinned
                ? (l10n?.conversationUnpin ?? 'Unpin')
                : (l10n?.conversationPin ?? 'Pin to top')),
            onTap: () => Navigator.of(context).pop('pin'),
          ),
          ListTile(
            key: const ValueKey('conversation-menu-mute'),
            leading: Icon(c.muted
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined),
            title: Text(c.muted
                ? (l10n?.conversationUnmute ?? 'Unmute')
                : (l10n?.conversationMute ?? 'Mute notifications')),
            onTap: () => Navigator.of(context).pop('mute'),
          ),
          if (!c.hasUnread)
            ListTile(
              key: const ValueKey('conversation-menu-unread'),
              leading: const Icon(Icons.mark_chat_unread_outlined),
              title: Text(l10n?.conversationMarkUnread ?? 'Mark as unread'),
              onTap: () => Navigator.of(context).pop('unread'),
            ),
          ListTile(
            key: const ValueKey('conversation-menu-archive'),
            leading: Icon(
                c.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
            title: Text(c.isArchived
                ? (l10n?.conversationUnarchive ?? 'Restore from archive')
                : (l10n?.conversationArchive ?? 'Archive')),
            onTap: () => Navigator.of(context).pop('archive'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ]),
      ),
    );
    if (action == null || !context.mounted) return;
    final repo = ref.read(workspaceRepositoryProvider);
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'conversation prefs failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => switch (action) {
        'pin' => repo.setConversationPrefs(c.id, pinned: !c.isPinned),
        'mute' => repo.setConversationPrefs(c.id, muted: !c.muted),
        'archive' => repo.setConversationPrefs(c.id, archived: !c.isArchived),
        _ => repo.markConversationUnread(c.id),
      },
    );
    if (!ok || !context.mounted) return;
    ref.invalidate(conversationsProvider);
    ref.invalidate(archivedConversationsProvider);
    if (action == 'archive' && !c.isArchived) {
      AppSnack.success(
        context,
        l10n?.conversationArchived ?? 'Conversation archived.',
        replace: true,
      );
    }
  }

  /// The pencil's action, shared with the empty state's button so the two
  /// entry points can never drift apart.
  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    final id = await showNewConversationSheet(context, ref);
    ref.invalidate(conversationsProvider);
    // Straight into it. Starting a conversation and being left on the
    // list reads as failure, because a thread with nothing in it has
    // nothing to show on a row.
    if (id != null && context.mounted) {
      await _open(context, ref, id);
    }
  }

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
