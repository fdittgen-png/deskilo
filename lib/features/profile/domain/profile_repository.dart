// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/i18n/format_prefs.dart';
import 'personal_info.dart';
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


  /// #886 — the whole structured identity in one write (the form saves
  /// every field together, so a half-saved address cannot exist).
  Future<void> updatePersonalInfo(PersonalInfo info);

  /// Everything printed about this member as the CUSTOMER of an
  /// invoice, in ONE write: the postal address (0060, '' clears it), the
  /// address country an EN 16931 invoice needs (BT-55, '' falls back to
  /// the workspace's) and the VAT id of a business member (BT-48, '' =
  /// none). Self-only.
  ///
  /// One write for the same reason [updatePersonalInfo] is one: the form
  /// saves them together, and they are one block on the document. As two
  /// calls, a failure on the second billed the member at their new
  /// address under their old VAT identity (#1532).
  Future<void> updateInvoiceIdentity({
    required String address,
    required String countryCode,
    required String vatId,
  });

  /// Foreground heartbeat: stamps my `last_seen_at` via the self-scoped
  /// `touch_last_seen` RPC (0028).
  Future<void> touchLastSeen();

  /// #751 — record the acceptance of the privacy policy [version] on the
  /// account (server timestamp).
  Future<void> acceptPrivacyPolicy(String version);

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
