// SPDX-License-Identifier: MIT

/// Connection settings for the shared backend (ADR 0002).
///
/// The committed defaults point at the hosted reference deployment. Both
/// values are *publishable* by design (Supabase URL + publishable key; RLS
/// is the security boundary — see docs/security/SUPABASE_RLS_MATRIX.md).
///
/// Self-hosters override at build time:
///   flutter build … --dart-define=SUPABASE_URL=https://…
///                   --dart-define=SUPABASE_KEY=sb_publishable_…
abstract final class BackendConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zwzbynivewivvjmripeb.supabase.co',
  );

  static const String supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_PqXoa0tyQTjsZCPD_LrEQw_P7LJtalL',
  );
}
