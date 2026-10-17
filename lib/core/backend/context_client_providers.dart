// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 C1 -- the providers of the context clients. This file and the
// bootstrap are where the process-wide client is named; everything else
// receives a client (or a context) from here.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connected_installation_providers.dart';
import 'connected_pool_host_resolver.dart';
import 'context_clients.dart';
import 'operation_context.dart';

part 'context_client_providers.g.dart';

@Riverpod(keepAlive: true)
ContextClients contextClients(Ref ref) {
  final active = Supabase.instance.client;
  return ContextClients(active, active);
}

/// The long-lived client of the personal home (P).
@Riverpod(keepAlive: true)
SupabaseClient personalClient(Ref ref) =>
    ref.watch(contextClientsProvider).personal;

/// The client of the verified workspace installation [installationId].
/// Throws [UnverifiedInstallation] for an id no context has verified.
@Riverpod(keepAlive: true)
SupabaseClient workspaceClient(Ref ref, String installationId) =>
    ref.watch(contextClientsProvider).workspace(installationId);

@Riverpod(keepAlive: true)
InstallationIdReader installationIdReader(Ref ref) => readInstallationId;

/// The connected installation the selected workspace lives on, or none
/// when it lives on the installation the app is signed in to.
@Riverpod(keepAlive: true)
class SelectedWorkspaceHost extends _$SelectedWorkspaceHost {
  @override
  ({String workspaceId, String source})? build() => null;

  void select(String workspaceId, String source) =>
      state = (workspaceId: workspaceId, source: source);

  void clear() => state = null;
}

/// Finds the host of a workspace: the connected installation its selection
/// names, else the installation the app is signed in to.
@Riverpod(keepAlive: true)
WorkspaceHostResolver workspaceHostResolver(Ref ref) {
  final active = ActiveInstallationHostResolver(
    ref.watch(personalClientProvider),
    ref.watch(installationIdReaderProvider),
  );
  final selected = ref.watch(selectedWorkspaceHostProvider);
  return ConnectedPoolHostResolver(
    active: active,
    root: ref.watch(personalClientProvider),
    pool: () => ref.read(connectedInstallationsProvider),
    sourceOf: (workspaceId) =>
        selected != null && selected.workspaceId == workspaceId
        ? selected.source
        : null,
  );
}

@Riverpod(keepAlive: true)
EpochLedger epochLedger(Ref ref) => EpochLedger();
