// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/private_value.dart';
import '../../../workspace/domain/member_note_refs.dart';
import '../../domain/messenger.dart';
import '../../providers/blocks_providers.dart';
import '../directory_pages.dart';
import 'context_labels.dart';
import 'message_requests_card.dart';

/// The inbox's exclusive views: every conversation, the unread ones, the
/// archived ones.
enum InboxView { all, unread, archived }

/// The inbox list's header: the exclusive views, search, the labelled
/// count of message requests (when they live behind it rather than above
/// the list), the primary New conversation, and the secondary menu that
/// holds New group and Starred.
class InboxHeader extends ConsumerWidget {
  const InboxHeader({
    super.key,
    required this.view,
    required this.unread,
    required this.searching,
    required this.onView,
    required this.onSearch,
    this.requests = false,
  });

  final InboxView view;
  final int unread;
  final bool searching;
  final ValueChanged<InboxView> onView;
  final VoidCallback onSearch;

  /// Whether the message requests are reached from here.
  final bool requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final waiting = requests
        ? (ref.watch(messageRequestsProvider).value ?? const []).length
        : 0;
    FilterChip chip(InboxView of, String key, String label) => FilterChip(
      key: ValueKey(key),
      label: Text(label),
      selected: view == of,
      onSelected: (_) => onView(of),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          chip(InboxView.all, 'unified-inbox-all', l10n.inboxFilterAll),
          chip(
            InboxView.unread,
            'unified-inbox-unread',
            unread > 0
                ? '${l10n.inboxFilterUnread} · $unread'
                : l10n.inboxFilterUnread,
          ),
          chip(
            InboxView.archived,
            'unified-inbox-archived',
            l10n.inboxFilterArchived,
          ),
          IconButton(
            key: const ValueKey('unified-inbox-search'),
            tooltip: l10n.messageSearchTitle,
            icon: Icon(searching ? Icons.search_off : Icons.search),
            onPressed: onSearch,
          ),
          if (waiting > 0)
            ActionChip(
              key: const ValueKey('unified-inbox-requests'),
              avatar: const Icon(Icons.mark_email_unread_outlined, size: 18),
              label: Text(l10n.inboxRequestsCount(waiting)),
              onPressed: () => unawaited(_showRequests(context)),
            ),
          FilledButton.tonalIcon(
            key: const ValueKey('unified-inbox-people'),
            onPressed: () => context.push('/account-messages'),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.newConversationTitle),
          ),
          PopupMenuButton<VoidCallback>(
            key: const ValueKey('unified-inbox-more'),
            tooltip: l10n.inboxMoreActions,
            icon: const Icon(Icons.more_vert),
            onSelected: (open) => open(),
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const ValueKey('unified-inbox-new-group'),
                value: () => createGroupPage.open<void>(context, null),
                child: ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: Text(l10n.groupNew),
                ),
              ),
              PopupMenuItem(
                key: const ValueKey('unified-inbox-starred'),
                value: () => starredMessagesPage.open<void>(context, null),
                child: ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: Text(l10n.messengerStarred),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The waiting requests, with their Accept, Ignore and Block.
  Future<void> _showRequests(BuildContext context) => showAppSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const SafeArea(
      child: SingleChildScrollView(child: MessageRequestsCard()),
    ),
  );
}

/// The design size of an inbox row: rows are at least this tall and grow
/// with their text.
@visibleForTesting
abstract final class InboxListRowMetrics {
  static const double minHeight = 88;
}

/// One conversation of the inbox: who or what, where, the latest words,
/// when, unread, muted and pinned; a tap opens it, a long press its marks.
class InboxListRow extends ConsumerWidget {
  const InboxListRow({
    super.key,
    required this.entry,
    required this.servers,
    required this.pinned,
    required this.selected,
    required this.onOpen,
    required this.onMarks,
  });

  final InboxEntry entry;
  final Map<String, String> servers;
  final bool pinned, selected;
  final VoidCallback onOpen, onMarks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final format = ref.watch(appFormatProvider);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: InboxListRowMetrics.minHeight,
      ),
      child: ListTile(
        key: ValueKey('inbox-entry-${entry.contextId}'),
        selected: selected,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          child: Icon(contextIcon(entry.kind)),
        ),
        title: Text(
          entry.title,
          overflow: TextOverflow.ellipsis,
          style: entry.unread > 0
              ? theme.textTheme.bodyLarge?.emphasised
              : null,
        ),
        // The latest words are private: where the mask is offered they
        // stay hidden until revealed; the context is not.
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              contextSubtitle(l10n, entry, servers),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            PrivateValue(
              onlyWhereOffered: true,
              revealKey: ValueKey('inbox-preview-reveal-${entry.contextId}'),
              child: Text(
                notePreview(
                  entry.lastBody,
                  max: 120,
                  referenceFallback: l10n.uxLinkedReference,
                ),
                key: ValueKey('inbox-preview-${entry.contextId}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (entry.flags?.muted ?? false)
              Icon(
                Icons.notifications_off_outlined,
                key: ValueKey('inbox-muted-${entry.contextId}'),
                size: 14,
              ),
            if (pinned)
              Icon(
                Icons.push_pin_outlined,
                key: ValueKey('inbox-pinned-${entry.contextId}'),
                size: 14,
              ),
            Text(format.date(entry.lastAt), style: theme.textTheme.labelSmall),
            if (entry.unread > 0)
              Badge.count(
                key: ValueKey('inbox-unread-${entry.contextId}'),
                count: entry.unread,
              ),
          ],
        ),
        onTap: onOpen,
        onLongPress: onMarks,
      ),
    );
  }
}
