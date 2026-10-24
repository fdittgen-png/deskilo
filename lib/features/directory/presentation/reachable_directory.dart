// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/loading_view.dart';
import '../domain/messenger.dart';
import '../domain/public_workspace.dart';
import '../domain/recipient_search.dart';
import '../providers/directory_providers.dart';
import '../providers/messenger_providers.dart';
import 'messenger/open_inbox_entry.dart';

/// A new discussion starts from who I can write to: the people of each
/// workspace I share, on every server, one collapsible section per
/// workspace with its count, then the groups I am in. A person in two
/// workspaces is listed under both. The server already applied
/// reachability, blocks and each space's directory switch, so nothing here
/// decides who may be written to; finding someone by name is the
/// typeahead's job (messenger/recipient_typeahead.dart).
class ReachableSection extends StatelessWidget {
  const ReachableSection({
    super.key,
    required this.servers,
    required this.onOpen,
    this.self,
  });

  /// Server origin to its host label; '' is this server.
  final Map<String, String> servers;

  /// My own account on this server, never listed.
  final String? self;
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
          self: server.key.isEmpty ? self : null,
          onOpen: (id, name) => onOpen(server.key, id, name),
        ),
      const _ReachableGroups(),
    ],
  );
}

/// A row's avatar: the initials of [name], or a group's icon.
class RecipientAvatar extends StatelessWidget {
  const RecipientAvatar({super.key, required this.name, this.group = false});
  final String name;
  final bool group;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CircleAvatar(
      radius: 18,
      child: group
          ? const Icon(Icons.group_outlined, size: 20)
          : Text(initialsOf(name)),
    ),
  );
}

/// The people one server lists, grouped by the workspace I share with them.
class _ReachableDirectory extends ConsumerWidget {
  const _ReachableDirectory({
    super.key,
    required this.source,
    required this.host,
    required this.self,
    required this.onOpen,
  });

  final String source, host;
  final String? self;
  final void Function(String id, String name) onOpen;

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
      if (r.id == self) continue;
      byWorkspace.putIfAbsent(r.workspaceId, () => []).add(r);
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
      children: [
        for (final entry in byWorkspace.entries)
          _section(context, entry.key, entry.value),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String workspaceId,
    List<ReachablePerson> people,
  ) {
    final name = people.first.workspaceName;
    return ExpansionTile(
      key: ValueKey('reachable-workspace-$source-$workspaceId'),
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      title: Text(
        context.l10n.portalDirectoryCount(
          host.isEmpty ? name : '$name · $host',
          people.length,
        ),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      children: [
        for (final person in people)
          ListTile(
            key: ValueKey('reachable-person-$source-$workspaceId-${person.id}'),
            leading: RecipientAvatar(name: person.name),
            title: Text(person.name),
            trailing: const Icon(Icons.chat_outlined),
            onTap: () => onOpen(person.id, person.name),
          ),
      ],
    );
  }
}

/// The groups I am in, as the unified inbox knows them — every one, with
/// or without a message; tapping opens the group thread.
class _ReachableGroups extends ConsumerWidget {
  const _ReachableGroups();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final entries = ref.watch(unifiedInboxProvider).value?.entries ?? const [];
    final groups = [
      for (final e in entries)
        if (e.kind == MessageContextKind.accountGroup) e,
    ];
    if (groups.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      key: const ValueKey('reachable-groups-heading'),
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      title: Text(
        l.portalDirectoryCount(l.portalGroupsHeading, groups.length),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      children: [
        for (final g in groups)
          ListTile(
            key: ValueKey('reachable-group-${g.contextId}'),
            leading: RecipientAvatar(name: g.title, group: true),
            title: Text(g.title),
            onTap: () => openInboxEntry(context, ref, g),
          ),
      ],
    );
  }
}
