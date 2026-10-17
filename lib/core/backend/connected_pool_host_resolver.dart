// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 -- the workspace host resolver of a split deployment: a workspace
// that lives on a connected installation is reached through that
// installation's OWN verified client from the connected pool, with that
// target's own session. Whatever goes wrong (not connected, quarantined,
// expired, changed, outage) is a typed refusal; the request is never
// answered by the root client or by another host.
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connected_installations.dart';
import 'context_clients.dart';

/// The connected installation (its origin) that hosts [workspaceId], or null
/// when it lives on the installation the app is signed in to.
typedef WorkspaceSourceLookup = String? Function(String workspaceId);

class ConnectedPoolHostResolver implements WorkspaceHostResolver {
  ConnectedPoolHostResolver({
    required this.active,
    required this.root,
    required this.pool,
    required this.sourceOf,
  });

  final WorkspaceHostResolver active;

  /// The root (personal) client: a split target may never resolve to it.
  final SupabaseClient root;
  final ConnectedInstallations Function() pool;
  final WorkspaceSourceLookup sourceOf;

  @override
  Future<ResolvedWorkspaceHost> resolve(String workspaceId) async {
    final source = sourceOf(workspaceId);
    if (source == null) return active.resolve(workspaceId);
    final pooled = await pool().open(source);
    if (identical(pooled.client, root)) {
      throw UnverifiedInstallation(pooled.installationId);
    }
    return ResolvedWorkspaceHost(
      installationId: pooled.installationId,
      client: pooled.client,
      localUserId: pooled.account,
    );
  }
}
