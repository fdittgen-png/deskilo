// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/privacy/recording_privacy.dart';
import '../../../core/privacy/recording_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/my_profile_edits.dart';
import '../data/supabase_profile_repository.dart';
import '../domain/member_monogram.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';
import '../domain/privacy_notice.dart';
import '../../../core/privacy/privacy_policy.dart';

part 'profile_providers.g.dart';

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) =>
    SupabaseProfileRepository(Supabase.instance.client);

/// My own profile row (#223); null while signed out. Invalidated by the
/// WhatsApp editor after a successful save.
// The app router keeps listening to the consent gate for its lifetime.
/// #1823 — the writes My account makes about me (photo, invoice block).
/// #1914 — the notices that apply to the signed-in person in the current
/// space; [PrivacyNotices.none] signed out or when the server has none.
@Riverpod(keepAlive: true)
Future<PrivacyNotices> privacyNotices(Ref ref) async {
  final signedIn = ref.watch(authStateProvider).value != null;
  if (!signedIn) return PrivacyNotices.none;
  final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
  return ref.read(profileRepositoryProvider).fetchPrivacyNotices(workspaceId);
}

/// #1914 — the version the consent gate asks for: the installation
/// notice the SERVER publishes, so an operator's new notice is the one
/// acknowledged; the shipped version while it loads or on an older
/// server.
@Riverpod(keepAlive: true)
String requiredPrivacyVersion(Ref ref) =>
    ref.watch(privacyNoticesProvider).value?.installation?.version ??
    kPrivacyPolicyVersion;

@riverpod
MyProfileEdits myProfileEdits(Ref ref) =>
    MyProfileEdits(ref.watch(profileRepositoryProvider));

@Riverpod(keepAlive: true)
Future<Profile?> myProfile(Ref ref) async {
  final signedIn = ref.watch(authStateProvider).value != null;
  if (!signedIn) return null;
  // #1514 — the seam. My own name, address, telephone number and
  // identity are personal data like anybody else's, and the settings
  // screens that print them are exactly what a support video films.
  // Watched BEFORE the gap (#1218).
  final recording = ref.watch(recordingPrivacyProvider);
  final profile = await ref.watch(profileRepositoryProvider).fetchMyProfile();
  if (profile == null || !recording) return profile;
  return recordingProfile(profile);
}

/// Bytes of [userId]'s profile photo (0038), or null when they have none.
/// Kept alive so a member's avatar is fetched once and reused across the
/// directory, calendar and sheets; callers gate on `Profile.hasAvatar`
/// before watching this so the download only runs for members who set one.
@Riverpod(keepAlive: true)
Future<Uint8List?> memberAvatar(Ref ref, String userId) async {
  // #1514 — a face identifies a person at least as well as the name
  // beside it. Filming mode shows the monogram every member without a
  // photograph already shows, so the plan, the directory and the kiosk
  // receipt carry nobody's likeness. The photograph is never fetched at
  // all, so it is not merely hidden.
  if (ref.watch(recordingPrivacyProvider)) return null;
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
  return assignMonograms(
    {
      for (final member in members)
        if ((names[member.id] ?? '').trim().isNotEmpty)
          member.userId: names[member.id]!,
    },
    // First come, first served: a member's letters never move because
    // somebody else joined later.
    order: {for (final member in members) member.userId: member.joinedAt},
  );
}

/// One account/workspace context for private personal preferences (#1791).
@Riverpod(keepAlive: true)
({String? account, String? workspace}) personalPreferenceContext(Ref ref) => (
  account: ref.watch(currentAccountIdProvider),
  workspace: ref.watch(currentWorkspaceProvider).value?.id,
);

void invalidatePersonalPreferenceConsumers(Ref ref) {
  ref.invalidate(myProfileProvider);
  ref.invalidate(workspaceMembersProvider);
  ref.invalidate(myMemberProvider);
}
