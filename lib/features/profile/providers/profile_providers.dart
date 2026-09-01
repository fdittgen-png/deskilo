// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_profile_repository.dart';
import '../domain/member_monogram.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';

part 'profile_providers.g.dart';

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) =>
    SupabaseProfileRepository(Supabase.instance.client);

/// My own profile row (#223); null while signed out. Invalidated by the
/// WhatsApp editor after a successful save.
@riverpod
Future<Profile?> myProfile(Ref ref) async {
  final signedIn = ref.watch(authStateProvider).value != null;
  if (!signedIn) return null;
  return ref.watch(profileRepositoryProvider).fetchMyProfile();
}

/// Bytes of [userId]'s profile photo (0038), or null when they have none.
/// Kept alive so a member's avatar is fetched once and reused across the
/// directory, calendar and sheets; callers gate on `Profile.hasAvatar`
/// before watching this so the download only runs for members who set one.
@Riverpod(keepAlive: true)
Future<Uint8List?> memberAvatar(Ref ref, String userId) async {
  return ref.watch(profileRepositoryProvider).fetchAvatarBytes(userId);
}

/// #793 — the monogram each member's avatar shows, keyed by auth user id
/// (what [MemberAvatar] holds) rather than member id.
///
/// Computed for the whole workspace at once, because uniqueness is a
/// property of the SET: no row can pick its own letters without knowing
/// what the others took. Empty while the feature is off or the member
/// list has not arrived — the avatar then falls back to the single first
/// letter it always drew, which is also the right answer for a face the
/// member list does not cover (a former member on an old message).
@riverpod
Map<String, String> memberMonograms(Ref ref) {
  final features = ref.watch(enabledFeaturesSyncProvider);
  if (!features.contains(WorkspaceFeature.uniqueMonograms)) return const {};
  final members = ref.watch(workspaceMembersProvider).value ?? const <Member>[];
  final names = ref.watch(memberNamesProvider).value ?? const <String, String>{};
  return assignMonograms({
    for (final member in members)
      if ((names[member.id] ?? '').trim().isNotEmpty)
        member.userId: names[member.id]!,
  });
}
