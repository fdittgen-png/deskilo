// SPDX-License-Identifier: AGPL-3.0-or-later

/// The social sign-in providers DesKilo offers next to e-mail+password.
/// Browser-based Supabase OAuth, no vendor SDK — the F-Droid flavor stays
/// Google-services-free (ADR 0003).
///
/// Offered only when the current installation advertises the provider enabled.
enum SocialProvider {
  google('Google', 'google'),
  apple('Apple', 'apple'),
  microsoft('Microsoft', 'azure');

  const SocialProvider(this.label, this.wireName);

  /// Brand name — deliberately NOT translated.
  final String label;

  /// Supabase provider id.
  final String wireName;

  /// The catalog entry for a stored identity's provider id, or null for
  /// non-social identities ('email', 'phone', …).
  static SocialProvider? fromWire(String provider) =>
      values.where((p) => p.wireName == provider).firstOrNull;
}

/// One identity attached to the signed-in account (e-mail or a social
/// provider), as listed on the linked-accounts screen.
typedef LinkedIdentity = ({String id, String provider});
