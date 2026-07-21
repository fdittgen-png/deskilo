// SPDX-License-Identifier: 0BSD

/// The social sign-in providers DesKilo offers next to e-mail+password.
/// All four run the browser-based Supabase OAuth flow — no vendor SDKs,
/// so the F-Droid flavor stays Google-services-free (ADR 0003).
enum SocialProvider {
  google('Google', 'google'),
  microsoft('Microsoft', 'azure'),
  apple('Apple', 'apple'),
  facebook('Facebook', 'facebook');

  const SocialProvider(this.label, this.wireName);

  /// Brand name — deliberately NOT translated.
  final String label;

  /// Supabase provider id (Microsoft is 'azure' server-side).
  final String wireName;

  /// The catalog entry for a stored identity's provider id, or null for
  /// non-social identities ('email', 'phone', …).
  static SocialProvider? fromWire(String provider) =>
      values.where((p) => p.wireName == provider).firstOrNull;
}

/// One identity attached to the signed-in account (e-mail or a social
/// provider), as listed on the linked-accounts screen.
typedef LinkedIdentity = ({String id, String provider});
