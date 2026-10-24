// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/messaging_windows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/member_note_refs.dart';
import '../../domain/inbox_composition.dart';
import '../../domain/inbox_sources.dart';
import '../../domain/messenger.dart';
import '../../providers/inbox_marks.dart';
import '../../providers/messenger_providers.dart';
import '../directory_pages.dart';
import 'context_labels.dart';
import 'open_inbox_entry.dart';

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
  bool _unreadOnly = false;
  bool _archived = false;
  bool _searching = false;
  String _query = '';
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(ref.read(messagingWindowsProvider).inboxPoll, (_) {
      if (mounted) ref.invalidate(messengerInboxProvider);
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inbox = ref.watch(messengerInboxProvider);
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
                  label: Text(l10n.inboxFilterAll),
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
                        ? '${l10n.inboxFilterUnread} · $unread'
                        : (l10n.inboxFilterUnread),
                  ),
                  selected: _unreadOnly,
                  onSelected: (_) => setState(() {
                    _unreadOnly = true;
                    _archived = false;
                  }),
                ),
                FilterChip(
                  key: const ValueKey('unified-inbox-archived'),
                  label: Text(l10n.inboxFilterArchived),
                  selected: _archived,
                  onSelected: (_) => setState(() {
                    _archived = true;
                    _unreadOnly = false;
                  }),
                ),
                TextButton.icon(
                  key: const ValueKey('unified-inbox-starred'),
                  icon: const Icon(Icons.star_outline, size: 18),
                  label: Text(l10n.messengerStarred),
                  onPressed: () =>
                      starredMessagesPage.open<void>(context, null),
                ),
                IconButton(
                  key: const ValueKey('unified-inbox-search'),
                  tooltip: l10n.messageSearchTitle,
                  icon: Icon(_searching ? Icons.search_off : Icons.search),
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) _query = '';
                  }),
                ),
                TextButton.icon(
                  key: const ValueKey('unified-inbox-new-group'),
                  onPressed: () => createGroupPage.open<void>(context, null),
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: Text(l10n.groupNew),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('unified-inbox-people'),
                  onPressed: () => context.push('/account-messages'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    l10n.newConversationTitle,
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
                  hintText: l10n.messageSearchTitle,
                ),
              ),
            ),
          Expanded(
            child: switch (inbox) {
              // #2556 — nothing read yet from any source: still loading,
              // never an empty inbox.
              AsyncData(value: ComposedInbox(:final entries, :final reading))
                  when entries.isEmpty && reading =>
                const LoadingView(),
              AsyncData(value: final value) => _list(
                context,
                value,
                servers,
                l10n,
              ),
              AsyncError() => Center(
                child: TextButton(
                  key: const ValueKey('unified-inbox-retry'),
                  onPressed: () => ref.invalidate(messengerInboxProvider),
                  child: Text(l10n.commonRetry),
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
    AppLocalizations l10n,
  ) {
    final format = ref.watch(appFormatProvider);
    final words = l10n;
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
      onRefresh: () async => ref.invalidate(messengerInboxProvider),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
        key: const ValueKey('unified-inbox-list'),
        padding: AppSpacing.gutterAll,
        children: [
          ..._sourceStates(inbox, l10n),
          if (shown.isEmpty)
            Padding(
              padding: AppSpacing.lgAll,
              child: Text(
                _unreadOnly
                    ? (l10n.inboxNoUnread)
                    : _archived
                        ? (l10n.inboxNoArchived)
                        : (l10n.messagesEmpty),
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
          ..._showOlder(inbox, l10n),
        ],
      ),
        ),
      ),
    );
  }

  /// #2556 — the next page of every source that has more.
  List<Widget> _showOlder(UnifiedInbox inbox, AppLocalizations l10n) => [
        if (inbox case ComposedInbox(hasMore: true, :final loadingMore))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Center(
              child: TextButton(
                key: const ValueKey('inbox-show-older'),
                onPressed: loadingMore
                    ? null
                    : () => ref.read(messengerInboxProvider.notifier).more(),
                child: Text(l10n.inboxShowOlder),
              ),
            ),
          ),
      ];

  /// #2556 — one line per source that did not answer, by the name the
  /// person knows it by: failed (Try again reads it alone again) or
  /// unavailable with this sign-in. A source that answered says nothing.
  List<Widget> _sourceStates(UnifiedInbox inbox, AppLocalizations l10n) {
    String nameOf(InboxSlot slot) => slot.label.isNotEmpty
        ? slot.label
        : slot.role == InboxSourceRole.personalHome
            ? l10n.inboxSourcePersonal
            : l10n.inboxSourceWorkspaces;
    final failed = <String, List<InboxSlot>>{};
    final unavailable = <String, List<InboxSlot>>{};
    final sources = inbox is ComposedInbox ? inbox.sources : const <InboxSlot>[];
    for (final slot in sources) {
      final into = switch (slot.state) {
        InboxSlotState.failed => failed,
        InboxSlotState.unavailable => unavailable,
        _ => null,
      };
      (into?[nameOf(slot)] ??= [])?.add(slot);
    }
    void retry(List<InboxSlot> slots) {
      final notifier = ref.read(messengerInboxProvider.notifier);
      for (final slot in slots) {
        notifier.retry(slot.key);
      }
    }
    return [
      // A plain merge (no sources) names the servers that did not answer.
      if (inbox.unavailable.isNotEmpty)
        ListTile(
          key: const ValueKey('unified-inbox-unavailable'),
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(
            l10n.messengerInboxUnavailable(inbox.unavailable.join(', ')),
          ),
          onTap: () => ref.invalidate(messengerInboxProvider),
        ),
      for (final MapEntry(key: name, value: slots) in failed.entries)
        ListTile(
          key: ValueKey('inbox-source-failed-$name'),
          leading: const Icon(Icons.error_outline),
          title: Text(l10n.inboxSourceFailed(name)),
          trailing: TextButton(
            key: ValueKey('inbox-source-retry-$name'),
            onPressed: () => retry(slots),
            child: Text(l10n.commonRetry),
          ),
        ),
      for (final MapEntry(key: name, value: slots) in unavailable.entries)
        ListTile(
          key: ValueKey('inbox-source-unavailable-$name'),
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(l10n.inboxSourceUnavailable(name)),
          onTap: () => retry(slots),
        ),
    ];
  }

  /// Long-press: pin and archive (kept on this device).
  Future<void> _marksMenu(BuildContext context, InboxEntry entry) async {
    final l10n = context.l10n;
    final marks = ref.read(inboxMarksProvider);
    final flags = entry.flags;
    final pinned = flags?.pinned ?? marks.pinned.contains(entry.key);
    final archived = flags?.archived ?? marks.archived.contains(entry.key);
    final choice = await showAppSheet<String>(
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
                  ? (l10n.conversationUnpin)
                  : (l10n.conversationPin)),
              onTap: () => Navigator.of(sheet).pop('pin'),
            ),
            if (flags != null) ...[
              ListTile(
                key: const ValueKey('inbox-menu-mute'),
                leading: Icon(flags.muted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined),
                title: Text(flags.muted
                    ? (l10n.conversationUnmute)
                    : (l10n.conversationMute)),
                onTap: () => Navigator.of(sheet).pop('mute'),
              ),
              if (entry.unread == 0)
                ListTile(
                  key: const ValueKey('inbox-menu-unread'),
                  leading: const Icon(Icons.mark_chat_unread_outlined),
                  title: Text(l10n.conversationMarkUnread),
                  onTap: () => Navigator.of(sheet).pop('unread'),
                ),
            ],
            ListTile(
              key: const ValueKey('inbox-menu-archive'),
              leading: const Icon(Icons.archive_outlined),
              title: Text(archived
                  ? (l10n.conversationUnarchive)
                  : (l10n.conversationArchive)),
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
      ref.invalidate(messengerInboxProvider);
      return;
    }
    if (choice == 'pin') ref.read(inboxMarksProvider.notifier).togglePin(entry.key);
    if (choice == 'archive') {
      ref.read(inboxMarksProvider.notifier).toggleArchive(entry.key);
    }
  }
}
