// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import 'profile.dart';

/// Pure-Dart profile boundary (#223). Implemented by Supabase in data/,
/// faked in tests — presentation never sees supabase_flutter types.
abstract class ProfileRepository {
  /// My own profile row, or null when signed out.
  Future<Profile?> fetchMyProfile();

  /// Profiles of [userIds] (auth.users ids) — the #224 directory read.
  /// RLS trims the result to people sharing a workspace with the caller.
  Future<List<Profile>> fetchProfiles(List<String> userIds);

  /// Writes my WhatsApp number, already normalized by
  /// [normalizeWhatsapp]; '' clears it. Throws [StateError] signed out.
  Future<void> updateWhatsapp(String whatsapp);

  /// Writes my status line (#231), already trimmed + hard-capped by
  /// [normalizeStatusText]; '' clears it. Throws [StateError] signed
  /// out.
  Future<void> updateStatusText(String statusText);

  /// Foreground heartbeat: stamps my `last_seen_at` via the self-scoped
  /// `touch_last_seen` RPC (0028).
  Future<void> touchLastSeen();

  /// Uploads my profile photo to the private `avatars` bucket (0038) and
  /// records its path on my profile row. Throws [StateError] signed out.
  Future<void> setAvatar({
    required Uint8List bytes,
    required String contentType,
  });

  /// Removes my profile photo (storage object + the path column); a no-op
  /// when none is set. Throws [StateError] signed out.
  Future<void> clearAvatar();

  /// Bytes of [userId]'s avatar, or null when they have none / it is not
  /// readable. RLS grants it to self and co-workspace members (0038).
  Future<Uint8List?> fetchAvatarBytes(String userId);
}
