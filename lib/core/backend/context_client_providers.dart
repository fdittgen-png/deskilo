// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 C1 -- the providers of the context clients. This file and the
// bootstrap are where the process-wide client is named; everything else
// receives a client (or a context) from here.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
@riverpod
SupabaseClient workspaceClient(Ref ref, String installationId) =>
    ref.watch(contextClientsProvider).workspace(installationId);

@Riverpod(keepAlive: true)
InstallationIdReader installationIdReader(Ref ref) => readInstallationId;

/// Finds the host of a workspace; the combined deployment's is the
/// installation the app is signed in to.
@Riverpod(keepAlive: true)
WorkspaceHostResolver workspaceHostResolver(Ref ref) =>
    ActiveInstallationHostResolver(
      ref.watch(personalClientProvider),
      ref.watch(installationIdReaderProvider),
    );

@Riverpod(keepAlive: true)
EpochLedger epochLedger(Ref ref) => EpochLedger();
