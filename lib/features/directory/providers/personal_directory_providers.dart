// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/context_client_providers.dart';
import '../../../core/trace/trace_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/supabase_personal_message_directory_repository.dart';
import '../domain/personal_message_directory.dart';

part 'personal_directory_providers.g.dart';

/// #2472 (P) — the directory reader, always at the personal home; a new
/// account is a new reader.
@riverpod
PersonalMessageDirectoryRepository personalMessageDirectoryRepository(
  Ref ref,
) {
  ref.watch(authStateProvider);
  return SupabasePersonalMessageDirectoryRepository(
    ref.watch(personalClientProvider),
  );
}

/// What the new discussion lists before any search: every workspace I hold
/// a relationship with, the first page of each one's people, and every
/// group I am in. A home without the reader fails with
/// [DirectoryFailure.unsupported], which the screen answers with the
/// per-server directory; any other failure is shown, never read as empty.
@Riverpod(retry: personalDirectoryRetry)
class PersonalDirectoryController extends _$PersonalDirectoryController {
  @override
  Future<PersonalDirectory> build() async {
    final repository = ref.watch(personalMessageDirectoryRepositoryProvider);
    final workspaces = <DirectoryWorkspace>[];
    var status = RelationshipStatus.ready;
    String? after;
    do {
      final page = await repository.workspaces(after: after);
      if (after == null) status = page.status;
      workspaces.addAll(page.items);
      // A cursor that does not move would ask the same page forever.
      if (page.nextKey == after) break;
      after = page.nextKey;
    } while (after != null);
    final groups = <DirectoryGroup>[];
    after = null;
    do {
      final page = await repository.groups(after: after);
      groups.addAll(page.items);
      if (page.nextKey == after) break;
      after = page.nextKey;
    } while (after != null);
    final pages = await Future.wait([
      for (final w in workspaces) _firstPeople(repository, w.networkId),
    ]);
    return PersonalDirectory(
      workspaces: workspaces,
      groups: groups,
      status: status,
      people: {
        for (final (i, w) in workspaces.indexed) w.networkId: pages[i],
      },
    );
  }

  /// One workspace's first page. A workspace that stopped being mine
  /// between the two reads lists nobody, as unavailable; every other
  /// failure fails the directory.
  Future<DirectoryPage<DirectoryPerson>> _firstPeople(
    PersonalMessageDirectoryRepository repository,
    String networkId,
  ) async {
    try {
      return await repository.people(networkId);
    } on DirectoryRefused catch (e, st) {
      if (e.failure != DirectoryFailure.forbidden) rethrow;
      TraceLogger.instance.warn(
        'messages',
        'a directory workspace was refused',
        error: e.failure.name,
        stackTrace: st,
      );
      return const DirectoryPage(
        items: [],
        status: RelationshipStatus.unavailable,
      );
    }
  }

  /// The next page of [networkId]'s people, appended. A failure keeps
  /// what is shown and is logged; Show more stays to try again.
  Future<void> more(String networkId) async {
    final current = state.value;
    final next = current?.people[networkId]?.nextKey;
    if (current == null || next == null) return;
    try {
      final page = await ref
          .read(personalMessageDirectoryRepositoryProvider)
          .people(networkId, after: next);
      if (!ref.mounted || !identical(state.value, current)) return;
      state = AsyncData(current.withPeople(networkId, page));
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'messages',
        'the next page of a directory workspace could not be read',
        error: e.runtimeType,
        stackTrace: st,
      );
    }
  }
}

/// Whether the personal home answers the directory: false only when it
/// lacks the reader, so the screen keeps the per-server directory.
bool personalDirectoryUnsupported(Object? error) =>
    error is DirectoryRefused &&
    error.failure == DirectoryFailure.unsupported;
