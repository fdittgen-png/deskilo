// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/directory_providers.dart';
import 'account_thread.dart';

class AccountMessengerScreen extends ConsumerStatefulWidget {
  const AccountMessengerScreen({
    super.key,
    this.source = '',
    this.recipient,
    this.name = '',
  });
  final String source, name;
  final String? recipient;
  @override
  ConsumerState<AccountMessengerScreen> createState() => _MessengerState();
}

class _MessengerState extends ConsumerState<AccountMessengerScreen> {
  late String _source = widget.source;
  String _query = '';
  String? _account;
  final _search = TextEditingController();
  final _pages = <({DateTime at, String id})>[];
  final _contactPages = <String>[];
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authStateProvider).value;
    final l = AppLocalizations.of(context);
    if (account == null) return const SizedBox.shrink();
    if (account != _account) {
      _account = account;
      _pages.clear();
      _contactPages.clear();
      _query = '';
      _search.clear();
    }
    if (widget.recipient != null) {
      return AccountThread(
        key: ValueKey((account, _source, widget.recipient)),
        source: _source,
        recipient: widget.recipient!,
        name: widget.name,
        account: account,
      );
    }
    final sources = ref.watch(connectedSourcesProvider).value ?? [];
    final cursor = _pages.lastOrNull;
    final provider = accountConversationsProvider(
      source: _source,
      beforeAt: cursor?.at,
      beforeId: cursor?.id,
    );
    final rows = ref.watch(provider);
    final contacts = _query.isEmpty
        ? null
        : ref.watch(
            accountContactsProvider(
              _query,
              source: _source,
              before: _contactPages.lastOrNull,
            ),
          );
    void open(String recipient, String name, {String? conversation}) =>
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AccountThread(
              key: ValueKey((account, _source, recipient)),
              source: _source,
              recipient: recipient,
              name: name,
              account: account,
              conversation: conversation,
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(l?.portalMessenger ?? 'Account messenger'),
        actions: [
          IconButton(
            tooltip: l?.portalConnections ?? 'Connected servers',
            onPressed: () => context.push('/connections'),
            icon: const Icon(Icons.dns_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.mdAll,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _source,
            isExpanded: true,
            items: [
              for (final entry in <String, String>{
                '': l?.portalThisServer ?? 'This server',
                for (final s in sources) s.endpoint.url: s.endpoint.host,
                if (_source.isNotEmpty) _source: _source,
              }.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _source = value;
                  _pages.clear();
                  _contactPages.clear();
                });
              }
            },
          ),
          // #1823 — who may find and write to me is chosen per audience
          // in Me › Who sees me, with a live preview; the single switch
          // that stood here is gone.
          ListTile(
            key: const ValueKey('portal-visibility-link'),
            leading: const Icon(Icons.visibility_outlined),
            title: Text(l?.portalVisibilityLink ?? 'Who can find and message me'),
            subtitle: Text(l?.portalVisibilityLinkBody ?? 'Chosen in Me, under Who sees me.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/me?tab=me'),
          ),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: l?.portalFindPeople ?? 'Find available people',
              suffixIcon: IconButton(
                tooltip: l?.portalFindPeople ?? 'Find available people',
                icon: const Icon(Icons.search),
                onPressed: () => setState(() {
                  _query = _search.text.trim();
                  _contactPages.clear();
                }),
              ),
            ),
            onSubmitted: (value) => setState(() {
              _query = value.trim();
              _contactPages.clear();
            }),
          ),
          if (contacts != null)
            switch (contacts) {
              AsyncData(value: final people) => Column(
                children: [
                  for (final person in people)
                    ListTile(
                      title: Text(person['name'] as String),
                      trailing: const Icon(Icons.chat_outlined),
                      onTap: () => open(
                        person['id'] as String,
                        person['name'] as String,
                      ),
                    ),
                  if (people.length == 50)
                    TextButton(
                      onPressed: () => setState(
                        () => _contactPages.add(people.last['id'] as String),
                      ),
                      child: Text(
                        MaterialLocalizations.of(context).nextPageTooltip,
                      ),
                    ),
                  if (_contactPages.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          setState(() => _contactPages.removeLast()),
                      child: Text(
                        MaterialLocalizations.of(context).previousPageTooltip,
                      ),
                    ),
                ],
              ),
              AsyncError() => Text(
                l?.portalSourceUnavailable ?? 'A server is unavailable. This overview is incomplete. Tap to retry.',
              ),
              _ => const LoadingView(),
            },
          switch (rows) {
            AsyncData(value: final conversations) => Column(
              children: [
                for (final conversation in conversations)
                  ListTile(
                    title: Text(conversation['name'] as String),
                    onTap: conversation['recipient'] == null
                        ? null
                        : () => open(
                            conversation['recipient'] as String,
                            conversation['name'] as String,
                            conversation: conversation['id'] as String,
                          ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .previousPageTooltip,
                      onPressed: _pages.isEmpty
                          ? null
                          : () => setState(() => _pages.removeLast()),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .nextPageTooltip,
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
              onPressed: () => ref.invalidate(provider),
              child: Text(
                l?.portalSourceUnavailable ?? 'A server is unavailable. This overview is incomplete. Tap to retry.',
              ),
            ),
            _ => const LoadingView(),
          },
        ],
      ),
    );
  }
}
