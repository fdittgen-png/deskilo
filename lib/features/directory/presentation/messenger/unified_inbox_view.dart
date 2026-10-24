// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/messaging_windows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/inbox_composition.dart';
import '../../domain/inbox_sources.dart';
import '../../domain/messenger.dart';
import '../../providers/inbox_marks.dart';
import '../../providers/messenger_providers.dart';
import 'foreground_poll.dart';
import 'inbox_header.dart';
import 'open_inbox_entry.dart';

/// #1824 — Me › Messages: every conversation I take part in, on every
/// server I connected, in ONE list — each labelled with its context, the
/// server named only when it is not this one, unread counted per row.
///
/// A body, not a screen: the Me shell owns the app bar around it.
class UnifiedInboxView extends ConsumerStatefulWidget {
  const UnifiedInboxView({
    super.key,
    this.onOpen,
    this.selected,
    this.requestsInHeader = false,
  });

  /// Opens a row in the messenger's own pane; without it a row opens its
  /// thread as a page of its own.
  final ValueChanged<InboxEntry>? onOpen;

  /// The [InboxEntry.key] of the conversation the pane shows.
  final String? selected;

  /// The message requests are reached from the header's labelled count
  /// rather than a card above the list.
  final bool requestsInHeader;

  @override
  ConsumerState<UnifiedInboxView> createState() => _UnifiedInboxState();
}

class _UnifiedInboxState extends ConsumerState<UnifiedInboxView> {
  InboxView _view = InboxView.all;
  bool get _unreadOnly => _view == InboxView.unread;
  bool get _archived => _view == InboxView.archived;
  bool _searching = false;
  String _query = '';

  /// The inbox is read again only while it is on screen and the app in the
  /// foreground; shown again, one read catches up.
  late final ForegroundPoll _poll = ForegroundPoll(
    period: ref.read(messagingWindowsProvider).inboxPoll,
    onTick: _reread,
    onResume: _reread,
  );

  void _reread() {
    if (mounted) ref.invalidate(messengerInboxProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _poll.setShown(shown: TickerMode.valuesOf(context).enabled);
  }

  @override
  void dispose() {
    _poll.dispose();
    super.dispose();
  }

  void _open(BuildContext context, InboxEntry entry) {
    final open = widget.onOpen;
    if (open != null) {
      open(entry);
    } else {
      unawaited(openInboxEntry(context, ref, entry));
    }
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
          InboxHeader(
            view: _view,
            unread: unread,
            searching: _searching,
            requests: widget.requestsInHeader,
            onView: (view) => setState(() => _view = view),
            onSearch: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
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
    final before = _sourceStates(inbox, l10n);
    final after = _showOlder(inbox, l10n);
    final empty = shown.isEmpty ? 1 : 0;
    // Built as they scroll in: one row per conversation, nothing fetched
    // for a row that is not on screen.
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(messengerInboxProvider),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.builder(
            key: const ValueKey('unified-inbox-list'),
            padding: AppSpacing.gutterAll,
            itemCount: before.length + empty + shown.length + after.length,
            itemBuilder: (context, index) {
              if (index < before.length) return before[index];
              index -= before.length;
              if (index < empty) {
                return Padding(
                  padding: AppSpacing.lgAll,
                  child: Text(
                    _unreadOnly
                        ? l10n.inboxNoUnread
                        : _archived
                        ? l10n.inboxNoArchived
                        : l10n.messagesEmpty,
                    key: const ValueKey('unified-inbox-empty'),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              index -= empty;
              if (index >= shown.length) return after[index - shown.length];
              final entry = shown[index];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index > 0) const Divider(height: 1),
                  InboxListRow(
                    entry: entry,
                    servers: servers,
                    pinned: pinnedOf(entry),
                    selected: entry.key == widget.selected,
                    onOpen: () => _open(context, entry),
                    onMarks: () => _marksMenu(context, entry),
                  ),
                ],
              );
            },
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
