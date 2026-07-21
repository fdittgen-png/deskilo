// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/supabase_profile_repository.dart';
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
