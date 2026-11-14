// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3858 — the dated plan changes and pauses of the active workspace's members
// the caller may read, shared by the members table and a member's Plan tab.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/member_term_change.dart';
import 'workspace_providers.dart';

part 'member_term_providers.g.dart';

@riverpod
Future<List<MemberTermChange>> memberTermChanges(Ref ref) async {
  // the repository is watched before the gap (#1218)
  final repository = ref.watch(workspaceRepositoryProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return repository.fetchMemberTermChanges(workspace.id);
}
