// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — how the active workspace's members are shown: their names and
// the profile each caller may read of them. Both are read of the
// workspace's members by almost every feature; kept here, and re-exported
// by workspace_providers.dart, so a feature that knows the workspace
// imports neither the reservations nor the members feature to print a
// name or a face.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/privacy/recording_privacy.dart';
import '../../../core/privacy/recording_providers.dart';
import '../../profile/domain/profile.dart';
import '../../profile/providers/profile_providers.dart';
import '../domain/member.dart';
import 'workspace_providers.dart';

part 'member_display_providers.g.dart';

/// member id → display name for the active workspace.
@Riverpod(keepAlive: true)
Future<Map<String, String>> memberNames(Ref ref) async {
  // #1514 — the seam. Every name the plan, the calendar, the week grid
  // and the kiosk print comes through here, so while filming mode is on
  // none of them can print a real one. Watched BEFORE the gap (#1218).
  final recording = ref.watch(recordingPrivacyProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const {};
  final names = await ref
      .watch(workspaceRepositoryProvider)
      .fetchMemberNames(workspace.id);
  if (!recording) return names;
  return {
    for (final entry in names.entries)
      entry.key: recordingName(entry.key, entry.value),
  };
}

/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. #1833: each profile is the projection the
/// caller may read in this space — the community fields for a space
/// mate, the printed identity only with `viewPersonalData` or
/// `issueInvoices` (invoices, letters, the Excel export).
@riverpod
Future<Map<String, Profile>> memberProfiles(Ref ref) async {
  // #1514 — the seam. The directory is the densest personal page in the
  // app: names, status lines, WhatsApp numbers and photographs, all at
  // once. Watched BEFORE the gap (#1218).
  final recording = ref.watch(recordingPrivacyProvider);
  final members = await ref.watch(workspaceMembersProvider.future);
  // A managed member (#962) has no account and therefore no profile;
  // its empty user id must never reach the query, where PostgREST
  // rejects the whole request over one malformed uuid.
  final ids = accountIdsOf(members);
  if (ids.isEmpty) return const {};
  // #1833 — asked as members of the space these ids came from: what the
  // caller may read of a person depends on their rights in THAT space.
  final profiles = await ref
      .watch(memberProfileRepositoryProvider)
      .fetchProfiles(members.first.workspaceId, ids);
  // Filming mode replaces the people and keeps the page.
  return {for (final p in profiles) p.id: recording ? recordingProfile(p) : p};
}
