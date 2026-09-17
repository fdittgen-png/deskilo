// SPDX-License-Identifier: 0BSD
//
// #1309 — what a device can say about its instance without holding any
// credential. Pure Dart: derived from the host alone.

/// The Supabase project ref of [host] (`<ref>.supabase.co`), or null for a
/// host that is not a hosted Supabase project (a self-hosted server).
String? supabaseProjectRef(String host) =>
    RegExp(r'^([a-z0-9]+)\.supabase\.(co|in)$')
        .firstMatch(host.trim().toLowerCase())
        ?.group(1);

/// The project's page in the Supabase dashboard. Opening it asks the
/// person to sign in to THEIR organization — the app passes no token.
Uri supabaseDashboardUri(String ref) =>
    Uri.https('supabase.com', '/dashboard/project/$ref');
