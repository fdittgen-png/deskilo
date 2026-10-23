// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/loading_view.dart';
import '../domain/messenger.dart';
import '../domain/public_workspace.dart';
import '../providers/directory_providers.dart';
import '../providers/messenger_providers.dart';
import 'messenger/open_inbox_entry.dart';

/// A new discussion starts from who I can write to: the people of each
/// workspace I share, on every server, then the groups I am in. [query]
/// narrows both from the first character; the server already applied
/// reachability, blocks and each space's directory switch, so nothing here
/// decides who may be written to.
class ReachableSection extends StatelessWidget {
  const ReachableSection({
    super.key,
    required this.servers,
    required this.query,
    required this.onOpen,
  });

  /// Server origin to its host label; '' is this server.
  final Map<String, String> servers;
  final String query;
  final void Function(String source, String id, String name) onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          context.l10n.portalReachableHeading,
          key: const ValueKey('reachable-heading'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      for (final server in servers.entries)
        _ReachableDirectory(
          key: ValueKey('reachable-${server.key}'),
          source: server.key,
          host: server.value,
          query: query,
          onOpen: (id, name) => onOpen(server.key, id, name),
        ),
      _ReachableGroups(query: query),
    ],
  );
}

/// The people one server lists, grouped by the workspace I share with them.
class _ReachableDirectory extends ConsumerWidget {
  const _ReachableDirectory({
    super.key,
    required this.source,
    required this.host,
    required this.query,
    required this.onOpen,
  });

  final String source, host, query;
  final void Function(String id, String name) onOpen;

  bool _matches(String text) =>
      query.isEmpty || text.toLowerCase().contains(query.toLowerCase());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return switch (ref.watch(reachablePeopleProvider(source: source))) {
      AsyncData(value: final rows) => _sections(context, rows),
      AsyncError() => TextButton(
        key: ValueKey('reachable-retry-$source'),
        onPressed: () =>
            ref.invalidate(reachablePeopleProvider(source: source)),
        child: Text(l.portalSourceUnavailable),
      ),
      _ => const LoadingView(),
    };
  }

  Widget _sections(BuildContext context, List<ReachablePerson> rows) {
    final l = context.l10n;
    final byWorkspace = <String, List<ReachablePerson>>{};
    for (final r in rows) {
      if (!_matches(r.name)) continue;
      byWorkspace.putIfAbsent(r.workspaceName, () => []).add(r);
    }
    if (byWorkspace.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          l.portalReachableEmpty,
          key: ValueKey('reachable-empty-$source'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in byWorkspace.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              host.isEmpty ? entry.key : '${entry.key} · $host',
              key: ValueKey('reachable-workspace-$source-${entry.key}'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final person in entry.value)
            ListTile(
              key: ValueKey(
                'reachable-person-$source-${person.workspaceId}-${person.id}',
              ),
              dense: true,
              title: Text(person.name),
              trailing: const Icon(Icons.chat_outlined),
              onTap: () => onOpen(person.id, person.name),
            ),
        ],
      ],
    );
  }
}

/// The groups I am in, as the unified inbox knows them, filtered by
/// [query]; tapping opens the group thread.
class _ReachableGroups extends ConsumerWidget {
  const _ReachableGroups({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final entries = ref.watch(unifiedInboxProvider).value?.entries ?? const [];
    final groups = [
      for (final e in entries)
        if (e.kind == MessageContextKind.accountGroup &&
            (query.isEmpty ||
                e.title.toLowerCase().contains(query.toLowerCase())))
          e,
    ];
    if (groups.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            l.portalGroupsHeading,
            key: const ValueKey('reachable-groups-heading'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final g in groups)
          ListTile(
            key: ValueKey('reachable-group-${g.contextId}'),
            dense: true,
            leading: const Icon(Icons.group_outlined),
            title: Text(g.title),
            onTap: () => openInboxEntry(context, ref, g),
          ),
      ],
    );
  }
}
