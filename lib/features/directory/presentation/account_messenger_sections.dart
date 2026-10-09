// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/directory_providers.dart';

/// #1824 — the account messenger's two lists, ONE SERVER each, so every
/// server pages on its own: a long list on one never hides the other.
/// A row names its server only when it is not this one.

/// People found on one server.
class ContactResults extends ConsumerStatefulWidget {
  const ContactResults({
    super.key,
    required this.source,
    required this.host,
    required this.query,
    required this.onOpen,
  });
  final String source, host, query;
  final void Function(String id, String name) onOpen;
  @override
  ConsumerState<ContactResults> createState() => _ContactResultsState();
}

class _ContactResultsState extends ConsumerState<ContactResults> {
  final _pages = <String>[];

  Widget _person(BuildContext context, Map<String, dynamic> person) {
    final l = AppLocalizations.of(context);
    final id = '${person['id']}';
    final name = '${person['name'] ?? ''}';
    return ListTile(
      key: ValueKey('account-messenger-person-$id'),
      title: Text(name),
      subtitle: widget.host.isEmpty
          ? null
          : Text(l?.messengerOnServer(widget.host) ?? 'on ${widget.host}'),
      trailing: const Icon(Icons.chat_outlined),
      onTap: () => widget.onOpen(id, name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = accountContactsProvider(
      widget.query,
      source: widget.source,
      before: _pages.lastOrNull,
    );
    return switch (ref.watch(provider)) {
      AsyncData(value: final people) => Column(
        children: [
          for (final person in people) _person(context, person),
          if (people.length == 50)
            TextButton(
              key: const ValueKey('account-messenger-sections-text-button'),
              onPressed: () =>
                  setState(() => _pages.add(people.last['id'] as String)),
              child: Text(MaterialLocalizations.of(context).nextPageTooltip),
            ),
          if (_pages.isNotEmpty)
            TextButton(
              key: const ValueKey('account-messenger-sections-text-button-2'),
              onPressed: () => setState(_pages.removeLast),
              child: Text(
                MaterialLocalizations.of(context).previousPageTooltip,
              ),
            ),
        ],
      ),
      AsyncError() => TextButton(
        key: const ValueKey('account-messenger-sections-portal-source-unavailable'),
        onPressed: () => ref.invalidate(provider),
        child: Text(
          l?.portalSourceUnavailable ?? 'A server is unavailable. This overview is incomplete. Tap to retry.',
        ),
      ),
      _ => const LoadingView(),
    };
  }
}

/// My account conversations on one server, with their unread counts.
class AccountConversationList extends ConsumerStatefulWidget {
  const AccountConversationList({
    super.key,
    required this.source,
    required this.host,
    required this.onOpen,
  });
  final String source, host;
  final void Function(String recipient, String name, String conversation)
  onOpen;
  @override
  ConsumerState<AccountConversationList> createState() =>
      _AccountConversationListState();
}

class _AccountConversationListState
    extends ConsumerState<AccountConversationList> {
  final _pages = <({DateTime at, String id})>[];

  /// One conversation: its unread count, and its server when not this one.
  Widget _row(BuildContext context, Map<String, dynamic> conversation) {
    final l = AppLocalizations.of(context);
    final id = '${conversation['id']}';
    final name = '${conversation['name'] ?? ''}';
    final recipient = conversation['recipient'] as String?;
    final unread = (conversation['unread'] as num?)?.toInt() ?? 0;
    return ListTile(
      key: ValueKey('account-conversation-$id'),
      title: Text(name),
      subtitle: widget.host.isEmpty
          ? null
          : Text(l?.messengerOnServer(widget.host) ?? 'on ${widget.host}'),
      trailing: unread > 0
          ? Badge.count(
              key: ValueKey('account-conversation-unread-$id'),
              count: unread,
            )
          : null,
      onTap: recipient == null
          ? null
          : () => widget.onOpen(recipient, name, id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cursor = _pages.lastOrNull;
    final provider = accountConversationsProvider(
      source: widget.source,
      beforeAt: cursor?.at,
      beforeId: cursor?.id,
    );
    return switch (ref.watch(provider)) {
      AsyncData(value: final conversations) => Column(
        children: [
          for (final conversation in conversations) _row(context, conversation),
          if (_pages.isNotEmpty || conversations.length >= 50)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  key: const ValueKey('account-messenger-sections-chevron-left'),
                  tooltip: MaterialLocalizations.of(context)
                      .previousPageTooltip,
                  onPressed: _pages.isEmpty
                      ? null
                      : () => setState(_pages.removeLast),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  key: const ValueKey('account-messenger-sections-chevron-right'),
                  tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                  onPressed: conversations.length < 50
                      ? null
                      : () => setState(
                          () => _pages.add((
                            at: DateTime.parse(
                              conversations.last['updated_at'] as String,
                            ),
                            id: conversations.last['id'] as String,
                          )),
                        ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
      AsyncError() => TextButton(
        key: const ValueKey('account-messenger-sections-portal-source-unavailable-2'),
        onPressed: () => ref.invalidate(provider),
        child: Text(
          l?.portalSourceUnavailable ?? 'A server is unavailable. This overview is incomplete. Tap to retry.',
        ),
      ),
      _ => const LoadingView(),
    };
  }
}
