// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/messenger.dart';
import '../../providers/messenger_providers.dart';
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
  static const _poll = Duration(seconds: 30);
  bool _unreadOnly = false;
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
                  onSelected: (_) => setState(() => _unreadOnly = false),
                ),
                FilterChip(
                  key: const ValueKey('unified-inbox-unread'),
                  label: Text(
                    unread > 0
                        ? '${l10n?.inboxFilterUnread ?? 'Unread'} · $unread'
                        : (l10n?.inboxFilterUnread ?? 'Unread'),
                  ),
                  selected: _unreadOnly,
                  onSelected: (_) => setState(() => _unreadOnly = true),
                ),
                TextButton.icon(
                  key: const ValueKey('unified-inbox-people'),
                  onPressed: () => context.push('/account-messages'),
                  icon: const Icon(Icons.person_search_outlined),
                  label: Text(
                    l10n?.portalFindPeople ?? 'Find available people',
                  ),
                ),
              ],
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
    final shown = _unreadOnly
        ? [
            for (final e in inbox.entries)
              if (e.unread > 0) e,
          ]
        : inbox.entries;
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
                '${contextSubtitle(l10n, entry, servers)}\n${entry.lastBody}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
}
