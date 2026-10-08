// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import '../../domain/messenger.dart';
import '../../providers/inbox_marks.dart';
import '../../providers/messenger_providers.dart';
import '../../../workspace/domain/member_note_refs.dart';
import 'context_labels.dart';
import 'create_group_screen.dart';
import 'open_inbox_entry.dart';
import 'starred_messages_screen.dart';

/// #1824 — Me › Messages: every conversation I take part in, on every
/// server I connected, in ONE list — each labelled with its context, the
/// server named only when it is not this one, unread counted per row.
///
/// A body, not a screen: the Me shell owns the app bar around it.
class UnifiedInboxView extends ConsumerStatefulWidget {
  const UnifiedInboxView({super.key});

  @override
  ConsumerState<UnifiedInboxView> createState() => _UnifiedInboxState();
}

class _UnifiedInboxState extends ConsumerState<UnifiedInboxView> {
  static const _poll = Duration(seconds: 30);
  bool _unreadOnly = false;
  bool _archived = false;
  bool _searching = false;
  String _query = '';
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(_poll, (_) {
      if (mounted) ref.invalidate(unifiedInboxProvider);
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inbox = ref.watch(unifiedInboxProvider);
    final servers = ref.watch(serverLabelsProvider).value ?? const {};
    final unread = inbox.value?.unread ?? 0;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        key: const ValueKey('unified-inbox'),
        children: [
          Padding(
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
                FilterChip(
                  key: const ValueKey('unified-inbox-all'),
                  label: Text(l10n?.inboxFilterAll ?? 'All'),
                  selected: !_unreadOnly,
                  onSelected: (_) => setState(() {
                    _unreadOnly = false;
                    _archived = false;
                  }),
                ),
                FilterChip(
                  key: const ValueKey('unified-inbox-unread'),
                  label: Text(
                    unread > 0
                        ? '${l10n?.inboxFilterUnread ?? 'Unread'} · $unread'
                        : (l10n?.inboxFilterUnread ?? 'Unread'),
                  ),
                  selected: _unreadOnly,
                  onSelected: (_) => setState(() {
                    _unreadOnly = true;
                    _archived = false;
                  }),
                ),
                FilterChip(
                  key: const ValueKey('unified-inbox-archived'),
                  label: Text(l10n?.inboxFilterArchived ?? 'Archived'),
                  selected: _archived,
                  onSelected: (_) => setState(() {
                    _archived = true;
                    _unreadOnly = false;
                  }),
                ),
                TextButton.icon(
                  key: const ValueKey('unified-inbox-starred'),
                  icon: const Icon(Icons.star_outline, size: 18),
                  label: Text(l10n?.messengerStarred ?? 'Starred'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StarredMessagesScreen(),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('unified-inbox-search'),
                  tooltip: l10n?.messageSearchTitle ?? 'Search',
                  icon: Icon(_searching ? Icons.search_off : Icons.search),
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) _query = '';
                  }),
                ),
                TextButton.icon(
                  key: const ValueKey('unified-inbox-new-group'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateGroupScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: Text(l10n?.groupNew ?? 'New group'),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('unified-inbox-people'),
                  onPressed: () => context.push('/account-messages'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    l10n?.newConversationTitle ?? 'New conversation',
                  ),
                ),
              ],
            ),
          ),
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: TextField(
                key: const ValueKey('unified-inbox-search-field'),
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n?.messageSearchTitle ?? 'Search',
                ),
              ),
            ),
          Expanded(
            child: switch (inbox) {
              AsyncData(value: final value) => _list(
                context,
                value,
                servers,
                l10n,
              ),
              AsyncError() => Center(
                child: TextButton(
                  key: const ValueKey('unified-inbox-retry'),
                  onPressed: () => ref.invalidate(unifiedInboxProvider),
                  child: Text(l10n?.commonRetry ?? 'Try again'),
                ),
              ),
              _ => const LoadingView(),
            },
          ),
        ],
      ),
    );
  }

  Widget _list(
    BuildContext context,
    UnifiedInbox inbox,
    Map<String, String> servers,
    AppLocalizations? l10n,
  ) {
    final format = ref.watch(appFormatProvider);
    final words = l10n ?? AppLocalizationsEn();
    final marks = ref.watch(inboxMarksProvider);
    // A workspace conversation's pin / archive are the server's (0386); every
    // other kind keeps this device's marks.
    bool pinnedOf(InboxEntry e) =>
        e.flags?.pinned ?? marks.pinned.contains(e.key);
    bool archivedOf(InboxEntry e) =>
        e.flags?.archived ?? marks.archived.contains(e.key);
    final needle = _query.trim().toLowerCase();
    bool matches(InboxEntry e) =>
        needle.isEmpty ||
        e.title.toLowerCase().contains(needle) ||
        e.lastBody.toLowerCase().contains(needle) ||
        e.workspaceName.toLowerCase().contains(needle);
    // Pinned first, then newest activity (the merge already sorts by it).
    final shown = [
      for (final e in inbox.entries)
        if (archivedOf(e) == _archived &&
            (!_unreadOnly || e.unread > 0) &&
            matches(e))
          e,
    ]..sort((a, b) {
        final pa = pinnedOf(a) ? 0 : 1;
        final pb = pinnedOf(b) ? 0 : 1;
        return pa.compareTo(pb);
      });
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(unifiedInboxProvider),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
        key: const ValueKey('unified-inbox-list'),
        padding: AppSpacing.gutterAll,
        children: [
          if (inbox.unavailable.isNotEmpty)
            ListTile(
              key: const ValueKey('unified-inbox-unavailable'),
              leading: const Icon(Icons.cloud_off_outlined),
              title: Text(
                l10n?.messengerInboxUnavailable(inbox.unavailable.join(', ')) ??
                    'Not reachable right now: ${inbox.unavailable.join(', ')}. '
                        'Their conversations are missing from this list.',
              ),
              onTap: () => ref.invalidate(unifiedInboxProvider),
            ),
          if (shown.isEmpty)
            Padding(
              padding: AppSpacing.lgAll,
              child: Text(
                _unreadOnly
                    ? (l10n?.inboxNoUnread ??
                          'Nothing unread — you are up to date.')
                    : _archived
                        ? (l10n?.inboxNoArchived ?? 'No archived conversation.')
                        : (l10n?.messagesEmpty ?? 'No conversations yet.'),
                key: const ValueKey('unified-inbox-empty'),
                textAlign: TextAlign.center,
              ),
            ),
          if (shown.isNotEmpty)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
          for (final (i, entry) in shown.indexed) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              key: ValueKey('inbox-entry-${entry.contextId}'),
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                child: Icon(contextIcon(entry.kind)),
              ),
              title: Text(
                entry.title,
                overflow: TextOverflow.ellipsis,
                style: entry.unread > 0
                    ? Theme.of(context).textTheme.bodyLarge?.emphasised
                    : null,
              ),
              subtitle: Text(
                '${contextSubtitle(l10n, entry, servers)}\n${notePreview(entry.lastBody, max: 120, referenceFallback: words.uxLinkedReference)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                  if (pinnedOf(entry))
                    Icon(
                      Icons.push_pin_outlined,
                      key: ValueKey('inbox-pinned-${entry.contextId}'),
                      size: 14,
                    ),
                  Text(
                    format.date(entry.lastAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (entry.unread > 0)
                    Badge.count(
                      key: ValueKey('inbox-unread-${entry.contextId}'),
                      count: entry.unread,
                    ),
                ],
              ),
              onTap: () => openInboxEntry(context, ref, entry),
              onLongPress: () => _marksMenu(context, entry),
            ),
          ],
                ],
              ),
            ),
        ],
      ),
        ),
      ),
    );
  }

  /// Long-press: pin and archive (kept on this device).
  Future<void> _marksMenu(BuildContext context, InboxEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final marks = ref.read(inboxMarksProvider);
    final flags = entry.flags;
    final pinned = flags?.pinned ?? marks.pinned.contains(entry.key);
    final archived = flags?.archived ?? marks.archived.contains(entry.key);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('inbox-menu-pin'),
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(pinned
                  ? (l10n?.conversationUnpin ?? 'Unpin')
                  : (l10n?.conversationPin ?? 'Pin')),
              onTap: () => Navigator.of(sheet).pop('pin'),
            ),
            if (flags != null) ...[
              ListTile(
                key: const ValueKey('inbox-menu-mute'),
                leading: Icon(flags.muted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined),
                title: Text(flags.muted
                    ? (l10n?.conversationUnmute ?? 'Unmute')
                    : (l10n?.conversationMute ?? 'Mute notifications')),
                onTap: () => Navigator.of(sheet).pop('mute'),
              ),
              if (entry.unread == 0)
                ListTile(
                  key: const ValueKey('inbox-menu-unread'),
                  leading: const Icon(Icons.mark_chat_unread_outlined),
                  title: Text(l10n?.conversationMarkUnread ?? 'Mark as unread'),
                  onTap: () => Navigator.of(sheet).pop('unread'),
                ),
            ],
            ListTile(
              key: const ValueKey('inbox-menu-archive'),
              leading: const Icon(Icons.archive_outlined),
              title: Text(archived
                  ? (l10n?.conversationUnarchive ?? 'Unarchive')
                  : (l10n?.conversationArchive ?? 'Archive')),
              onTap: () => Navigator.of(sheet).pop('archive'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (flags != null) {
      // The server's preference: set it there, then read the inbox again.
      final actions = ref.read(messengerActionsProvider(source: entry.source));
      final id = entry.contextId;
      if (!context.mounted) return;
      await runGuarded(
        context,
        domain: 'messages',
        message: 'conversation flags failed',
        action: () => switch (choice) {
          'pin' => actions.setConversationFlags(id, pinned: !pinned),
          'mute' => actions.setConversationFlags(id, muted: !flags.muted),
          'archive' => actions.setConversationFlags(id, archived: !archived),
          _ => actions.markConversationUnread(id),
        },
      );
      ref.invalidate(unifiedInboxProvider);
      return;
    }
    if (choice == 'pin') ref.read(inboxMarksProvider.notifier).togglePin(entry.key);
    if (choice == 'archive') {
      ref.read(inboxMarksProvider.notifier).toggleArchive(entry.key);
    }
  }
}
