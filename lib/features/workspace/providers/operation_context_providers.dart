// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 C1 -- produces the personal and workspace contexts from the root
// personal session, the selected workspace and the settings capture. Every
// input is watched BEFORE the first await, so a later selection (W-B instead
// of W-A, another account) rebuilds the context rather than retargeting an
// operation already under way; the personal context does not depend on the
// selected workspace at all.
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
  clients.registerWorkspace(host.installationId, host.client);
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
