// SPDX-License-Identifier: MIT
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../profile/domain/profile.dart';
import '../../profile/providers/profile_providers.dart';
import '../../workspace/providers/workspace_providers.dart';

part 'directory_providers.g.dart';

/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. RLS already trims the read to people
/// sharing a workspace with the caller (#223).
@riverpod
Future<Map<String, Profile>> memberProfiles(Ref ref) async {
  final members = await ref.watch(workspaceMembersProvider.future);
  if (members.isEmpty) return const {};
  final profiles = await ref
      .watch(profileRepositoryProvider)
      .fetchProfiles(members.map((m) => m.userId).toList());
  return {for (final p in profiles) p.id: p};
}
