// SPDX-License-Identifier: 0BSD
import '../../../core/i18n/format_prefs.dart';
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


  /// Writes my preferred DOCUMENT language (0098, #496); '' clears it.
  Future<void> setPreferredLocale(String locale);

  /// #711 — numbers, dates, clock and zone preferences.
  Future<void> setFormatPrefs(FormatPrefs prefs);

  /// Writes my status line (#231), already trimmed + hard-capped by
  /// [normalizeStatusText]; '' clears it. Throws [StateError] signed
  /// out.
  Future<void> updateStatusText(String statusText);

  /// Postal address (0060), printed on invoices; '' clears it.
  Future<void> updateAddress(String address);

  /// The two facts an EN 16931 e-invoice needs about the CUSTOMER (0069):
  /// the address country (BT-55, mandatory — '' lets the invoice fall back
  /// to the workspace's country) and the VAT id of a business member
  /// (BT-48; '' = none). Self-only.
  Future<void> updateTaxIdentity({
    required String countryCode,
    required String vatId,
  });

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
