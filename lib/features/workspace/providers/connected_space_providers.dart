// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 -- entering a workspace of a connected installation: the member's
// workspaces are read through that installation's pinned client, then the
// selection (workspace id + source) is made so the app is pinned,
// channel-backed and root-free for it. A refusal changes nothing.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../data/connected_space_reader.dart';
import '../domain/workspace.dart';
import 'workspace_providers.dart';

part 'connected_space_providers.g.dart';

/// Enters workspaces of connected installations. Only the latest entry may
/// select: an answer that arrives after a newer request (installation A
/// after the person chose B) selects nothing.
@Riverpod(keepAlive: true)
class ConnectedSpaceEntry extends _$ConnectedSpaceEntry {
  int _latest = 0;

  @override
  void build() {}

  /// The entered workspace, or null when a newer entry superseded this one.
  /// Throws the typed [ConnectionFailure] of the pool (or `denied` for a
  /// workspace that installation does not show) and then selects nothing.
  Future<Workspace?> enter(String source, String workspaceId) async {
    final attempt = ++_latest;
    final pool = ref.read(connectedInstallationsProvider);
    final space = await readConnectedWorkspace(
      pool,
      ref.read(connectedWorkspaceReaderProvider),
      source,
      workspaceId,
    );
    if (attempt != _latest || !ref.mounted) return null;
    ref
        .read(activeWorkspaceIdProvider.notifier)
        .activateConnected(workspaceId, source);
    return space;
  }
}
