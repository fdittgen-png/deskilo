// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../instance/schema_compatibility.dart';
import '../trace/trace_logger.dart';
import 'backend_config.dart';
import 'schema_version.dart';

part 'backend_settings.g.dart';

/// #780 — WHICH Supabase instance this device talks to.
///
/// The compiled defaults ([BackendConfig]) point at the author's hosted
/// reference deployment and stay the default for everyone who just
/// installs the app. A community running its OWN Supabase project — the
/// schema, RLS policies and edge functions ship in this repository —
/// used to need a rebuild with `--dart-define`; now they type the two
/// values into Settings instead, which is also what F-Droid's reviewers
/// look for (fdroiddata!42093 on the sibling app).
///
/// Deliberately NOT behind a `WorkspaceFeature` flag, for the same
/// reason the GDPR consent gate (#751) is not: the flags live in a
/// workspace, and this setting decides which server the workspace is
/// even read from. It is a device setting, like the scan lens.
///
/// Only Supabase is accepted — this is a *which instance* switch, not a
/// pluggable-backend abstraction: everything above it (RLS, RPCs, edge
/// functions, realtime) is Supabase's contract.
class BackendEndpoint {
  const BackendEndpoint(this.url, this.key);

  final String url;
  final String key;

  /// The host shown in Settings ("zwzbynivewivvjmripeb.supabase.co").
  String get host => Uri.tryParse(url)?.host ?? url;
}

/// Why a typed endpoint was refused. The UI maps these to sentences —
/// a refusal has to say which of the two fields is wrong and why.
enum BackendEndpointError {
  urlEmpty,
  urlNotHttps,
  urlNoHost,
  keyEmpty,
  keyNotSupabase,
}

/// Validates a hand-typed endpoint. Accepts any HTTPS host, because a
/// self-hosted Supabase lives on its owner's own domain — but the KEY
/// must be a Supabase publishable key (`sb_publishable_…`) or the
/// legacy anon JWT, which is what rejects "some other database".
BackendEndpointError? validateBackendEndpoint(String url, String key) {
  final u = url.trim();
  final k = key.trim();
  if (u.isEmpty) return BackendEndpointError.urlEmpty;
  final uri = Uri.tryParse(u);
  if (uri == null || uri.scheme.toLowerCase() != 'https') {
    return BackendEndpointError.urlNotHttps;
  }
  if (uri.host.isEmpty || !uri.host.contains('.')) {
    return BackendEndpointError.urlNoHost;
  }
  if (k.isEmpty) return BackendEndpointError.keyEmpty;
  final looksPublishable = k.startsWith('sb_publishable_') && k.length > 20;
  final looksAnonJwt = k.startsWith('eyJ') && k.split('.').length == 3;
  if (!looksPublishable && !looksAnonJwt) {
    return BackendEndpointError.keyNotSupabase;
  }
  return null;
}

/// Persists the chosen endpoint on THIS device. Null = the compiled
/// defaults, which is what an untouched install (and every store build)
/// uses.
abstract class BackendSettingsStore {
  Future<BackendEndpoint?> read();
  Future<void> write(BackendEndpoint? endpoint);
}

class PrefsBackendSettingsStore implements BackendSettingsStore {
  const PrefsBackendSettingsStore();

  static const _urlKey = 'backend_supabase_url';
  static const _keyKey = 'backend_supabase_key';

  @override
  Future<BackendEndpoint?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey);
    final key = prefs.getString(_keyKey);
    if (url == null || key == null || url.isEmpty || key.isEmpty) return null;
    return BackendEndpoint(url, key);
  }

  @override
  Future<void> write(BackendEndpoint? endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    if (endpoint == null) {
      await prefs.remove(_urlKey);
      await prefs.remove(_keyKey);
      return;
    }
    await prefs.setString(_urlKey, endpoint.url.trim());
    await prefs.setString(_keyKey, endpoint.key.trim());
  }
}

@Riverpod(keepAlive: true)
BackendSettingsStore backendSettingsStore(Ref ref) =>
    const PrefsBackendSettingsStore();

/// The endpoint in force: the stored one, or the compiled default.
/// Startup reads the store directly (before any provider exists); this
/// provider is what Settings displays and edits.
@Riverpod(keepAlive: true)
class ActiveBackend extends _$ActiveBackend {
  @override
  Future<BackendEndpoint> build() async =>
      await ref.watch(backendSettingsStoreProvider).read() ??
      const BackendEndpoint(
        BackendConfig.supabaseUrl,
        BackendConfig.supabaseKey,
      );

  /// True while this device uses the app's own default instance.
  static bool isDefault(BackendEndpoint endpoint) =>
      endpoint.url == BackendConfig.supabaseUrl;

  /// Stores a custom endpoint; null resets to the default. Takes effect
  /// on the next start — `Supabase.initialize` runs once per process, so
  /// the caller signs out and asks for a restart rather than pretending
  /// the switch was live.
  Future<void> setEndpoint(BackendEndpoint? endpoint) async {
    await ref.read(backendSettingsStoreProvider).write(endpoint);
    ref.invalidateSelf();
  }
}

/// What a connection test found. The screen turns each into one
/// sentence — "it does not work" is useless when the cause could be a
/// typo, a wrong key, or a project whose schema was never installed.
enum BackendProbeResult {
  ok,
  unreachable,
  badKey,
  schemaMissing,

  /// #1312 — the schema is there, older than this app needs.
  behind,

  /// #1312 — the schema is newer than this app. Works; an update of the
  /// app is available.
  ahead,
}

/// Tries the candidate endpoint BEFORE it is saved, on a throwaway
/// client (the app's own singleton keeps pointing at the live server
/// until the next start). Reading one row of `workspaces` exercises the
/// whole path: DNS, TLS, the key, and whether this project actually
/// carries the app's schema. RLS returning an empty list is a SUCCESS —
/// it means the request was accepted and evaluated.
Future<BackendProbeResult> probeBackend(BackendEndpoint endpoint) async {
  SupabaseClient? probe;
  try {
    probe = SupabaseClient(endpoint.url, endpoint.key);
    await probe
        .from('workspaces')
        .select('id')
        .limit(1)
        .timeout(const Duration(seconds: 12));
    // #1312 — reachable and carrying tables is not yet "usable": the
    // version decides. A marker that cannot be read after the table read
    // succeeded says nothing new, so it stays `ok`.
    try {
      return switch (compareSchema(await readSchemaVersion(probe))) {
        SchemaCompatibility.behind => BackendProbeResult.behind,
        SchemaCompatibility.ahead => BackendProbeResult.ahead,
        SchemaCompatibility.current ||
        SchemaCompatibility.unknown =>
          BackendProbeResult.ok,
      };
    } on SchemaVersionUnavailable catch (e, st) {
      TraceLogger.instance.warn('backend', 'probe could not read the schema version',
          error: e, stackTrace: st);
      return BackendProbeResult.ok;
    }
  } on PostgrestException catch (e, st) {
    TraceLogger.instance.warn(
      'backend',
      'probe answered with an error: ${e.code} ${e.message}',
      error: e,
      stackTrace: st,
    );
    final code = e.code ?? '';
    final message = e.message.toLowerCase();
    if (code == '42P01' || message.contains('does not exist')) {
      return BackendProbeResult.schemaMissing;
    }
    if (code == '401' ||
        code == 'PGRST301' ||
        message.contains('api key') ||
        message.contains('jwt')) {
      return BackendProbeResult.badKey;
    }
    // Any other Postgrest answer still proves the project answered.
    return BackendProbeResult.ok;
  } catch (e, st) {
    TraceLogger.instance.warn(
      'backend',
      'probe could not reach the endpoint',
      error: e,
      stackTrace: st,
    );
    return BackendProbeResult.unreachable;
  } finally {
    await probe?.dispose();
  }
}

/// What a connection test found, as the one sentence the Server screen shows.
String backendProbeText(AppLocalizations? l10n, BackendProbeResult result) =>
    switch (result) {
      BackendProbeResult.ok =>
        l10n?.backendTestOk ?? 'Reached it — the app\'s schema is there.',
      BackendProbeResult.unreachable => l10n?.backendTestUnreachable ??
          'Could not reach that address. Check the URL and your network.',
      BackendProbeResult.badKey => l10n?.backendTestBadKey ??
          'Reached it, but the key was refused. Copy the publishable key '
              'again from Project Settings → API keys.',
      BackendProbeResult.schemaMissing => l10n?.backendTestSchemaMissing ??
          'Reached it, but the DesKilo tables are missing — run the '
              'migrations from supabase/migrations on that project first.',
      BackendProbeResult.behind => l10n?.backendTestBehind ??
          'Reached it, but its DesKilo schema is older than this app needs. '
              'Update the server before using it.',
      BackendProbeResult.ahead => l10n?.backendTestAhead ??
          'Reached it. Its schema is newer than this app — it works, and a '
              'newer app is available.',
    };

/// One sentence per refusal — the UI never says "invalid input".
String backendErrorText(AppLocalizations? l10n, BackendEndpointError error) =>
    switch (error) {
      BackendEndpointError.urlEmpty =>
        l10n?.backendErrorUrlEmpty ?? 'Enter the project URL.',
      BackendEndpointError.urlNotHttps =>
        l10n?.backendErrorUrlNotHttps ?? 'The URL must start with https://.',
      BackendEndpointError.urlNoHost =>
        l10n?.backendErrorUrlNoHost ?? 'That is not a complete address.',
      BackendEndpointError.keyEmpty =>
        l10n?.backendErrorKeyEmpty ?? 'Enter the publishable key.',
      BackendEndpointError.keyNotSupabase => l10n?.backendErrorKeyNotSupabase ??
          'That is not a Supabase publishable key (sb_publishable_…).',
    };
