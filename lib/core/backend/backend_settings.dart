// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../cache/cache_scope.dart';
import '../instance/schema_compatibility.dart';
import '../trace/trace_logger.dart';
import 'backend_config.dart';
import 'backend_key.dart';
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

  /// #1651 — what a probe result is bound to: this exact pair. A result
  /// captured for one candidate says nothing about an edited one.
  String get fingerprint => '${url.trim()}\u0000${key.trim()}';
}

/// Why a typed endpoint was refused. The UI maps these to sentences —
/// a refusal has to say which of the two fields is wrong and why, and
/// never repeats the value (#1651: a pasted secret must not be echoed).
enum BackendEndpointError {
  urlEmpty,
  urlNotHttps,
  urlNoHost,

  /// #1651 — userinfo, a query, a fragment or a path: not a bare origin.
  urlNotCanonical,
  keyEmpty,
  keyNotSupabase,

  /// #1651 — `sb_secret_…` or a service-role JWT.
  keySecret,

  /// #1651 — `sbp_…`, the Management API token.
  keyPersonalToken,

  /// #1651 — a session, refresh-bearing or OIDC id token.
  keyUserToken,

  /// #1651 — `postgres://…`.
  keyConnectionString,
}

/// The maximum length of a project URL; longer is refused unparsed.
const int backendUrlMaxLength = 512;

/// #1651 — the canonical `https://host[:port]` origin of [url], or null
/// when it is not one: userinfo, a query, a fragment or a path would
/// ride along into every request the client makes.
String? canonicalBackendUrl(String url) {
  final u = url.trim();
  if (u.isEmpty || u.length > backendUrlMaxLength) return null;
  final uri = Uri.tryParse(u);
  if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
  if (uri.host.isEmpty || !uri.host.contains('.')) return null;
  if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) return null;
  if (uri.path.isNotEmpty && uri.path != '/') return null;
  return uri.hasPort && uri.port != 443
      ? 'https://${uri.host.toLowerCase()}:${uri.port}'
      : 'https://${uri.host.toLowerCase()}';
}

/// Validates a hand-typed endpoint. Accepts any HTTPS host, because a
/// self-hosted Supabase lives on its owner's own domain — but the KEY
/// must be a public client key: `sb_publishable_…` or the legacy anon
/// JWT. Everything else names a person, an operator or the database
/// itself, and is refused before it is sent, stored or drawn as a QR.
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
  if (canonicalBackendUrl(u) == null) {
    return BackendEndpointError.urlNotCanonical;
  }
  if (k.isEmpty) return BackendEndpointError.keyEmpty;
  return switch (classifyBackendKey(k)) {
    BackendKeyKind.publishable || BackendKeyKind.legacyAnon => null,
    BackendKeyKind.secret => BackendEndpointError.keySecret,
    BackendKeyKind.personalAccessToken => BackendEndpointError.keyPersonalToken,
    BackendKeyKind.userToken => BackendEndpointError.keyUserToken,
    BackendKeyKind.connectionString =>
      BackendEndpointError.keyConnectionString,
    BackendKeyKind.malformed => BackendEndpointError.keyNotSupabase,
  };
}

/// #1651 — the endpoint a switch replaced, so the switch can be undone
/// before the restart that would make it real. `previous == null` means
/// the compiled default was in force.
class BackendSwitchRecord {
  const BackendSwitchRecord({required this.previous});
  final BackendEndpoint? previous;
}

/// Persists the chosen endpoint on THIS device. Null = the compiled
/// defaults, which is what an untouched install (and every store build)
/// uses.
abstract class BackendSettingsStore {
  Future<BackendEndpoint?> read();
  Future<void> write(BackendEndpoint? endpoint);

  /// #1651 — the pending switch, if a save has not been followed by a
  /// restart yet.
  Future<BackendSwitchRecord?> readSwitch();
  Future<void> writeSwitch(BackendSwitchRecord? record);
}

class PrefsBackendSettingsStore implements BackendSettingsStore {
  const PrefsBackendSettingsStore();

  static const _urlKey = 'backend_supabase_url';
  static const _keyKey = 'backend_supabase_key';
  static const _switchKey = 'backend_switch_pending';
  static const _previousUrlKey = 'backend_previous_url';
  static const _previousKeyKey = 'backend_previous_key';

  @override
  Future<BackendEndpoint?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return _endpoint(prefs.getString(_urlKey), prefs.getString(_keyKey));
  }

  static BackendEndpoint? _endpoint(String? url, String? key) {
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

  @override
  Future<BackendSwitchRecord?> readSwitch() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_switchKey) != true) return null;
    return BackendSwitchRecord(
      previous: _endpoint(
        prefs.getString(_previousUrlKey),
        prefs.getString(_previousKeyKey),
      ),
    );
  }

  @override
  Future<void> writeSwitch(BackendSwitchRecord? record) async {
    final prefs = await SharedPreferences.getInstance();
    if (record == null) {
      await prefs.remove(_switchKey);
      await prefs.remove(_previousUrlKey);
      await prefs.remove(_previousKeyKey);
      return;
    }
    await prefs.setBool(_switchKey, true);
    final previous = record.previous;
    if (previous == null) {
      await prefs.remove(_previousUrlKey);
      await prefs.remove(_previousKeyKey);
    } else {
      await prefs.setString(_previousUrlKey, previous.url);
      await prefs.setString(_previousKeyKey, previous.key);
    }
  }
}

@Riverpod(keepAlive: true)
BackendSettingsStore backendSettingsStore(Ref ref) =>
    const PrefsBackendSettingsStore();

/// #1651 — the URL this PROCESS was initialised with, which is what every
/// RPC still targets whatever the store now holds. Empty when the process
/// was not booted through `initializeApp` (tests, Demo).
@Riverpod(keepAlive: true)
String bootedBackendUrl(Ref ref) => bootBackendUrl;

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
  /// the switch was live. The endpoint it replaces is kept (#1651) so the
  /// switch can be undone until that restart.
  Future<void> setEndpoint(BackendEndpoint? endpoint) async {
    final store = ref.read(backendSettingsStoreProvider);
    final previous = await store.read();
    final pending = await store.readSwitch();
    // A second save before the restart still undoes to what the PROCESS
    // runs on, not to the intermediate choice.
    await store.writeSwitch(
      pending ?? BackendSwitchRecord(previous: previous),
    );
    await store.write(endpoint);
    ref.invalidateSelf();
  }

  /// #1651 — puts the endpoint back to what this process runs on. True
  /// when there was a pending switch to undo.
  Future<bool> undoSwitch() async {
    final store = ref.read(backendSettingsStoreProvider);
    final pending = await store.readSwitch();
    if (pending == null) return false;
    await store.write(pending.previous);
    await store.writeSwitch(null);
    ref.invalidateSelf();
    return true;
  }
}

/// #1651 — the pending switch, read alongside the active endpoint.
@riverpod
Future<BackendSwitchRecord?> pendingBackendSwitch(Ref ref) async {
  ref.watch(activeBackendProvider);
  return ref.watch(backendSettingsStoreProvider).readSwitch();
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

  /// #1312 — the schema is newer than this app. Supported by the declared
  /// compatibility contract: an older app ignores what it does not know.
  ahead,

  /// #1651 — the host answered, and the answer fits no known shape: an
  /// unclassified PostgREST error, a redirect, a 5xx, a schema version
  /// that could not be read. Not verified, not refused — look before use.
  attention,
}

/// #1651 — one fact a probe established, or could not.
enum ProbeFacet { yes, no, unknown }

/// #1651 — what a probe actually found, fact by fact. The summary
/// [result] is derived from the facets, never the other way round, so
/// the UI can show "reached, key accepted, schema unknown" instead of a
/// green line that hides which half was never checked.
class BackendProbeReport {
  const BackendProbeReport({
    required this.result,
    required this.reachable,
    required this.keyAccepted,
    required this.schemaRecognised,
    required this.compatibility,
  });

  final BackendProbeResult result;
  final ProbeFacet reachable;
  final ProbeFacet keyAccepted;
  final ProbeFacet schemaRecognised;

  /// Null when the version was not read (unreachable, refused key,
  /// missing schema, unavailable marker).
  final SchemaCompatibility? compatibility;

  /// May this candidate be saved as the device's server? Only a schema
  /// this app can use — current, or newer under the declared contract.
  bool get usable =>
      result == BackendProbeResult.ok || result == BackendProbeResult.ahead;

  static const unreachable = BackendProbeReport(
    result: BackendProbeResult.unreachable,
    reachable: ProbeFacet.no,
    keyAccepted: ProbeFacet.unknown,
    schemaRecognised: ProbeFacet.unknown,
    compatibility: null,
  );
}

/// #1651 — the two reads a probe makes, behind a seam so a test can
/// answer them with every shape a server can produce.
abstract interface class BackendProbeTransport {
  /// One row of `workspaces`: DNS, TLS, the key and the schema in one go.
  Future<void> readOneWorkspace();

  /// `deskilo_schema_version()`; null when the function is absent.
  Future<int?> readVersion();

  Future<void> dispose();
}

typedef BackendProbeTransportFactory = BackendProbeTransport Function(
  BackendEndpoint endpoint,
);

/// A throwaway client on the candidate, sending the public key only.
/// Redirects are not followed: a host that answers "go elsewhere" is not
/// the host that was named, and the key must not travel to the elsewhere.
class SupabaseProbeTransport implements BackendProbeTransport {
  SupabaseProbeTransport(BackendEndpoint endpoint)
      : _client = SupabaseClient(
          endpoint.url,
          endpoint.key,
          httpClient: _NoRedirectClient(http.Client()),
        );

  final SupabaseClient _client;

  @override
  Future<void> readOneWorkspace() => _client
      .from('workspaces')
      .select('id')
      .limit(1)
      .timeout(const Duration(seconds: 12));

  @override
  Future<int?> readVersion() => readSchemaVersion(_client);

  @override
  Future<void> dispose() => _client.dispose();
}

class _NoRedirectClient extends http.BaseClient {
  _NoRedirectClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.followRedirects = false;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

@Riverpod(keepAlive: true)
BackendProbeTransportFactory backendProbeTransport(Ref ref) =>
    SupabaseProbeTransport.new;

/// Tries the candidate endpoint BEFORE it is saved, on a throwaway
/// client (the app's own singleton keeps pointing at the live server
/// until the next start). Reading one row of `workspaces` exercises the
/// whole path: DNS, TLS, the key, and whether this project actually
/// carries the app's schema. RLS returning an empty list is a SUCCESS —
/// it means the request was accepted and evaluated.
///
/// #1651 — an answer the probe cannot classify is [BackendProbeResult
/// .attention], never `ok`: "the project answered" used to be enough, and
/// a 5xx, a redirect or a permission error all read as green.
Future<BackendProbeReport> probeBackend(
  BackendEndpoint endpoint, {
  BackendProbeTransportFactory transport = SupabaseProbeTransport.new,
}) async {
  BackendProbeTransport? probe;
  try {
    probe = transport(endpoint);
    await probe.readOneWorkspace();
    try {
      final compatibility = compareSchema(await probe.readVersion());
      return BackendProbeReport(
        result: switch (compatibility) {
          SchemaCompatibility.behind => BackendProbeResult.behind,
          SchemaCompatibility.ahead => BackendProbeResult.ahead,
          SchemaCompatibility.current => BackendProbeResult.ok,
          SchemaCompatibility.unknown => BackendProbeResult.attention,
        },
        reachable: ProbeFacet.yes,
        keyAccepted: ProbeFacet.yes,
        schemaRecognised: ProbeFacet.yes,
        compatibility: compatibility,
      );
    } on SchemaVersionUnavailable catch (e, st) {
      TraceLogger.instance.warn(
          'backend', 'probe could not read the schema version',
          error: e, stackTrace: st);
      return const BackendProbeReport(
        result: BackendProbeResult.attention,
        reachable: ProbeFacet.yes,
        keyAccepted: ProbeFacet.yes,
        schemaRecognised: ProbeFacet.yes,
        compatibility: null,
      );
    }
  } on PostgrestException catch (e, st) {
    TraceLogger.instance.warn(
      'backend',
      'probe answered with an error: ${e.code}',
      error: e,
      stackTrace: st,
    );
    return classifyProbeError(e);
  } catch (e, st) {
    TraceLogger.instance.warn(
      'backend',
      'probe could not reach the endpoint',
      error: e,
      stackTrace: st,
    );
    return BackendProbeReport.unreachable;
  } finally {
    await probe?.dispose();
  }
}

/// #1651 — what a PostgREST error says about the candidate. Pure, so the
/// table of answers is testable without a transport.
BackendProbeReport classifyProbeError(PostgrestException e) {
  final code = e.code ?? '';
  final message = e.message.toLowerCase();
  if (code == '42P01' || message.contains('does not exist')) {
    return const BackendProbeReport(
      result: BackendProbeResult.schemaMissing,
      reachable: ProbeFacet.yes,
      keyAccepted: ProbeFacet.yes,
      schemaRecognised: ProbeFacet.no,
      compatibility: null,
    );
  }
  if (code == '401' ||
      code == 'PGRST301' ||
      code == 'PGRST302' ||
      message.contains('api key') ||
      message.contains('jwt')) {
    return const BackendProbeReport(
      result: BackendProbeResult.badKey,
      reachable: ProbeFacet.yes,
      keyAccepted: ProbeFacet.no,
      schemaRecognised: ProbeFacet.unknown,
      compatibility: null,
    );
  }
  // A redirect, a 5xx, a permission error, an unknown code: the host is
  // there, and nothing else is established.
  return const BackendProbeReport(
    result: BackendProbeResult.attention,
    reachable: ProbeFacet.yes,
    keyAccepted: ProbeFacet.unknown,
    schemaRecognised: ProbeFacet.unknown,
    compatibility: null,
  );
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
      BackendProbeResult.attention => l10n?.backendTestAttention ??
          'Reached it, but the answer could not be classified. Check the '
              'server before using it.',
    };

/// #1651 — the facets, as one short line under the sentence.
String backendProbeFacetsText(AppLocalizations? l10n, BackendProbeReport r) {
  String facet(ProbeFacet f) => switch (f) {
        ProbeFacet.yes => l10n?.backendFacetYes ?? 'yes',
        ProbeFacet.no => l10n?.backendFacetNo ?? 'no',
        ProbeFacet.unknown => l10n?.backendFacetUnknown ?? 'unknown',
      };
  final version = switch (r.compatibility) {
    SchemaCompatibility.current => l10n?.backendVersionShortCurrent ?? 'current',
    SchemaCompatibility.behind => l10n?.backendVersionShortBehind ?? 'older',
    SchemaCompatibility.ahead => l10n?.backendVersionShortAhead ?? 'newer',
    SchemaCompatibility.unknown || null =>
      l10n?.backendFacetUnknown ?? 'unknown',
  };
  return l10n?.backendFacets(
        facet(r.reachable),
        facet(r.keyAccepted),
        facet(r.schemaRecognised),
        version,
      ) ??
      'Reached: ${facet(r.reachable)} · Key accepted: ${facet(r.keyAccepted)}'
          ' · Schema: ${facet(r.schemaRecognised)} · Version: $version';
}

/// One sentence per refusal — the UI never says "invalid input", and
/// never repeats what was pasted.
String backendErrorText(AppLocalizations? l10n, BackendEndpointError error) =>
    switch (error) {
      BackendEndpointError.urlEmpty =>
        l10n?.backendErrorUrlEmpty ?? 'Enter the project URL.',
      BackendEndpointError.urlNotHttps =>
        l10n?.backendErrorUrlNotHttps ?? 'The URL must start with https://.',
      BackendEndpointError.urlNoHost =>
        l10n?.backendErrorUrlNoHost ?? 'That is not a complete address.',
      BackendEndpointError.urlNotCanonical => l10n?.backendErrorUrlNotCanonical ??
          'Use only the project\'s address (https://host), without a path, '
              'a query or credentials.',
      BackendEndpointError.keyEmpty =>
        l10n?.backendErrorKeyEmpty ?? 'Enter the publishable key.',
      BackendEndpointError.keyNotSupabase => l10n?.backendErrorKeyNotSupabase ??
          'That is not a Supabase publishable key (sb_publishable_…).',
      BackendEndpointError.keySecret => l10n?.backendErrorKeySecret ??
          'That is a secret key, not a publishable one. Never share it: '
              'rotate it in Project Settings → API keys, then paste the '
              'publishable key here.',
      BackendEndpointError.keyPersonalToken =>
        l10n?.backendErrorKeyPersonalToken ??
            'That is a personal access token. It stays with its owner — '
                'paste the project\'s publishable key here.',
      BackendEndpointError.keyUserToken => l10n?.backendErrorKeyUserToken ??
          'That is a session or identity token, not a project key. Paste '
              'the project\'s publishable key here.',
      BackendEndpointError.keyConnectionString =>
        l10n?.backendErrorKeyConnectionString ??
            'That is a database connection string. It never leaves the '
                'server — paste the project\'s publishable key here.',
    };
