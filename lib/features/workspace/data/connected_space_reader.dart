// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 -- the member's workspaces on a connected installation, read through
// the PINNED client of that installation only. The root client is never a
// fallback: whatever goes wrong is the typed ConnectionFailure of the pool.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connected_installations.dart';
import '../domain/workspace.dart';

/// Reads the workspaces [client]'s account may see on its own server.
typedef ConnectedWorkspaceReader =
    Future<List<Workspace>> Function(SupabaseClient client);

/// The workspace [workspaceId] of the connected installation [source], read
/// with that installation's own pinned client; the lease is given back
/// whatever the answer. Not connected / replaced / expired / disconnected
/// rethrow as the pool's typed [ConnectionFailure]; a workspace that
/// installation does not show this account is [ConnectionFailureReason.denied].
Future<Workspace> readConnectedWorkspace(
  ConnectedInstallations pool,
  ConnectedWorkspaceReader read,
  String source,
  String workspaceId,
) async {
  final pin = await pool.pin(source);
  try {
    final spaces = await read(pin.client);
    // The connection may have ended while the answer was in flight: its
    // answer then belongs to nobody (throws the lease's typed end).
    pin.client;
    for (final space in spaces) {
      if (space.id == workspaceId) return space;
    }
    throw ConnectionFailure(source, ConnectionFailureReason.denied);
  } finally {
    pin.release();
  }
}
