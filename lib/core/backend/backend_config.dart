// SPDX-License-Identifier: AGPL-3.0-or-later

/// Connection settings for the shared backend (ADR 0002).
///
/// The committed defaults point at the hosted reference deployment. Both
/// values are *publishable* by design (Supabase URL + publishable key; RLS
/// is the security boundary — see docs/security/SUPABASE_RLS_MATRIX.md).
///
/// Self-hosters override at build time:
///   flutter build … --dart-define=SUPABASE_URL=https://…
///                   --dart-define=SUPABASE_KEY=sb_publishable_…
///
/// #2343 — a build made with `--dart-define=DESKILO_NO_DEFAULT_SERVER=true`
/// (the F-Droid build) ships NO default server: the first start asks the
/// person to pick one — the reference deployment, an existing server, or
/// a new instance the wizard builds — and contacts nothing before that.
/// The reference endpoint stays in the binary as one of those choices and
/// as the home of the global directory.
abstract final class BackendConfig {
  /// The hosted reference deployment: one server among many, and the one
  /// that carries the global directory every server can be linked to.
  static const String referenceUrl = 'https://zwzbynivewivvjmripeb.supabase.co';
  static const String referenceKey =
      'sb_publishable_PqXoa0tyQTjsZCPD_LrEQw_P7LJtalL';

  /// True in a build that must start without a server.
  static const bool noDefaultServer = bool.fromEnvironment(
    'DESKILO_NO_DEFAULT_SERVER',
  );

  /// The compiled default server; empty when [noDefaultServer].
  static const String supabaseUrl = noDefaultServer
      ? ''
      : String.fromEnvironment('SUPABASE_URL', defaultValue: referenceUrl);

  static const String supabaseKey = noDefaultServer
      ? ''
      : String.fromEnvironment('SUPABASE_KEY', defaultValue: referenceKey);

  /// Whether this build falls back to a server nobody chose.
  static const bool hasDefault = supabaseUrl != '';
}
