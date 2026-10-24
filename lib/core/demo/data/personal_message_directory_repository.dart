// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2472 (P) — the demonstration's personal-home directory: the persona's
// two spaces (both hosted by the one fictional installation, so both are
// named), the active cast it shares with each, read at every call so a
// persona switch is followed, and the cast's group. Pages are keyset pages
// of the registry's default size, like the real reader's.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:meta/meta.dart';

import '../../../features/directory/domain/personal_message_directory.dart';
import '../../../features/directory/domain/public_workspace.dart';
import '../../../features/directory/providers/personal_directory_providers.dart';
import '../../settings/setting_defaults.g.dart';

/// The demonstration's reader: [reachable] and [groups] at every call.
Override demoPersonalDirectory(
  List<ReachablePerson> Function() reachable,
  List<DirectoryGroup> Function() groups,
) => personalMessageDirectoryRepositoryProvider.overrideWith(
  (ref) => FakePersonalMessageDirectoryRepository(
    reachable: reachable,
    groupsOf: groups,
  ),
);

/// Tests use it directly for a home without the reader.
@visibleForTesting
class FakePersonalMessageDirectoryRepository
    implements PersonalMessageDirectoryRepository {
  FakePersonalMessageDirectoryRepository({
    required this.reachable,
    this.groupsOf = _noGroups,
    this.pageSize = SettingDefaults.personalMessageDirectoryPageSize,
  });

  /// Who the persona may write to, one row per shared space.
  final List<ReachablePerson> Function() reachable;
  final List<DirectoryGroup> Function() groupsOf;
  final int pageSize;

  /// When set, every read fails with it (a home that refuses or lacks the
  /// reader).
  DirectoryRefused? refusal;

  static List<DirectoryGroup> _noGroups() => const [];

  DirectoryPage<T> _slice<T>(
    List<T> all,
    String Function(T) key,
    String? after,
  ) {
    final rest = [
      for (final item in all)
        if (after == null || key(item).compareTo(after) > 0) item,
    ];
    final page = rest.take(pageSize).toList();
    return DirectoryPage(
      items: page,
      status: RelationshipStatus.ready,
      nextKey: rest.length > pageSize ? key(page.last) : null,
    );
  }

  void _check() {
    final r = refusal;
    if (r != null) throw r;
  }

  @override
  Future<DirectoryPage<DirectoryWorkspace>> workspaces({String? after}) async {
    _check();
    final names = <String, String>{
      for (final p in reachable()) p.workspaceId: p.workspaceName,
    };
    final all = [
      for (final id in names.keys.toList()..sort())
        DirectoryWorkspace(networkId: id, name: names[id]),
    ];
    return _slice(all, (w) => w.networkId, after);
  }

  @override
  Future<DirectoryPage<DirectoryPerson>> people(
    String networkId, {
    String? after,
    String query = '',
  }) async {
    _check();
    final q = query.trim().toLowerCase();
    final all = [
      for (final p in reachable())
        if (p.workspaceId == networkId &&
            (q.isEmpty || p.name.toLowerCase().contains(q)))
          DirectoryPerson(id: p.id, workspaceRef: networkId, name: p.name),
    ]..sort((a, b) => a.id.compareTo(b.id));
    return _slice(all, (p) => p.id, after);
  }

  @override
  Future<DirectoryPage<DirectoryGroup>> groups({String? after}) async {
    _check();
    final all = groupsOf().toList()..sort((a, b) => a.id.compareTo(b.id));
    return _slice(all, (g) => g.id, after);
  }
}
