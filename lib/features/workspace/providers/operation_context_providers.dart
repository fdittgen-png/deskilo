// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 C1 -- produces the personal and workspace contexts from the root
// personal session, the selected workspace and the settings capture. Every
// input is watched BEFORE the first await, so a later selection (W-B instead
// of W-A, another account) rebuilds the context rather than retargeting an
// operation already under way; the personal context does not depend on the
// selected workspace at all.
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connected_installations.dart'
    show ConnectionFailure, ConnectionFailureReason;
import '../../../core/backend/context_client_providers.dart';
import '../../../core/backend/context_clients.dart';
import '../../../core/backend/operation_context.dart';
import '../../../core/session/session_source.dart';
import 'settings_providers.dart';
import 'workspace_providers.dart';

part 'operation_context_providers.g.dart';

/// Who is signed in at the personal home, or null when nobody is.
@Riverpod(keepAlive: true)
Future<PersonalContext?> personalContext(Ref ref) async {
  final client = ref.watch(personalClientProvider);
  final read = ref.watch(installationIdReaderProvider);
  final ledger = ref.watch(epochLedgerProvider);
  final subject = await ref.watch(sessionStateProvider.future);
  if (subject == null) return null;
  final identity = CanonicalIdentity(
    issuer: nativeIssuerOf(client),
    subject: subject,
  );
  final home = await read(client);
  return PersonalContext(
    identity: identity,
    homeInstallationId: home,
    personalLocalUserId: subject,
    personalEpoch: ledger.epochOf(
      'personal',
      '${identity.issuer}|$subject|$home',
    ),
  );
}

/// The context of the selected workspace, captured whole: person, verified
/// target, local account, both epochs, settings and time zone. Null while
/// nobody is signed in or no workspace is selected.
@Riverpod(keepAlive: true)
Future<WorkspaceContext?> workspaceContext(Ref ref) async {
  final personalAnswer = ref.watch(personalContextProvider.future);
  final workspaceAnswer = ref.watch(currentWorkspaceProvider.future);
  final settingsAnswer = ref.watch(currentSettingsCaptureProvider.future);
  final resolver = ref.watch(workspaceHostResolverProvider);
  final clients = ref.watch(contextClientsProvider);
  final ledger = ref.watch(epochLedgerProvider);

  final personal = await personalAnswer;
  final workspace = await workspaceAnswer;
  final settings = await settingsAnswer;
  if (personal == null || workspace == null || settings == null) return null;

  final host = await resolver.resolve(workspace.id);
  final lease = host.lease;
  if (!ref.mounted) {
    lease?.release();
    return null;
  }
  clients.registerWorkspace(host.installationId, host.client);
  if (lease != null) {
    // #2562 -- the host's pinned client lives as long as this context. When
    // its connection ends (disconnect, replacement, sign-out, closed pool)
    // the registration is withdrawn and the context re-resolves: it then
    // refuses with the typed reason instead of serving a dead client.
    ref.onDispose(lease.release);
    unawaited(
      lease.ended.then((_) {
        clients.unregisterWorkspace(host.installationId, host.client);
        if (ref.mounted) ref.invalidateSelf();
      }),
    );
  }
  final target = WorkspaceTarget.local(
    installationId: host.installationId,
    workspaceId: workspace.id,
  );
  return WorkspaceContext(
    identity: personal.identity,
    target: target,
    workspaceLocalUserId: host.localUserId,
    personalEpoch: personal.personalEpoch,
    workspaceEpoch: ledger.epochOf(
      'workspace:${target.networkId}',
      '${host.localUserId}|${host.installationId}',
    ),
    settings: settings,
    timezone: workspace.timezone,
  );
}

/// #2564 O1 -- the client the selected workspace's operations run on: the
/// verified host client of the captured [WorkspaceContext]'s installation.
/// Dependents rebuild only when that installation changes. Until a context exists (signed out, no workspace
/// selected, still resolving) it is the root client -- the combined
/// deployment's one installation, where the two are the same object; a split
/// deployment's resolver (#2562) never yields the root client for a W target.
@Riverpod(keepAlive: true)
SupabaseClient selectedWorkspaceClient(Ref ref) {
  // Whole-context watch: an unchanged client compares equal, so dependents
  // rebuild only when the installation does.
  final context = ref.watch(workspaceContextProvider);
  final clients = ref.watch(contextClientsProvider);
  final installation = context.value?.target.installationId;
  if (installation == null) {
    // #2562 -- a workspace on a connected installation (a selection names
    // it) is never answered by the root client: while its context is still
    // resolving, or was refused, the answer is the typed refusal.
    final split = ref.watch(selectedWorkspaceHostProvider);
    if (split != null) {
      final error = context.error;
      throw error is ConnectionFailure
          ? error
          : ConnectionFailure(split.source, ConnectionFailureReason.unavailable);
    }
    return clients.legacyActive;
  }
  // Read from the registry, not a cached family: the client of an
  // installation changes when its connection is replaced.
  try {
    return clients.workspace(installation);
  } on UnverifiedInstallation {
    // #2564 -- the lease ended and the registration was withdrawn, but the
    // context has not re-resolved yet: a connected workspace answers with
    // the typed refusal in that window too, never a raw registry error.
    final split = ref.watch(selectedWorkspaceHostProvider);
    if (split == null) rethrow;
    throw ConnectionFailure(split.source, ConnectionFailureReason.unavailable);
  }
}
