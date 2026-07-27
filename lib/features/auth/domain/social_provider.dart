// SPDX-License-Identifier: 0BSD

/// The social sign-in providers DesKilo offers next to e-mail+password.
/// Browser-based Supabase OAuth, no vendor SDK — the F-Droid flavor stays
/// Google-services-free (ADR 0003).
///
/// Google alone (field decision 2026-07-27): Microsoft, Apple and Facebook
/// were offered but never configured server-side, so every tap on them
/// ended in a provider error. A button that cannot work is worse than no
/// button. [fromWire] still resolves the retired ids so an account that
/// linked one of them keeps rendering.
enum SocialProvider {
  google('Google', 'google');

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
