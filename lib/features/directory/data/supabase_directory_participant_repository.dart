// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/connected_installations.dart';
import '../../../core/public_network/data/public_network_client.dart';
import '../../../core/public_network/public_network_negotiator.dart';
import '../../../core/public_network/public_network_operations.dart';
import '../domain/public_workspace.dart';

/// #1847 — the PARTICIPANT interface: a signed-in account acting for
/// itself. Registering probes the endpoint anonymously first; asking to
/// join goes through the account's own session on the card's installation.
///
/// #1847 B — every mutation negotiates its version with the installation
/// that will perform it, BEFORE anything is sent, and names that version
/// in `x-deskilo-operation`, which the server revalidates. What this
/// client cannot honour there is a [PublicActionRefusal]; nothing is sent.
class SupabaseDirectoryParticipantRepository
    implements DirectoryParticipantRepository {
  SupabaseDirectoryParticipantRepository(
    this.active,
    this.connections, {
    PublicNetworkNegotiator? negotiator,
    http.Client Function()? transport,
  }) : negotiator = negotiator ?? PublicNetworkNegotiator(),
       transport = transport ?? http.Client.new;
  final SupabaseClient active;
  final ConnectedInstallations? connections;
  final PublicNetworkNegotiator negotiator;
  final http.Client Function() transport;

  static const _probe = PublicNetworkOperations.directoryWorkspacesSearch;
  static const _register = PublicNetworkOperations.directorySourcesRegister;
  static const _request = PublicNetworkOperations.workspaceProfileRequest;

  /// The header that carries the negotiated version.
  static const operationHeader = 'x-deskilo-operation';

  /// Sends [call] and turns the server's version refusal into the typed
  /// outcome, forgetting what [origin] said so the next action asks again.
  Future<void> _revalidated(
    String origin,
    PublicNegotiation negotiation,
    Future<void> Function() call,
  ) async {
    try {
      await call();
      // ignore: catch_no_st — rethrows, or throws the typed refusal.
    } on PostgrestException catch (e) {
      if (e.message != publicNetworkVersionRefusal) rethrow;
      negotiator.forget(origin);
      throw PublicActionRefusal(
        negotiation.operation.id,
        PublicRefusalReason.versionUnsupported,
        byServer: true,
      );
    }
  }

  @override
  Future<void> register(String origin, String key) async {
    if (validateBackendEndpoint(origin, key) != null) {
      throw StateError('invalid public endpoint');
    }
    final home = Uri.parse(active.rest.url).origin;
    final negotiation = await negotiator.negotiate(
      home,
      active.auth.headers['apikey']!,
      _register,
    );
    final client = SupabaseClient(
      origin,
      key,
      httpClient: OriginOnlyClient(origin, transport()),
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
    await _revalidated(
      home,
      negotiation,
      () => active
          .rpc<void>(
            _register.rpc!,
            params: {'p_origin': canonicalBackendUrl(origin), 'p_key': key},
          )
          .setHeader(operationHeader, negotiation.header),
    );
  }

  @override
  Future<void> apply(PublicWorkspace workspace) async {
    final registry = connections;
    if (registry == null) throw StateError('sign in required');
    final negotiation = await negotiator.negotiate(
      workspace.source,
      workspace.key,
      _request,
    );
    await _revalidated(
      workspace.source,
      negotiation,
      () => registry.use(
        workspace.source,
        (client) => client
            .rpc<void>(_request.rpc!, params: {'p_workspace': workspace.id})
            .setHeader(operationHeader, negotiation.header),
      ),
    );
  }
}
