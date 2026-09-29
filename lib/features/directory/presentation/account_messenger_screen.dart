// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/directory_providers.dart';
import 'account_thread.dart';
import 'account_messenger_sections.dart';

/// Person-to-person messages, on this server and every connected one.
///
/// #1824 — no server picker: a person should not need to know where
/// someone is hosted. Every server answers the search and the
/// conversation list at once; a row names its server only when it is
/// not this one, and carries its unread count.
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
  String _query = '';
  String? _account;
  final _search = TextEditingController();
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
      _query = '';
      _search.clear();
    }
    if (widget.recipient != null) {
      return AccountThread(
        key: ValueKey((account, widget.source, widget.recipient)),
        source: widget.source,
        recipient: widget.recipient!,
        name: widget.name,
        account: account,
      );
    }
    final sources = ref.watch(connectedSourcesProvider).value ?? [];
    final servers = <String, String>{
      '': '',
      for (final s in sources) s.endpoint.url: s.endpoint.host,
    };
    void open(
      String source,
      String recipient,
      String name, {
      String? conversation,
    }) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountThread(
          key: ValueKey((account, source, recipient)),
          source: source,
          recipient: recipient,
          name: name,
          account: account,
          conversation: conversation,
        ),
      ),
    );
    void submit(String value) => setState(() => _query = value.trim());
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
          for (final server in servers.entries)
            _AvailabilitySwitch(source: server.key, host: server.value),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: l?.portalFindPeople ?? 'Find available people',
              suffixIcon: IconButton(
                tooltip: l?.portalFindPeople ?? 'Find available people',
                icon: const Icon(Icons.search),
                onPressed: () => submit(_search.text),
              ),
            ),
            onSubmitted: submit,
          ),
          if (_query.isNotEmpty)
            for (final server in servers.entries)
              ContactResults(
                key: ValueKey(('contacts', server.key, _query)),
                source: server.key,
                host: server.value,
                query: _query,
                onOpen: (id, name) => open(server.key, id, name),
              ),
          for (final server in servers.entries)
            AccountConversationList(
              key: ValueKey(('conversations', server.key)),
              source: server.key,
              host: server.value,
              onOpen: (recipient, name, conversation) => open(
                server.key,
                recipient,
                name,
                conversation: conversation,
              ),
            ),
        ],
      ),
    );
  }
}

/// "Let users find and message my account", per server: the setting
/// lives on each server, so each one is its own switch — named by its
/// server when it is not this one.
class _AvailabilitySwitch extends ConsumerWidget {
  const _AvailabilitySwitch({required this.source, required this.host});
  final String source, host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final available = ref.watch(contactAvailabilityProvider(source: source));
    return SwitchListTile(
      key: ValueKey('availability-$source'),
      value: available.value ?? false,
      title: Text(l?.portalAvailable ?? 'Let users find and message my account'),
      subtitle: host.isEmpty
          ? null
          : Text(l?.messengerOnServer(host) ?? 'on $host'),
      onChanged: available.hasValue
          ? (value) async {
              final ok = await runGuarded(
                context,
                domain: 'messages',
                message: 'save account availability failed',
                errorText:
                    l?.portalActionFailed ??
                    'Could not save this change. Please try again.',
                action: () => ref
                    .read(accountContactActionsProvider(source: source))
                    .setAvailability(value),
              );
              if (ok && context.mounted) {
                ref.invalidate(contactAvailabilityProvider(source: source));
              }
            }
          : null,
    );
  }
}
