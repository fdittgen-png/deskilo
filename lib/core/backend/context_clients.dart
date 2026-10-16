// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 C1 -- the clients an operation context runs on, supplied
// independently: the personal client talks to P, a workspace client talks to
// the one verified installation its target names. A consumer receives the
// client it needs through these seams; it never reaches for
// `Supabase.instance.client` or for whatever backend is selected later.
//
// In a combined deployment P and W are the same installation and therefore
// the same client; in a split one each is its own. A workspace client is
// handed out only for an installation that was VERIFIED (its own
// `installation_identity` read) and registered, otherwise the request is
// refused with a typed [UnverifiedInstallation], never answered by another
// host.
import 'package:supabase_flutter/supabase_flutter.dart';

/// No verified client exists for this installation id.
class UnverifiedInstallation implements Exception {
  const UnverifiedInstallation(this.installationId);
  final String installationId;
  @override
  String toString() => 'UnverifiedInstallation: $installationId';
}

/// The installation identity answered by [client]'s OWN server.
typedef InstallationIdReader = Future<String> Function(SupabaseClient client);

Future<String> readInstallationId(SupabaseClient client) async {
  final row = await client
      .from('installation_identity')
      .select('installation_id')
      .single();
  final id = row['installation_id'];
  if (id is! String || id.isEmpty) {
    throw const FormatException('installation_identity has no installation_id');
  }
  return id;
}

/// The native authority of [client]'s server, as the issuer of the
/// subjects it mints. Until an installation publishes its own issuer this is
/// its auth endpoint; it is never taken from a token the user controls.
String nativeIssuerOf(SupabaseClient client) =>
    '${Uri.parse(client.rest.url).origin}/auth/v1';

/// The two kinds of client, by role.
class ContextClients {
  ContextClients(this.personal, [this._legacyActive]);

  /// The long-lived native client of the personal home (P).
  final SupabaseClient personal;

  final SupabaseClient? _legacyActive;

  /// The process-wide client the not-yet-migrated repository methods still
  /// use (#2564 moves them onto contexts); in a combined deployment it is
  /// [personal]. New code takes a context or a role client, never this.
  SupabaseClient get legacyActive => _legacyActive ?? personal;

  final _workspace = <String, SupabaseClient>{};

  /// Records the verified client for [installationId].
  void registerWorkspace(String installationId, SupabaseClient client) {
    _workspace[installationId] = client;
  }

  /// The client of a verified workspace installation.
  SupabaseClient workspace(String installationId) =>
      _workspace[installationId] ??
      (throw UnverifiedInstallation(installationId));
}

/// A workspace host that was reached and identified itself.
class ResolvedWorkspaceHost {
  const ResolvedWorkspaceHost({
    required this.installationId,
    required this.client,
    required this.localUserId,
  });

  final String installationId;
  final SupabaseClient client;

  /// The signed-in account's id on THAT host (it differs per host).
  final String localUserId;
}

/// Finds and verifies the host of a workspace.
abstract interface class WorkspaceHostResolver {
  Future<ResolvedWorkspaceHost> resolve(String workspaceId);
}

/// The combined deployment: the workspace lives on the installation the app
/// is signed in to. A split deployment supplies a resolver backed by the
/// connected-installation pool (the successor checkpoint).
class ActiveInstallationHostResolver implements WorkspaceHostResolver {
  ActiveInstallationHostResolver(this._client, this._read);

  final SupabaseClient _client;
  final InstallationIdReader _read;

  @override
  Future<ResolvedWorkspaceHost> resolve(String workspaceId) async {
    final user = _client.auth.currentUser?.id;
    final installationId = await _read(_client);
    if (user == null) throw UnverifiedInstallation(installationId);
    return ResolvedWorkspaceHost(
      installationId: installationId,
      client: _client,
      localUserId: user,
    );
  }
}
