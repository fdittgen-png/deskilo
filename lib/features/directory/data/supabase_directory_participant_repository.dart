// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/connected_installations.dart';
import '../../../core/public_network/public_network_operations.dart';
import '../domain/public_workspace.dart';

/// #1847 — the PARTICIPANT interface: a signed-in account acting for
/// itself. Registering probes the endpoint anonymously first; asking to
/// join goes through the account's own session on the card's installation.
class SupabaseDirectoryParticipantRepository
    implements DirectoryParticipantRepository {
  SupabaseDirectoryParticipantRepository(this.active, this.connections);
  final SupabaseClient active;
  final ConnectedInstallations? connections;

  static const _probe = PublicNetworkOperations.directoryWorkspacesSearch;
  static const _register = PublicNetworkOperations.directorySourcesRegister;
  static const _request = PublicNetworkOperations.workspaceProfileRequest;

  @override
  Future<void> register(String origin, String key) async {
    if (validateBackendEndpoint(origin, key) != null) {
      throw StateError('invalid public endpoint');
    }
    final client = SupabaseClient(
      origin,
      key,
      httpClient: OriginOnlyClient(origin, http.Client()),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    try {
      await client
          .from(_probe.relation!)
          .select('workspace_id')
          .limit(1)
          .timeout(Duration(seconds: _probe.timeoutSeconds ?? 12));
    } finally {
      await client.dispose();
    }
    await active.rpc<void>(
      _register.rpc!,
      params: {'p_origin': canonicalBackendUrl(origin), 'p_key': key},
    );
  }

  @override
  Future<void> apply(PublicWorkspace workspace) async {
    final registry = connections;
    if (registry == null) throw StateError('sign in required');
    await registry.use(
      workspace.source,
      (client) => client.rpc<void>(
        _request.rpc!,
        params: {'p_workspace': workspace.id},
      ),
    );
  }
}
