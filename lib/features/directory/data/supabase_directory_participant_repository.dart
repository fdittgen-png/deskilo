// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/connected_installations.dart';
import '../../../core/trace/trace_logger.dart';
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
    this.directory = globalDirectoryEndpoint,
  }) : negotiator = negotiator ?? PublicNetworkNegotiator(),
       transport = transport ?? http.Client.new;
  final SupabaseClient active;
  final ConnectedInstallations? connections;
  final PublicNetworkNegotiator negotiator;
  final http.Client Function() transport;

  /// #2343 — the server that carries the global directory. A link is
  /// written THERE, whatever server this device uses; from another
  /// server it goes through the account's connection to the directory.
  final BackendEndpoint directory;

  static const _probe = PublicNetworkOperations.directoryWorkspacesSearch;
  static const _sources = PublicNetworkOperations.directorySourcesList;
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

  SupabaseClient _anonymous(String origin, String key) => SupabaseClient(
    origin,
    key,
    httpClient: OriginOnlyClient(origin, transport()),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  /// Reads one published card of [origin], anonymously: the evidence that
  /// it answers with spaces this app can list.
  Future<void> _probeCards(String origin, String key) async {
    final client = _anonymous(origin, key);
    try {
      await client
          .from(_probe.relation!)
          .select('workspace_id')
          .limit(1)
          .timeout(Duration(seconds: _probe.timeoutSeconds ?? 12));
    } finally {
      await client.dispose();
    }
  }

  /// #2343 — [action] with a session on the directory's server: this
  /// device's own when it uses that server, else the account's connection
  /// to it ([ConnectionFailureReason.notConnected] when there is none).
  Future<void> _onDirectory(Future<void> Function(SupabaseClient) action) {
    if (Uri.parse(active.rest.url).origin == directory.url) {
      return action(active);
    }
    final registry = connections;
    if (registry == null) {
      throw ConnectionFailure(
        directory.url,
        ConnectionFailureReason.notConnected,
      );
    }
    return registry.use(directory.url, action);
  }

  @override
  Future<void> register(String origin, String key) async {
    if (validateBackendEndpoint(origin, key) != null) {
      throw StateError('invalid public endpoint');
    }
    final negotiation = await negotiator.negotiate(
      directory.url,
      directory.key,
      _register,
    );
    await _probeCards(origin, key);
    await _revalidated(
      directory.url,
      negotiation,
      () => _onDirectory(
        (client) => client
            .rpc<void>(
              _register.rpc!,
              params: {'p_origin': canonicalBackendUrl(origin), 'p_key': key},
            )
            .setHeader(operationHeader, negotiation.header),
      ),
    );
  }

  @override
  Future<DirectoryLinkState> linkState(String origin, String key) async {
    final canonical = canonicalBackendUrl(origin);
    if (canonical == null || validateBackendEndpoint(origin, key) != null) {
      throw StateError('invalid public endpoint');
    }
    if (canonical == directory.url) return DirectoryLinkState.directory;
    try {
      await _probeCards(canonical, key);
    } catch (e, st) {
      TraceLogger.instance.warn(
        'directory',
        'server cannot be linked',
        error: e.runtimeType,
        stackTrace: st,
      );
      return DirectoryLinkState.unreachable;
    }
    // The registered origins, read the way Discover reads them: page by
    // page, anonymously, until the origin shows or the list ends.
    final size = _sources.pageSize!;
    final client = _anonymous(directory.url, directory.key);
    try {
      for (var page = 0; page < 50; page++) {
        final rows = await client
            .from(_sources.relation!)
            .select(_sources.selectClause)
            .order('origin')
            .range(page * size, page * size + size - 1)
            .timeout(Duration(seconds: _sources.timeoutSeconds ?? 12));
        if (rows.any((row) => row['origin'] == canonical)) {
          return DirectoryLinkState.linked;
        }
        if (rows.length < size) break;
      }
    } finally {
      await client.dispose();
    }
    return DirectoryLinkState.linkable;
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
