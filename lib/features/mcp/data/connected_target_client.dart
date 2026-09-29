// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — a connected installation as a registry client. Each call runs
// through [ConnectedInstallations.use]: a fresh SDK client seeded from
// that installation's own encrypted record (namespaced by origin and
// owning account), refreshed there, re-checked against the installation
// id it was connected as, and disposed after the call. No other
// installation's session or the main app's is read or written.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connected_installations.dart';
import '../../auth/data/supabase_identity_binding_repository.dart';
import '../../auth/data/supabase_second_factor_repository.dart';
import '../domain/mcp_client.dart';
import '../domain/mcp_context.dart';
import 'supabase_action_confirmation_repository.dart';
import 'supabase_mcp_admin_repository.dart';
import 'supabase_mcp_connection_repository.dart';

McpRepositories supabaseMcpRepositories(SupabaseClient client) =>
    McpRepositories(
      admin: SupabaseMcpAdminRepository(client),
      connections: SupabaseMcpConnectionRepository(client),
      confirmations: SupabaseActionConfirmationRepository(client),
      identity: SupabaseIdentityBindingRepository(client),
      secondFactor: SupabaseSecondFactorRepository(client),
    );

class ConnectedMcpTargetClient implements McpTargetClient {
  ConnectedMcpTargetClient(this.key, this._connections, this._source);

  @override
  final McpTargetKey key;
  final ConnectedInstallations _connections;
  final String _source;
  bool _disposed = false;

  @override
  Future<T> run<T>(Future<T> Function(McpRepositories repositories) action) {
    if (_disposed) throw const McpTargetChanged();
    return _connections.use(
      _source,
      (client) => action(supabaseMcpRepositories(client)),
    );
  }

  /// Each call already disposed its SDK client; the record itself stays
  /// until the person disconnects the installation.
  @override
  Future<void> dispose() async => _disposed = true;
}
