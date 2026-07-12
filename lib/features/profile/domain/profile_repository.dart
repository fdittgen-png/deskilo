// SPDX-License-Identifier: MIT
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

  /// Foreground heartbeat: stamps my `last_seen_at` via the self-scoped
  /// `touch_last_seen` RPC (0028).
  Future<void> touchLastSeen();
}
